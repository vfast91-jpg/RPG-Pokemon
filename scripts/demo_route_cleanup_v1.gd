extends "res://scripts/demo_route_events_v1.gd"

# Phase H compatibility cleanup.
# Several older route layers still contain Direct/Dangerous/+25%-XP callbacks
# because later, valuable UI/evolution fixes inherit through them. Deleting
# those files wholesale would risk unrelated regressions. This active top layer
# makes the obsolete entry points unreachable and harmless while preserving the
# mature inherited systems beneath them.


func _show_stage_choices(message: String = "") -> void:
    stage_xp_multiplier = 1.0
    super._show_stage_choices(message)


func _choose_path(choice: Dictionary) -> void:
    var kind: String = str(choice.get("kind", ""))
    if kind == EVENT_DIRECT or kind == EVENT_DANGEROUS:
        stage_xp_multiplier = 1.0
        _show_stage_choices(
            "Dieser alte Weg gehört nicht mehr zum aktiven Routensystem. "
            + "Die drei Wegoptionen wurden neu ausgewürfelt."
        )
        return

    stage_xp_multiplier = 1.0
    super._choose_path(choice)


func _decline_tm_reward() -> void:
    # Stale inherited buttons/callbacks must never restore the retired +25%-EP
    # consolation reward. The active Fundstelle always returns to its six-choice
    # selection instead.
    stage_xp_multiplier = 1.0
    if _fundstelle_active:
        _show_fundstelle_options()
    else:
        _show_stage_choices("Die alte +25%-EP-TM-Alternative existiert nicht mehr.")


func _decline_pending_capture() -> void:
    # The active Fangwiese uses up to three explicit searches and no XP
    # consolation. If a stale inherited callback reaches this method, interpret
    # it as leaving the current Fangwiese without a capture.
    stage_xp_multiplier = 1.0
    if not pending_capture.is_empty():
        _leave_capture_without_capture()
