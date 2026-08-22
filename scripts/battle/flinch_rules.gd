extends RefCounted

# Canonical Timeflow rule for Zurückschrecken.
# The move only owns the proc chance. If it procs, the target's CURRENT action
# bar is reset completely. Legacy numeric knockback amounts are intentionally
# not part of this rule and must never influence the result.
const RESET_ATB_PERCENT: float = 0.0


static func apply(target: Dictionary, chance: float, roll: float = -1.0) -> bool:
    var safe_chance: float = clampf(chance, 0.0, 1.0)
    if safe_chance <= 0.0:
        return false

    var resolved_roll: float = randf() if roll < 0.0 else clampf(roll, 0.0, 0.999999)
    if resolved_roll >= safe_chance:
        return false

    target["atb"] = RESET_ATB_PERCENT
    return true


static func player_summary(chance: float) -> String:
    var percent: int = int(round(clampf(chance, 0.0, 1.0) * 100.0))
    return str(percent) + " % Chance auf Zurückschrecken: Aktionsleiste auf 0 %"
