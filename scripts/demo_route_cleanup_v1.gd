extends "res://scripts/demo_route_events_v1.gd"

# Phase H compatibility cleanup.
# Several older route layers still contain Direct/Dangerous/+25%-XP callbacks
# because later, valuable UI/evolution fixes inherit through them. Deleting
# those files wholesale would risk unrelated regressions. This active top layer
# makes the obsolete entry points unreachable and harmless while preserving the
# mature inherited systems beneath them.
#
# This final layer also owns the compact Fangwiese replacement layout and the
# shared route-decision polish. Gameplay callbacks stay inherited; this layer
# only changes how capture/training choices are presented and selected.

const DEFAULT_EVENT_LABEL_HEIGHT: float = 58.0
const CAPTURE_EVENT_LABEL_HEIGHT: float = 44.0
const CAPTURE_PREVIEW_MAX_HEIGHT: float = 100.0
const TRAINING_CARD_HEIGHT: float = 52.0

var _capture_replacement_selection_active: bool = false


func _show_stage_choices(message: String = "") -> void:
    var restore_team_cards: bool = _capture_replacement_selection_active
    _capture_replacement_selection_active = false
    stage_xp_multiplier = 1.0
    super._show_stage_choices(message)
    _set_capture_layout_compact(false)
    if restore_team_cards:
        _refresh_team_panel()


func _show_current_capture_offer() -> void:
    var restore_team_cards: bool = _capture_replacement_selection_active
    _capture_replacement_selection_active = false

    super._show_current_capture_offer()
    _set_capture_layout_compact(true)
    _compact_capture_preview_card()
    _polish_capture_action_buttons()

    if restore_team_cards:
        _refresh_team_panel()


func _polish_capture_action_buttons() -> void:
    if capture_actions == null or pending_capture.is_empty():
        return

    var capture_name: String = str(pending_capture.get("name", "Pokémon"))
    for child: Node in capture_actions.get_children():
        if not (child is Button):
            continue

        var button := child as Button
        var original_text: String = button.text

        if original_text == "INS TEAM AUFNEHMEN":
            button.text = "➕  INS TEAM AUFNEHMEN\n%s dem Team hinzufügen" % capture_name
            _style_route_decision_button(button, true)
        elif original_text == "TEAM-POKÉMON ERSETZEN":
            button.text = "🔄  TEAM-POKÉMON ERSETZEN\nRechts im Team ein Pokémon auswählen"
            _style_route_decision_button(button, true)
        elif original_text.begins_with("WEITERSUCHEN"):
            var next_search: int = mini(_capture_search_number + 1, CAPTURE_SEARCH_MAX)
            var next_level: int = _capture_level_for_search(next_search)
            button.text = (
                "🌿  WEITERSUCHEN\n"
                + "Suche %d/%d · nächstes Pokémon ca. Lv.%d"
            ) % [next_search, CAPTURE_SEARCH_MAX, next_level]
            _style_route_decision_button(button, false)
        elif original_text.begins_with("NICHT AUFNEHMEN"):
            button.text = "↩  NICHT AUFNEHMEN\nFangwiese ohne Pokémon verlassen"
            _style_route_decision_button(button, false)


func _style_route_decision_button(button: Button, primary: bool) -> void:
    button.custom_minimum_size = Vector2(0.0, 44.0)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.add_theme_font_size_override("font_size", 11)

    if primary:
        button.add_theme_color_override("font_color", Color("fff0ad"))
        button.add_theme_color_override("font_hover_color", Color("fff6c9"))
        button.add_theme_color_override("font_pressed_color", Color("e9d58b"))
        button.add_theme_color_override("font_focus_color", Color("fff6c9"))
        button.add_theme_stylebox_override(
            "normal",
            _route_decision_button_style(Color("1b2d27"), Color("bda95b"), 1)
        )
        button.add_theme_stylebox_override(
            "hover",
            _route_decision_button_style(Color("243b32"), Color("e0c968"), 2)
        )
        button.add_theme_stylebox_override(
            "pressed",
            _route_decision_button_style(Color("15251f"), Color("c6b461"), 2)
        )
        button.add_theme_stylebox_override(
            "focus",
            _route_decision_button_style(Color("1b2d27"), Color("e0c968"), 2)
        )
    else:
        button.add_theme_color_override("font_color", Color("d9eee5"))
        button.add_theme_color_override("font_hover_color", Color("f1fff8"))
        button.add_theme_color_override("font_pressed_color", Color("bdd8cc"))
        button.add_theme_color_override("font_focus_color", Color("f1fff8"))
        button.add_theme_stylebox_override(
            "normal",
            _route_decision_button_style(Color("182722"), Color("5d8172"), 1)
        )
        button.add_theme_stylebox_override(
            "hover",
            _route_decision_button_style(Color("20342c"), Color("83b59f"), 2)
        )
        button.add_theme_stylebox_override(
            "pressed",
            _route_decision_button_style(Color("13211c"), Color("6f9d89"), 2)
        )
        button.add_theme_stylebox_override(
            "focus",
            _route_decision_button_style(Color("182722"), Color("83b59f"), 2)
        )


func _route_decision_button_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(8)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 5.0
    style.content_margin_bottom = 5.0
    return style


func _begin_training_event() -> void:
    # Let the mature training layers establish their exact current text/rules
    # (including the 15% post-level-up Max-KP cost), then replace only the plain
    # text buttons with visual Pokémon selection cards.
    super._begin_training_event()

    if capture_actions == null:
        return

    _clear_container(capture_actions)

    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value
        var level: int = maxi(1, int(member.get("level", 1)))
        var required_xp: int = _xp_needed_for_member_level(member, level)
        capture_actions.add_child(
            _make_training_choice_card(member, index, required_xp)
        )


func _make_training_choice_card(member: Dictionary, index: int, required_xp: int) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0.0, TRAINING_CARD_HEIGHT)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override(
        "panel",
        _panel(Color("182822"), Color("55796a"), 8, 5.0)
    )

    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 8)
    card.add_child(row)

    var sprite := TextureRect.new()
    sprite.custom_minimum_size = Vector2(42.0, 42.0)
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.texture = _route_member_texture(str(member.get("name", "Pokémon")))
    row.add_child(sprite)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.alignment = BoxContainer.ALIGNMENT_CENTER
    info.add_theme_constant_override("separation", 1)
    row.add_child(info)

    var identity := Label.new()
    identity.text = "%s · Lv.%d" % [
        str(member.get("name", "Pokémon")),
        maxi(1, int(member.get("level", 1)))
    ]
    identity.add_theme_font_size_override("font_size", 12)
    identity.add_theme_color_override("font_color", Color("f4f7f5"))
    info.add_child(identity)

    var outcome := Label.new()
    outcome.text = "🏋️ Training → +%d EP · Levelaufstieg" % required_xp
    outcome.add_theme_font_size_override("font_size", 9)
    outcome.add_theme_color_override("font_color", Color("9fe7bd"))
    info.add_child(outcome)

    var click_area := Button.new()
    click_area.text = ""
    click_area.focus_mode = Control.FOCUS_NONE
    click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    click_area.tooltip_text = (
        "Dieses Pokémon erhält genau %d EP gemäß seiner eigenen EP-Kurve. "
        + "Der bestehende EP-Stand bleibt erhalten. Nach dem Levelaufstieg verliert es "
        + "15%% seiner neuen Max-KP; ein lebendes Pokémon behält mindestens 1 KP."
    ) % required_xp
    click_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    click_area.add_theme_stylebox_override(
        "normal",
        _route_choice_overlay_style(Color("00000000"), Color("00000000"), 0)
    )
    click_area.add_theme_stylebox_override(
        "hover",
        _route_choice_overlay_style(Color("d7f5e60d"), Color("83b59f"), 2)
    )
    click_area.add_theme_stylebox_override(
        "pressed",
        _route_choice_overlay_style(Color("d7f5e614"), Color("e0c968"), 2)
    )
    click_area.pressed.connect(_train_team_member.bind(index))
    card.add_child(click_area)

    return card


func _show_replace_choices() -> void:
    if pending_capture.is_empty():
        return

    _capture_replacement_selection_active = true
    _clear_container(capture_actions)
    continue_button.visible = false
    _set_capture_layout_compact(true)

    var capture_name: String = str(pending_capture.get("name", "Pokémon"))
    var capture_level: int = maxi(1, int(pending_capture.get("level", 1)))
    event_label.text = (
        "[b]🌿 Fangwiese · Team voll[/b]\n"
        + "%s Lv.%d soll ins Team. Klicke rechts im [b]TEAM[/b] auf das Pokémon, "
        + "das dafür dein Team verlassen soll."
    ) % [capture_name, capture_level]

    _add_capture_preview_card()
    var preview: Node = capture_actions.get_node_or_null("CapturePokemonPreview")
    if preview != null:
        capture_actions.move_child(preview, 0)
        _compact_capture_preview_card()

    var hint := Label.new()
    hint.text = "👆 Rechts im TEAM auswählen · die Teamkarten sind jetzt anklickbar"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 9)
    hint.add_theme_color_override("font_color", Color("9fe7bd"))
    capture_actions.add_child(hint)

    var back_button := Button.new()
    back_button.text = "↩  ZURÜCK ZUR AUSWAHL"
    back_button.tooltip_text = "Zurück zum gefundenen Pokémon und den Fangwiesen-Aktionen."
    back_button.pressed.connect(_begin_capture_event_again)
    _style_route_decision_button(back_button, false)
    back_button.custom_minimum_size.y = 36.0
    capture_actions.add_child(back_button)

    _refresh_team_panel()


func _begin_capture_event_again() -> void:
    if pending_capture.is_empty():
        return
    _show_current_capture_offer()


func _make_route_team_card(member: Dictionary, index: int) -> Control:
    var card: Control = super._make_route_team_card(member, index)
    if not _capture_replacement_selection_active:
        return card

    if card is PanelContainer:
        (card as PanelContainer).add_theme_stylebox_override(
            "panel",
            _panel(Color("1c3029"), Color("d6bd62"), 7, 2.0)
        )

    var replacement_button := Button.new()
    replacement_button.text = ""
    replacement_button.focus_mode = Control.FOCUS_NONE
    replacement_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    replacement_button.tooltip_text = "%s durch %s ersetzen" % [
        str(member.get("name", "Pokémon")),
        str(pending_capture.get("name", "das gefundene Pokémon"))
    ]
    replacement_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    replacement_button.add_theme_stylebox_override(
        "normal",
        _route_choice_overlay_style(Color("00000000"), Color("00000000"), 0)
    )
    replacement_button.add_theme_stylebox_override(
        "hover",
        _route_choice_overlay_style(Color("ffe57612"), Color("ffe576"), 2)
    )
    replacement_button.add_theme_stylebox_override(
        "pressed",
        _route_choice_overlay_style(Color("ffe5761f"), Color("d6bd62"), 2)
    )
    replacement_button.pressed.connect(_replace_team_member.bind(index))
    card.add_child(replacement_button)

    return card


func _route_choice_overlay_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(7)
    return style


func _replace_team_member(index: int) -> void:
    if pending_capture.is_empty() or index < 0 or index >= team.size():
        return

    _capture_replacement_selection_active = false
    super._replace_team_member(index)


func _set_capture_layout_compact(compact: bool) -> void:
    if event_label == null:
        return

    if compact:
        event_label.custom_minimum_size = Vector2(0.0, CAPTURE_EVENT_LABEL_HEIGHT)
        # Do not let this RichTextLabel consume all spare route-panel height.
        # Its own scrollbar remains available if a future capture message grows.
        event_label.size_flags_vertical = Control.SIZE_FILL
    else:
        event_label.custom_minimum_size = Vector2(0.0, DEFAULT_EVENT_LABEL_HEIGHT)
        event_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _compact_capture_preview_card() -> void:
    if capture_actions == null:
        return
    var card_node: Node = capture_actions.get_node_or_null("CapturePokemonPreview")
    if not (card_node is Control):
        return

    var card := card_node as Control
    card.custom_minimum_size = Vector2(
        card.custom_minimum_size.x,
        minf(card.custom_minimum_size.y, CAPTURE_PREVIEW_MAX_HEIGHT)
        if card.custom_minimum_size.y > 0.0
        else CAPTURE_PREVIEW_MAX_HEIGHT
    )
    card.size_flags_vertical = Control.SIZE_FILL


func _choose_path(choice: Dictionary) -> void:
    var kind: String = str(choice.get("kind", ""))
    if kind == EVENT_DIRECT or kind == EVENT_DANGEROUS:
        stage_xp_multiplier = 1.0
        _show_stage_choices(
            "Dieser alte Weg gehört nicht mehr zum aktiven Routensystem. "
            + "Die drei Wegoptionen wurden neu ausgewürfelt."
        )
        return

    stage_xp_multiplier = 1.0
    super._choose_path(choice)


func _decline_tm_reward() -> void:
    # Stale inherited buttons/callbacks must never restore the retired +25%-EP
    # consolation reward. The active Fundstelle always returns to its six-choice
    # selection instead.
    stage_xp_multiplier = 1.0
    if _fundstelle_active:
        _show_fundstelle_options()
    else:
        _show_stage_choices("Die alte +25%-EP-TM-Alternative existiert nicht mehr.")


func _decline_pending_capture() -> void:
    # The active Fangwiese uses up to three explicit searches and no XP
    # consolation. If a stale inherited callback reaches this method, interpret
    # it as leaving the current Fangwiese without a capture.
    _capture_replacement_selection_active = false
    stage_xp_multiplier = 1.0
    if not pending_capture.is_empty():
        _leave_capture_without_capture()
