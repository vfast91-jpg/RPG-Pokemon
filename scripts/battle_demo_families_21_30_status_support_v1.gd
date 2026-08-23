extends "res://scripts/battle_demo_families_21_30_registry_v1.gd"

func _f30_aqua_ring(actor: Dictionary) -> float:
    if bool(actor.get("f30_aqua_ring_active", false)):
        _spawn_feedback_label(actor, "✖ WASSERRING AKTIV", Color("d9a5a5"))
        return 0.0
    actor["f30_aqua_ring_active"] = true
    actor["f30_aqua_ring_last_heal_serial"] = -1
    _spawn_feedback_label(actor, "💍 WASSERRING", Color("8fd7e8"))
    return 0.0

func _f30_trigger_aqua_ring_after_action(actor: Dictionary) -> void:
    if (
        actor.is_empty()
        or not bool(actor.get("alive", false))
        or not bool(actor.get("f30_aqua_ring_active", false))
    ):
        return
    var serial: int = int(actor.get("action_serial", 0))
    if int(actor.get("f30_aqua_ring_last_heal_serial", -1)) == serial:
        return
    actor["f30_aqua_ring_last_heal_serial"] = serial

    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var missing: int = maxi(0, max_hp - int(actor.get("hp", 0)))
    if missing <= 0:
        return
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var requested: int = maxi(1, int(round(float(max_hp) * 0.125 * ratio)))
    var healed: int = mini(missing, requested)
    actor["hp"] = int(actor.get("hp", 0)) + healed
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(healed)
    _spawn_feedback_label(actor, "💍 +" + str(healed) + " KP", Color("8fe39b"))

func _f30_modifier_on_damage(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    var chance: float = clampf(float(mechanic.get("chance", 1.0)), 0.0, 1.0)
    if randf() > chance:
        return 0.0
    var kind: String = str(mechanic.get("modifier_kind", ""))
    var signed_weight: float = float(mechanic.get("signed_weight", 0.0))
    var source_name: String = str(_move_data(_f30_current_move_id()).get("name", _f30_current_move_id()))
    var value: float = _f30_apply_exact_modifier(
        actor, target, kind, signed_weight, source_name
    )
    if kind == "outgoing_damage_mod":
        _spawn_feedback_label(target, "ANGRIFF ↓ · 3 AKTIONEN", Color("d9b0a4"))
    elif kind == "incoming_damage_mod":
        _spawn_feedback_label(target, "VERTEIDIGUNG ↓ · 3 AKTIONEN", Color("d9b0a4"))
    return value

func _f30_apply_exact_modifier(
    source: Dictionary,
    target: Dictionary,
    kind: String,
    signed_weight: float,
    source_name: String
) -> float:
    if target.is_empty() or kind.is_empty():
        return 0.0

    _f30_remove_source_modifier_kind(target, source_name, kind)
    var ratio: float = _status_ratio(float(source.get("special", 0.0)))
    var scaled: float = absf(signed_weight) * ratio
    var multiplier: float = 1.0

    match kind:
        "outgoing_damage_mod":
            multiplier = 1.0 + scaled if signed_weight >= 0.0 else 1.0 - scaled
        "incoming_damage_mod":
            multiplier = 1.0 - scaled if signed_weight >= 0.0 else 1.0 + scaled
        "atb_cycle_mod":
            multiplier = 1.0 + scaled if signed_weight >= 0.0 else 1.0 - scaled
        "accuracy_mod":
            multiplier = 1.0 + scaled if signed_weight >= 0.0 else 1.0 - scaled
        _:
            return 0.0

    multiplier = maxf(0.05, multiplier)
    _add_timed_modifier(target, kind, multiplier, source_name, _actor_name(source))
    return _status_effect_aggro(kind, multiplier)

func _f30_remove_source_modifier_kind(
    target: Dictionary,
    source_move: String,
    kind: String
) -> void:
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return
    var kept: Array = []
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if (
            str(modifier.get("source_move", "")) == source_move
            and str(modifier.get("kind", "")) == kind
        ):
            continue
        kept.append(modifier)
    target["timed_modifiers"] = kept

func _f30_poison_gas(actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0
    var before: String = str(target.get("major_status", ""))
    if not before.is_empty() or _database_status_is_blocked(target, "poison"):
        return 0.0

    _zf_apply_status_direct(actor, target, "poison", 1.0)
    if before.is_empty() and str(target.get("major_status", "")) == "poison":
        return float(target.get("max_hp", 1)) * F30_STATUS_CONTROL_HP_FRACTION
    return 0.0

func _f30_minimize(actor: Dictionary) -> float:
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var multiplier: float = pow(maxf(0.0, 1.0 - ratio), 2.0)
    multiplier = maxf(0.05, multiplier)
    actor["db_incoming_accuracy_mult"] = multiplier
    actor["db_incoming_accuracy_expires"] = int(actor.get("action_serial", 0)) + 3
    actor["f30_minimize_expires_serial"] = int(actor.get("action_serial", 0)) + 3
    _tf_set_state(actor, "minimized", true)
    _spawn_feedback_label(actor, "🤏 AUSWEICHWIRKUNG ↑ · 3 AKTIONEN", Color("ddd0ff"))
    return _status_effect_aggro("accuracy_mod", multiplier)

func _f30_cleanup_minimized_states() -> void:
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        var expires: int = int(candidate.get("f30_minimize_expires_serial", -1))
        if expires >= 0 and int(candidate.get("action_serial", 0)) >= expires:
            candidate["f30_minimize_expires_serial"] = -1
            _tf_set_state(candidate, "minimized", false)

func _f30_memento(actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty() or str(target.get("side", "")) == str(actor.get("side", "")):
        return 0.0
    var aggro: float = _f30_apply_exact_modifier(
        actor, target, "outgoing_damage_mod", -1.0, "Memento-Mori"
    )
    _f30_memento_any_effect = true
    _spawn_feedback_label(target, "🕯️ ANGRIFF ↓ · 3 AKTIONEN", Color("d9b0a4"))
    return aggro

func _f30_mean_look(actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0
    if _type_array(target.get("types", [])).has("ghost"):
        _spawn_feedback_label(target, "👻 IMMUN", Color("b8d9ff"))
        return 0.0
    var actor_id: String = str(actor.get("id", ""))
    if str(target.get("f30_mean_look_source_id", "")) == actor_id:
        return 0.0
    target["f30_mean_look_source_id"] = actor_id
    target["f30_mean_look_aggro_floor"] = float(target.get("aggro", 0.0))
    _spawn_feedback_label(target, "👁️ AGGRO GESPERRT", Color("d8c4e8"))
    return float(target.get("max_hp", 1)) * F30_STATUS_CONTROL_HP_FRACTION

func _f30_enforce_mean_look_locks() -> void:
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        var source_id: String = str(candidate.get("f30_mean_look_source_id", ""))
        if source_id.is_empty():
            continue
        var source: Dictionary = _zf_find_combatant(source_id)
        if (
            source.is_empty()
            or not bool(source.get("alive", false))
            or not bool(candidate.get("alive", false))
        ):
            candidate["f30_mean_look_source_id"] = ""
            candidate["f30_mean_look_aggro_floor"] = 0.0
            continue

        var floor_value: float = float(candidate.get("f30_mean_look_aggro_floor", 0.0))
        var current: float = float(candidate.get("aggro", 0.0))
        if current < floor_value:
            candidate["aggro"] = floor_value
        else:
            candidate["f30_mean_look_aggro_floor"] = current

func _f30_destiny_bond(actor: Dictionary) -> float:
    if bool(actor.get("f30_destiny_recast_block", false)):
        _spawn_feedback_label(actor, "✖ ABGANGSBUND FEHLGESCHLAGEN", Color("d9a5a5"))
        _f30_destiny_activation_succeeded = false
        return 0.0
    actor["f30_destiny_bond_active"] = true
    _f30_destiny_activation_succeeded = true
    _spawn_feedback_label(actor, "🔗 ABGANGSBUND", Color("d9c7ef"))
    return 0.0

func _f30_expire_destiny_bond_at_action_opportunity(actor: Dictionary) -> void:
    if bool(actor.get("f30_destiny_bond_active", false)):
        actor["f30_destiny_bond_active"] = false

func _f30_resolve_destiny_bond_damage(
    bonded: Dictionary,
    source: Dictionary,
    hp_before: int
) -> void:
    if (
        not bool(bonded.get("f30_destiny_bond_active", false))
        or int(bonded.get("hp", 0)) > 0
        or int(bonded.get("hp", 0)) >= hp_before
        or source.is_empty()
        or not bool(source.get("alive", false))
        or str(source.get("side", "")) == str(bonded.get("side", ""))
    ):
        return

    bonded["f30_destiny_bond_active"] = false
    var removed: int = maxi(0, int(source.get("hp", 0)))
    if removed <= 0:
        return
    source["hp"] = 0
    source["alive"] = false
    source["aggro"] = 0.0
    _spawn_feedback_label(source, "🔗 MITGERISSEN · K.O.", Color("d9c7ef"))
    _refresh_cards()
    _check_end()

func _f30_ancient_power(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > clampf(float(mechanic.get("chance", 0.10)), 0.0, 1.0):
        return 0.0

    var total: float = 0.0
    total += _f30_apply_exact_modifier(
        actor, actor, "outgoing_damage_mod", 1.0, "Antik-Kraft"
    )
    total += _f30_apply_exact_modifier(
        actor, actor, "incoming_damage_mod", 1.0, "Antik-Kraft"
    )
    total += _f30_apply_exact_modifier(
        actor, actor, "atb_cycle_mod", -1.0, "Antik-Kraft"
    )
    _spawn_feedback_label(actor, "🗿 ANGRIFF · VERTEIDIGUNG · TEMPO ↑", Color("b9e2a8"))
    return total

func _f30_self_speed_on_damage(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    _f30_apply_exact_modifier(
        actor,
        actor,
        "atb_cycle_mod",
        float(mechanic.get("signed_weight", 1.0)),
        str(_move_data(_f30_current_move_id()).get("name", _f30_current_move_id()))
    )
    _spawn_feedback_label(
        actor,
        str(mechanic.get("label", "GESCHWINDIGKEIT ↓")) + " · 3 AKTIONEN",
        Color("d9b0a4")
    )
    # The V20 design explicitly excludes self-debuff Aggro for Hammerarm.
    return 0.0

func _f30_wide_guard(actor: Dictionary) -> float:
    var side: String = str(actor.get("side", ""))
    if side.is_empty():
        return 0.0
    if _f30_wide_guard_by_side.has(side):
        var existing_value: Variant = _f30_wide_guard_by_side.get(side, {})
        if (
            existing_value is Dictionary
            and str((existing_value as Dictionary).get("source_id", "")) == str(actor.get("id", ""))
        ):
            # all_allies resolves the team mechanic once per ally; subsequent
            # callbacks from the same cast are intentionally no-ops.
            return 0.0
        _spawn_feedback_label(actor, "✖ RUNDUMSCHUTZ AKTIV", Color("d9a5a5"))
        return 0.0
    _f30_wide_guard_by_side[side] = {
        "source_id": str(actor.get("id", ""))
    }
    _spawn_feedback_label(actor, "🛡️ RUNDUMSCHUTZ", Color("b8d9ff"))
    return 0.0

func _f30_wide_guard_blocks(target: Dictionary, move: Dictionary) -> bool:
    if target.is_empty() or move.is_empty():
        return false
    var side: String = str(target.get("side", ""))
    if side.is_empty() or not _f30_wide_guard_by_side.has(side):
        return false
    return (
        F30_SingleTargetAggroRules.is_spread_move(move)
        and F30_SingleTargetAggroRules.is_damage_resolution_move(move)
    )

func _f30_award_wide_guard_prevention_aggro(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> void:
    var side: String = str(target.get("side", ""))
    var guard_value: Variant = _f30_wide_guard_by_side.get(side, {})
    if not (guard_value is Dictionary):
        return
    var source: Dictionary = _zf_find_combatant(str((guard_value as Dictionary).get("source_id", "")))
    if source.is_empty() or not bool(source.get("alive", false)):
        return

    # Calculate the would-be HP loss on deep copies so reaction/state hooks in
    # lower damage layers cannot mutate the real combatants.
    var predicted: int = super._damage(
        actor.duplicate(true),
        target.duplicate(true),
        power,
        move_type,
        category
    )
    var prevented: int = mini(maxi(0, predicted), maxi(0, int(target.get("hp", 0))))
    if prevented > 0:
        source["aggro"] = float(source.get("aggro", 0.0)) + float(prevented)

func _f30_consume_wide_guards() -> void:
    for side_value: Variant in _f30_wide_guard_consumed_sides.keys():
        _f30_wide_guard_by_side.erase(str(side_value))
    _f30_wide_guard_consumed_sides.clear()

func _f30_flail_power(actor: Dictionary) -> int:
    var max_hp: float = maxf(1.0, float(actor.get("max_hp", 1)))
    var ratio: float = clampf(float(actor.get("hp", 0)) / max_hp, 0.0, 1.0)
    if ratio > 0.6875:
        return 20
    if ratio > 0.3542:
        return 40
    if ratio > 0.2083:
        return 80
    if ratio > 0.1042:
        return 100
    if ratio > 0.0417:
        return 150
    return 200
