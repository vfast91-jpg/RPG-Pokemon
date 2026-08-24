extends "res://scripts/demo_route_global_pokemon_choice_ui_v1.gd"

# Route viewport guard.
#
# The outer gold route frame is always fixed to the visible game viewport and
# must never become a scrollable surface itself. Dynamic overflow is handled
# only by the individual UI regions that can actually grow:
# - event/result text scrolls inside its RichTextLabel,
# - dynamic route actions (training, TM/item targets, capture choices, etc.)
#   scroll inside their own local ScrollContainer.
#
# This keeps the whole screen fixed while still guaranteeing that every choice
# and every local back button remains reachable with larger teams/content.

var _tf_route_frame: PanelContainer
var _tf_action_scroll: ScrollContainer


func _ready() -> void:
    super._ready()
    _tf_install_route_viewport_guard()
    _tf_install_local_action_scroll()
    _tf_bound_event_log()
    _tf_refresh_action_scroll_state()


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    _tf_install_route_viewport_guard()
    _tf_install_local_action_scroll()
    _tf_bound_event_log()
    _tf_refresh_action_scroll_state()


func _begin_training_event() -> void:
    super._begin_training_event()
    _tf_install_local_action_scroll()
    _tf_add_training_back_button()
    _tf_refresh_action_scroll_state()
    _tf_reset_action_scroll()


func _prepare_boss_reward_finish(reward_text: String) -> void:
    super._prepare_boss_reward_finish(reward_text)

    # The CTA already says exactly what clicking it does. A duplicate tooltip
    # only covers the button and can intercept the mouse in the custom tooltip UI.
    if capture_actions == null:
        return
    var finish_card: Node = capture_actions.get_node_or_null("NextStageCTA")
    if finish_card == null:
        return

    for child: Node in finish_card.get_children():
        if child is Button:
            (child as Button).tooltip_text = ""


func _tf_prepare_route_choice_layout(landscape_choice: bool) -> void:
    # The landscape layer historically switched fit_content back on here. That
    # makes long battle summaries part of the route panel's minimum height and
    # can push the gold frame below the viewport. Keep its intended minimum
    # height, but restore local text scrolling immediately afterwards.
    super._tf_prepare_route_choice_layout(landscape_choice)
    _tf_bound_event_log()
    _tf_refresh_action_scroll_state()


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


func _tf_install_local_action_scroll() -> void:
    if capture_actions == null:
        return

    var current_parent: Node = capture_actions.get_parent()
    if current_parent is ScrollContainer:
        _tf_action_scroll = current_parent as ScrollContainer
        _tf_configure_action_scroll(_tf_action_scroll)
        _tf_connect_action_scroll_signals()
        return

    if current_parent == null:
        return

    var original_index: int = capture_actions.get_index()
    current_parent.remove_child(capture_actions)

    _tf_action_scroll = ScrollContainer.new()
    _tf_action_scroll.name = "RouteActionScroll"
    _tf_configure_action_scroll(_tf_action_scroll)
    current_parent.add_child(_tf_action_scroll)
    current_parent.move_child(_tf_action_scroll, original_index)
    _tf_action_scroll.add_child(capture_actions)

    # The action VBox may grow to any height; its parent scroll region, not the
    # outer route frame, owns that overflow.
    capture_actions.custom_minimum_size = Vector2.ZERO
    capture_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    capture_actions.size_flags_vertical = Control.SIZE_FILL

    _tf_connect_action_scroll_signals()
    _tf_refresh_action_scroll_state()


func _tf_configure_action_scroll(scroll: ScrollContainer) -> void:
    scroll.custom_minimum_size = Vector2.ZERO
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.clip_contents = true


func _tf_connect_action_scroll_signals() -> void:
    if capture_actions == null:
        return

    var entered_callback := Callable(self, "_tf_on_action_child_entered")
    if not capture_actions.child_entered_tree.is_connected(entered_callback):
        capture_actions.child_entered_tree.connect(entered_callback)

    var exiting_callback := Callable(self, "_tf_on_action_child_exiting")
    if not capture_actions.child_exiting_tree.is_connected(exiting_callback):
        capture_actions.child_exiting_tree.connect(exiting_callback)


func _tf_on_action_child_entered(_child: Node) -> void:
    if capture_actions != null and capture_actions.get_child_count() == 1:
        _tf_reset_action_scroll()
    call_deferred("_tf_refresh_action_scroll_state")


func _tf_on_action_child_exiting(_child: Node) -> void:
    call_deferred("_tf_refresh_action_scroll_state")


func _tf_refresh_action_scroll_state() -> void:
    if _tf_action_scroll == null or capture_actions == null:
        return

    var has_actions: bool = capture_actions.get_child_count() > 0
    _tf_action_scroll.visible = has_actions

    # When a choice list is open, reserve only the event label's own bounded
    # height and give the remaining route space to the local action scroller.
    # Without choices the event/result area may use the spare space normally.
    if event_label != null:
        event_label.size_flags_vertical = (
            Control.SIZE_FILL if has_actions else Control.SIZE_EXPAND_FILL
        )


func _tf_reset_action_scroll() -> void:
    if _tf_action_scroll != null:
        _tf_action_scroll.scroll_vertical = 0


func _tf_add_training_back_button() -> void:
    if capture_actions == null:
        return
    if capture_actions.get_node_or_null("TrainingBackButton") != null:
        return

    var back_button := Button.new()
    back_button.name = "TrainingBackButton"
    back_button.text = "↩  ZURÜCK ZUR WEGAUSWAHL"
    back_button.tooltip_text = "Trainingsplatz verlassen und für diese Etappe einen anderen Weg wählen."
    back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    back_button.pressed.connect(_show_stage_choices)
    _style_route_decision_button(back_button, false)
    back_button.custom_minimum_size.y = 36.0
    capture_actions.add_child(back_button)


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