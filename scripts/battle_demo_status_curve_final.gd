extends "res://scripts/battle_demo_fixed_hp_healing.gd"

# Final mathematical refinement of the shared Status curve.
#
# R = Status / (75 + Status)
#
# Positive increases/slowdowns keep the existing first-order rule 1 + kR.
# Negative reductions/speedups use (1 - R)^k. This has two useful properties:
# - a 1x reduction is exactly R (Status 25 = 25%, Status 50 = 40%, ...),
# - 2x/3x effects are stronger but can never become zero/negative at finite Status.
#
# For incoming-damage modifiers the battle engine stores the inverse defense
# multiplier, so reduction/vulnerability values are converted accordingly.


func _status_modifier_multiplier(
    actor: Dictionary,
    mechanic: Dictionary,
    kind: String,
    apply_type_bonus: bool = true,
    apply_sun_bonus: bool = true
) -> float:
    var signed_weight: float = float(mechanic.get("multiplier_from_special", 1.0))
    var weight: float = _status_strength_weight(
        actor,
        mechanic,
        apply_type_bonus,
        apply_sun_bonus
    )
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))

    if signed_weight >= 0.0:
        var increased: float = 1.0 + weight * ratio
        if kind == "incoming_damage_mod":
            # Positive incoming modifier = vulnerability. Damage resolution
            # divides by this stored value, producing x(1+kR) damage.
            return 1.0 / increased
        return increased

    var remaining: float = pow(maxf(0.0001, 1.0 - ratio), weight)
    if kind == "incoming_damage_mod":
        # Negative incoming modifier = protection. Store the inverse because
        # damage resolution divides by the defense multiplier.
        return 1.0 / maxf(0.0001, remaining)
    return maxf(0.0001, remaining)


func _process(delta: float) -> void:
    # The parent freezes ATB gain while db_atb_pause is active. Also protect the
    # edge case where a target was already exactly at 100 ATB when the pause was
    # applied: temporarily lower it below the ready threshold for this process
    # pass and restore the original fill immediately afterwards.
    var full_atb_snapshots: Array = []
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if (
            float(combatant.get("db_atb_pause_remaining_seconds", 0.0)) > 0.0
            and float(combatant.get("atb", 0.0)) >= 100.0
        ):
            full_atb_snapshots.append({
                "combatant": combatant,
                "atb": float(combatant.get("atb", 100.0))
            })
            combatant["atb"] = 99.0

    super._process(delta)

    for snapshot_value: Variant in full_atb_snapshots:
        if not (snapshot_value is Dictionary):
            continue
        var snapshot: Dictionary = snapshot_value
        var combatant_value: Variant = snapshot.get("combatant", {})
        if combatant_value is Dictionary:
            var combatant: Dictionary = combatant_value
            combatant["atb"] = float(snapshot.get("atb", 100.0))
