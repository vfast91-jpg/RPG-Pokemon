extends "res://scripts/demo_route_user_polish.gd"

# Route level plateaus.
# Capture level and the neutral encounter baseline intentionally use the same
# table so route progression is easy to understand and balance:
# 1-5 -> 3, 6-10 -> 7, then +8 levels per ten-stage block through stage 90.
#
# Stages 1-5 are a fixed onboarding sequence without positive action-economy
# corrections. From stage 6 onward encounters are random again and use the
# established +5 / +1 / -1 / -3 modifiers.

const ENCOUNTER_LEVEL_MODIFIERS := {
    1: 5,
    2: 1,
    3: -1,
    4: -3
}

const ONBOARDING_ENCOUNTERS := {
    1: {"count": 1, "level": 2},
    2: {"count": 1, "level": 3},
    3: {"count": 2, "level": 3},
    4: {"count": 2, "level": 4},
    5: {"count": 3, "level": 4}
}


func _route_base_level_for_stage(current_stage: int) -> int:
    var clamped_stage: int = clampi(current_stage, 1, 90)
    if clamped_stage <= 5:
        return 3
    if clamped_stage <= 10:
        return 7
    if clamped_stage <= 20:
        return 15
    if clamped_stage <= 30:
        return 23
    if clamped_stage <= 40:
        return 31
    if clamped_stage <= 50:
        return 39
    if clamped_stage <= 60:
        return 47
    if clamped_stage <= 70:
        return 55
    if clamped_stage <= 80:
        return 63
    return 71


func _capture_level_for_stage(current_stage: int) -> int:
    return _route_base_level_for_stage(current_stage)


func _enemy_level_for_stage(current_stage: int) -> int:
    return _route_base_level_for_stage(current_stage)


func _roll_enemy_count(current_stage: int) -> int:
    var onboarding_value: Variant = ONBOARDING_ENCOUNTERS.get(current_stage, {})
    if onboarding_value is Dictionary and not (onboarding_value as Dictionary).is_empty():
        return int((onboarding_value as Dictionary).get("count", 1))
    return super._roll_enemy_count(current_stage)


func _enemy_level_for_encounter(current_stage: int, enemy_count: int) -> int:
    var onboarding_value: Variant = ONBOARDING_ENCOUNTERS.get(current_stage, {})
    if onboarding_value is Dictionary and not (onboarding_value as Dictionary).is_empty():
        return maxi(1, int((onboarding_value as Dictionary).get("level", 1)))

    var base_level: int = _route_base_level_for_stage(current_stage)
    var clamped_count: int = clampi(enemy_count, 1, 4)
    return maxi(1, base_level + int(ENCOUNTER_LEVEL_MODIFIERS[clamped_count]))


func _show_stage_choices(message: String = "") -> void:
    var level_notice: String = _route_level_notice_for_stage(stage)
    if not level_notice.is_empty():
        if message.is_empty():
            message = level_notice
        else:
            message = level_notice + "\n\n" + message
    super._show_stage_choices(message)


func _route_level_notice_for_stage(current_stage: int) -> String:
    var is_new_level_band: bool = current_stage == 6
    if current_stage >= 11 and current_stage <= 90:
        is_new_level_band = ((current_stage - 1) % 10) == 0

    if not is_new_level_band:
        return ""

    return (
        "[b]⬆ Neues Levelniveau[/b]\n"
        + "Die Gegnerstärke orientiert sich jetzt an [b]Lv.%d[/b]. "
        + "Kleine Gruppen liegen darüber, große Gruppen darunter."
    ) % _route_base_level_for_stage(current_stage)
