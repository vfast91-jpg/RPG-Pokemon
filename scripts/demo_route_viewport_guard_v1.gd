extends "res://scripts/demo_route_global_pokemon_choice_ui_v1.gd"

# Route viewport guard.
#
# The outer gold route frame is always fixed to the visible game viewport and
# must never become a scrollable surface itself. Dynamic overflow is handled
# only by the individual UI regions that can actually grow. In particular, the
# event/result text owns its own scrollbar and never contributes extra height
# for XP, level-up or other multi-line summaries.

var _tf_route_frame: PanelContainer


func _ready() -> void:
    super._ready()
    _tf_install_route_viewport_guard()
    _tf_bound_event_log()


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    _tf_install_route_viewport_guard()
    _tf_bound_event_log()


func _tf_prepare_route_choice_layout(landscape_choice: bool) -> void:
    # The landscape layer historically switched fit_content back on here. That
    # makes long battle summaries part of the route panel's minimum height and
    # can push the gold frame below the viewport. Keep its intended minimum
    # height, but restore local text scrolling immediately afterwards.
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

    # The frame itself follows the viewport and is deliberately NOT wrapped in
    # a ScrollContainer. The whole route screen must never show a global
    # scrollbar; only bounded child regions may scroll when their own content
    # becomes too large.
    _tf_route_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _tf_route_frame.offset_left = 8.0
    _tf_route_frame.offset_top = 8.0
    _tf_route_frame.offset_right = -8.0
    _tf_route_frame.offset_bottom = -8.0


func _tf_find_route_frame() -> PanelContainer:
    if root == null:
        return null

    for child: Node in root.get_children():
        if child is PanelContainer:
            return child as PanelContainer
    return null


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
