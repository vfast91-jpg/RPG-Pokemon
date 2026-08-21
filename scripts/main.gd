extends Node2D

const MAIN_MENU_BACKGROUND: Texture2D = preload("res://assets/main_menu_background.jpg")

@onready var battle_demo: CanvasLayer = $BattleDemo
@onready var demo_route: CanvasLayer = $DemoRoute

var menu_layer: CanvasLayer
var menu_root: Control


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
    frame.custom_minimum_size = Vector2(388, 244)
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
    route_button.tooltip_text = "Zehn Etappen mit Pfadwahl, Fangen, Heilung, EP und persistenten KP."
    route_button.pressed.connect(_start_demo_route)
    content.add_child(route_button)

    var hint := Label.new()
    hint.text = "Die Demo-Route startet mit einem zufälligen Pokémon auf Level 5."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 9)
    hint.add_theme_color_override("font_color", Color("91b0a3"))
    content.add_child(hint)


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
    menu_layer.visible = false
    demo_route.visible = false
    battle_demo.visible = true
    battle_demo.call("open_config")


func _start_demo_route() -> void:
    menu_layer.visible = false
    battle_demo.visible = false
    demo_route.call("start_route")


func _show_main_menu() -> void:
    battle_demo.visible = false
    demo_route.visible = false
    if menu_layer != null:
        menu_layer.visible = true
