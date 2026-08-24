extends "res://scripts/main_menu_adventure_v1.gd"

# Main-menu integration for the single active adventure slot.
# The existing full-width adventure button simply changes between start/continue.

var _run_save_adventure_button: Button


func _build_main_menu() -> void:
    super._build_main_menu()
    _run_save_adventure_button = _find_menu_button(menu_root, "AUF INS ABENTEUER!")
    _refresh_run_save_menu()


func _show_main_menu() -> void:
    super._show_main_menu()
    _refresh_run_save_menu()


func _start_demo_route() -> void:
    _hide_leaderboard()
    _hide_timeflow_help()
    menu_layer.visible = false
    battle_demo.visible = false

    if RunSaveManager.has_run_save() and demo_route.has_method("continue_saved_route"):
        demo_route.call("continue_saved_route")
    else:
        demo_route.call("start_route")


func _refresh_leaderboard() -> void:
    super._refresh_leaderboard()
    if leaderboard_text != null:
        leaderboard_text.text = leaderboard_text.text.replace("/90", "/100")


func _refresh_run_save_menu() -> void:
    if _run_save_adventure_button == null:
        _run_save_adventure_button = _find_menu_button(menu_root, "AUF INS ABENTEUER!")
        if _run_save_adventure_button == null:
            _run_save_adventure_button = _find_menu_button(menu_root, "ABENTEUER FORTFÜHREN")

    if _run_save_adventure_button == null:
        return

    _run_save_adventure_button.custom_minimum_size = Vector2(240, 44)
    _run_save_adventure_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _run_save_adventure_button.tooltip_text = ""

    if RunSaveManager.has_run_save():
        _run_save_adventure_button.text = "ABENTEUER FORTFÜHREN"
    else:
        _run_save_adventure_button.text = "AUF INS ABENTEUER!"
