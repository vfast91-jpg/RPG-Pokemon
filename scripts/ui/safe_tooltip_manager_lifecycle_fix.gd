extends "res://scripts/ui/safe_tooltip_manager.gd"

# Lifecycle fix for the global tooltip manager.
#
# A tooltip may still be under the mouse when its source control disappears,
# for example after clicking a Trainingsplatz Pokemon button that immediately
# opens the level-up overlay. The tooltip itself then becomes the hovered
# control, and the base manager intentionally keeps internal tooltip controls
# open for scrolling. Without an explicit source-lifecycle check, that leaves
# the old tooltip floating above the new overlay.


func _process(delta: float) -> void:
    if _tf_tooltip_source_is_stale():
        _switch_source(null)
        return

    super._process(delta)


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
