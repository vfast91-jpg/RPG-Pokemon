extends "res://scripts/demo_route_stage50_mirror_v1.gd"

# Travel-companion extension event.
# Unlocks exactly when stage 25 begins, is guaranteed among that stage's three
# route choices, and remains a normal random route option from stage 25 onward.

const EVENT_CAMPFIRE: String = "campfire"
const CAMPFIRE_UNLOCK_STAGE: int = 25
const CAMPFIRE_EXTENSION_STAGES: int = 5

var _campfire_unlock_announced: bool = false
var _campfire_unlock_overlay: Control


func start_route() -> void:
    # A new adventure must always receive the stage-25 introduction again.
    # Saved adventures restore this flag through RunSaveManager instead.
    _campfire_unlock_announced = false
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    var should_announce: bool = (
        stage == CAMPFIRE_UNLOCK_STAGE
        and not _campfire_unlock_announced
    )

    # Set this before the inherited stage checkpoint is saved so reloading stage
    # 25 can never repeat the tutorial popup.
    if should_announce:
        _campfire_unlock_announced = true

    super._show_stage_choices(message)

    if should_announce and visible:
        call_deferred("_show_campfire_unlock_popup")


func _route_event_pool_for_stage(current_stage: int) -> Array[String]:
    var pool: Array[String] = super._route_event_pool_for_stage(current_stage)
    if current_stage >= CAMPFIRE_UNLOCK_STAGE and not pool.has(EVENT_CAMPFIRE):
        pool.append(EVENT_CAMPFIRE)
    return pool


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    if current_stage != CAMPFIRE_UNLOCK_STAGE:
        return choices

    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == EVENT_CAMPFIRE:
            return choices

    var campfire_choice: Dictionary = _active_event_choice(EVENT_CAMPFIRE, current_stage)
    if choices.size() < 3:
        choices.append(campfire_choice)
    else:
        # Preserve two naturally rolled options and reserve exactly one of the
        # three stage-25 slots for the newly introduced mechanic.
        choices[choices.size() - 1] = campfire_choice
    return choices


func _active_event_choice(kind: String, current_stage: int) -> Dictionary:
    if kind == EVENT_CAMPFIRE:
        return {
            "kind": EVENT_CAMPFIRE,
            "label": "🔥 Gemeinsam am Lagerfeuer",
            "hint": "Wähle einen Reisegefährten. Er bleibt 5 weitere Etappen bei dir."
        }
    return super._active_event_choice(kind, current_stage)


func _choose_path(choice: Dictionary) -> void:
    var kind: String = str(choice.get("kind", ""))
    if kind != EVENT_CAMPFIRE:
        super._choose_path(choice)
        return

    _set_path_buttons_disabled(true)
    _clear_container(capture_actions)
    continue_button.visible = false
    path_box.visible = false
    stage_xp_multiplier = 1.0
    _begin_campfire_event()


func _begin_campfire_event() -> void:
    event_label.text = (
        "[b]🔥 Gemeinsam am Lagerfeuer[/b]\n"
        + "Wähle einen Reisegefährten. Er bleibt [b]5 weitere Etappen[/b] bei dir."
    )

    var added_button: bool = false
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value as Dictionary
        _ensure_member_companion_duration(member)
        team[index] = member

        var remaining: int = int(member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT))
        var companion_name: String = str(member.get("name", "Pokémon"))
        capture_actions.add_child(
            _make_route_pokemon_choice_card(
                member,
                "🔥 Lagerfeuer · 🧭 %d → %d gemeinsame Etappen" % [
                    remaining,
                    remaining + CAMPFIRE_EXTENSION_STAGES
                ],
                "%s bleibt nach dieser Rast 5 Etappen länger bei dir." % companion_name,
                _on_campfire_companion_selected.bind(index)
            )
        )
        added_button = true

    if not added_button:
        event_label.text = "Für das Lagerfeuer ist gerade kein Reisegefährte verfügbar."
        continue_button.visible = true


func _on_campfire_companion_selected(team_index: int) -> void:
    if team_index < 0 or team_index >= team.size():
        return

    var member_value: Variant = team[team_index]
    if not (member_value is Dictionary):
        return

    var member: Dictionary = member_value as Dictionary
    _ensure_member_companion_duration(member)

    var previous_remaining: int = int(
        member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT)
    )
    var new_remaining: int = previous_remaining + CAMPFIRE_EXTENSION_STAGES
    member[COMPANION_REMAINING_KEY] = new_remaining
    team[team_index] = member

    var companion_name: String = str(member.get("name", "Dein Reisegefährte"))
    var summary: String = (
        "[b]🔥 Gemeinsam am Lagerfeuer[/b]\n"
        + "%s genießt die gemeinsame Zeit und möchte noch ein Stück länger mit dir reisen.\n"
        + "[b]+5 Etappen[/b] · 🧭 %d → %d Etappen"
    ) % [companion_name, previous_remaining, new_remaining]

    _clear_container(capture_actions)
    last_route_message = summary
    event_label.text = summary
    continue_button.visible = true
    _refresh_team_panel()

    # The extension is committed immediately. The inherited save layer turns
    # this into the normal ready-for-battle checkpoint, so reloads cannot grant
    # the same +5 twice.
    _autosave_run("team_change")


func _show_campfire_unlock_popup() -> void:
    if stage != CAMPFIRE_UNLOCK_STAGE or not visible:
        return

    var overlay: Control = _ensure_campfire_unlock_overlay()
    overlay.visible = true


func _ensure_campfire_unlock_overlay() -> Control:
    if _campfire_unlock_overlay != null and is_instance_valid(_campfire_unlock_overlay):
        return _campfire_unlock_overlay

    var overlay := ColorRect.new()
    overlay.name = "CampfireUnlockOverlay"
    overlay.color = Color("07100de0")
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _campfire_unlock_overlay = overlay

    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(520.0, 0.0)
    card.add_theme_stylebox_override(
        "panel",
        _campfire_unlock_card_style()
    )
    center.add_child(card)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    card.add_child(content)

    var eyebrow := Label.new()
    eyebrow.text = "ETAPPE 25 · NEUE MÖGLICHKEIT"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", Color("e0c968"))
    content.add_child(eyebrow)

    var title := Label.new()
    title.text = "🔥  Gemeinsam am Lagerfeuer"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 19)
    title.add_theme_color_override("font_color", Color("fff0ad"))
    content.add_child(title)

    var intro := Label.new()
    intro.text = "Deine Reisegefährten können jetzt länger an deiner Seite bleiben."
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.add_theme_font_size_override("font_size", 11)
    intro.add_theme_color_override("font_color", Color("dce8e2"))
    content.add_child(intro)

    var feature := PanelContainer.new()
    feature.add_theme_stylebox_override(
        "panel",
        _panel(Color("182822"), Color("55796a"), 8, 9.0)
    )
    content.add_child(feature)

    var feature_row := HBoxContainer.new()
    feature_row.add_theme_constant_override("separation", 10)
    feature.add_child(feature_row)

    var icon := Label.new()
    icon.text = "🧭"
    icon.custom_minimum_size = Vector2(34.0, 34.0)
    icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    icon.add_theme_font_size_override("font_size", 22)
    feature_row.add_child(icon)

    var feature_copy := VBoxContainer.new()
    feature_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    feature_copy.add_theme_constant_override("separation", 2)
    feature_row.add_child(feature_copy)

    var feature_title := Label.new()
    feature_title.text = "+5 gemeinsame Etappen"
    feature_title.add_theme_font_size_override("font_size", 13)
    feature_title.add_theme_color_override("font_color", Color("9fe7bd"))
    feature_copy.add_child(feature_title)

    var feature_text := Label.new()
    feature_text.text = (
        "Wähle am Lagerfeuer ein Pokémon aus. Auf Etappe 25 ist diese "
        + "Möglichkeit garantiert; danach kann sie erneut auftauchen."
    )
    feature_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feature_text.add_theme_font_size_override("font_size", 10)
    feature_text.add_theme_color_override("font_color", Color("dce8e2"))
    feature_copy.add_child(feature_text)

    var understood := Button.new()
    understood.text = "VERSTANDEN  →"
    understood.custom_minimum_size = Vector2(0.0, 36.0)
    understood.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    understood.pressed.connect(_dismiss_campfire_unlock_popup)
    _style_route_decision_button(understood, true)
    content.add_child(understood)

    return overlay


func _campfire_unlock_card_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = _panel(Color("12251f"), Color("e0c968"), 12, 16.0)
    style.set_border_width_all(2)
    style.shadow_color = Color("00000099")
    style.shadow_size = 10
    return style


func _dismiss_campfire_unlock_popup() -> void:
    if _campfire_unlock_overlay == null or not is_instance_valid(_campfire_unlock_overlay):
        return
    _campfire_unlock_overlay.queue_free()
    _campfire_unlock_overlay = null
