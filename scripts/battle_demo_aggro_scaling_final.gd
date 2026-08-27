extends "res://scripts/battle_demo_miss_recovery.gd"

const FinalAggroRules = preload("res://scripts/battle/aggro_rules.gd")

# Final Aggro correction layer.
#
# Canonical rule: effect Aggro is based on the EFFECT THAT ACTUALLY HAPPENED.
# Damage already contributes its real dealt HP, healing its real restored HP and
# Status-scaled modifiers use their real multiplier delta. This layer removes
# the remaining legacy +1/+3/+4/+5 effect-Aggro magic numbers from active move
# mechanics and replaces them with values derived from the shared level basis,
# duration, modifier magnitude, removed ATB or actually changed hazards.
#
# These fractions are balancing coefficients on the central level basis, not
# flat Aggro awards and not Max-KP fractions. The legacy function name remains
# temporarily for compatibility with the many existing move implementations.

const AGGRO_STATUS_ACTION_HP_FRACTION: float = 0.10
const AGGRO_IMMUNITY_ACTION_HP_FRACTION: float = 0.04
const AGGRO_REDIRECT_ACTION_HP_FRACTION: float = 0.06
const AGGRO_GUARD_HP_FRACTION: float = 0.25
const AGGRO_ENDURE_ACTION_HP_FRACTION: float = 0.18
const AGGRO_CRIT_SETUP_HP_FRACTION: float = 0.12
const AGGRO_MODIFIER_BLOCK_ACTION_HP_FRACTION: float = 0.04
const AGGRO_PROTECT_BREAK_HP_FRACTION: float = 0.20
const AGGRO_HAZARD_LAYER_HP_FRACTION: float = 0.04
const AGGRO_REST_STATUS_CLEANSE_HP_FRACTION: float = 0.10


func _hp_scaled_aggro(combatant: Dictionary, fraction: float, actions: int = 1) -> float:
    return (
        FinalAggroRules.level_basis(combatant)
        * maxf(0.0, fraction)
        * float(maxi(1, actions))
    )


func _team_max_hp(side: String) -> float:
    var total: float = 0.0
    for candidate_value: Variant in _team_for_side(side):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if bool(candidate.get("alive", false)):
            total += maxf(1.0, float(candidate.get("max_hp", 1)))
    return total


func _positive_modifier_aggro(target: Dictionary) -> float:
    var result: float = 0.0
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return result

    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        var kind: String = str(modifier.get("kind", ""))
        var multiplier: float = float(modifier.get("multiplier", 1.0))
        var positive: bool = (
            (kind == "outgoing_damage_mod" and multiplier > 1.0)
            or (kind == "incoming_damage_mod" and multiplier > 1.0)
            or (kind == "accuracy_mod" and multiplier > 1.0)
            or (kind == "atb_cycle_mod" and multiplier < 1.0)
        )
        if positive:
            result += _status_effect_aggro(kind, multiplier)
    return result


func _all_timed_modifier_aggro(target: Dictionary) -> float:
    var result: float = 0.0
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return result

    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        var kind: String = str(modifier.get("kind", ""))
        var multiplier: float = float(modifier.get("multiplier", 1.0))
        if kind in ["outgoing_damage_mod", "incoming_damage_mod", "accuracy_mod", "atb_cycle_mod"]:
            result += _status_effect_aggro(kind, multiplier)
    return result


func _status_application_aggro(target: Dictionary, status_id: String, actions: int = 1) -> float:
    return FinalAggroRules.status_application(target, status_id, actions)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    # Preserve Delegator's central interception behavior before custom handling.
    if _bulba_substitute_blocks_effect(actor, target, mechanic):
        return super._effect(actor, target, mechanic)

    # Legacy generic status mechanics used a flat +3 Aggro regardless of level.
    if kind == "status":
        var status_id: String = str(mechanic.get("status", ""))
        if status_id in ["paralysis", "confusion"]:
            if randf() > float(mechanic.get("chance", 1.0)):
                return 0.0
            if _database_status_is_blocked(target, status_id):
                _spawn_feedback_label(target, "🛡️ IMMUN", Color("b8d9ff"))
                return 0.0

            if status_id == "paralysis":
                if bool(target.get("paralyzed", false)):
                    return 0.0
                target["paralyzed"] = true
                return _status_application_aggro(target, status_id)

            var old_turns: int = maxi(0, int(target.get("confused_turns", 0)))
            var new_turns: int = randi_range(1, 4)
            target["confused_turns"] = new_turns
            var added_turns: int = maxi(0, new_turns - old_turns)
            return _status_application_aggro(target, status_id, added_turns) if added_turns > 0 else 0.0

    # Legacy ATB knockback used a flat +3. Value only the ATB that was actually
    # removed, relative to the affected Pokemon's live combat scale.
    if kind == "atb_knockback":
        if randf() > float(mechanic.get("chance", 1.0)):
            return 0.0
        var before: float = clampf(float(target.get("atb", 0.0)), 0.0, 100.0)
        var requested: float = maxf(0.0, float(mechanic.get("amount", 0.25)) * 100.0)
        var removed: float = minf(before, requested)
        target["atb"] = maxf(0.0, before - removed)
        return maxf(1.0, float(target.get("max_hp", 1))) * removed / 100.0

    match kind:
        "db_status":
            if str(mechanic.get("status", "")) != "sleep":
                return super._effect(actor, target, mechanic)
            if randf() > float(mechanic.get("chance", 1.0)):
                return 0.0
            if _database_status_is_blocked(target, "sleep"):
                return 0.0
            if not str(target.get("major_status", "")).is_empty():
                return 0.0
            var sleep_actions: int = randi_range(1, 3)
            target["major_status"] = "sleep"
            target["db_sleep_actions"] = sleep_actions
            return _status_application_aggro(target, "sleep", sleep_actions)

        "db_team_cleanse":
            var cleanse_status: String = str(mechanic.get("status", ""))
            if cleanse_status != str(target.get("major_status", "")):
                return 0.0
            var cleanse_aggro: float = _status_application_aggro(target, cleanse_status)
            target["major_status"] = ""
            target["paralyzed"] = false
            target["db_sleep_actions"] = 0
            return cleanse_aggro

        "db_team_immunity":
            var immunity_actions: int = maxi(1, int(mechanic.get("duration_actions", 3)))
            var immunities_value: Variant = target.get("db_status_immunities", [])
            var immunities: Array = immunities_value if immunities_value is Array else []
            immunities.append({
                "status": str(mechanic.get("status", "major_status")),
                "expires_after_action": int(target.get("action_serial", 0)) + immunity_actions
            })
            target["db_status_immunities"] = immunities
            return _hp_scaled_aggro(target, AGGRO_IMMUNITY_ACTION_HP_FRACTION, immunity_actions)

        "db_redirect":
            var redirect_actions: int = maxi(1, int(mechanic.get("duration_actions", 3)))
            var current_action: int = int(target.get("action_serial", 0))
            var old_remaining: int = maxi(0, int(target.get("db_redirect_expires", 0)) - current_action)
            target["db_redirect_expires"] = current_action + redirect_actions
            var added_actions: int = maxi(0, redirect_actions - old_remaining)
            return _hp_scaled_aggro(target, AGGRO_REDIRECT_ACTION_HP_FRACTION, added_actions) if added_actions > 0 else 0.0

        "db_guaranteed_crit":
            if bool(actor.get("db_guaranteed_crit", false)):
                return 0.0
            actor["db_guaranteed_crit"] = true
            return _hp_scaled_aggro(actor, AGGRO_CRIT_SETUP_HP_FRACTION)

        "db_stockpile":
            var max_stacks: int = maxi(1, int(mechanic.get("max", 3)))
            actor["db_stockpile"] = mini(max_stacks, int(actor.get("db_stockpile", 0)) + 1)
            var stacks: int = int(actor.get("db_stockpile", 0))
            var stockpile_mechanic: Dictionary = {"multiplier_from_special": -2.0 * float(stacks)}
            var stockpile_multiplier: float = _status_modifier_multiplier(
                actor,
                stockpile_mechanic,
                "incoming_damage_mod",
                false,
                false
            )
            _add_timed_modifier(
                actor,
                "incoming_damage_mod",
                stockpile_multiplier,
                "Horter",
                _actor_name(actor)
            )
            return _status_effect_aggro("incoming_damage_mod", stockpile_multiplier)

        "db_cleanse_positive_modifiers":
            var removed_positive_aggro: float = _positive_modifier_aggro(target)
            _database_remove_positive_modifiers(target)
            return removed_positive_aggro

        "db_block_positive_modifiers":
            var block_actions: int = maxi(1, int(mechanic.get("duration_actions", 3)))
            var block_current: int = int(target.get("action_serial", 0))
            var block_old_remaining: int = maxi(0, int(target.get("db_block_positive_expires", 0)) - block_current)
            target["db_block_positive_expires"] = block_current + block_actions
            var block_added: int = maxi(0, block_actions - block_old_remaining)
            return _hp_scaled_aggro(target, AGGRO_MODIFIER_BLOCK_ACTION_HP_FRACTION, block_added) if block_added > 0 else 0.0

        "db_clear_all_temporary_modifiers":
            var cleared_aggro: float = 0.0
            for candidate_value: Variant in combatants:
                if not (candidate_value is Dictionary):
                    continue
                var candidate: Dictionary = candidate_value
                cleared_aggro += _all_timed_modifier_aggro(candidate)
                candidate["timed_modifiers"] = []
            return cleared_aggro

        "db_break_protect":
            if not bool(target.get("protective_guard", false)):
                return 0.0
            target["protective_guard"] = false
            return _hp_scaled_aggro(target, AGGRO_PROTECT_BREAK_HP_FRACTION)

        "db_toxic_spikes":
            var enemy_side: String = "enemy" if str(actor.get("side", "")) == "player" else "player"
            var layers_key: String = "db_toxic_spikes_" + enemy_side
            var old_layers: int = int(get_meta(layers_key, 0))
            var new_layers: int = mini(int(mechanic.get("max_layers", 2)), old_layers + 1)
            set_meta(layers_key, new_layers)
            if new_layers <= old_layers:
                return 0.0
            return _team_max_hp(enemy_side) * AGGRO_HAZARD_LAYER_HP_FRACTION * float(new_layers - old_layers)

        "db_clear_allied_hazards":
            var allied_side: String = str(actor.get("side", ""))
            var allied_key: String = "db_toxic_spikes_" + allied_side
            var removed_layers: int = int(get_meta(allied_key, 0))
            set_meta(allied_key, 0)
            if removed_layers <= 0:
                return 0.0
            return _team_max_hp(allied_side) * AGGRO_HAZARD_LAYER_HP_FRACTION * float(removed_layers)

    return super._effect(actor, target, mechanic)


func _bulba_guard_attempt(actor: Dictionary, endure: bool) -> float:
    var chain: int = maxi(0, int(actor.get("db_guard_family_chain", 0)))
    var chance: float = pow(1.0 / 3.0, float(chain))
    actor["db_guard_family_chain"] = chain + 1
    if randf() > chance:
        _spawn_feedback_label(actor, "✖ SCHUTZ FEHLGESCHLAGEN", Color("d9a5a5"))
        return 0.0

    if endure:
        var duration_actions: int = 3
        actor["db_endure_expires_after_action"] = int(actor.get("action_serial", 0)) + duration_actions
        _spawn_feedback_label(actor, "💪 AUSDAUER · 3 AKTIONEN", Color("f1d88d"))
        return _hp_scaled_aggro(actor, AGGRO_ENDURE_ACTION_HP_FRACTION, duration_actions)

    actor["protective_guard"] = true
    _spawn_feedback_label(actor, "🛡️ SCHUTZSCHILD", Color("9fe7bd"))
    return _hp_scaled_aggro(actor, AGGRO_GUARD_HP_FRACTION)


func _bulba_create_substitute(actor: Dictionary) -> float:
    if int(actor.get("db_substitute_hp", 0)) > 0:
        _spawn_feedback_label(actor, "🧸 DELEGATOR BEREITS AKTIV", Color("edcf9b"))
        return 0.0

    var cost: int = maxi(1, int(floor(float(actor.get("max_hp", 1)) * 0.25)))
    if int(actor.get("hp", 0)) <= cost:
        _spawn_feedback_label(actor, "✖ ZU WENIG KP", Color("d9a5a5"))
        return 0.0

    actor["hp"] = int(actor.get("hp", 0)) - cost
    actor["db_substitute_hp"] = cost
    actor["db_substitute_max_hp"] = cost
    _spawn_feedback_label(actor, "🧸 DELEGATOR " + str(cost) + " KP", Color("edcf9b"))

    # Exact effect valuation: one point of created shield HP = one point of Aggro.
    return float(cost)


func _bulba_activate_grassy_terrain(actor: Dictionary) -> float:
    _bulba_grassy_terrain = {
        "source_id": str(actor.get("id", "")),
        "source_side": str(actor.get("side", "")),
        "expires_after_action": int(actor.get("action_serial", 0)) + 3
    }
    _spawn_feedback_label(actor, "🌱 GRASFELD · 3 AKTIONEN", Color("9ee28d"))

    # No speculative flat Aggro at cast time. The terrain's real extra damage is
    # already included in damage Aggro and every real healing pulse already adds
    # exactly the HP restored to the source's Aggro.
    return 0.0


func _bulba_rest(actor: Dictionary) -> float:
    if int(actor.get("hp", 0)) >= int(actor.get("max_hp", 1)):
        _spawn_feedback_label(actor, "✖ KP BEREITS VOLL", Color("d9a5a5"))
        return 0.0
    if _database_status_is_blocked(actor, "sleep"):
        _spawn_feedback_label(actor, "🛡️ SCHLAF VERHINDERT", Color("b8d9ff"))
        return 0.0

    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    var had_major_status: bool = (
        not str(actor.get("major_status", "")).is_empty()
        or bool(actor.get("paralyzed", false))
    )

    actor["major_status"] = ""
    actor["paralyzed"] = false
    actor["db_sleep_actions"] = 0
    actor["hp"] = int(actor.get("max_hp", 1))
    actor["major_status"] = "sleep"
    actor["db_sleep_actions"] = 2
    _spawn_feedback_label(actor, "🛌 VOLLE KP · SCHLAF 2", Color("bfc8ff"))

    var cleanse_aggro: float = (
        _hp_scaled_aggro(actor, AGGRO_REST_STATUS_CLEANSE_HP_FRACTION)
        if had_major_status
        else 0.0
    )
    return float(missing) + cleanse_aggro
