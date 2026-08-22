extends RefCounted

# Central Pokemon Timeflow spread-damage rule.
# The multiplier is applied to the FINAL damage dealt to each target, after
# normal damage, type, critical-hit, weather, terrain and barrier modifiers.
#
# 1 target  -> 100 %
# 2 targets ->  75 %
# 3 targets ->  60 %
# 4+ targets->  50 %
#
# Individual moves may explicitly opt out via runtime.timeflow_full_spread_power
# (currently used by moves whose design contract says "full power per target").
# Conditional spread moves may advertise the central contract through
# runtime.central_area_damage_scaling even while their base data is single-target.

const FULL_SPREAD_RUNTIME_FLAG: String = "timeflow_full_spread_power"
const CENTRAL_SCALING_RUNTIME_FLAG: String = "central_area_damage_scaling"


static func damage_multiplier(target_count: int) -> float:
    var count: int = maxi(0, target_count)
    if count <= 1:
        return 1.0
    if count == 2:
        return 0.75
    if count == 3:
        return 0.60
    return 0.50


static func move_uses_central_scaling(move: Dictionary) -> bool:
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if bool(runtime.get(FULL_SPREAD_RUNTIME_FLAG, false)):
        return false

    return (
        bool(move.get("area", false))
        or bool(runtime.get(CENTRAL_SCALING_RUNTIME_FLAG, false))
    )
