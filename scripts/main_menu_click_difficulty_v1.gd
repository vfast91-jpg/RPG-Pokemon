extends "res://scripts/main_menu_run_save_v1.gd"

# Difficulty selection is intentionally mouse/touch driven like the rest of
# the adventure UI. No card receives keyboard focus automatically and arrow-key
# navigation must not create a misleading golden preselection border.

const BossGauntletRules = preload("res://scripts/route_boss_rules.gd")

var _boss_gauntlet_button: Button
var _boss_gauntlet_settings_overlay: Control
var _boss_gauntlet_boss_level_offset: SpinBox
var _boss_gauntlet_boss_atb: SpinBox
var _boss_gauntlet_legendary_level_offset: SpinBox
var _boss_gauntlet_legendary_atb: SpinBox


func _build_main_menu() -> void:
    super._build_main_menu()
    _install_boss_gauntlet_button()
    _build_boss_gauntlet_settings_overlay()


func _show_main_menu() -> void:
    super._show_main_menu()
    _hide_boss_gauntlet_settings()


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
    _boss_gauntlet_button.tooltip_text = "Endgame ab Etappe 91 testen und dabei die echten Endgame-Balancewerte einstellen."
    _boss_gauntlet_button.pressed.connect(_show_boss_gauntlet_settings)
    _apply_main_menu_button_style(_boss_gauntlet_button)
    row.add_child(_boss_gauntlet_button)


func _build_boss_gauntlet_settings_overlay() -> void:
    if menu_root == null or _boss_gauntlet_settings_overlay != null:
        return

    _boss_gauntlet_settings_overlay = Control.new()
    _boss_gauntlet_settings_overlay.name = "BossGauntletSettingsOverlay"
    _boss_gauntlet_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _boss_gauntlet_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _boss_gauntlet_settings_overlay.z_index = 60
    _boss_gauntlet_settings_overlay.visible = false
    menu_root.add_child(_boss_gauntlet_settings_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.80)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _boss_gauntlet_settings_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _boss_gauntlet_settings_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(568, 300)
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("14251f"), Color("e0c95f"), 13, 12.0)
    )
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 7)
    panel.add_child(content)

    var title := Label.new()
    title.text = "🔥 BOSSKAMPFLAUF · BALANCE-LABOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 19)
    title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Testteam: 4 zufällige Pokémon auf Lv.80 · Deine Werte gelten zugleich im normalen Hauptlauf."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size", 9)
    subtitle.add_theme_color_override("font_color", Color("c8d8d1"))
    content.add_child(subtitle)

    var grid := GridContainer.new()
    grid.columns = 3
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 8)
    content.add_child(grid)

    grid.add_child(_boss_gauntlet_grid_label(""))
    grid.add_child(_boss_gauntlet_grid_label("LEVEL-BONUS"))
    grid.add_child(_boss_gauntlet_grid_label("ATB-FAKTOR"))

    grid.add_child(_boss_gauntlet_grid_label("Etappe 91–95 · Superbosse", true))
    _boss_gauntlet_boss_level_offset = _boss_gauntlet_spinbox(-20.0, 30.0, 1.0)
    grid.add_child(_boss_gauntlet_boss_level_offset)
    _boss_gauntlet_boss_atb = _boss_gauntlet_spinbox(0.50, 4.00, 0.05)
    grid.add_child(_boss_gauntlet_boss_atb)

    grid.add_child(_boss_gauntlet_grid_label("Etappe 96–100 · Legendäre", true))
    _boss_gauntlet_legendary_level_offset = _boss_gauntlet_spinbox(-20.0, 30.0, 1.0)
    grid.add_child(_boss_gauntlet_legendary_level_offset)
    _boss_gauntlet_legendary_atb = _boss_gauntlet_spinbox(0.50, 4.00, 0.05)
    grid.add_child(_boss_gauntlet_legendary_atb)

    var hint := Label.new()
    hint.text = "Beispiel: Lv.80 + Level-Bonus 10 = Gegner Lv.90. ATB 1,50 = 50 % schnellerer ATB-Aufbau. Beim Start werden diese Werte als echte Endgame-Spielwerte gespeichert."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 9)
    hint.add_theme_color_override("font_color", Color("aebfb7"))
    content.add_child(hint)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 8)
    content.add_child(buttons)

    var cancel_button := Button.new()
    cancel_button.text = "ABBRECHEN"
    cancel_button.custom_minimum_size = Vector2(135, 38)
    cancel_button.focus_mode = Control.FOCUS_NONE
    cancel_button.pressed.connect(_hide_boss_gauntlet_settings)
    _apply_main_menu_button_style(cancel_button)
    buttons.add_child(cancel_button)

    var reset_button := Button.new()
    reset_button.text = "AKTUELLE WERTE"
    reset_button.custom_minimum_size = Vector2(135, 38)
    reset_button.tooltip_text = "Lädt die derzeit für das echte Endgame geltenden Werte in die Regler."
    reset_button.focus_mode = Control.FOCUS_NONE
    reset_button.pressed.connect(_reset_boss_gauntlet_settings_to_game_values)
    _apply_main_menu_button_style(reset_button)
    buttons.add_child(reset_button)

    var start_button := Button.new()
    start_button.text = "ÜBERNEHMEN & TESTEN"
    start_button.custom_minimum_size = Vector2(190, 38)
    start_button.focus_mode = Control.FOCUS_NONE
    start_button.pressed.connect(_start_boss_gauntlet_test)
    _apply_main_menu_button_style(start_button)
    buttons.add_child(start_button)

    _apply_boss_gauntlet_settings(_load_boss_gauntlet_settings())


func _boss_gauntlet_grid_label(text_value: String, accent: bool = false) -> Label:
    var label := Label.new()
    label.text = text_value
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 10 if not accent else 11)
    label.add_theme_color_override(
        "font_color",
        Color("e7efeb") if not accent else Color("ffe46f")
    )
    return label


func _boss_gauntlet_spinbox(minimum: float, maximum: float, step_value: float) -> SpinBox:
    var box := SpinBox.new()
    box.min_value = minimum
    box.max_value = maximum
    box.step = step_value
    box.allow_greater = false
    box.allow_lesser = false
    box.custom_minimum_size = Vector2(118, 34)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.focus_mode = Control.FOCUS_ALL
    return box


func _boss_gauntlet_default_settings() -> Dictionary:
    if demo_route != null and demo_route.has_method("boss_gauntlet_default_settings"):
        var route_defaults: Variant = demo_route.call("boss_gauntlet_default_settings")
        if route_defaults is Dictionary:
            return (route_defaults as Dictionary).duplicate(true)
    return BossGauntletRules.endgame_balance_settings()


func _load_boss_gauntlet_settings() -> Dictionary:
    return _boss_gauntlet_default_settings()


func _save_boss_gauntlet_settings(settings: Dictionary) -> bool:
    return BossGauntletRules.save_endgame_balance_settings(settings)


func _collect_boss_gauntlet_settings() -> Dictionary:
    return {
        "boss_level_offset": int(round(_boss_gauntlet_boss_level_offset.value)),
        "boss_atb_rate_multiplier": float(_boss_gauntlet_boss_atb.value),
        "legendary_level_offset": int(round(_boss_gauntlet_legendary_level_offset.value)),
        "legendary_atb_rate_multiplier": float(_boss_gauntlet_legendary_atb.value)
    }


func _apply_boss_gauntlet_settings(settings: Dictionary) -> void:
    if _boss_gauntlet_boss_level_offset == null:
        return
    _boss_gauntlet_boss_level_offset.value = float(settings.get("boss_level_offset", 10))
    _boss_gauntlet_boss_atb.value = float(settings.get("boss_atb_rate_multiplier", 1.5))
    _boss_gauntlet_legendary_level_offset.value = float(settings.get("legendary_level_offset", 10))
    _boss_gauntlet_legendary_atb.value = float(settings.get("legendary_atb_rate_multiplier", 2.0))


func _reset_boss_gauntlet_settings_to_game_values() -> void:
    _apply_boss_gauntlet_settings(_boss_gauntlet_default_settings())


func _show_boss_gauntlet_settings() -> void:
    _hide_adventure_intro()
    _hide_difficulty_selector()
    _hide_leaderboard()
    _hide_timeflow_help()
    _apply_boss_gauntlet_settings(_load_boss_gauntlet_settings())
    if _boss_gauntlet_settings_overlay != null:
        _boss_gauntlet_settings_overlay.visible = true


func _hide_boss_gauntlet_settings() -> void:
    if _boss_gauntlet_settings_overlay != null:
        _boss_gauntlet_settings_overlay.visible = false


func _start_boss_gauntlet_test() -> void:
    if demo_route == null or not demo_route.has_method("start_boss_gauntlet_test"):
        push_error("Bosskampflauf: Aktiver Routenlayer unterstützt den Testmodus nicht.")
        return

    var settings: Dictionary = _collect_boss_gauntlet_settings()
    if not _save_boss_gauntlet_settings(settings):
        push_error("Bosskampflauf: Endgame-Spielwerte konnten nicht übernommen werden.")
        return
    _hide_boss_gauntlet_settings()

    menu_layer.visible = false
    battle_demo.visible = false
    demo_route.call("start_boss_gauntlet_test", settings)


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
