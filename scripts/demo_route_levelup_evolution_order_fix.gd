extends "res://scripts/demo_route_training_hp_cost.gd"

# Regression fix: a level-up must always be presented before an evolution
# unlocked by that level-up. The gameplay state may already have reached the
# new level when deferred UI callbacks are queued, so checking only whether the
# level-up overlay is currently visible leaves a race where the evolution popup
# can appear first.
#
# Route-run isolation:
# Progression presentation queues belong to exactly one route run. Without an
# explicit reset, an evolution that was queued in an earlier/aborted run can be
# presented much later in a new run even though the current Pokemon never
# evolved. This is especially misleading around level thresholds (for example
# Pichu Lv.14 while Pichu -> Pikachu is correctly configured for Lv.15).
#
# Capture presentation polish:
# The Fangwiese now keeps the caught Pokemon visually prominent with its sprite
# and opens the same complete between-battle member view used by the team cards
# (stats, radar chart and moves). A pending capture can be inspected before the
# player decides whether to replace a team member or decline it.

var _capture_preview_member: Dictionary = {}
var _capture_preview_team_index: int = -1


func start_route() -> void:
    _reset_progression_presentation_state()
    super.start_route()


func _reset_progression_presentation_state() -> void:
    _levelup_queue.clear()
    _evolution_queue.clear()
    _evolution_choice_queue.clear()
    _active_evolution_choice = {}

    if _levelup_overlay != null:
        _levelup_overlay.visible = false
    if _evolution_overlay != null:
        _evolution_overlay.visible = false
    if _evolution_choice_overlay != null:
        _evolution_choice_overlay.visible = false


func _show_stage_choices(message: String = "") -> void:
    _capture_preview_member = {}
    _capture_preview_team_index = -1
    super._show_stage_choices(message)


func _begin_capture_event() -> void:
    var team_size_before: int = team.size()
    _capture_preview_member = {}
    _capture_preview_team_index = -1

    super._begin_capture_event()

    if not pending_capture.is_empty():
        _capture_preview_member = pending_capture.duplicate(true)
    elif team.size() > team_size_before:
        var added_index: int = team.size() - 1
        var added_value: Variant = team[added_index]
        if added_value is Dictionary:
            _capture_preview_member = (added_value as Dictionary).duplicate(true)
            _capture_preview_team_index = added_index

    _add_capture_preview_card()


func _show_replace_choices() -> void:
    super._show_replace_choices()
    _add_capture_preview_card()


func _begin_capture_event_again() -> void:
    super._begin_capture_event_again()
    _add_capture_preview_card()


func _replace_team_member(index: int) -> void:
    var had_pending_capture: bool = not pending_capture.is_empty()
    super._replace_team_member(index)

    if had_pending_capture and index >= 0 and index < team.size():
        var accepted_value: Variant = team[index]
        if accepted_value is Dictionary:
            _capture_preview_member = (accepted_value as Dictionary).duplicate(true)
            _capture_preview_team_index = index
            _add_capture_preview_card()


func _decline_pending_capture() -> void:
    super._decline_pending_capture()
    _capture_preview_member = {}
    _capture_preview_team_index = -1


func _add_capture_preview_card() -> void:
    if capture_actions == null or _capture_preview_member.is_empty():
        return

    for child: Node in capture_actions.get_children():
        if child.name == "CapturePokemonPreview":
            child.free()

    var name: String = str(_capture_preview_member.get("name", "Pokémon"))
    var level: int = maxi(1, int(_capture_preview_member.get("level", 1)))

    var card := PanelContainer.new()
    card.name = "CapturePokemonPreview"
    card.custom_minimum_size = Vector2(0.0, 82.0)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override(
        "panel",
        _panel(Color("13231e"), Color("d9c968"), 9, 5.0)
    )
    capture_actions.add_child(card)
    capture_actions.move_child(card, 0)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    card.add_child(row)

    var sprite := TextureRect.new()
    sprite.custom_minimum_size = Vector2(74.0, 70.0)
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.texture = _capture_preview_texture(_capture_preview_member)
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(sprite)

    var text_box := VBoxContainer.new()
    text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_box.alignment = BoxContainer.ALIGNMENT_CENTER
    text_box.add_theme_constant_override("separation", 2)
    row.add_child(text_box)

    var caught_label := Label.new()
    caught_label.text = "✓ BEGLEITET DICH JETZT"
    caught_label.add_theme_font_size_override("font_size", 9)
    caught_label.add_theme_color_override("font_color", Color("9fe7bd"))
    caught_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(caught_label)

    var name_label := Label.new()
    name_label.text = "%s · Lv.%d" % [name, level]
    name_label.add_theme_font_size_override("font_size", 15)
    name_label.add_theme_color_override("font_color", Color("fff1a6"))
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(name_label)

    var hint := Label.new()
    hint.text = "Anklicken: Werte · Netzdiagramm · Attacken"
    hint.add_theme_font_size_override("font_size", 8)
    hint.add_theme_color_override("font_color", Color("b8d3c7"))
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(hint)

    var click_area := Button.new()
    click_area.flat = true
    click_area.text = ""
    click_area.focus_mode = Control.FOCUS_NONE
    click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    click_area.tooltip_text = "Dieses Pokémon vollständig ansehen"
    click_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    click_area.pressed.connect(_show_capture_preview_info)
    card.add_child(click_area)


func _capture_preview_texture(member: Dictionary) -> Texture2D:
    var species_id: String = str(member.get("species_id", ""))
    if battle_demo != null and battle_demo.has_method("route_species_texture"):
        var texture_value: Variant = battle_demo.route_species_texture(species_id)
        if texture_value is Texture2D:
            return texture_value as Texture2D

    return _route_member_texture(str(member.get("name", "")))


func _show_capture_preview_info() -> void:
    if _capture_preview_team_index >= 0 and _capture_preview_team_index < team.size():
        _show_route_member_info(_capture_preview_team_index)
        return

    if _capture_preview_member.is_empty():
        return

    # Reuse the exact established team-member view without introducing a
    # second, subtly different Pokemon sheet. Pending captures are inserted
    # only for the duration of rendering and removed immediately afterwards.
    var temporary_index: int = team.size()
    team.append(_capture_preview_member.duplicate(true))
    _show_route_member_info(temporary_index)
    team.remove_at(temporary_index)
    _route_info_member_index = -1
    _disable_pending_capture_move_order_buttons(_route_info_moves)


func _disable_pending_capture_move_order_buttons(node: Node) -> void:
    if node == null:
        return
    for child: Node in node.get_children():
        if child is Button:
            (child as Button).disabled = true
        _disable_pending_capture_move_order_buttons(child)


func _levelup_presentation_pending() -> bool:
    return (
        not _levelup_queue.is_empty()
        or (_levelup_overlay != null and _levelup_overlay.visible)
    )


func _try_show_evolution_choice_popup() -> void:
    if _evolution_choice_overlay == null or _evolution_choice_overlay.visible:
        return
    if _levelup_presentation_pending():
        return
    if _evolution_overlay != null and _evolution_overlay.visible:
        return
    if _evolution_choice_queue.is_empty():
        return

    _show_next_evolution_choice_popup()


func _try_show_evolution_popup() -> void:
    if _evolution_overlay == null or _evolution_overlay.visible:
        return
    if _levelup_presentation_pending():
        return
    if _evolution_choice_overlay != null and _evolution_choice_overlay.visible:
        return
    if _evolution_queue.is_empty():
        return

    _show_next_evolution_popup()
