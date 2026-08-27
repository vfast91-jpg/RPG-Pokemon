class_name StatusStageScaling
extends RefCounted

# Central translation from original positive stat stages to Timeflow Status
# weights. This is intentionally independent of any individual move.
#
# +1 stage: full Status curve contribution (1.00 x R)
# +/-2 stages: first stage full + second stage at 25 % (1.25 x R)
#
# No +3-stage rule is introduced here. Values other than an exact positive
# two-stage boost keep their existing weight until a separate rule is decided.

const SECOND_STAGE_SHARE: float = 0.25
const TWO_STAGE_WEIGHT: float = 1.0 + SECOND_STAGE_SHARE


static func is_positive_attribute_boost(kind: String, signed_stages: float) -> bool:
    match kind:
        "outgoing_damage_mod":
            return signed_stages > 0.0
        "incoming_damage_mod":
            # Damage is divided by this stored multiplier, therefore a negative
            # mechanic weight denotes a positive Defense boost in the legacy
            # move data.
            return signed_stages < 0.0
        "accuracy_mod":
            return signed_stages > 0.0
        "atb_cycle_mod":
            # A shorter ATB cycle is the Timeflow representation of a positive
            # Speed boost.
            return signed_stages < 0.0
        _:
            return false


static func effective_positive_stage_weight(kind: String, signed_stages: float) -> float:
    var magnitude: float = absf(signed_stages)
    # Preserve the direction, but soften the second stage in both directions.
    if is_equal_approx(magnitude, 2.0):
        return TWO_STAGE_WEIGHT
    return magnitude


static func adjusted_signed_stage_weight(kind: String, signed_stages: float) -> float:
    var magnitude: float = effective_positive_stage_weight(kind, signed_stages)
    return -magnitude if signed_stages < 0.0 else magnitude
