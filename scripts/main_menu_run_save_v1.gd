extends "res://scripts/main_menu_adventure_v1.gd"

# Main-menu integration for the single active adventure slot.
# The existing adventure button becomes the continue button while a save exists.

var _run_save_adventure_button: Button
var _run_save_adventure_row: HBoxContainer
var _run_save_new_button: Button
var _run_save_new_dialog: ConfirmationDialog


func _build_main_menu() -> void:
    super._build_main_menu()
    _rewrite_stage_count_copy(menu_root)
    _run_save_adventure_button = _find_menu_button(menu_root, "AUF INS ABENTEUER!")
    _install_single_slot_adventure_row()
    _build_new_adventure_dialog()
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


func _install_single_slot_adventure_row() -> void:
    if _run_save_adventure_button == null:
        return

    var old_parent: Node = _run_save_adventure_button.get_parent()
    if old_parent == null:
        return

    var old_index: int = _run_save_adventure_button.get_index()
    old_parent.remove_child(_run_save_adventure_button)

    _run_save_adventure_row = HBoxContainer.new()
    _run_save_adventure_row.name = "AdventureSaveRow"
    _run_save_adventure_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _run_save_adventure_row.add_theme_constant_override("separation", 6)
    old_parent.add_child(_run_save_adventure_row)
    old_parent.move_child(_run_save_adventure_row, old_index)
    _run_save_adventure_row.add_child(_run_save_adventure_button)

    _run_save_new_button = Button.new()
    _run_save_new_button.name = "NewAdventureButton"
    _run_save_new_button.text = "NEU"
    _run_save_new_button.custom_minimum_size = Vector2(64, 44)
    _run_save_new_button.tooltip_text = "Aktuellen Lauf beenden und ein neues Abenteuer beginnen."
    _run_save_new_button.pressed.connect(_request_new_adventure)
    _apply_main_menu_button_style(_run_save_new_button)
    _run_save_adventure_row.add_child(_run_save_new_button)


func _build_new_adventure_dialog() -> void:
    _run_save_new_dialog = ConfirmationDialog.new()
    _run_save_new_dialog.name = "NewAdventureDialog"
    _run_save_new_dialog.title = "Neues Abenteuer beginnen?"
    _run_save_new_dialog.dialog_text = (
        "Der aktuelle Lauf wird gelöscht und durch ein neues Abenteuer ersetzt.\n"
        + "Pokédex, dauerhafter Fortschritt und Bestenliste bleiben erhalten."
    )
    _run_save_new_dialog.ok_button_text = "NEUES ABENTEUER"
    _run_save_new_dialog.cancel_button_text = "ABBRECHEN"
    _run_save_new_dialog.confirmed.connect(_confirm_new_adventure)
    menu_root.add_child(_run_save_new_dialog)


func _request_new_adventure() -> void:
    if not RunSaveManager.has_run_save():
        _confirm_new_adventure()
        return
    _run_save_new_dialog.popup_centered(Vector2i(450, 180))


func _confirm_new_adventure() -> void:
    RunSaveManager.clear_run_save()
    _refresh_run_save_menu()
    _start_demo_route()


func _refresh_run_save_menu() -> void:
    if _run_save_adventure_button == null:
        return

    var has_save: bool = RunSaveManager.has_run_save()
    if has_save:
        _run_save_adventure_button.text = "ABENTEUER FORTFÜHREN · ETAPPE %d" % RunSaveManager.saved_stage()
        _run_save_adventure_button.custom_minimum_size = Vector2(250, 44)
    else:
        _run_save_adventure_button.text = "AUF INS ABENTEUER!"
        _run_save_adventure_button.custom_minimum_size = Vector2(240, 44)

    _run_save_adventure_button.tooltip_text = ""
    if _run_save_new_button != null:
        _run_save_new_button.visible = has_save


func _rewrite_stage_count_copy(node: Node) -> void:
    if node is Label:
        var label: Label = node as Label
        label.text = label.text.replace("90 Etappen", "100 Etappen")
        label.text = label.text.replace("Etappe 90", "Etappe 100")
    elif node is Button:
        var button: Button = node as Button
        button.tooltip_text = button.tooltip_text.replace("90 Etappen", "100 Etappen")
        button.tooltip_text = button.tooltip_text.replace("Etappe 90", "Etappe 100")

    for child: Node in node.get_children():
        _rewrite_stage_count_copy(child)
