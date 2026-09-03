extends RefCounted

# Central Pokemon Timeflow spread-status rule for NUMERICAL buffs/debuffs.
# Only the numerical strength is reduced; duration, accuracy/status chance and
# binary effects stay unchanged.
#
# 1 target  -> 100 %
# 2 targets ->  75 %
# 3 targets ->  60 %
# 4+ targets->  50 %

const NUMERICAL_MECHANIC_KINDS: Array[String] = [
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod"
]


static func effect_multiplier(target_count: int) -> float:
    var count: int = maxi(0, target_count)
    if count <= 1:
        return 1.0
    if count == 2:
        return 0.75
    if count == 3:
        return 0.60
    return 0.50


static func scale_special_coefficient(coefficient: float, target_count: int) -> float:
    return coefficient * effect_multiplier(target_count)


static func scale_modifier_multiplier(multiplier: float, target_count: int) -> float:
    # Timed modifiers are neutral at 1.0. Scaling the finished multiplier
    # directly could turn a buff into a debuff (e.g. 1.8 * 0.5 = 0.9).
    # Therefore only scale the distance from neutral.
    return 1.0 + (multiplier - 1.0) * effect_multiplier(target_count)


static func target_rule_uses_scaling(target_rule: String) -> bool:
    return target_rule.begins_with("all_")


static func mechanic_uses_scaling(mechanic: Dictionary) -> bool:
    return (
        NUMERICAL_MECHANIC_KINDS.has(str(mechanic.get("kind", "")))
        and mechanic.has("multiplier_from_special")
    )
