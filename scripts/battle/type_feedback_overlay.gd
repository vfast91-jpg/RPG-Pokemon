extends CanvasLayer

const FEEDBACK_HOLD_SECONDS: float = 2.0

var feedback_shade: ColorRect
var feedback_panel: PanelContainer
var feedback_header: Label
var feedback_label: Label

var observed_demo: CanvasLayer
var last_log_text: String = ""
var feedback_time_left: float = 0.0
var restore_demo_processing: bool = false

func _ready() -> void:
    layer = 80
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()

func _process(delta: float) -> void:
    var demo: CanvasLayer = _find_battle_demo()
    if demo == null or not demo.visible:
        last_log_text = ""
        _cancel_feedback()
        return

    observed_demo = demo
    var log_variant: Variant = demo.get("log_label")
    if log_variant is RichTextLabel:
        var current_text: String = str((log_variant as RichTextLabel).text)
        if current_text != last_log_text:
            last_log_text = current_text
            var feedback: Dictionary = _feedback_from_log(current_text)
            if not feedback.is_empty():
                _show_feedback(demo, str(feedback["text"]), feedback["color"] as Color)

    if feedback_time_left > 0.0:
        feedback_time_left -= delta
        if feedback_time_left <= 0.0:
            _finish_feedback()

func _find_battle_demo() -> CanvasLayer:
    var node: Node = get_tree().root.find_child("BattleDemo", true, false)
    if node is CanvasLayer:
        return node as CanvasLayer
    return null

func _feedback_from_log(text: String) -> Dictionary:
    var lower: String = text.to_lower()

    # Reihenfolge ist wichtig: "nicht sehr effektiv" enthält ebenfalls "sehr effektiv".
    if lower.contains("nicht sehr effektiv"):
        return {
            "text": "NICHT SEHR EFFEKTIV!",
            "color": Color("79b9ff")
        }
    if lower.contains("sehr effektiv"):
        return {
            "text": "SEHR EFFEKTIV!",
            "color": Color("ffd34f")
        }
    if lower.contains("keine wirkung"):
        return {
            "text": "KEINE WIRKUNG!",
            "color": Color("c9ced6")
        }
    return {}

func _show_feedback(demo: CanvasLayer, text: String, accent: Color) -> void:
    if observed_demo != null and observed_demo != demo and restore_demo_processing and is_instance_valid(observed_demo):
        observed_demo.set_process(true)

    observed_demo = demo
    restore_demo_processing = demo.is_processing()
    demo.set_process(false)

    feedback_time_left = FEEDBACK_HOLD_SECONDS
    feedback_label.text = text
    feedback_label.add_theme_color_override("font_color", accent)
    feedback_header.add_theme_color_override("font_color", accent.lightened(0.2))
    feedback_panel.add_theme_stylebox_override("panel", _feedback_style(accent))

    feedback_shade.visible = true
    feedback_panel.visible = true

func _finish_feedback() -> void:
    feedback_time_left = 0.0
    feedback_shade.visible = false
    feedback_panel.visible = false

    if observed_demo != null and is_instance_valid(observed_demo) and restore_demo_processing:
        observed_demo.set_process(true)

    restore_demo_processing = false

func _cancel_feedback() -> void:
    if feedback_time_left <= 0.0 and (feedback_panel == null or not feedback_panel.visible):
        observed_demo = null
        restore_demo_processing = false
        return

    _finish_feedback()
    observed_demo = null

func _build_ui() -> void:
    feedback_shade = ColorRect.new()
    feedback_shade.position = Vector2.ZERO
    feedback_shade.size = Vector2(480, 220)
    feedback_shade.color = Color(0.02, 0.025, 0.03, 0.34)
    feedback_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_shade.visible = false
    add_child(feedback_shade)

    feedback_panel = PanelContainer.new()
    feedback_panel.position = Vector2(54, 78)
    feedback_panel.size = Vector2(372, 86)
    feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_panel.visible = false
    add_child(feedback_panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 1)
    feedback_panel.add_child(content)

    feedback_header = Label.new()
    feedback_header.text = "TYPENWIRKUNG"
    feedback_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_header.add_theme_font_size_override("font_size", 11)
    content.add_child(feedback_header)

    feedback_label = Label.new()
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    feedback_label.add_theme_font_size_override("font_size", 23)
    feedback_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
    feedback_label.add_theme_constant_override("shadow_offset_x", 2)
    feedback_label.add_theme_constant_override("shadow_offset_y", 2)
    content.add_child(feedback_label)

func _feedback_style(accent: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.065, 0.075, 0.97)
    style.border_color = accent
    style.set_border_width_all(4)
    style.set_corner_radius_all(12)
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    return style
