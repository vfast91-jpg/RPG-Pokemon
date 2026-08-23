extends "res://scripts/battle_demo_ad_registry_v1.gd"

# Combat/field mechanics for the Abra -> Dodri ten-family attack batch.
# Existing generic runtime mechanics (damage, high-crit, multi-hit, flinch,
# timed soft-cap modifiers, protection, status and weather) stay inherited.

const AD_StatusEffects = preload("res://scripts/battle/status_effect_runtime.gd")
const AD_SHORT_CHARGE_DEFAULT_SECONDS: float = 0.45
const AD_TRICK_ROOM_DURATION_SECONDS: float = 50.0

var _ad_active_move_id: String = ""
var _ad_psychic_terrain: Dictionary = {}
var _ad_trick_room_remaining: float = 0.0
var _ad_pending_short_charges: Array = []



func _ad_replace_runtime_move(move_id: String, move: Dictionary) -> void:
    var moves_value: Variant = data.get("moves", {})
    if moves_value is Dictionary:
        (moves_value as Dictionary)[move_id] = move
        data["moves"] = moves_value


func _ad_execute_empty_action(actor: Dictionary, move_id: String, move: Dictionary) -> void:
    var empty_move: Dictionary = move.duplicate(true)
    empty_move["power"] = null
    empty_move["accuracy"] = null
    empty_move["mechanics"] = []
    _ad_replace_runtime_move(move_id, empty_move)
    var serial_before: int = int(actor.get("action_serial", 0))
    _ad_active_move_id = move_id
    super._execute_move(actor, move_id)
    _ad_active_move_id = ""
    _ad_replace_runtime_move(move_id, move)
    if int(actor.get("action_serial", 0)) > serial_before:
        _ad_after_counted_action(actor)


func _ad_begin_short_charge(
    actor: Dictionary,
    move_id: String,
    runtime: Dictionary
) -> void:
    actor["ad_short_charging"] = true
    actor["ad_short_charge_move"] = move_id
    actor["ad_revenge_was_hit"] = false
    actor["atb"] = 0.0
    actor["cycle"] = 1.0

    var seconds: float = maxf(
        0.10,
        float(runtime.get("ad_short_charge_seconds", AD_SHORT_CHARGE_DEFAULT_SECONDS))
    )
    _ad_pending_short_charges.append({
        "actor_id": str(actor.get("id", "")),
        "move_id": move_id,
        "remaining": seconds
    })
    _spawn_feedback_label(actor, "⏳ KURZES ANSETZEN", Color("f0d78b"))
    _set_log(
        _actor_name(actor) + " bereitet [b]"
        + str(_move_data(move_id).get("name", move_id)) + "[/b] kurz vor."
    )
    _refresh_cards()


func _ad_advance_short_charges(delta: float) -> void:
    if _ad_pending_short_charges.is_empty():
        return

    var remaining_entries: Array = []
    var due_entries: Array = []
    for entry_value: Variant in _ad_pending_short_charges:
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
        if float(entry.get("remaining", 0.0)) <= 0.0:
            due_entries.append(entry)
        else:
            remaining_entries.append(entry)
    _ad_pending_short_charges = remaining_entries

    for entry_value: Variant in due_entries:
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var actor: Dictionary = _zf_find_combatant(str(entry.get("actor_id", "")))
        if actor.is_empty():
            continue
        actor["ad_short_charging"] = false
        var move_id: String = str(entry.get("move_id", ""))
        actor["ad_short_charge_move"] = ""
        if not bool(actor.get("alive", false)):
            continue

        if move_id == "revenge" and bool(actor.get("ad_revenge_was_hit", false)):
            actor["ad_revenge_power_bonus"] = true
            _spawn_feedback_label(actor, "👊 VERGELTUNG ×2", Color("ffd59d"))
        actor["ad_short_charge_resolving"] = true
        _execute_move(actor, move_id)
        actor["ad_short_charge_resolving"] = false
        actor["ad_revenge_was_hit"] = false


func _ad_snapshot_hp() -> Dictionary:
    var result: Dictionary = {}
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            result[str(candidate.get("id", ""))] = int(candidate.get("hp", 0))
    return result


func _ad_any_target_lost_hp(targets: Array, hp_before: Dictionary) -> bool:
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        if int(target.get("hp", 0)) < int(hp_before.get(target_id, int(target.get("hp", 0)))):
            return true
    return false


func _ad_heal(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var resolved_target: Dictionary = (
        actor if str(mechanic.get("scope", "self")) == "self" else target
    )
    if resolved_target.is_empty() or not bool(resolved_target.get("alive", false)):
        return 0.0

    var missing: int = maxi(
        0,
        int(resolved_target.get("max_hp", 1)) - int(resolved_target.get("hp", 0))
    )
    if missing <= 0:
        return 0.0

    var requested: int = AD_StatusEffects.max_hp_heal(
        int(resolved_target.get("max_hp", 1)),
        float(actor.get("special", 0.0)),
        float(mechanic.get("status_weight", 1.0))
    )
    var healed: int = mini(missing, requested)
    if healed <= 0:
        return 0.0

    resolved_target["hp"] = int(resolved_target.get("hp", 0)) + healed
    _spawn_feedback_label(
        resolved_target, "💚 +" + str(healed) + " KP", Color("8fe39b")
    )
    return float(healed)


func _ad_protect(actor: Dictionary) -> float:
    var chain: int = maxi(0, int(actor.get("ad_shared_protect_chain", 0)))
    var success_chance: float = pow(1.0 / 3.0, float(chain))
    actor["ad_shared_protect_chain"] = chain + 1
    if randf() <= success_chance:
        actor["protective_guard"] = true
        _spawn_feedback_label(actor, "👁️ SCANNER", Color("9fe7bd"))
        return 4.0
    _spawn_feedback_label(actor, "✖ SCHUTZ FEHLGESCHLAGEN", Color("d9a5a5"))
    return 0.0


func _ad_reflect_type(actor: Dictionary, target: Dictionary) -> float:
    var types: Array = _type_array(target.get("types", []))
    if types.is_empty():
        return 0.0
    actor["types"] = types.duplicate()
    _spawn_feedback_label(actor, "🪞 TYP KOPIERT", Color("cbd9ef"))
    return 3.0


func _ad_apply_modifier(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if target.is_empty():
        return 0.0

    var source_name: String = str(
        _move_data(_ad_active_move_id).get("name", _ad_active_move_id)
    )
    if not source_name.is_empty():
        _zf_remove_modifiers_from_move(target, source_name)

    var kind: String = str(mechanic.get("modifier_kind", ""))
    var proxy: Dictionary = mechanic.duplicate(true)
    proxy["kind"] = kind
    var multiplier: float = _status_modifier_multiplier(
        actor, proxy, kind, false, false
    )
    _add_timed_modifier(
        target, kind, multiplier, source_name, _actor_name(actor)
    )
    return _status_effect_aggro(kind, multiplier)


func _ad_ally_switch(actor: Dictionary) -> float:
    var best: Dictionary = {}
    for ally_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        if (
            not bool(ally.get("alive", false))
            or str(ally.get("id", "")) == str(actor.get("id", ""))
            or bool(ally.get("ad_hidden_cycle", false))
        ):
            continue
        if best.is_empty():
            best = ally
            continue
        var ally_aggro: float = float(ally.get("aggro", 0.0))
        var best_aggro: float = float(best.get("aggro", 0.0))
        if ally_aggro > best_aggro:
            best = ally
        elif (
            is_equal_approx(ally_aggro, best_aggro)
            and int(ally.get("index", 0)) < int(best.get("index", 0))
        ):
            best = ally

    if best.is_empty():
        _spawn_feedback_label(actor, "✖ KEIN VERBÜNDETER", Color("d9a5a5"))
        return 0.0

    var actor_aggro: float = float(actor.get("aggro", 0.0))
    actor["aggro"] = float(best.get("aggro", 0.0))
    best["aggro"] = actor_aggro
    _spawn_feedback_label(actor, "🔄 AGGRO GETAUSCHT", Color("c9d7ff"))
    _spawn_feedback_label(best, "🔄 AGGRO GETAUSCHT", Color("c9d7ff"))
    return 0.0


func _ad_yawn(target: Dictionary) -> float:
    if (
        not str(target.get("major_status", "")).is_empty()
        or int(target.get("ad_drowsy_trigger_serial", -1)) >= 0
        or _database_status_is_blocked(target, "sleep")
    ):
        return 0.0

    target["ad_drowsy_trigger_serial"] = int(target.get("action_serial", 0)) + 1
    _spawn_feedback_label(target, "🥱 SCHLÄFRIG", Color("d8d1e8"))
    return 4.0


func _ad_resolve_drowsy_after_action(actor: Dictionary) -> void:
    var trigger: int = int(actor.get("ad_drowsy_trigger_serial", -1))
    if trigger < 0 or int(actor.get("action_serial", 0)) < trigger:
        return

    actor["ad_drowsy_trigger_serial"] = -1
    if (
        not str(actor.get("major_status", "")).is_empty()
        or _database_status_is_blocked(actor, "sleep")
    ):
        return

    actor["major_status"] = "sleep"
    actor["db_sleep_actions"] = randi_range(1, 3)
    _spawn_feedback_label(actor, "💤 EINGESCHLAFEN", Color("c9c4ee"))

