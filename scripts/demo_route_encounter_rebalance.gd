extends "res://scripts/demo_route_user_polish.gd"

# Post-onboarding encounter rebalance.
# Stages 1-5 stay exactly on the hand-tuned gentle onboarding curve inherited
# from demo_route_balance_polish.gd. From stage 6 onward, enemy level is based
# on route stage plus an action-economy modifier:
# 1 enemy +5, 2 enemies +1, 3 enemies -1, 4 enemies -3.

const ENCOUNTER_LEVEL_MODIFIERS := {
    1: 5,
    2: 1,
    3: -1,
    4: -3
}


func _enemy_level_for_encounter(current_stage: int, enemy_count: int) -> int:
    if current_stage <= 5:
        return super._enemy_level_for_encounter(current_stage, enemy_count)

    var clamped_count: int = clampi(enemy_count, 1, 4)
    return maxi(1, current_stage + int(ENCOUNTER_LEVEL_MODIFIERS[clamped_count]))
