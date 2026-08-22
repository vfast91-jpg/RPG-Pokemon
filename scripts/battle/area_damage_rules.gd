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

const FULL_SPREAD_RUNTIME_FLAG: String = "timeflow_full_spread_power"


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
    if not bool(move.get("area", false)):
        return false

    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary:
        var runtime: Dictionary = runtime_value
        if bool(runtime.get(FULL_SPREAD_RUNTIME_FLAG, false)):
            return false

    return true
