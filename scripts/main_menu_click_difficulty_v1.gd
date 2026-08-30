extends "res://scripts/main_menu_run_save_v1.gd"

# Difficulty selection is intentionally mouse/touch driven like the rest of
# the adventure UI. No card receives keyboard focus automatically and arrow-key
# navigation must not create a misleading golden preselection border.

var _boss_gauntlet_button: Button


func _build_main_menu() -> void:
    super._build_main_menu()
    _install_boss_gauntlet_button()


func _install_boss_gauntlet_button() -> void:
    if menu_root == null or _boss_gauntlet_button != null:
        return

    var pvp_button: Button = _find_menu_button(menu_root, "PLAYER VS PLAYER")
    if pvp_button == null:
        push_warning("Bosskampflauf: Player-versus-Player-Schaltfläche nicht gefunden.")
        return

    var menu_parent: Node = pvp_button.get_parent()
    if menu_parent == null:
        return

    var row_index: int = pvp_button.get_index()
    var row := HBoxContainer.new()
    row.name = "PvpBossGauntletRow"
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 8)
    menu_parent.add_child(row)
    menu_parent.move_child(row, row_index)

    pvp_button.reparent(row)
    pvp_button.custom_minimum_size = Vector2(0, 44)
    pvp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    _boss_gauntlet_button = Button.new()
    _boss_gauntlet_button.name = "BossGauntletButton"
    _boss_gauntlet_button.text = "🔥  BOSSKAMPFLAUF"
    _boss_gauntlet_button.custom_minimum_size = Vector2(0, 44)
    _boss_gauntlet_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _boss_gauntlet_button.tooltip_text = "Endgame ab Etappe 91 mit einem zufälligen Level-80-Team testen."
    _boss_gauntlet_button.pressed.connect(_start_boss_gauntlet_test)
    _apply_main_menu_button_style(_boss_gauntlet_button)
    row.add_child(_boss_gauntlet_button)


func _start_boss_gauntlet_test() -> void:
    _hide_adventure_intro()
    _hide_difficulty_selector()
    _hide_leaderboard()
    _hide_timeflow_help()

    if demo_route == null or not demo_route.has_method("start_boss_gauntlet_test"):
        push_error("Bosskampflauf: Aktiver Routenlayer unterstützt den Testmodus nicht.")
        return

    menu_layer.visible = false
    battle_demo.visible = false
    demo_route.call("start_boss_gauntlet_test")


func _make_difficulty_button(
    label_text: String,
    difficulty_key: String,
    level_offset: int,
    base_color: Color
) -> Button:
    var button: Button = super._make_difficulty_button(
        label_text,
        difficulty_key,
        level_offset,
        base_color
    )
    button.focus_mode = Control.FOCUS_NONE
    return button


func _show_difficulty_selector() -> void:
    if _difficulty_overlay == null:
        _confirm_difficulty("normal", 0)
        return

    _difficulty_overlay.visible = true
    if _difficulty_first_button != null:
        _difficulty_first_button.release_focus()
