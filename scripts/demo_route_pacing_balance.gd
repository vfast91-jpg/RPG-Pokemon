extends "res://scripts/demo_route_levelup_evolution_order_fix.gd"

# Final route pacing balance.
#
# The route is built around level plateaus. Entering a new plateau should feel
# noticeably harder; during the following stages the player's team catches up
# and the same plateau becomes easier before the next jump.
#
# The previous normal stage reward effectively granted a Medium-Fast Pokemon a
# complete level every stage. A Lv.5 starter therefore reached roughly Lv.15
# before stage 11, exactly matching the new Lv.15 enemy plateau before optional
# training, boss or bonus-XP rewards were even considered. That erased the
# intended difficulty spike.
#
# Normal stage XP now grants 55% of that old one-level reference. Optional
# route rewards remain untouched, so Training, Direct Path, rare encounters and
# captures still have real strategic value instead of being mandatory just to
# keep pace.

const ROUTE_BASE_XP_FRACTION: float = 0.55

# Action economy still matters, but large enemy groups were being pushed too
# far below the plateau. This restores the earlier, slightly firmer spread:
# 1 / 2 / 3 / 4 enemies = +5 / +2 / +0 / -2 levels around the plateau.
const FINAL_ENCOUNTER_LEVEL_MODIFIERS := {
    1: 5,
    2: 2,
    3: 0,
    4: -2
}


func _route_stage_xp(current_stage: int) -> int:
    var old_reference_reward: int = super._route_stage_xp(current_stage)
    return maxi(
        1,
        int(round(float(old_reference_reward) * ROUTE_BASE_XP_FRACTION))
    )


func _enemy_level_for_encounter(current_stage: int, enemy_count: int) -> int:
    # Keep the hand-authored onboarding fights unchanged.
    if current_stage <= 5:
        return super._enemy_level_for_encounter(current_stage, enemy_count)

    var base_level: int = _route_base_level_for_stage(current_stage)
    var clamped_count: int = clampi(enemy_count, 1, 4)
    return maxi(
        1,
        base_level + int(FINAL_ENCOUNTER_LEVEL_MODIFIERS[clamped_count])
    )
