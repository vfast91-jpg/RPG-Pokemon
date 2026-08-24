extends "res://scripts/main_endgame_v1.gd"

# Player-facing main-menu cleanup:
# - removes the obsolete free-configurable test battle / Kampflabor entry
# - promotes Player vs Player to a full-width standalone menu button
# - presents the route as the actual adventure instead of a demo
# - keeps the four main actions visually consistent without adding extra copy


func _build_main_menu() -> void:
    super._build_main_menu()
    _promote_adventure_menu()


func _promote_adventure_menu() -> void:
    if menu_root == null:
        return

    var route_button: Button = _find_menu_button(menu_root, "DEMO-ROUTE")
    if route_button != null:
        route_button.text = "AUF INS ABENTEUER!"
        route_button.custom_minimum_size = Vector2(240, 44)
        route_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var test_button: Button = _find_menu_button(menu_root, "TESTKAMPF")
    var pvp_button: Button = _find_menu_button(menu_root, "PLAYER VS PLAYER")

    if pvp_button != null:
        var battle_mode_row: Node = pvp_button.get_parent()
        if battle_mode_row != null and battle_mode_row.name == "BattleModeRow":
            var menu_parent: Node = battle_mode_row.get_parent()
            if menu_parent != null:
                var row_index: int = battle_mode_row.get_index()
                pvp_button.reparent(menu_parent)
                menu_parent.move_child(pvp_button, row_index)
                battle_mode_row.queue_free()

        pvp_button.custom_minimum_size = Vector2(240, 44)
        pvp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        pvp_button.remove_theme_font_size_override("font_size")
    elif test_button != null:
        test_button.queue_free()

    _remove_unrequested_menu_copy(menu_root)
    _polish_main_menu_buttons()


func _polish_main_menu_buttons() -> void:
    var button_texts: Array[String] = [
        "AUF INS ABENTEUER!",
        "PLAYER VS PLAYER",
        "BESTENLISTE",
        "WAS IST TIMEFLOW?"
    ]

    for button_text: String in button_texts:
        var button: Button = _find_menu_button(menu_root, button_text)
        if button == null:
            continue
        button.tooltip_text = ""
        _apply_main_menu_button_style(button)


func _apply_main_menu_button_style(button: Button) -> void:
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    button.add_theme_color_override("font_color", Color("e9f0ed"))
    button.add_theme_color_override("font_hover_color", Color("ffffff"))
    button.add_theme_color_override("font_pressed_color", Color("dbe7e1"))
    button.add_theme_color_override("font_focus_color", Color("ffffff"))

    button.add_theme_stylebox_override(
        "normal",
        _main_menu_button_style(Color("172520"), Color("667a72"))
    )
    button.add_theme_stylebox_override(
        "hover",
        _main_menu_button_style(Color("20322c"), Color("95aaa1"))
    )
    button.add_theme_stylebox_override(
        "pressed",
        _main_menu_button_style(Color("111d19"), Color("82978e"))
    )
    button.add_theme_stylebox_override(
        "focus",
        _main_menu_button_style(Color("1b2c26"), Color("a6bab1"))
    )


func _main_menu_button_style(bg: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
    style.shadow_size = 2
    style.shadow_offset = Vector2(0.0, 1.0)
    return style


func _remove_unrequested_menu_copy(node: Node) -> void:
    if node is Label:
        var label := node as Label
        var text: String = label.text.strip_edges()
        if (
            text == "Wähle, was du testen möchtest."
            or text == "Dein Abenteuer beginnt hier."
            or text.begins_with("Die Demo-Route startet mit einem zufälligen Pokémon")
            or text.begins_with("Dein Abenteuer startet mit einem zufälligen Pokémon")
        ):
            label.visible = false
            label.queue_free()
            return

    for child: Node in node.get_children():
        _remove_unrequested_menu_copy(child)


func _make_pvp_candidate_card(entry: Dictionary) -> PanelContainer:
    var panel: PanelContainer = super._make_pvp_candidate_card(entry)
    _remove_pvp_info_tooltip(panel)
    return panel


func _remove_pvp_info_tooltip(node: Node) -> void:
    if node is Button:
        var button := node as Button
        if button.text == "i":
            button.tooltip_text = ""

    for child: Node in node.get_children():
        _remove_pvp_info_tooltip(child)


func _refresh_leaderboard() -> void:
    super._refresh_leaderboard()
    if leaderboard_text != null:
        leaderboard_text.text = leaderboard_text.text.replace("Demo-Route", "Route")
