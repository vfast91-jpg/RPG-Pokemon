extends "res://scripts/demo_route_global_pokemon_choice_ui_v1.gd"

# Route viewport guard.
#
# Dynamic route content must never be allowed to enlarge the outer gold frame
# beyond the visible game viewport. The normal route UI still keeps its compact
# layout, but the complete frame content now has a ScrollContainer as a final
# safety net. In addition, the event/result text stays in its own bounded,
# scrollable RichTextLabel instead of growing with every XP/level-up line.

var _tf_route_frame: PanelContainer
var _tf_route_frame_scroll: ScrollContainer


func _ready() -> void:
    super._ready()
    _tf_install_route_viewport_guard()
    _tf_bound_event_log()


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    _tf_bound_event_log()


func _tf_prepare_route_choice_layout(landscape_choice: bool) -> void:
    # The landscape layer historically switched fit_content back on here. That
    # makes long battle summaries part of the route panel's minimum height and
    # can push the gold frame below the viewport. Keep its intended minimum
    # height, but restore scrolling immediately afterwards.
    super._tf_prepare_route_choice_layout(landscape_choice)
    _tf_bound_event_log()


func _tf_install_route_viewport_guard() -> void:
    if root == null:
        return

    _tf_route_frame = _tf_find_route_frame()
    if _tf_route_frame == null:
        push_warning("Demo-Route: äußerer Routenrahmen für Viewport-Schutz nicht gefunden.")
        return

    _tf_route_frame.name = "RouteViewportFrame"
    _tf_route_frame.clip_contents = true
    _tf_route_frame.custom_minimum_size = Vector2.ZERO

    # The frame itself always follows the viewport. Content is never permitted
    # to redefine these bounds; overflow belongs to the inner scroll areas.
    _tf_route_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _tf_route_frame.offset_left = 8.0
    _tf_route_frame.offset_top = 8.0
    _tf_route_frame.offset_right = -8.0
    _tf_route_frame.offset_bottom = -8.0

    if _tf_route_frame.get_child_count() == 0:
        return

    var existing_child: Node = _tf_route_frame.get_child(0)
    if existing_child is ScrollContainer:
        _tf_route_frame_scroll = existing_child as ScrollContainer
        _tf_configure_frame_scroll(_tf_route_frame_scroll)
        return

    _tf_route_frame.remove_child(existing_child)

    _tf_route_frame_scroll = ScrollContainer.new()
    _tf_route_frame_scroll.name = "RouteViewportScroll"
    _tf_configure_frame_scroll(_tf_route_frame_scroll)
    _tf_route_frame.add_child(_tf_route_frame_scroll)
    _tf_route_frame_scroll.add_child(existing_child)

    if existing_child is Control:
        var content := existing_child as Control
        content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _tf_find_route_frame() -> PanelContainer:
    if root == null:
        return null

    for child: Node in root.get_children():
        if child is PanelContainer:
            return child as PanelContainer
    return null


func _tf_configure_frame_scroll(scroll: ScrollContainer) -> void:
    scroll.custom_minimum_size = Vector2.ZERO
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func _tf_bound_event_log() -> void:
    if event_label == null:
        return

    # The result/event text gets the available space, but its text length never
    # contributes additional minimum height. Long summaries are read by scrolling
    # inside this field instead of moving the route frame out of the picture.
    event_label.fit_content = false
    event_label.scroll_active = true
    event_label.scroll_following = false
    event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    event_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
