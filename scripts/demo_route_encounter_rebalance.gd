extends "res://scripts/demo_route_user_polish.gd"

# Route level plateaus.
# Capture level and the neutral encounter baseline intentionally use the same
# table so route progression is easy to understand and balance:
# 1-5 -> 3, 6-10 -> 7, then +8 levels per ten-stage block through stage 90.
#
# Encounter size still changes the actual enemy level to compensate for action
# economy. Stages 1-5 keep their reduced enemy-count caps from the onboarding
# layer and use a gentler modifier set; from stage 6 onward the established
# +5 / +1 / -1 / -3 modifiers apply.

const ENCOUNTER_LEVEL_MODIFIERS := {
    1: 5,
    2: 1,
    3: -1,
    4: -3
}

const ONBOARDING_LEVEL_MODIFIERS := {
    1: 2,
    2: 1,
    3: 0,
    4: -1
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


func _enemy_level_for_encounter(current_stage: int, enemy_count: int) -> int:
    var base_level: int = _route_base_level_for_stage(current_stage)
    var clamped_count: int = clampi(enemy_count, 1, 4)

    if current_stage <= 5:
        return maxi(1, base_level + int(ONBOARDING_LEVEL_MODIFIERS[clamped_count]))

    return maxi(1, base_level + int(ENCOUNTER_LEVEL_MODIFIERS[clamped_count]))
