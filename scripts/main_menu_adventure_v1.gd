extends "res://scripts/main_endgame_v1.gd"

# Player-facing main-menu cleanup:
# - removes the obsolete free-configurable test battle / Kampflabor entry
# - promotes Player vs Player to a full-width standalone menu button
# - presents the route as the actual adventure instead of a demo


func _build_main_menu() -> void:
    super._build_main_menu()
    _promote_adventure_menu()


func _promote_adventure_menu() -> void:
    if menu_root == null:
        return

    var route_button: Button = _find_menu_button(menu_root, "DEMO-ROUTE")
    if route_button != null:
        route_button.text = "AUF INS ABENTEUER!"
        route_button.tooltip_text = "Starte dein Abenteuer durch 100 Etappen mit Pfadwahl, Fangen, Heilung, TMs, EP und persistenten KP."

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
        if route_button != null:
            pvp_button.size_flags_horizontal = route_button.size_flags_horizontal
        pvp_button.remove_theme_font_size_override("font_size")
        pvp_button.tooltip_text = "Lokales 4-gegen-4: gemeinsames Level wählen, Teams abwechselnd draften und an einem Bildschirm gegeneinander kämpfen."
    elif test_button != null:
        test_button.queue_free()

    _rewrite_main_menu_copy(menu_root)


func _rewrite_main_menu_copy(node: Node) -> void:
    if node is Label:
        var label := node as Label
        if label.text == "Wähle, was du testen möchtest.":
            label.text = "Dein Abenteuer beginnt hier."
        label.text = label.text.replace("Die Demo-Route startet", "Dein Abenteuer startet")
        label.text = label.text.replace("Demo-Route", "Route")
    elif node is Button:
        var button := node as Button
        button.tooltip_text = button.tooltip_text.replace("Demo-Route", "Route")

    for child: Node in node.get_children():
        _rewrite_main_menu_copy(child)


func _refresh_leaderboard() -> void:
    super._refresh_leaderboard()
    if leaderboard_text != null:
        leaderboard_text.text = leaderboard_text.text.replace("Demo-Route", "Route")
