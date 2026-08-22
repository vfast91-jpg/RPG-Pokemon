class_name StatusEffectRuntime
extends RefCounted

# Central runtime formulas for quantitative Status effects.
# Keep this file free of battle-scene state so the formulas are testable and
# reusable by later data-driven runtimes.

const CURVE: float = 75.0


static func ratio(status_value: float) -> float:
    var value: float = maxf(0.0, status_value)
    return value / (CURVE + value)


static func bounded_ratio(status_value: float, weight: float = 1.0) -> float:
    return clampf(maxf(0.0, weight) * ratio(status_value), 0.0, 1.0)


static func max_hp_heal(max_hp: int, status_value: float, weight: float = 1.0) -> int:
    if max_hp <= 0:
        return 0
    return maxi(0, int(floor(float(max_hp) * bounded_ratio(status_value, weight))))


static func drain_heal(actual_hp_damage: int, status_value: float, weight: float = 1.0) -> int:
    if actual_hp_damage <= 0:
        return 0
    return maxi(0, int(floor(float(actual_hp_damage) * bounded_ratio(status_value, weight))))


static func damage_reduction_multiplier(status_value: float, weight: float = 1.0) -> float:
    return pow(1.0 - ratio(status_value), maxf(0.0, weight))


static func additive_damage_multiplier(status_value: float, weight: float = 1.0) -> float:
    return 1.0 + maxf(0.0, weight) * ratio(status_value)


static func critical_bonus_fraction(status_value: float, weight: float = 1.0) -> float:
    return clampf(maxf(0.0, weight) * ratio(status_value), 0.0, 1.0)


static func atb_start_percent(status_value: float, weight: float = 1.0) -> float:
    return 100.0 * maxf(0.0, weight) * ratio(status_value)


static func next_cycle_multiplier(status_value: float, weight: float = 1.0) -> float:
    return pow(1.0 - ratio(status_value), maxf(0.0, weight))
