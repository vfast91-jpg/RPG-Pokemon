extends "res://scripts/demo_route_global_pokemon_choice_ui_v1.gd"

# Route viewport guard.
#
# The gold outer frame is a hard viewport boundary. It is NEVER a scrollable
# surface. Overflow is handled only where scrolling is actually useful:
# - event/result text scrolls inside its RichTextLabel,
# - dynamic action lists (training, TM/item targets, capture choices, etc.)
#   scroll locally if needed,
# - route/path content (including the two landscape cards) is clipped inside a
#   bounded viewport but deliberately has NO scrollbar.
#
# This breaks minimum-size propagation from dynamic content before the outer
# frame is re-anchored. Adding text, cards or future route choices must not be
# able to push the gold frame below the visible 640x360 game viewport.

const ROUTE_EVENT_LABEL_MAX_MIN_HEIGHT: float = 58.0
const ROUTE_PATH_MAX_HEIGHT: float = 168.0

var _tf_route_frame: PanelContainer
var _tf_path_viewport: Control
var _tf_action_scroll: ScrollContainer


func _ready() -> void:
    super._ready()
    _tf_install_local_path_viewport()
    _tf_install_local_action_scroll()
    _tf_bound_event_log()
    _tf_refresh_local_scroll_state()
    _tf_install_route_viewport_guard()


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    _tf_install_local_path_viewport()
    _tf_install_local_action_scroll()
    _tf_bound_event_log()
    _tf_refresh_local_scroll_state()
    _tf_install_route_viewport_guard()


func _begin_training_event() -> void:
    super._begin_training_event()
    _tf_install_local_action_scroll()
    _tf_add_training_back_button()
    _tf_refresh_local_scroll_state()
    _tf_reset_action_scroll()
    _tf_install_route_viewport_guard()


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

    _tf_refresh_local_scroll_state()
    _tf_install_route_viewport_guard()


func _tf_prepare_route_choice_layout(landscape_choice: bool) -> void:
    # Older landscape code deliberately requests a larger, non-scrolling text
    # block. The active guard restores the global rule afterwards: information
    # text is bounded and scrolls locally instead of contributing arbitrary
    # minimum height to the route layout.
    super._tf_prepare_route_choice_layout(landscape_choice)
    _tf_bound_event_log()
    _tf_refresh_local_scroll_state()
    _tf_install_route_viewport_guard()


func _tf_install_route_viewport_guard() -> void:
    if root == null:
        return

    _tf_route_frame = _tf_find_route_frame()
    if _tf_route_frame == null:
        push_warning("Demo-Route: äußerer Routenrahmen für Viewport-Schutz nicht gefunden.")
        return

    _tf_apply_route_frame_bounds(_tf_route_frame)


func _tf_apply_route_frame_bounds(frame: PanelContainer) -> void:
    frame.name = "RouteViewportFrame"
    frame.clip_contents = true
    frame.custom_minimum_size = Vector2.ZERO

    # IMPORTANT: no ScrollContainer may ever wrap this frame. Reapplying these
    # exact anchors after local minimum-size guards have been installed makes the
    # visible viewport, not child content, authoritative for the outer bounds.
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    frame.offset_left = 8.0
    frame.offset_top = 8.0
    frame.offset_right = -8.0
    frame.offset_bottom = -8.0


func _tf_install_local_path_viewport() -> void:
    if path_box == null:
        return

    var current_parent: Node = path_box.get_parent()

    # Compatibility cleanup for builds that still have the previous
    # RoutePathScroll wrapper alive during a hot reload. Replace that scrollbar
    # with the non-scrolling clipped viewport used by the current layout.
    if current_parent is ScrollContainer:
        var old_scroll := current_parent as ScrollContainer
        var holder: Node = old_scroll.get_parent()
        if holder == null:
            return
        var old_index: int = old_scroll.get_index()
        old_scroll.remove_child(path_box)
        holder.remove_child(old_scroll)
        old_scroll.free()
        _tf_path_viewport = _tf_make_path_viewport()
        holder.add_child(_tf_path_viewport)
        holder.move_child(_tf_path_viewport, old_index)
        _tf_path_viewport.add_child(path_box)
        _tf_configure_path_box()
        _tf_connect_path_viewport_signals()
        return

    if current_parent is Control and current_parent.name == "RoutePathViewport":
        _tf_path_viewport = current_parent as Control
        _tf_configure_path_viewport(_tf_path_viewport)
        _tf_configure_path_box()
        _tf_connect_path_viewport_signals()
        return

    if current_parent == null:
        return

    var original_index: int = path_box.get_index()
    current_parent.remove_child(path_box)

    _tf_path_viewport = _tf_make_path_viewport()
    current_parent.add_child(_tf_path_viewport)
    current_parent.move_child(_tf_path_viewport, original_index)
    _tf_path_viewport.add_child(path_box)

    _tf_configure_path_box()
    _tf_connect_path_viewport_signals()


# Compatibility alias retained for older tests/callers. Despite the historical
# name this no longer installs a scrollbar around path/landscape content.
func _tf_install_local_path_scroll() -> void:
    _tf_install_local_path_viewport()


func _tf_make_path_viewport() -> Control:
    var viewport := Control.new()
    viewport.name = "RoutePathViewport"
    _tf_configure_path_viewport(viewport)
    return viewport


func _tf_configure_path_viewport(viewport: Control) -> void:
    viewport.custom_minimum_size = Vector2.ZERO
    viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    viewport.size_flags_vertical = Control.SIZE_FILL
    viewport.clip_contents = true


func _tf_configure_path_box() -> void:
    if path_box == null:
        return

    # A plain Control boundary does not propagate the VBox minimum height to the
    # outer route layout. The VBox still uses its natural height internally, and
    # the known landscape layout fits inside the capped 168px viewport without a
    # scrollbar.
    path_box.custom_minimum_size = Vector2.ZERO
    path_box.anchor_left = 0.0
    path_box.anchor_top = 0.0
    path_box.anchor_right = 1.0
    path_box.anchor_bottom = 0.0
    path_box.offset_left = 0.0
    path_box.offset_top = 0.0
    path_box.offset_right = 0.0
    path_box.offset_bottom = 0.0
    path_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    path_box.size_flags_vertical = Control.SIZE_FILL


func _tf_install_local_action_scroll() -> void:
    if capture_actions == null:
        return

    var current_parent: Node = capture_actions.get_parent()
    if current_parent is ScrollContainer:
        _tf_action_scroll = current_parent as ScrollContainer
        _tf_action_scroll.name = "RouteActionScroll"
        _tf_configure_local_scroll(_tf_action_scroll)
        _tf_connect_action_scroll_signals()
        return

    if current_parent == null:
        return

    var original_index: int = capture_actions.get_index()
    current_parent.remove_child(capture_actions)

    _tf_action_scroll = ScrollContainer.new()
    _tf_action_scroll.name = "RouteActionScroll"
    _tf_configure_local_scroll(_tf_action_scroll)
    current_parent.add_child(_tf_action_scroll)
    current_parent.move_child(_tf_action_scroll, original_index)
    _tf_action_scroll.add_child(capture_actions)

    # The action VBox may grow to any height; its local parent, never the outer
    # route frame, owns that overflow.
    capture_actions.custom_minimum_size = Vector2.ZERO
    capture_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    capture_actions.size_flags_vertical = Control.SIZE_FILL

    _tf_connect_action_scroll_signals()


func _tf_configure_local_scroll(scroll: ScrollContainer) -> void:
    scroll.custom_minimum_size = Vector2.ZERO
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.clip_contents = true


func _tf_connect_path_viewport_signals() -> void:
    if path_box == null:
        return

    var entered_callback := Callable(self, "_tf_on_path_child_entered")
    if not path_box.child_entered_tree.is_connected(entered_callback):
        path_box.child_entered_tree.connect(entered_callback)

    var exiting_callback := Callable(self, "_tf_on_path_child_exiting")
    if not path_box.child_exiting_tree.is_connected(exiting_callback):
        path_box.child_exiting_tree.connect(exiting_callback)

    var visibility_callback := Callable(self, "_tf_on_path_visibility_changed")
    if not path_box.visibility_changed.is_connected(visibility_callback):
        path_box.visibility_changed.connect(visibility_callback)


# Compatibility alias retained for older callers.
func _tf_connect_path_scroll_signals() -> void:
    _tf_connect_path_viewport_signals()


func _tf_connect_action_scroll_signals() -> void:
    if capture_actions == null:
        return

    var entered_callback := Callable(self, "_tf_on_action_child_entered")
    if not capture_actions.child_entered_tree.is_connected(entered_callback):
        capture_actions.child_entered_tree.connect(entered_callback)

    var exiting_callback := Callable(self, "_tf_on_action_child_exiting")
    if not capture_actions.child_exiting_tree.is_connected(exiting_callback):
        capture_actions.child_exiting_tree.connect(exiting_callback)


func _tf_on_path_child_entered(_child: Node) -> void:
    call_deferred("_tf_refresh_local_scroll_state")


func _tf_on_path_child_exiting(_child: Node) -> void:
    call_deferred("_tf_refresh_local_scroll_state")


func _tf_on_path_visibility_changed() -> void:
    call_deferred("_tf_refresh_local_scroll_state")


func _tf_on_action_child_entered(_child: Node) -> void:
    if capture_actions != null and capture_actions.get_child_count() == 1:
        _tf_reset_action_scroll()
    call_deferred("_tf_refresh_local_scroll_state")


func _tf_on_action_child_exiting(_child: Node) -> void:
    call_deferred("_tf_refresh_local_scroll_state")


func _tf_refresh_local_scroll_state() -> void:
    var has_actions: bool = (
        capture_actions != null
        and capture_actions.visible
        and capture_actions.get_child_count() > 0
    )
    var has_paths: bool = (
        path_box != null
        and path_box.visible
        and path_box.get_child_count() > 0
        and not has_actions
    )

    # Path/landscape content is visually bounded but never scrollable. Its
    # wrapper only reserves the natural height that is actually needed, capped at
    # the known safe landscape height so it can never push the outer frame.
    if _tf_path_viewport != null:
        _tf_path_viewport.visible = has_paths
        var path_height: float = 0.0
        if has_paths:
            path_height = minf(
                path_box.get_combined_minimum_size().y,
                ROUTE_PATH_MAX_HEIGHT
            )
        _tf_path_viewport.custom_minimum_size = Vector2(0.0, path_height)

    if _tf_action_scroll != null:
        _tf_action_scroll.visible = has_actions

    # Dynamic action lists need the maximum remaining height and therefore keep
    # the event text compact. Normal paths and landscape choices fit without a
    # path scrollbar, so the event text may use any spare vertical space.
    if event_label != null:
        event_label.size_flags_vertical = (
            Control.SIZE_FILL if has_actions else Control.SIZE_EXPAND_FILL
        )

    # A later child minimum-size recalculation must still not be able to move the
    # gold frame. Reassert the fixed viewport bounds after every local state change.
    if _tf_route_frame != null:
        _tf_apply_route_frame_bounds(_tf_route_frame)


# Compatibility alias retained for older tests/callers from the first local
# action-scroll implementation.
func _tf_refresh_action_scroll_state() -> void:
    _tf_refresh_local_scroll_state()


# Compatibility no-op: path/landscape content no longer has a scrollbar.
func _tf_reset_path_scroll() -> void:
    pass


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

    # No route message is allowed to reserve more than this compact base height.
    # Longer content remains fully readable through the RichTextLabel's own local
    # scrollbar instead of increasing the minimum height of the complete layout.
    event_label.custom_minimum_size = Vector2(
        event_label.custom_minimum_size.x,
        minf(event_label.custom_minimum_size.y, ROUTE_EVENT_LABEL_MAX_MIN_HEIGHT)
    )
    event_label.fit_content = false
    event_label.scroll_active = true
    event_label.scroll_following = false
    event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
