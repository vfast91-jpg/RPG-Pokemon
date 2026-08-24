extends "res://scripts/battle_demo_low_hp_power_v1.gd"

# Global positive +2-stage Status rule and Stockpile integrity layer.
#
# This layer deliberately sits above the complete active battle stack so every
# current and future move that reaches the central Status modifier path gets the
# same rule without per-move formulas:
#   +1 positive stage -> 1.00 x R
#   +2 positive stages -> 1.25 x R
# where R = Status / (75 + Status).
#
# Stockpile/Horter is also repaired here because the legacy handler created a
# new timed modifier on every use and multiplied the current stack count into
# each new modifier. Horter now owns one persistent Defense contribution that is
# derived from its stack count and disappears only when its stacks are consumed.

const StatusStageScaling = preload("res://scripts/battle/status_stage_scaling.gd")
const STOCKPILE_ORIGINAL_POSITIVE_STAGES: float = 2.0


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["db_stockpile_defense_multiplier"] = 1.0
    return combatant


func _status_modifier_multiplier(
    actor: Dictionary,
    mechanic: Dictionary,
    kind: String,
    apply_type_bonus: bool = true,
    apply_sun_bonus: bool = true
) -> float:
    var signed_stages: float = float(mechanic.get("multiplier_from_special", 1.0))
    var adjusted: Dictionary = mechanic.duplicate(true)
    adjusted["multiplier_from_special"] = StatusStageScaling.adjusted_signed_stage_weight(
        kind,
        signed_stages
    )

    # Defense is a real Timeflow attribute. A positive Defense stage therefore
    # increases that attribute additively by its Status contribution instead of
    # being translated through the old inverse damage-reduction curve.
    if kind == "incoming_damage_mod" and signed_stages < 0.0:
        var weight: float = _status_strength_weight(
            actor,
            adjusted,
            apply_type_bonus,
            apply_sun_bonus
        )
        return 1.0 + weight * _status_ratio(float(actor.get("special", 0.0)))

    return super._status_modifier_multiplier(
        actor,
        adjusted,
        kind,
        apply_type_bonus,
        apply_sun_bonus
    )


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    if kind == "db_stockpile":
        return _apply_global_stockpile(actor, mechanic)

    if kind == "db_swallow" or kind == "db_spit_up":
        var result: float = super._effect(actor, target, mechanic)
        if int(actor.get("db_stockpile", 0)) <= 0:
            _clear_global_stockpile_defense(actor)
        return result

    return super._effect(actor, target, mechanic)


func _apply_global_stockpile(actor: Dictionary, mechanic: Dictionary) -> float:
    _remove_legacy_stockpile_timed_modifiers(actor)

    var max_stacks: int = maxi(1, int(mechanic.get("max", 3)))
    var stacks: int = mini(
        max_stacks,
        int(actor.get("db_stockpile", 0)) + 1
    )
    actor["db_stockpile"] = stacks

    var signed_stages: float = -STOCKPILE_ORIGINAL_POSITIVE_STAGES
    var per_stack_weight: float = StatusStageScaling.effective_positive_stage_weight(
        "incoming_damage_mod",
        signed_stages
    )
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))

    # Each Horter use adds the same translated +2-stage contribution. Stacks
    # are summed into ONE Defense multiplier instead of multiplying separate
    # temporary effects into each other.
    actor["db_stockpile_defense_multiplier"] = 1.0 + float(stacks) * per_stack_weight * ratio
    return float(stacks)


func _combined_timed_modifier(combatant: Dictionary, kind: String) -> float:
    var result: float = super._combined_timed_modifier(combatant, kind)
    if kind == "incoming_damage_mod":
        result *= maxf(
            1.0,
            float(combatant.get("db_stockpile_defense_multiplier", 1.0))
        )
    return maxf(0.0001, result)


func _clear_global_stockpile_defense(actor: Dictionary) -> void:
    actor["db_stockpile_defense_multiplier"] = 1.0
    _remove_legacy_stockpile_timed_modifiers(actor)


func _remove_legacy_stockpile_timed_modifiers(actor: Dictionary) -> void:
    var modifiers_value: Variant = actor.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return

    var remaining: Array = []
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        var is_legacy_stockpile: bool = (
            str(modifier.get("kind", "")) == "incoming_damage_mod"
            and str(modifier.get("source_move", "")) == "Horter"
        )
        if not is_legacy_stockpile:
            remaining.append(modifier)
    actor["timed_modifiers"] = remaining


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var stacks: int = clampi(int(combatant.get("db_stockpile", 0)), 0, 3)
    if stacks > 0:
        tokens.append("HORTER×" + str(stacks))
    return tokens
