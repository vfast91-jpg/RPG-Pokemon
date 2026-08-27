extends "res://scripts/demo_route_boss_reinforcement_v1.gd"

# Travel companions deliberately stay for a limited part of the adventure.
# The stage on which a Pokemon joins counts as the first shared stage. A member
# therefore leaves after 30 completed stages together, independent of KOs,
# level-ups, evolutions or battle type.

const COMPANION_STAGE_LIMIT: int = 30
const COMPANION_REMAINING_KEY: String = "travel_stages_remaining"

# This is the stage for which the current remaining values are already valid.
# Keeping the checkpoint makes repeated redraws/resume screens on the same stage
# harmless: a stage can consume companion duration at most once.
var _companion_duration_checkpoint_stage: int = 0

# Departures are presented one at a time after the stage transition. Keeping the
# visual queue separate from the duration logic means the established 30-stage
# rule and team removal timing remain untouched.
var _companion_departure_queue: Array[Dictionary] = []
var _companion_departure_overlay: Control
var _companion_departure_popup_pending: bool = false


func start_route() -> void:
    # A genuinely new adventure starts a fresh duration clock. Saved adventures
    # restore this variable through RunSaveManager instead of calling start_route.
    _companion_duration_checkpoint_stage = 0
    _companion_departure_queue.clear()
    _companion_departure_popup_pending = false
    if _companion_departure_overlay != null and is_instance_valid(_companion_departure_overlay):
        _companion_departure_overlay.queue_free()
    _companion_departure_overlay = null
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    var departed: Array[String] = _advance_companion_durations_to_stage(stage)
    var combined_message: String = _message_with_companion_departures(message, departed)

    if not departed.is_empty():
        _refresh_team_panel()

    # Without a reserve system there is no legal battle party if every current
    # companion leaves on the same transition. End cleanly instead of allowing
    # a later battle button to soft-lock on an empty team.
    if not departed.is_empty() and team.is_empty():
        _schedule_companion_departure_popup()
        var finish_message: String = combined_message
        if not finish_message.is_empty():
            finish_message += "\n\n"
        finish_message += "Dein letzter Reisegefährte ist weitergezogen. Dein Abenteuer endet hier."
        _finish_run(false, finish_message)
        return

    super._show_stage_choices(combined_message)

    if not departed.is_empty():
        _schedule_companion_departure_popup()


func _advance_companion_durations_to_stage(target_stage: int) -> Array[String]:
    _ensure_team_companion_durations()

    var normalized_stage: int = maxi(1, target_stage)
    if _companion_duration_checkpoint_stage <= 0:
        _companion_duration_checkpoint_stage = normalized_stage
        return []

    if normalized_stage <= _companion_duration_checkpoint_stage:
        return []

    var completed_stages: int = normalized_stage - _companion_duration_checkpoint_stage
    _companion_duration_checkpoint_stage = normalized_stage

    var departed: Array[String] = []
    for index: int in range(team.size() - 1, -1, -1):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value
        var remaining: int = maxi(0, int(member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT)))
        remaining = maxi(0, remaining - completed_stages)
        member[COMPANION_REMAINING_KEY] = remaining

        if remaining <= 0:
            var companion_name: String = str(member.get("name", "Pokémon"))
            departed.push_front(companion_name)
            _companion_departure_queue.push_front({
                "species_id": str(member.get("species_id", "")),
                "name": companion_name
            })
            team.remove_at(index)
        else:
            team[index] = member

    return departed


func _ensure_team_companion_durations() -> void:
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        _ensure_member_companion_duration(member)
        team[index] = member


func _ensure_member_companion_duration(member: Dictionary) -> void:
    # Missing means old save/newly created member. Existing values are never
    # reset here, including low values carried through evolution or save/load.
    if not member.has(COMPANION_REMAINING_KEY):
        member[COMPANION_REMAINING_KEY] = COMPANION_STAGE_LIMIT


func _ensure_pending_companion_duration() -> void:
    if pending_capture.is_empty():
        return
    _ensure_member_companion_duration(pending_capture)


func _accept_pending_capture() -> void:
    _ensure_pending_companion_duration()
    super._accept_pending_capture()


func _replace_team_member(index: int) -> void:
    _ensure_pending_companion_duration()
    super._replace_team_member(index)


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    # The current battle stack returns full member dictionaries, but preserve
    # this route-owned metadata defensively. A future battle refactor that
    # rebuilds combatants from a fixed field set must never reset a companion to
    # a fresh 30 stages simply because it did not know this key.
    var protected_team: Array = _preserve_companion_duration_metadata(updated_team)
    super._on_route_battle_finished(victory, protected_team)


func _preserve_companion_duration_metadata(updated_team: Array) -> Array:
    var protected_team: Array = updated_team.duplicate(true)
    var count: int = mini(team.size(), protected_team.size())

    for index: int in range(count):
        var current_value: Variant = team[index]
        var updated_value: Variant = protected_team[index]
        if not (current_value is Dictionary) or not (updated_value is Dictionary):
            continue

        var current_member: Dictionary = current_value
        var updated_member: Dictionary = updated_value
        if (
            not updated_member.has(COMPANION_REMAINING_KEY)
            and current_member.has(COMPANION_REMAINING_KEY)
        ):
            updated_member[COMPANION_REMAINING_KEY] = int(
                current_member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT)
            )
            protected_team[index] = updated_member

    return protected_team


func _message_with_companion_departures(message: String, departed: Array[String]) -> String:
    if departed.is_empty():
        return message

    var lines: Array[String] = []
    for companion_name: String in departed:
        lines.append("[b]🧭 %s[/b] setzt seine eigene Reise fort und verlässt dein Team." % companion_name)

    var departure_text: String = "\n".join(lines)
    if message.is_empty():
        return departure_text
    return message + "\n\n" + departure_text


func _schedule_companion_departure_popup() -> void:
    if _companion_departure_queue.is_empty():
        return
    _companion_departure_popup_pending = true
    call_deferred("_try_show_companion_departure_popup")


func _on_levelup_continue() -> void:
    super._on_levelup_continue()
    if _companion_departure_popup_pending:
        call_deferred("_try_show_companion_departure_popup")


func _try_show_companion_departure_popup() -> void:
    if not _companion_departure_popup_pending:
        return
    if _companion_departure_queue.is_empty():
        _companion_departure_popup_pending = false
        return
    if (
        _companion_departure_overlay != null
        and is_instance_valid(_companion_departure_overlay)
    ):
        return

    # Reuse the established post-battle presentation gate. This is the same
    # safety pattern used by the repaired campfire-unlock popup and prevents a
    # departure window from racing an already queued/visible level-up popup.
    if _levelup_presentation_pending():
        return

    _companion_departure_popup_pending = false
    _show_next_companion_departure_popup()


func _show_next_companion_departure_popup() -> void:
    if _companion_departure_queue.is_empty():
        return

    var event: Dictionary = _companion_departure_queue.pop_front()
    var overlay: Control = _build_companion_departure_overlay(event)
    _companion_departure_overlay = overlay
    overlay.visible = true


func _build_companion_departure_overlay(event: Dictionary) -> Control:
    var overlay := ColorRect.new()
    overlay.name = "CompanionDepartureOverlay"
    overlay.color = Color("07100de0")
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 120
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(410.0, 0.0)
    card.add_theme_stylebox_override(
        "panel",
        _companion_departure_card_style()
    )
    center.add_child(card)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    card.add_child(content)

    var eyebrow := Label.new()
    eyebrow.text = "🧭 GEMEINSAME REISE"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", Color("e0c968"))
    content.add_child(eyebrow)

    var sprite := TextureRect.new()
    sprite.custom_minimum_size = Vector2(120.0, 105.0)
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if battle_demo != null and battle_demo.has_method("route_species_texture"):
        var texture_value: Variant = battle_demo.route_species_texture(str(event.get("species_id", "")))
        if texture_value is Texture2D:
            sprite.texture = texture_value as Texture2D
    content.add_child(sprite)

    var companion_name: String = str(event.get("name", "Pokémon"))
    var name_label := Label.new()
    name_label.text = companion_name
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 19)
    name_label.add_theme_color_override("font_color", Color("fff0ad"))
    content.add_child(name_label)

    var departure_text := Label.new()
    departure_text.text = "%s setzt seine eigene Reise fort und verlässt dein Team." % companion_name
    departure_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    departure_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    departure_text.add_theme_font_size_override("font_size", 11)
    departure_text.add_theme_color_override("font_color", Color("dce8e2"))
    content.add_child(departure_text)

    var continue_departure := Button.new()
    continue_departure.text = "WEITER  →"
    continue_departure.custom_minimum_size = Vector2(0.0, 34.0)
    continue_departure.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    continue_departure.pressed.connect(_dismiss_companion_departure_popup)
    _style_route_decision_button(continue_departure, true)
    content.add_child(continue_departure)

    continue_departure.call_deferred("grab_focus")
    return overlay


func _companion_departure_card_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = _panel(Color("12251f"), Color("e0c968"), 12, 14.0)
    style.set_border_width_all(2)
    style.shadow_color = Color("00000099")
    style.shadow_size = 10
    return style


func _dismiss_companion_departure_popup() -> void:
    if _companion_departure_overlay != null and is_instance_valid(_companion_departure_overlay):
        _companion_departure_overlay.queue_free()
    _companion_departure_overlay = null

    if not _companion_departure_queue.is_empty():
        _companion_departure_popup_pending = true
        call_deferred("_try_show_companion_departure_popup")


func _companion_remaining_stages(member: Dictionary) -> int:
    return clampi(
        int(member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT)),
        0,
        999
    )


func _make_route_team_card(member: Dictionary, index: int) -> Control:
    _ensure_member_companion_duration(member)
    var card: Control = super._make_route_team_card(member, index)
    var remaining: int = _companion_remaining_stages(member)
    card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, 53.0)
    _add_companion_duration_below_xp(card, remaining)
    _set_companion_duration_tooltip(card, remaining)
    return card


func _add_companion_duration_below_xp(node: Node, remaining: int) -> bool:
    if node is VBoxContainer:
        var content := node as VBoxContainer
        var progress_bars: Array[ProgressBar] = []
        for content_child: Node in content.get_children():
            if content_child is ProgressBar:
                progress_bars.append(content_child as ProgressBar)

        if progress_bars.size() >= 2:
            var duration_label := Label.new()
            duration_label.name = "CompanionDurationLabel"
            duration_label.text = _companion_duration_card_text(remaining)
            duration_label.add_theme_font_size_override("font_size", 8)
            duration_label.add_theme_color_override("font_color", Color("d8d2a0"))
            duration_label.add_theme_constant_override("line_spacing", -5)
            duration_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            duration_label.tooltip_text = "Reisegefährte · noch %d gemeinsame Etappen" % remaining
            content.add_child(duration_label)
            content.move_child(duration_label, progress_bars[1].get_index() + 1)
            return true

    for child: Node in node.get_children():
        if _add_companion_duration_below_xp(child, remaining):
            return true
    return false


func _companion_duration_card_text(remaining: int) -> String:
    if remaining == 1:
        return "🧭 Noch 1 gemeinsame\n      Etappe"
    return "🧭 Noch %d gemeinsame\n      Etappen" % remaining


func _set_companion_duration_tooltip(node: Node, remaining: int) -> bool:
    if node is Button:
        var button: Button = node as Button
        if button.flat and button.text.is_empty():
            button.tooltip_text = "Reisegefährte · noch %d gemeinsame Etappen" % remaining
            return true

    for child: Node in node.get_children():
        if _set_companion_duration_tooltip(child, remaining):
            return true
    return false


func _show_route_member_info(index: int) -> void:
    super._show_route_member_info(index)
    if index < 0 or index >= team.size() or _route_info_body == null:
        return
    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return

    var remaining: int = _companion_remaining_stages(member_value as Dictionary)
    _route_info_body.text += (
        "\n\n[b]Reisegefährte[/b]\n"
        + "Noch %d gemeinsame Etappen, bevor dieses Pokémon seine eigene Reise fortsetzt."
    ) % remaining
