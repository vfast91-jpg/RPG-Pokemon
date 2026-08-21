extends Node2D

const MAIN_MENU_BACKGROUND: Texture2D = preload("res://assets/main_menu_background.jpg")
const LeaderboardStore = preload("res://scripts/demo_route_leaderboard.gd")

@onready var battle_demo: CanvasLayer = $BattleDemo
@onready var demo_route: CanvasLayer = $DemoRoute

var menu_layer: CanvasLayer
var menu_root: Control
var leaderboard_overlay: Control
var leaderboard_text: RichTextLabel


func _ready() -> void:
    demo_route.call("configure", battle_demo)

    if battle_demo.has_signal("request_main_menu"):
        battle_demo.connect("request_main_menu", Callable(self, "_show_main_menu"))
    if demo_route.has_signal("request_main_menu"):
        demo_route.connect("request_main_menu", Callable(self, "_show_main_menu"))

    _build_main_menu()
    _show_main_menu()


func _build_main_menu() -> void:
    menu_layer = CanvasLayer.new()
    menu_layer.layer = 100
    add_child(menu_layer)

    menu_root = Control.new()
    menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
    menu_layer.add_child(menu_root)

    var background := TextureRect.new()
    background.texture = MAIN_MENU_BACKGROUND
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_root.add_child(background)

    var dimmer := ColorRect.new()
    dimmer.color = Color(0.0, 0.0, 0.0, 0.22)
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_root.add_child(dimmer)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_root.add_child(center)

    var frame := PanelContainer.new()
    frame.custom_minimum_size = Vector2(420, 310)
    frame.add_theme_stylebox_override("panel", _panel(Color("172823"), Color("e0c95f"), 12, 14.0))
    center.add_child(frame)

    var content := VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 11)
    frame.add_child(content)

    var title := Label.new()
    title.text = "POKEMON TIMEFLOW"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Wähle, was du testen möchtest."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 11)
    subtitle.add_theme_color_override("font_color", Color("c4d9d0"))
    content.add_child(subtitle)

    var test_button := Button.new()
    test_button.text = "TESTKAMPF"
    test_button.custom_minimum_size = Vector2(240, 44)
    test_button.tooltip_text = "Öffnet die bisherige frei konfigurierbare Kampflabor-Maske."
    test_button.pressed.connect(_start_test_battle)
    content.add_child(test_button)

    var route_button := Button.new()
    route_button.text = "DEMO-ROUTE"
    route_button.custom_minimum_size = Vector2(240, 44)
    route_button.tooltip_text = "90 Etappen mit Pfadwahl, Fangen, Heilung, TMs, EP und persistenten KP."
    route_button.pressed.connect(_start_demo_route)
    content.add_child(route_button)

    var leaderboard_button := Button.new()
    leaderboard_button.text = "BESTENLISTE"
    leaderboard_button.custom_minimum_size = Vector2(240, 40)
    leaderboard_button.tooltip_text = "Zeigt die lokal gespeicherten Ergebnisse der Demo-Route samt letztem Team."
    leaderboard_button.pressed.connect(_show_leaderboard)
    content.add_child(leaderboard_button)

    var hint := Label.new()
    hint.text = "Die Demo-Route startet mit einem zufälligen Pokémon auf Level 5 und führt bis Etappe 90."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 9)
    hint.add_theme_color_override("font_color", Color("91b0a3"))
    content.add_child(hint)

    _build_leaderboard_overlay()


func _build_leaderboard_overlay() -> void:
    leaderboard_overlay = Control.new()
    leaderboard_overlay.name = "LeaderboardOverlay"
    leaderboard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    leaderboard_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    leaderboard_overlay.z_index = 30
    leaderboard_overlay.visible = false
    menu_root.add_child(leaderboard_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    leaderboard_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    leaderboard_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(620, 470)
    panel.add_theme_stylebox_override("panel", _panel(Color("172823"), Color("e0c95f"), 12, 14.0))
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    panel.add_child(content)

    var title := Label.new()
    title.text = "BESTENLISTE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Höchste erreichte Etappe zuerst · inklusive letztem Team"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 10)
    subtitle.add_theme_color_override("font_color", Color("b7cfc4"))
    content.add_child(subtitle)

    leaderboard_text = RichTextLabel.new()
    leaderboard_text.bbcode_enabled = false
    leaderboard_text.fit_content = false
    leaderboard_text.scroll_active = true
    leaderboard_text.custom_minimum_size = Vector2(570, 330)
    leaderboard_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    leaderboard_text.add_theme_font_size_override("normal_font_size", 12)
    content.add_child(leaderboard_text)

    var close_button := Button.new()
    close_button.text = "SCHLIESSEN"
    close_button.custom_minimum_size = Vector2(180, 36)
    close_button.pressed.connect(_hide_leaderboard)
    content.add_child(close_button)


func _show_leaderboard() -> void:
    _refresh_leaderboard()
    leaderboard_overlay.visible = true


func _hide_leaderboard() -> void:
    if leaderboard_overlay != null:
        leaderboard_overlay.visible = false


func _refresh_leaderboard() -> void:
    if leaderboard_text == null:
        return

    var entries: Array = LeaderboardStore.load_entries()
    if entries.is_empty():
        leaderboard_text.text = "Noch keine Einträge.\n\nBeende einen Lauf der Demo-Route und trage danach deinen Namen ein."
        return

    var lines: Array[String] = []
    for index: int in range(entries.size()):
        var entry_value: Variant = entries[index]
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var outcome: String = str(entry.get("outcome", "Niederlage"))
        lines.append("%d. %s · Etappe %d/90 · %s" % [
            index + 1,
            str(entry.get("name", "Unbekannt")),
            int(entry.get("stage", 1)),
            outcome
        ])
        lines.append("   Team: " + LeaderboardStore.team_text(entry))
        lines.append("")

    leaderboard_text.text = "\n".join(lines)
    leaderboard_text.scroll_to_line(0)


func _panel(bg: Color, border: Color, radius: int = 8, margin: float = 7.0) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.content_margin_left = margin
    style.content_margin_right = margin
    style.content_margin_top = margin
    style.content_margin_bottom = margin
    return style


func _start_test_battle() -> void:
    _hide_leaderboard()
    menu_layer.visible = false
    demo_route.visible = false
    battle_demo.visible = true
    battle_demo.call("open_config")


func _start_demo_route() -> void:
    _hide_leaderboard()
    menu_layer.visible = false
    battle_demo.visible = false
    demo_route.call("start_route")


func _show_main_menu() -> void:
    battle_demo.visible = false
    demo_route.visible = false
    _hide_leaderboard()
    if menu_layer != null:
        menu_layer.visible = true
