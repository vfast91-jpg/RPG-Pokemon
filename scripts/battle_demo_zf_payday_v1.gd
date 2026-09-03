extends "res://scripts/battle_demo_status_aggro_integrity_v1.gd"

# Zahltag / Pay Day combines its normal attack damage with a separate self-heal.
# The heal deliberately does NOT scale with damage dealt. It reuses Timeflow's
# central Status curve, but at half the weight of a dedicated healing move.

const PAY_DAY_STATUS_WEIGHT: float = 0.5


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) == "zf_pay_day":
        # Zahltag only heals after a real damaging hit. Once that condition is
        # met, the amount is completely independent of the damage dealt.
        if _zf_actual_damage(target) <= 0:
            return 0.0
        return _zf_pay_day_self_heal(actor)
    return super._effect(actor, target, mechanic)


func _zf_pay_day_self_heal(actor: Dictionary) -> float:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return 0.0

    var old_hp: int = maxi(0, int(actor.get("hp", 0)))
    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var missing_hp: int = maxi(0, max_hp - old_hp)
    if missing_hp <= 0:
        return 0.0

    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    ratio = clampf(ratio * PAY_DAY_STATUS_WEIGHT, 0.0, 1.0)

    # Use the same positive whole-KP rounding rule as the existing drain moves.
    var heal: int = mini(
        missing_hp,
        ZF_StatusEffects.positive_int(float(max_hp) * ratio)
    )
    if heal <= 0:
        return 0.0

    actor["hp"] = old_hp + heal
    _spawn_feedback_label(actor, "🪙 +" + str(heal) + " KP", Color("9be59f"))

    # Returning the actual heal lets the central effect-Aggro pipeline value the
    # healing exactly like other positive effects instead of adding custom Aggro.
    return float(heal)
