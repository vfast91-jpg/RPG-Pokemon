extends "res://scripts/demo_route_training_hp_cost.gd"

# Regression fix: a level-up must always be presented before an evolution
# unlocked by that level-up. The gameplay state may already have reached the
# new level when deferred UI callbacks are queued, so checking only whether the
# level-up overlay is currently visible leaves a race where the evolution popup
# can appear first.


func _levelup_presentation_pending() -> bool:
    return (
        not _levelup_queue.is_empty()
        or (_levelup_overlay != null and _levelup_overlay.visible)
    )


func _try_show_evolution_choice_popup() -> void:
    if _evolution_choice_overlay == null or _evolution_choice_overlay.visible:
        return
    if _levelup_presentation_pending():
        return
    if _evolution_overlay != null and _evolution_overlay.visible:
        return
    if _evolution_choice_queue.is_empty():
        return

    _show_next_evolution_choice_popup()


func _try_show_evolution_popup() -> void:
    if _evolution_overlay == null or _evolution_overlay.visible:
        return
    if _levelup_presentation_pending():
        return
    if _evolution_choice_overlay != null and _evolution_choice_overlay.visible:
        return
    if _evolution_queue.is_empty():
        return

    _show_next_evolution_popup()
