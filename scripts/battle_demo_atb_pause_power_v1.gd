extends "res://scripts/battle_demo_milestone_boss_layout_v2.gd"

# Strong Timeflow control pass for the Whirlwind-style ATB-pause family.
#
# The shared Status curve remains unchanged for healing, buffs, debuffs and all
# other Status effects. Only db_atb_pause is doubled:
#
#     pause = target full ATB cycle * 2 * Status / (75 + Status)
#
# There is deliberately no 100% cap. A sufficiently strong Status user can
# therefore freeze more than one full target cycle. This is intentional: these
# moves spend a full action and are meant to produce a clearly meaningful
# control swing.

const ATB_PAUSE_POWER_MULTIPLIER: float = 2.0

var _atb_pause_power_context: bool = false


func _load_data() -> void:
    super._load_data()
    _mark_strong_atb_pause_contracts()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) != "db_atb_pause":
        return super._effect(actor, target, mechanic)

    # The inherited central handler already owns exact freezing, remaining-time
    # replacement, feedback and effect Aggro. Keep that single source of truth
    # and only double the cycle duration it receives while resolving this one
    # mechanic.
    _atb_pause_power_context = true
    var result: float = super._effect(actor, target, mechanic)
    _atb_pause_power_context = false
    return result


func _target_full_atb_cycle_seconds(target: Dictionary) -> float:
    var seconds: float = super._target_full_atb_cycle_seconds(target)
    if _atb_pause_power_context:
        return seconds * ATB_PAUSE_POWER_MULTIPLIER
    return seconds


func _mark_strong_atb_pause_contracts() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return

    var moves: Dictionary = moves_value
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        if not _move_uses_db_atb_pause(move):
            continue

        move["status_scaling"] = (
            "Starke ATB-Pause: Ziel-Vollzyklus × 2 × R; R=Status/(75+Status). "
            + "Kein 100%-Deckel."
        )

        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = (
            (runtime_value as Dictionary).duplicate(true)
            if runtime_value is Dictionary else {}
        )
        runtime["timeflow_atb_pause_multiplier"] = ATB_PAUSE_POWER_MULTIPLIER
        runtime["timeflow_atb_pause_uncapped"] = true
        move["runtime"] = runtime

        var rules_value: Variant = move.get("special_rules", [])
        var rules: Array = rules_value.duplicate(true) if rules_value is Array else []
        var cleaned: Array = []
        for rule_value: Variant in rules:
            var rule: String = str(rule_value)
            var compact: String = rule.to_lower()
            var is_old_pause_formula: bool = (
                compact.contains("atb-pausendauer")
                and compact.contains("status/(75+status)")
            )
            if not is_old_pause_formula:
                cleaned.append(rule_value)
        cleaned.append(
            "ATB-Pausendauer = normale volle ATB-Zyklusdauer des Ziels × 2 × Status/(75+Status); ohne 100%-Deckel."
        )
        move["special_rules"] = cleaned
        moves[move_id] = move

    data["moves"] = moves


func _move_uses_db_atb_pause(move: Dictionary) -> bool:
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false
    for mechanic_value: Variant in mechanics_value:
        if _mechanic_uses_db_atb_pause(mechanic_value):
            return true
    return false


func _mechanic_uses_db_atb_pause(value: Variant) -> bool:
    if value is Dictionary:
        var mechanic: Dictionary = value
        if str(mechanic.get("kind", "")) == "db_atb_pause":
            return true
        for nested_value: Variant in mechanic.values():
            if _mechanic_uses_db_atb_pause(nested_value):
                return true
        return false
    if value is Array:
        for nested_value: Variant in value:
            if _mechanic_uses_db_atb_pause(nested_value):
                return true
    return false
