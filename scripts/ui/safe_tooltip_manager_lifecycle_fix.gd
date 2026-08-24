extends "res://scripts/ui/safe_tooltip_manager.gd"

# Lifecycle fix for the global tooltip manager.
#
# A tooltip may still be under the mouse when its source control disappears,
# for example after clicking a Trainingsplatz Pokemon button that immediately
# opens the level-up overlay. The tooltip itself then becomes the hovered
# control, and the base manager intentionally keeps internal tooltip controls
# open for scrolling. Without an explicit source-lifecycle check, that leaves
# the old tooltip floating above the new overlay.
#
# A second edge case occurs when the source is clicked while its tooltip is
# already open (for example a TM offer). GUI changes can happen in the same
# frame, while the tooltip itself remains the hovered control. Dismiss the
# tooltip immediately on the primary click/tap and suppress that exact source
# until the pointer has actually left it. This prevents route tooltips from
# leaking into recipient selection or the following battle.

var _tf_dismissed_source: Control = null


func _input(event: InputEvent) -> void:
    var dismiss_requested: bool = false
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        dismiss_requested = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
    elif event is InputEventScreenTouch:
        dismiss_requested = (event as InputEventScreenTouch).pressed

    if not dismiss_requested:
        return
    if _source == null or not is_instance_valid(_source):
        return

    _tf_dismissed_source = _source
    _switch_source(null)


func _process(delta: float) -> void:
    if _tf_tooltip_source_is_stale():
        _tf_dismissed_source = null
        _switch_source(null)
        return

    if _tf_should_suppress_dismissed_source():
        return

    super._process(delta)


func _tf_should_suppress_dismissed_source() -> bool:
    if _tf_dismissed_source == null:
        return false
    if not is_instance_valid(_tf_dismissed_source):
        _tf_dismissed_source = null
        return false
    if _tf_dismissed_source.is_queued_for_deletion():
        _tf_dismissed_source = null
        return false
    if not _tf_dismissed_source.is_inside_tree() or not _tf_dismissed_source.is_visible_in_tree():
        _tf_dismissed_source = null
        return false

    var viewport: Viewport = get_viewport()
    if viewport == null:
        _tf_dismissed_source = null
        return false

    var hovered: Control = viewport.gui_get_hovered_control()
    var hovered_source: Control = _find_tooltip_source(hovered)
    if hovered_source == _tf_dismissed_source:
        return true

    _tf_dismissed_source = null
    return false


func _tf_tooltip_source_is_stale() -> bool:
    if _source == null:
        return false
    if not is_instance_valid(_source):
        return true
    if _source.is_queued_for_deletion():
        return true
    if not _source.is_inside_tree():
        return true
    if not _source.is_visible_in_tree():
        return true
    return false
