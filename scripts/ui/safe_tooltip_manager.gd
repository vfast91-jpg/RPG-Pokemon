extends Node

# Global tooltip safety layer.
#
# Godot's native tooltip label does not impose a useful maximum text width for
# this project. Long descriptions can therefore grow past the game viewport.
# This manager replaces every ordinary Control.tooltip_text at runtime with one
# shared, bounded tooltip surface:
# - smart word wrapping is always enabled,
# - width is capped to the visible viewport,
# - very long text is capped vertically,
# - the whole box is clamped to the viewport,
# - the box follows the pointer and never intercepts clicks,
# - controls created later are covered automatically because the currently
#   hovered Control is inspected every frame instead of maintaining a fixed list.
#
# Existing UI code can keep assigning `tooltip_text` normally. No per-screen
# tooltip implementation is required.

const META_STORED_TOOLTIP: StringName = &"_tf_safe_tooltip_stored"
const META_INTERNAL: StringName = &"_tf_safe_tooltip_internal"

const TOOLTIP_DELAY_SECONDS: float = 0.28
const TOOLTIP_MIN_WIDTH: float = 150.0
const TOOLTIP_MAX_WIDTH: float = 320.0
const TOOLTIP_MAX_HEIGHT: float = 236.0
const TOOLTIP_VIEWPORT_MARGIN: float = 8.0
const TOOLTIP_CURSOR_GAP: float = 10.0
const TOOLTIP_HORIZONTAL_PADDING: float = 20.0
const TOOLTIP_VERTICAL_PADDING: float = 16.0
const TOOLTIP_MIN_TEXT_HEIGHT: float = 24.0
const TOOLTIP_FONT_SIZE: int = 10

var _layer: CanvasLayer
var _panel: PanelContainer
var _text: RichTextLabel
var _delay_timer: Timer

var _source: Control = null
var _source_text: String = ""
var _layout_serial: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_tooltip_surface()

    _delay_timer = Timer.new()
    _delay_timer.one_shot = true
    _delay_timer.wait_time = TOOLTIP_DELAY_SECONDS
    _delay_timer.timeout.connect(_on_tooltip_delay_timeout)
    add_child(_delay_timer)


func _exit_tree() -> void:
    _restore_source_tooltip()


func _process(_delta: float) -> void:
    var viewport: Viewport = get_viewport()
    if viewport == null:
        return

    var hovered: Control = viewport.gui_get_hovered_control()

    # Tooltip controls never become the hovered Control because their mouse
    # filter is IGNORE. Keep this guard as a safety net for future child nodes.
    if _is_internal_tooltip_control(hovered):
        return

    var next_source: Control = _find_tooltip_source(hovered)
    if next_source == _source:
        # Reposition every frame while visible. Besides feeling more natural,
        # this keeps the box out of the pointer's path when the player moves
        # from one nearby button to another.
        if _panel != null and _panel.visible:
            _position_tooltip(_viewport_size())
        return

    _switch_source(next_source)


func _build_tooltip_surface() -> void:
    _layer = CanvasLayer.new()
    _layer.name = "SafeTooltipLayer"
    _layer.layer = 4095
    add_child(_layer)

    _panel = PanelContainer.new()
    _panel.name = "SafeTooltipPanel"
    _panel.visible = false
    # A tooltip is information, not an interactive surface. IGNORE lets hover,
    # clicks and wheel events reach the game controls underneath it.
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.set_meta(META_INTERNAL, true)
    _layer.add_child(_panel)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.055, 0.050, 0.98)
    style.border_color = Color("d8c65e")
    style.set_border_width_all(1)
    style.set_corner_radius_all(6)
    style.content_margin_left = 9.0
    style.content_margin_right = 9.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    _panel.add_theme_stylebox_override("panel", style)

    _text = RichTextLabel.new()
    _text.name = "SafeTooltipText"
    _text.bbcode_enabled = false
    _text.fit_content = false
    _text.scroll_active = false
    _text.scroll_following = false
    _text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _text.set_meta(META_INTERNAL, true)
    _text.add_theme_font_size_override("normal_font_size", TOOLTIP_FONT_SIZE)
    _text.add_theme_color_override("default_color", Color("f7f5ea"))
    _text.add_theme_constant_override("line_separation", 1)
    _panel.add_child(_text)


func _find_tooltip_source(start: Control) -> Control:
    var node: Node = start
    while node != null:
        if node is Control:
            var control: Control = node as Control
            if _is_internal_tooltip_control(control):
                return null
            if not _tooltip_text_for(control).is_empty():
                return control
        node = node.get_parent()
    return null


func _tooltip_text_for(control: Control) -> String:
    if control == null or not is_instance_valid(control):
        return ""

    var current: String = control.tooltip_text.strip_edges()
    if not current.is_empty():
        return current

    if control.has_meta(META_STORED_TOOLTIP):
        return str(control.get_meta(META_STORED_TOOLTIP, "")).strip_edges()
    return ""


func _switch_source(next_source: Control) -> void:
    var previous_text: String = _source_text
    var keep_visible: bool = _panel != null and _panel.visible

    _restore_source_tooltip()
    _delay_timer.stop()

    _source = next_source
    _source_text = ""

    if _source == null or not is_instance_valid(_source):
        _hide_tooltip_surface()
        return

    _source_text = _tooltip_text_for(_source)
    if _source_text.is_empty():
        _source = null
        _hide_tooltip_surface()
        return

    # Clear the native tooltip while this Control is the active source. The
    # original text lives in metadata and is restored when the pointer leaves.
    _source.set_meta(META_STORED_TOOLTIP, _source_text)
    _source.tooltip_text = ""

    # Moving between a child and its parent can change the hovered Control while
    # still referring to the exact same tooltip. Keep the box stable in that
    # case instead of making it blink and wait for the delay again.
    if keep_visible and previous_text == _source_text:
        _show_tooltip_surface()
        return

    _hide_tooltip_surface()
    _delay_timer.start()


func _restore_source_tooltip() -> void:
    if _source == null or not is_instance_valid(_source):
        return
    if not _source.has_meta(META_STORED_TOOLTIP):
        return

    var stored: String = str(_source.get_meta(META_STORED_TOOLTIP, ""))
    # Respect a tooltip that another system may have replaced while this one was
    # active. Only restore our saved value when the property is still empty.
    if _source.tooltip_text.is_empty() and not stored.is_empty():
        _source.tooltip_text = stored
    _source.remove_meta(META_STORED_TOOLTIP)


func _on_tooltip_delay_timeout() -> void:
    if _source == null or not is_instance_valid(_source) or _source_text.is_empty():
        return
    _show_tooltip_surface()


func _show_tooltip_surface() -> void:
    if _panel == null or _text == null or _source_text.is_empty():
        return

    _layout_serial += 1
    var serial: int = _layout_serial
    var viewport_size: Vector2 = _viewport_size()
    var panel_width: float = _desired_tooltip_width(_source_text, viewport_size)

    _text.text = _source_text
    _text.scroll_active = false
    _text.custom_minimum_size = Vector2.ZERO

    # Give RichTextLabel the real wrap width before asking it for content height.
    var text_width: float = maxf(80.0, panel_width - TOOLTIP_HORIZONTAL_PADDING)
    _text.size = Vector2(text_width, TOOLTIP_MIN_TEXT_HEIGHT)

    _panel.size = Vector2(panel_width, TOOLTIP_MIN_TEXT_HEIGHT + TOOLTIP_VERTICAL_PADDING)
    _panel.visible = true
    _position_tooltip(viewport_size)

    # Containers finish assigning the exact child width at the end of the frame.
    # Recalculate then so wrapped content height is based on the final width.
    call_deferred("_finalize_tooltip_layout", serial, panel_width)


func _finalize_tooltip_layout(serial: int, panel_width: float) -> void:
    if serial != _layout_serial or _panel == null or _text == null or not _panel.visible:
        return

    var viewport_size: Vector2 = _viewport_size()
    var max_panel_height: float = minf(
        TOOLTIP_MAX_HEIGHT,
        maxf(TOOLTIP_MIN_TEXT_HEIGHT + TOOLTIP_VERTICAL_PADDING, viewport_size.y - TOOLTIP_VIEWPORT_MARGIN * 2.0)
    )
    var max_text_height: float = maxf(
        TOOLTIP_MIN_TEXT_HEIGHT,
        max_panel_height - TOOLTIP_VERTICAL_PADDING
    )

    var text_width: float = maxf(80.0, panel_width - TOOLTIP_HORIZONTAL_PADDING)
    _text.size = Vector2(text_width, max_text_height)

    var natural_height: float = maxf(
        TOOLTIP_MIN_TEXT_HEIGHT,
        float(_text.get_content_height()) + 3.0
    )
    var shown_text_height: float = minf(natural_height, max_text_height)

    _text.custom_minimum_size = Vector2(0.0, shown_text_height)
    _text.size = Vector2(text_width, shown_text_height)
    _text.scroll_active = natural_height > shown_text_height + 0.5

    _panel.size = Vector2(
        panel_width,
        minf(max_panel_height, shown_text_height + TOOLTIP_VERTICAL_PADDING)
    )
    _position_tooltip(viewport_size)


func _desired_tooltip_width(text_value: String, viewport_size: Vector2) -> float:
    var longest_line: int = 0
    for line_value: String in text_value.split("\n"):
        longest_line = maxi(longest_line, line_value.length())

    # Approximate only the preferred compact width; wrapping itself is handled
    # by RichTextLabel and remains authoritative.
    var desired: float = 26.0 + float(longest_line) * 5.6
    var viewport_cap: float = maxf(
        100.0,
        viewport_size.x - TOOLTIP_VIEWPORT_MARGIN * 2.0
    )
    return clampf(
        desired,
        minf(TOOLTIP_MIN_WIDTH, viewport_cap),
        minf(TOOLTIP_MAX_WIDTH, viewport_cap)
    )


func _position_tooltip(viewport_size: Vector2) -> void:
    if _panel == null or not _panel.visible:
        return

    var viewport: Viewport = get_viewport()
    if viewport == null:
        return

    var mouse: Vector2 = viewport.get_mouse_position()
    var panel_size: Vector2 = _panel.size
    var position_value: Vector2 = mouse + Vector2(TOOLTIP_CURSOR_GAP, TOOLTIP_CURSOR_GAP)

    if position_value.x + panel_size.x > viewport_size.x - TOOLTIP_VIEWPORT_MARGIN:
        position_value.x = mouse.x - panel_size.x - TOOLTIP_CURSOR_GAP
    if position_value.y + panel_size.y > viewport_size.y - TOOLTIP_VIEWPORT_MARGIN:
        position_value.y = mouse.y - panel_size.y - TOOLTIP_CURSOR_GAP

    position_value.x = clampf(
        position_value.x,
        TOOLTIP_VIEWPORT_MARGIN,
        maxf(TOOLTIP_VIEWPORT_MARGIN, viewport_size.x - panel_size.x - TOOLTIP_VIEWPORT_MARGIN)
    )
    position_value.y = clampf(
        position_value.y,
        TOOLTIP_VIEWPORT_MARGIN,
        maxf(TOOLTIP_VIEWPORT_MARGIN, viewport_size.y - panel_size.y - TOOLTIP_VIEWPORT_MARGIN)
    )
    _panel.position = position_value


func _viewport_size() -> Vector2:
    var viewport: Viewport = get_viewport()
    if viewport == null:
        return Vector2(640.0, 360.0)
    return viewport.get_visible_rect().size


func _hide_tooltip_surface() -> void:
    _layout_serial += 1
    if _panel != null:
        _panel.visible = false
    if _text != null:
        _text.text = ""
        _text.scroll_active = false


func _is_internal_tooltip_control(control: Control) -> bool:
    var node: Node = control
    while node != null:
        if node is Control and (node as Control).has_meta(META_INTERNAL):
            return true
        if node == _layer:
            return true
        node = node.get_parent()
    return false
