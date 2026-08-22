extends "res://scripts/demo_route_levelup_evolution_order_fix.gd"

# Controlled top-level layer for the approved 2026-08-22 route rebalance.
# Keeping the redesign here lets us add the new rules without rewriting the
# mature battle, level-up, evolution, team-card and capture-preview layers.

const NORMAL_STAGE_XP_FRACTION: float = 0.50


func _route_stage_xp(current_stage: int) -> int:
    var previous_stage_xp: int = super._route_stage_xp(current_stage)
    return maxi(
        1,
        int(round(float(previous_stage_xp) * NORMAL_STAGE_XP_FRACTION))
    )
