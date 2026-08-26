extends "res://scripts/main_menu_adventure_v1.gd"

# Main-menu integration for the single active adventure slot.
# - Existing runs continue immediately.
# - A new adventure first shows one compact, non-scrolling overview.
# - After the overview, the player chooses the run difficulty before Stage 1.

var _run_save_adventure_button: Button
var _adventure_intro_overlay: Control
var _adventure_intro_start_button: Button
var _difficulty_overlay: Control
var _difficulty_first_button: Button


func _build_main_menu() -> void:
    super._build_main_menu()
    _run_save_adventure_button = _find_menu_button(menu_root, "AUF INS ABENTEUER!")
    _build_adventure_intro_overlay()
    _build_difficulty_overlay()
    _refresh_run_save_menu()


func _show_main_menu() -> void:
    super._show_main_menu()
    _hide_adventure_intro()
    _hide_difficulty_selector()
    _refresh_run_save_menu()


func _start_demo_route() -> void:
    _hide_leaderboard()
    _hide_timeflow_help()

    if RunSaveManager.has_run_save() and demo_route.has_method("continue_saved_route"):
        menu_layer.visible = false
        battle_demo.visible = false
        demo_route.call("continue_saved_route")
        return

    _show_adventure_intro()


func _build_adventure_intro_overlay() -> void:
    if menu_root == null or _adventure_intro_overlay != null:
        return

    _adventure_intro_overlay = Control.new()
    _adventure_intro_overlay.name = "AdventureIntroOverlay"
    _adventure_intro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _adventure_intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _adventure_intro_overlay.z_index = 50
    _adventure_intro_overlay.visible = false
    menu_root.add_child(_adventure_intro_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.76)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _adventure_intro_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _adventure_intro_overlay.add_child(center)

    # Sized deliberately for the project's 640x360 internal viewport.
    # There is no ScrollContainer: title, five cards and button stay visible together.
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(596, 324)
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("14251f"), Color("e0c95f"), 13, 10.0)
    )
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    panel.add_child(content)

    var title := Label.new()
    title.text = "DEIN ABENTEUER BEGINNT!"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 21)
    title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "100 Etappen · verschiedene Landschaften · neue Pokémon"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 10)
    subtitle.add_theme_color_override("font_color", Color("b9d0c6"))
    content.add_child(subtitle)

    var cards := GridContainer.new()
    cards.columns = 2
    cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cards.add_theme_constant_override("h_separation", 8)
    cards.add_theme_constant_override("v_separation", 6)
    content.add_child(cards)

    cards.add_child(_make_adventure_intro_card(
        "🎒  START",
        "Du beginnst mit einem zufälligen Basis-Pokémon auf Level 5."
    ))
    cards.add_child(_make_adventure_intro_card(
        "🗺️  LANDSCHAFTEN",
        "Die Landschaft bestimmt, welche Gegner erscheinen und welchen Reisegefährten du begegnen kannst."
    ))
    cards.add_child(_make_adventure_intro_card(
        "🔎  SUCHEN",
        "Bei „Reisegefährten suchen“ kannst du bis zu 3-mal suchen. Mehr Suchen erhöht die Chance auf seltene Pokémon, senkt aber ihr Level."
    ))
    cards.add_child(_make_adventure_intro_card(
        "✨  FORTSCHRITT",
        "Je weiter du kommst, desto häufiger begegnest du beim Suchen seltenen Pokémon. Gegnerkämpfe bleiben davon unberührt."
    ))

    var companion_card := _make_adventure_intro_card(
        "🧭  REISEGEFÄHRTEN",
        "Pokémon begleiten dich 30 gemeinsame Etappen. Danach ziehen sie weiter. 🧭 zeigt dir, wie lange ihr noch gemeinsam reist."
    )
    companion_card.custom_minimum_size = Vector2(0, 52)
    companion_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    content.add_child(companion_card)

    _adventure_intro_start_button = Button.new()
    _adventure_intro_start_button.text = "JETZT GEHT'S LOS!"
    _adventure_intro_start_button.custom_minimum_size = Vector2(238, 34)
    _adventure_intro_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _adventure_intro_start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    _adventure_intro_start_button.add_theme_font_size_override("font_size", 13)
    _adventure_intro_start_button.add_theme_color_override("font_color", Color("fff4b5"))
    _adventure_intro_start_button.add_theme_color_override("font_hover_color", Color("ffffff"))
    _adventure_intro_start_button.add_theme_color_override("font_pressed_color", Color("e8ddb0"))
    _adventure_intro_start_button.add_theme_stylebox_override(
        "normal",
        _main_menu_button_style(Color("20362d"), Color("e0c95f"))
    )
    _adventure_intro_start_button.add_theme_stylebox_override(
        "hover",
        _main_menu_button_style(Color("2b473b"), Color("ffe46f"))
    )
    _adventure_intro_start_button.add_theme_stylebox_override(
        "pressed",
        _main_menu_button_style(Color("172820"), Color("cbb64f"))
    )
    _adventure_intro_start_button.add_theme_stylebox_override(
        "focus",
        _main_menu_button_style(Color("294238"), Color("fff0a0"))
    )
    _adventure_intro_start_button.pressed.connect(_confirm_new_adventure)
    content.add_child(_adventure_intro_start_button)


func _make_adventure_intro_card(title_text: String, body_text: String) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 70)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override(
        "panel",
        _panel(Color("1a3028"), Color("526e62"), 9, 7.0)
    )

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 2)
    card.add_child(box)

    var heading := Label.new()
    heading.text = title_text
    heading.add_theme_font_size_override("font_size", 12)
    heading.add_theme_color_override("font_color", Color("ffe46f"))
    box.add_child(heading)

    var body := Label.new()
    body.text = body_text
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_font_size_override("font_size", 9)
    body.add_theme_color_override("font_color", Color("e3ece8"))
    box.add_child(body)

    return card


func _build_difficulty_overlay() -> void:
    if menu_root == null or _difficulty_overlay != null:
        return

    _difficulty_overlay = Control.new()
    _difficulty_overlay.name = "AdventureDifficultyOverlay"
    _difficulty_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _difficulty_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _difficulty_overlay.z_index = 55
    _difficulty_overlay.visible = false
    menu_root.add_child(_difficulty_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.78)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _difficulty_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _difficulty_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(566, 270)
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("14251f"), Color("e0c95f"), 13, 12.0)
    )
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    panel.add_child(content)

    var title := Label.new()
    title.text = "WÄHLE DEINE SCHWIERIGKEIT"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Die Schwierigkeit verändert die Level aller gegnerischen Pokémon."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 10)
    subtitle.add_theme_color_override("font_color", Color("b9d0c6"))
    content.add_child(subtitle)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    content.add_child(grid)

    _difficulty_first_button = _make_difficulty_button(
        "🌱  ENTSPANNT\nGegner · 1 Level niedriger",
        "entspannt",
        -1,
        Color("244035")
    )
    grid.add_child(_difficulty_first_button)
    grid.add_child(_make_difficulty_button(
        "⚔️  NORMAL\nStandard-Schwierigkeit",
        "normal",
        0,
        Color("20362d")
    ))
    grid.add_child(_make_difficulty_button(
        "🔥  SCHWER\nGegner · 1 Level höher",
        "schwer",
        1,
        Color("3b3225")
    ))
    grid.add_child(_make_difficulty_button(
        "⭐  MEISTER\nGegner · 2 Level höher",
        "meister",
        2,
        Color("40292a")
    ))

    var note := Label.new()
    note.text = "Die Auswahl gilt für das gesamte Abenteuer und wird mit deinem Lauf gespeichert."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_font_size_override("font_size", 9)
    note.add_theme_color_override("font_color", Color("9fb8ad"))
    content.add_child(note)


func _make_difficulty_button(
    label_text: String,
    difficulty_key: String,
    level_offset: int,
    base_color: Color
) -> Button:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(0, 72)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.size_flags_vertical = Control.SIZE_EXPAND_FILL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_size_override("font_size", 12)
    button.add_theme_color_override("font_color", Color("fff4b5"))
    button.add_theme_color_override("font_hover_color", Color("ffffff"))
    button.add_theme_color_override("font_pressed_color", Color("e8ddb0"))
    button.add_theme_stylebox_override(
        "normal",
        _main_menu_button_style(base_color, Color("647d70"))
    )
    button.add_theme_stylebox_override(
        "hover",
        _main_menu_button_style(base_color.lightened(0.08), Color("ffe46f"))
    )
    button.add_theme_stylebox_override(
        "pressed",
        _main_menu_button_style(base_color.darkened(0.08), Color("cbb64f"))
    )
    button.add_theme_stylebox_override(
        "focus",
        _main_menu_button_style(base_color.lightened(0.05), Color("fff0a0"))
    )
    button.pressed.connect(_confirm_difficulty.bind(difficulty_key, level_offset))
    return button


func _show_adventure_intro() -> void:
    if _adventure_intro_overlay == null:
        _confirm_new_adventure()
        return

    _hide_difficulty_selector()
    _adventure_intro_overlay.visible = true
    if _adventure_intro_start_button != null:
        _adventure_intro_start_button.disabled = false
        _adventure_intro_start_button.release_focus()


func _hide_adventure_intro() -> void:
    if _adventure_intro_overlay != null:
        _adventure_intro_overlay.visible = false


func _confirm_new_adventure() -> void:
    if _adventure_intro_start_button != null:
        _adventure_intro_start_button.disabled = true

    _hide_adventure_intro()
    _show_difficulty_selector()


func _show_difficulty_selector() -> void:
    if _difficulty_overlay == null:
        _confirm_difficulty("normal", 0)
        return

    _difficulty_overlay.visible = true
    if _difficulty_first_button != null:
        _difficulty_first_button.grab_focus()


func _hide_difficulty_selector() -> void:
    if _difficulty_overlay != null:
        _difficulty_overlay.visible = false


func _confirm_difficulty(difficulty_key: String, level_offset: int) -> void:
    _hide_difficulty_selector()

    if demo_route != null and demo_route.has_method("set_route_difficulty"):
        demo_route.call("set_route_difficulty", difficulty_key, level_offset)
    else:
        push_warning("Abenteuer: Die Route unterstützt noch keine Schwierigkeitsauswahl; Normal wird verwendet.")

    menu_layer.visible = false
    battle_demo.visible = false
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
