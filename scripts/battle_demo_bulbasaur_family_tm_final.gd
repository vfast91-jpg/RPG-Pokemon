extends "res://scripts/battle_demo_pvp.gd"

# Final, central Timeflow integration for the complete Bisasam evolutionary-family
# TM package.  This layer deliberately contains no item system: Abschlag operates
# on temporary positive combat modifiers.  It also keeps Timeflow priority as a
# Round-0 concept; Grasrutsche uses an ATB start bonus instead.

const TF_BAD_POISON_MAX_STAGE: int = 15
const TF_KNOCK_OFF_KINDS: Array[String] = [
    "outgoing_damage_mod", "incoming_damage_mod", "accuracy_mod", "atb_cycle_mod"
]
const TF_STOMPING_BOOST_OUTCOMES: Array[String] = ["miss", "immune", "failed"]

const TF_TM_SUMMARIES: Dictionary = {
    "false_swipe": "Schaden · kann die echten KP des Ziels nicht unter 1 senken",
    "body_slam": "Schaden · 30 % Paralyse · gegen minimierte Ziele doppelte Stärke und keine normale Genauigkeitsprüfung",
    "leaf_storm": "Stärke 130 · Treffer: eigener Angriff stark ↓ (Statuswert) · 3 eigene Aktionen",
    "toxic": "Schwere Vergiftung · Schaden nach Zielaktionen: 1/16, 2/16, 3/16 … bis 15/16 Max-KP",
    "knock_off": "Schaden · gegen positiven temporären Attributseffekt stärker · entfernt danach einen solchen Effekt",
    "weather_ball": "Ohne Wetter: Normal/Stärke 50 · Sonne: Feuer 100 · Regen: Wasser 100",
    "grassy_glide": "Schaden · im Grasfeld am Boden: Treffer startet die nächste Zeitleiste bei 25 %",
    "curse": "Nicht-Geist: Angriff + Verteidigung ↑, Geschwindigkeit ↓ · Geist: 50 % Max-KP Kosten, Ziel verliert nach eigenen Aktionen 25 % Max-KP",
    "roar": "Pausiert die Zeitleiste des Ziels nach Statuswert · danach Fortsetzung vom bisherigen Füllstand",
    "bulldoze": "Trifft alle anderen Pokémon · Treffer: Geschwindigkeit ↓ (Statuswert) · 3 Zielaktionen · im Grasfeld am Boden halber Schaden",
    "stomping_tantrum": "Stärke 75 · nach Verfehlen, Immunität oder Fehlschlag der vorherigen eigenen Attacke Stärke 150",
    "amnesia": "Eigene Verteidigung stark ↑ (Statuswert) · 3 eigene Aktionen",
    "earth_power": "Schaden · 10 %: Verteidigung ↓ (Statuswert) · 3 Zielaktionen",
    "earthquake": "Trifft alle anderen Pokémon · im Grasfeld am Boden halber Schaden · unter der Erde doppelte Stärke",
    "frenzy_plant": "Stärke 150 · Treffer: nächste eigene Aktion ist Regeneration",
    "whirlwind": "Pausiert die Zeitleiste des Ziels nach Statuswert · dieselbe Wirkung wie Brüller",
    "acid_spray": "Schaden · Verteidigung stark ↓ (Statuswert) · 3 Zielaktionen"
}

var _tf_active_move_id: String = ""
var _tf_custom_effect_happened: bool = false
var _tf_custom_failure_reason: String = ""
var _tf_knock_off_candidate_index: int = -1
var _tf_knock_off_target_id: String = ""


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["tf_bad_poison_stage"] = 0
    combatant["tf_bad_poison_source_id"] = ""
    combatant["tf_curse_effect"] = {}
    combatant["tf_last_move_outcome"] = "none"
    combatant["tf_states"] = {}
    combatant["tf_atb_pause_remaining"] = 0.0
    combatant["tf_atb_pause_total"] = 0.0
    return combatant


func _process(delta: float) -> void:
    if not battle_active or paused:
        return

    var frozen_atb: Dictionary = {}
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)):
            continue
        if str(combatant.get("major_status", "")) != "bad_poison" and int(combatant.get("tf_bad_poison_stage", 0)) > 0:
            combatant["tf_bad_poison_stage"] = 0
            combatant["tf_bad_poison_source_id"] = ""
        var remaining: float = maxf(0.0, float(combatant.get("tf_atb_pause_remaining", 0.0)))
        if remaining <= 0.0:
            continue
        remaining = maxf(0.0, remaining - delta)
        combatant["tf_atb_pause_remaining"] = remaining
        if remaining > 0.0:
            var combatant_id: String = str(combatant.get("id", ""))
            frozen_atb[combatant_id] = float(combatant.get("atb", 0.0))
            combatant["atb"] = -1000000.0
        else:
            combatant["tf_atb_pause_total"] = 0.0
            _spawn_feedback_label(combatant, "📢 ZEITLEISTE LÄUFT WEITER", Color("d7e7ff"))

    super._process(delta)

    if frozen_atb.is_empty():
        return
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        if frozen_atb.has(combatant_id) and float(combatant.get("tf_atb_pause_remaining", 0.0)) > 0.0:
            combatant["atb"] = float(frozen_atb[combatant_id])
    _refresh_cards()


func _choose_wait() -> void:
    if not selected_actor.is_empty():
        selected_actor["tf_last_move_outcome"] = "wait"
    super._choose_wait()


func _database_consume_recharge(actor: Dictionary) -> void:
    actor["tf_last_move_outcome"] = "recharge"
    super._database_consume_recharge(actor)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    var source_move: Dictionary = _move_data(move_id)
    if source_move.is_empty():
        super._execute_move(actor, move_id)
        return

    var previous_outcome: String = str(actor.get("tf_last_move_outcome", "none"))
    var move: Dictionary = source_move.duplicate(true)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var target_snapshots: Dictionary = _tf_snapshot_targets(actor, move)

    _tf_custom_effect_happened = false
    _tf_custom_failure_reason = ""
    _tf_knock_off_candidate_index = -1
    _tf_knock_off_target_id = ""

    if move_id == "body_slam":
        var body_target: Dictionary = _tf_first_target_from_snapshot(target_snapshots)
        if not body_target.is_empty() and _tf_has_state(body_target, "minimized"):
            move["power"] = int(round(float(move.get("power", 85)) * 2.0))
            move["accuracy"] = null

    if move_id == "toxic" and _type_array(actor.get("types", [])).has("poison"):
        move["accuracy"] = null

    if move_id == "weather_ball":
        _tf_resolve_weather_ball(move)

    if move_id == "knock_off":
        var knock_target: Dictionary = _tf_first_target_from_snapshot(target_snapshots)
        if not knock_target.is_empty():
            _tf_knock_off_candidate_index = _tf_best_positive_modifier_index(knock_target)
            _tf_knock_off_target_id = str(knock_target.get("id", ""))
            if _tf_knock_off_candidate_index >= 0:
                move["power"] = int(round(float(move.get("power", 65)) * 1.5))

    if move_id == "stomping_tantrum" and TF_STOMPING_BOOST_OUTCOMES.has(previous_outcome):
        move["power"] = int(move.get("power", 75)) * 2
        _spawn_feedback_label(actor, "🦶 VERSTÄRKT", Color("f0c27d"))

    var runtime_moves_value: Variant = data.get("moves", {})
    if not (runtime_moves_value is Dictionary):
        super._execute_move(actor, move_id)
        return
    var runtime_moves: Dictionary = runtime_moves_value
    runtime_moves[move_id] = move
    data["moves"] = runtime_moves

    _tf_active_move_id = move_id
    super._execute_move(actor, move_id)
    _tf_active_move_id = ""

    runtime_moves[move_id] = source_move
    data["moves"] = runtime_moves

    var attempted: bool = _database_move_was_attempted(move_id)
    var hit_success: bool = _tf_any_target_hit(target_snapshots)

    if move_id == "curse" and attempted:
        _tf_custom_effect_happened = _tf_apply_curse(actor) or _tf_custom_effect_happened

    if move_id == "leaf_storm" and hit_success:
        _tf_apply_leaf_storm_debuff(actor)

    if move_id == "knock_off" and hit_success:
        _tf_finish_knock_off(actor, target_snapshots)

    if move_id == "grassy_glide" and hit_success and _tf_terrain_is_grassy() and _tf_is_grounded(actor):
        actor["atb"] = maxf(float(actor.get("atb", 0.0)), 25.0)
        _spawn_feedback_label(actor, "🌿 ZEITLEISTE +25 %", Color("9ee28d"))

    var outcome: String = _tf_resolve_move_outcome(actor, move, target_snapshots, attempted, hit_success)
    actor["tf_last_move_outcome"] = outcome

    _refresh_cards()
    _check_end()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    if kind in ["status", "db_status"] and str(mechanic.get("status", "")) == "bad_poison":
        if randf() > float(mechanic.get("chance", 1.0)):
            return 0.0
        return _tf_apply_bad_poison(actor, target)

    if kind == "db_atb_pause" and _tf_active_move_id in ["roar", "whirlwind"]:
        if _bulba_substitute_blocks_effect(actor, target, mechanic):
            _tf_custom_failure_reason = "blocked"
            _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
            return 0.0
        return _tf_apply_atb_pause(actor, target)

    return super._effect(actor, target, mechanic)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var adjusted_power: int = power

    if _tf_active_move_id in ["bulldoze", "earthquake"] and _tf_terrain_is_grassy() and _tf_is_grounded(target):
        adjusted_power = maxi(1, int(round(float(adjusted_power) * 0.5)))

    if _tf_active_move_id == "earthquake" and _tf_has_state(target, "underground"):
        adjusted_power *= 2

    var damage: int = super._damage(actor, target, adjusted_power, move_type, category)

    if _tf_active_move_id == "false_swipe" and damage > 0 and int(target.get("db_substitute_hp", 0)) <= 0:
        damage = mini(damage, maxi(0, int(target.get("hp", 0)) - 1))

    return damage


func _resolve_after_action_effects(combatant: Dictionary) -> void:
    if not bool(combatant.get("alive", false)):
        return

    var major_status: String = str(combatant.get("major_status", ""))
    if major_status == "burn":
        _deal_periodic_damage(combatant, BURN_DAMAGE_FRACTION, "🔥 VERBRENNUNG")
    elif major_status == "poison":
        _deal_periodic_damage(combatant, POISON_DAMAGE_FRACTION, "☠️ VERGIFTUNG")
    elif major_status == "bad_poison":
        _tf_tick_bad_poison(combatant)

    if not bool(combatant.get("alive", false)):
        return
    _resolve_seed_tick(combatant)

    if not bool(combatant.get("alive", false)):
        return
    _resolve_binding_tick(combatant)

    if not bool(combatant.get("alive", false)):
        return
    _tf_tick_curse(combatant)


func _tf_apply_bad_poison(actor: Dictionary, target: Dictionary) -> float:
    if _bulba_substitute_blocks_effect(actor, target, {"kind":"status"}):
        _tf_custom_failure_reason = "blocked"
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return 0.0

    if _database_status_is_blocked(target, "bad_poison"):
        _tf_custom_failure_reason = "failed"
        return 0.0

    if not str(target.get("major_status", "")).is_empty() or bool(target.get("paralyzed", false)):
        _tf_custom_failure_reason = "failed"
        _spawn_feedback_label(target, "✖ HAUPTSTATUS BEREITS AKTIV", Color("d9a5a5"))
        return 0.0

    var types: Array = _type_array(target.get("types", []))
    if types.has("poison") or types.has("steel"):
        _tf_custom_failure_reason = "immune"
        _spawn_feedback_label(target, "🛡️ IMMUN", Color("b8d9ff"))
        return 0.0

    target["major_status"] = "bad_poison"
    target["tf_bad_poison_stage"] = 1
    target["tf_bad_poison_source_id"] = str(actor.get("id", ""))
    _tf_custom_effect_happened = true
    _spawn_feedback_label(target, "☠️ SCHWER VERGIFTET", Color("bd86cf"))
    return 20.0


func _tf_tick_bad_poison(target: Dictionary) -> int:
    var stage: int = clampi(int(target.get("tf_bad_poison_stage", 1)), 1, TF_BAD_POISON_MAX_STAGE)
    var amount: int = maxi(1, int(floor(float(target.get("max_hp", 1)) * float(stage) / 16.0)))
    var actual: int = mini(amount, int(target.get("hp", 0)))
    if actual <= 0:
        return 0

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    target["tf_bad_poison_stage"] = mini(TF_BAD_POISON_MAX_STAGE, stage + 1)
    _spawn_feedback_label(target, "☠️ SCHWERES GIFT −" + str(actual), Color("bd86cf"))

    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false
    return actual


func _tf_apply_atb_pause(actor: Dictionary, target: Dictionary) -> float:
    if not bool(target.get("alive", false)):
        _tf_custom_failure_reason = "failed"
        return 0.0

    var statuswert: float = maxf(0.0, float(actor.get("special", 0.0)))
    var fraction: float = statuswert / (75.0 + statuswert) if statuswert > 0.0 else 0.0
    var full_cycle_seconds: float = _tf_full_atb_cycle_seconds(target)
    var pause_seconds: float = maxf(0.0, full_cycle_seconds * fraction)
    if pause_seconds <= 0.0:
        _tf_custom_failure_reason = "failed"
        return 0.0

    var current_remaining: float = maxf(0.0, float(target.get("tf_atb_pause_remaining", 0.0)))
    var applied: float = maxf(0.0, pause_seconds - current_remaining)
    target["tf_atb_pause_remaining"] = maxf(current_remaining, pause_seconds)
    target["tf_atb_pause_total"] = maxf(float(target.get("tf_atb_pause_total", 0.0)), pause_seconds)
    _tf_custom_effect_happened = true
    _spawn_feedback_label(target, "📢 ZEITLEISTE PAUSIERT", Color("b8d9ff"))

    var actual_fraction: float = applied / maxf(0.001, full_cycle_seconds)
    return _hp_scaled_aggro(target, 0.10) * actual_fraction


func _tf_full_atb_cycle_seconds(target: Dictionary) -> float:
    var effective_speed: float = maxf(1.0, float(target.get("speed", 10.0)))
    if bool(target.get("paralyzed", false)):
        effective_speed *= 0.5
    var ap_cycle: float = maxf(0.01, float(target.get("cycle", 1.0)))
    var status_cycle: float = _combined_timed_modifier(target, "atb_cycle_mod")
    var gain_per_second: float = (12.0 + effective_speed * 0.62) / maxf(0.01, ap_cycle * status_cycle)
    return 100.0 / maxf(0.001, gain_per_second)


func _tf_apply_leaf_storm_debuff(actor: Dictionary) -> void:
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var type_bonus: float = TypeSystem.get_same_type_status_multiplier("grass", _type_array(actor.get("types", [])))
    var multiplier: float = clampf(1.0 - 2.0 * ratio * type_bonus, 0.25, 2.5)
    _bulba_refresh_timed_modifier(actor, "outgoing_damage_mod", multiplier, "Blättersturm", _actor_name(actor))
    _spawn_feedback_label(actor, "ANGRIFF ↓ · 3 AKTIONEN", Color("d9b0a4"))


func _tf_finish_knock_off(actor: Dictionary, snapshots: Dictionary) -> void:
    if _tf_knock_off_candidate_index < 0 or _tf_knock_off_target_id.is_empty():
        return
    var snapshot_value: Variant = snapshots.get(_tf_knock_off_target_id, {})
    if not (snapshot_value is Dictionary):
        return
    var snapshot: Dictionary = snapshot_value
    var target_value: Variant = snapshot.get("target", {})
    if not (target_value is Dictionary):
        return
    var target: Dictionary = target_value

    # A Delegator present for this hit prevents removal even if the hit destroyed it.
    if int(snapshot.get("substitute_hp", 0)) > 0:
        return

    var modifiers_value: Variant = target.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return
    var modifiers: Array = modifiers_value
    if _tf_knock_off_candidate_index >= modifiers.size():
        return
    var candidate_value: Variant = modifiers[_tf_knock_off_candidate_index]
    if not (candidate_value is Dictionary) or not _tf_modifier_is_positive(candidate_value as Dictionary):
        return

    var candidate: Dictionary = candidate_value
    var label: String = _tf_modifier_label(candidate)
    modifiers.remove_at(_tf_knock_off_candidate_index)
    target["timed_modifiers"] = modifiers
    actor["aggro"] = float(actor.get("aggro", 0.0)) + _hp_scaled_aggro(target, 0.10)
    _tf_custom_effect_happened = true
    _spawn_feedback_label(target, "✋ ENTFERNT: " + label, Color("f1d88d"))


func _tf_best_positive_modifier_index(target: Dictionary) -> int:
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return -1
    var modifiers: Array = modifiers_value
    var best_index: int = -1
    var best_strength: float = -1.0
    for index: int in range(modifiers.size()):
        var modifier_value: Variant = modifiers[index]
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if not _tf_modifier_is_positive(modifier):
            continue
        var strength: float = _tf_modifier_strength(modifier)
        if strength > best_strength + 0.000001:
            best_strength = strength
            best_index = index
    return best_index


func _tf_modifier_is_positive(modifier: Dictionary) -> bool:
    var kind: String = str(modifier.get("kind", ""))
    if not TF_KNOCK_OFF_KINDS.has(kind):
        return false
    var multiplier: float = float(modifier.get("multiplier", 1.0))
    match kind:
        "outgoing_damage_mod", "incoming_damage_mod", "accuracy_mod":
            return multiplier > 1.000001
        "atb_cycle_mod":
            return multiplier < 0.999999
    return false


func _tf_modifier_strength(modifier: Dictionary) -> float:
    var kind: String = str(modifier.get("kind", ""))
    var multiplier: float = maxf(0.0001, float(modifier.get("multiplier", 1.0)))
    if kind == "atb_cycle_mod":
        return absf(1.0 / multiplier - 1.0)
    return absf(multiplier - 1.0)


func _tf_modifier_label(modifier: Dictionary) -> String:
    match str(modifier.get("kind", "")):
        "outgoing_damage_mod":
            return "Angriff"
        "incoming_damage_mod":
            return "Verteidigung"
        "accuracy_mod":
            return "Genauigkeit"
        "atb_cycle_mod":
            return "Geschwindigkeit"
    return "Attribut"


func _tf_apply_curse(actor: Dictionary) -> bool:
    if _type_array(actor.get("types", [])).has("ghost"):
        return _tf_apply_ghost_curse(actor)
    return _tf_apply_non_ghost_curse(actor)


func _tf_apply_non_ghost_curse(actor: Dictionary) -> bool:
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var attack_mult: float = clampf(1.0 + ratio, 0.25, 2.5)
    var defense_mult: float = clampf(1.0 + ratio, 0.25, 2.5)
    var speed_mult: float = clampf(1.0 + ratio, 0.45, 2.5)

    _bulba_refresh_timed_modifier(actor, "outgoing_damage_mod", attack_mult, "Fluch", _actor_name(actor))
    _bulba_refresh_timed_modifier(actor, "incoming_damage_mod", defense_mult, "Fluch", _actor_name(actor))
    _bulba_refresh_timed_modifier(actor, "atb_cycle_mod", speed_mult, "Fluch", _actor_name(actor))

    actor["aggro"] = (
        float(actor.get("aggro", 0.0))
        + _status_effect_aggro("outgoing_damage_mod", attack_mult)
        + _status_effect_aggro("incoming_damage_mod", defense_mult)
    )
    _spawn_feedback_label(actor, "👻 FLUCH · ANG/DEF ↑ · GES ↓", Color("c6a7e8"))
    return true


func _tf_apply_ghost_curse(actor: Dictionary) -> bool:
    var targets: Array = _targets(actor, "enemy_highest_aggro")
    if targets.is_empty() or not (targets[0] is Dictionary):
        _tf_custom_failure_reason = "failed"
        return false
    var target: Dictionary = targets[0]

    var existing_value: Variant = target.get("tf_curse_effect", {})
    if existing_value is Dictionary and not (existing_value as Dictionary).is_empty():
        _tf_custom_failure_reason = "failed"
        _spawn_feedback_label(target, "✖ BEREITS VERFLUCHT", Color("d9a5a5"))
        return false

    target["tf_curse_effect"] = {"source_id": str(actor.get("id", ""))}
    var cost: int = maxi(1, int(floor(float(actor.get("max_hp", 1)) * 0.5)))
    var actual_cost: int = mini(cost, int(actor.get("hp", 0)))
    actor["hp"] = maxi(0, int(actor.get("hp", 0)) - actual_cost)
    if int(actor.get("hp", 0)) <= 0:
        actor["alive"] = false

    actor["aggro"] = float(actor.get("aggro", 0.0)) + _hp_scaled_aggro(target, 0.10)
    _spawn_feedback_label(target, "👻 FLUCH", Color("c6a7e8"))
    _spawn_feedback_label(actor, "👻 −" + str(actual_cost) + " KP", Color("d9a5a5"))
    return true


func _tf_tick_curse(target: Dictionary) -> int:
    var curse_value: Variant = target.get("tf_curse_effect", {})
    if not (curse_value is Dictionary) or (curse_value as Dictionary).is_empty():
        return 0
    var amount: int = maxi(1, int(floor(float(target.get("max_hp", 1)) * 0.25)))
    var actual: int = mini(amount, int(target.get("hp", 0)))
    if actual <= 0:
        return 0

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    _spawn_feedback_label(target, "👻 FLUCH −" + str(actual), Color("c6a7e8"))

    var source: Dictionary = _tf_find_combatant(str((curse_value as Dictionary).get("source_id", "")))
    if not source.is_empty():
        source["aggro"] = float(source.get("aggro", 0.0)) + float(actual)

    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false
        target["tf_curse_effect"] = {}
    return actual


func _tf_resolve_weather_ball(move: Dictionary) -> void:
    var weather_id: String = battle_weather.current_id()
    match weather_id:
        "sun":
            move["type"] = "fire"
            move["power"] = 100
        "rain":
            move["type"] = "water"
            move["power"] = 100
        "snow", "hail":
            move["type"] = "ice"
            move["power"] = 100
        "sandstorm":
            move["type"] = "rock"
            move["power"] = 100
        "":
            move["type"] = "normal"
            move["power"] = 50
        _:
            move["type"] = "normal"
            move["power"] = 100


func _tf_terrain_is_grassy() -> bool:
    return _bulba_grassy_terrain_active()


func _tf_is_grounded(combatant: Dictionary) -> bool:
    if _tf_has_state(combatant, "raised"):
        return false
    return _bulba_is_grounded(combatant)


func _tf_has_state(combatant: Dictionary, state_id: String) -> bool:
    var states_value: Variant = combatant.get("tf_states", {})
    return states_value is Dictionary and bool((states_value as Dictionary).get(state_id, false))


func _tf_set_state(combatant: Dictionary, state_id: String, active: bool) -> void:
    var states_value: Variant = combatant.get("tf_states", {})
    var states: Dictionary = states_value if states_value is Dictionary else {}
    if active:
        states[state_id] = true
    else:
        states.erase(state_id)
    combatant["tf_states"] = states


func _tf_snapshot_targets(actor: Dictionary, move: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for target_value: Variant in _targets(actor, str(move.get("target", "enemy_highest_aggro"))):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        result[str(target.get("id", ""))] = {
            "target": target,
            "hp": int(target.get("hp", 0)),
            "substitute_hp": int(target.get("db_substitute_hp", 0)),
            "major_status": str(target.get("major_status", "")),
            "protective_guard": bool(target.get("protective_guard", false)),
            "modifier_count": _tf_modifier_count(target)
        }
    return result


func _tf_first_target_from_snapshot(snapshot: Dictionary) -> Dictionary:
    for snapshot_value: Variant in snapshot.values():
        if snapshot_value is Dictionary:
            var target_value: Variant = (snapshot_value as Dictionary).get("target", {})
            if target_value is Dictionary:
                return target_value as Dictionary
    return {}


func _tf_any_target_hit(snapshot: Dictionary) -> bool:
    for snapshot_value: Variant in snapshot.values():
        if not (snapshot_value is Dictionary):
            continue
        var entry: Dictionary = snapshot_value
        var target_value: Variant = entry.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if int(target.get("hp", 0)) < int(entry.get("hp", 0)):
            return true
        if int(target.get("db_substitute_hp", 0)) < int(entry.get("substitute_hp", 0)):
            return true
    return false


func _tf_modifier_count(target: Dictionary) -> int:
    var value: Variant = target.get("timed_modifiers", [])
    return (value as Array).size() if value is Array else 0


func _tf_resolve_move_outcome(
    actor: Dictionary,
    move: Dictionary,
    snapshots: Dictionary,
    attempted: bool,
    hit_success: bool
) -> String:
    if not attempted:
        return "skipped"

    if log_label != null:
        var log_text: String = log_label.get_parsed_text().to_lower()
        if log_text.contains("verfehlt"):
            return "miss"

    if _tf_custom_failure_reason == "immune":
        return "immune"
    if _tf_custom_failure_reason == "blocked":
        return "blocked"
    if _tf_custom_failure_reason == "failed":
        return "failed"

    if hit_success or _tf_custom_effect_happened:
        return "success"

    var has_damage: bool = false
    var mechanics_value: Variant = move.get("mechanics", move.get("effects", []))
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "damage":
                has_damage = true
                break

    if has_damage and _tf_all_targets_type_immune(move, snapshots):
        return "immune"

    for snapshot_value: Variant in snapshots.values():
        if snapshot_value is Dictionary and bool((snapshot_value as Dictionary).get("protective_guard", false)):
            return "blocked"

    if has_damage:
        # A successful zero-damage action such as Trugschlag against 1 KP still
        # counts as success; explicit immunity and protection were handled above.
        return "success"

    return "success"


func _tf_all_targets_type_immune(move: Dictionary, snapshots: Dictionary) -> bool:
    if snapshots.is_empty():
        return false
    var move_type: String = str(move.get("type", "normal"))
    for snapshot_value: Variant in snapshots.values():
        if not (snapshot_value is Dictionary):
            continue
        var target_value: Variant = (snapshot_value as Dictionary).get("target", {})
        if target_value is Dictionary:
            if not is_zero_approx(TypeSystem.get_multiplier(move_type, _type_array((target_value as Dictionary).get("types", [])))):
                return false
    return true


func _tf_find_combatant(combatant_id: String) -> Dictionary:
    if combatant_id.is_empty():
        return {}
    for combatant_value: Variant in combatants:
        if combatant_value is Dictionary and str((combatant_value as Dictionary).get("id", "")) == combatant_id:
            return combatant_value as Dictionary
    return {}


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if TF_TM_SUMMARIES.has(move_id):
        return str(TF_TM_SUMMARIES[move_id])
    return super._compact_effect_summary(move)


func _move_tooltip(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    var display_move: Dictionary = move.duplicate(true)
    if move_id == "weather_ball":
        _tf_resolve_weather_ball(display_move)
    var text: String = super._move_tooltip(display_move)
    if not TF_TM_SUMMARIES.has(move_id):
        return text
    var summary: String = str(TF_TM_SUMMARIES[move_id])
    if not text.contains(summary):
        text = text.strip_edges() + "\nEffekt: " + summary
    return _final_attack_text(text)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if str(combatant.get("major_status", "")) == "bad_poison":
        tokens.append("SCHWER GIFT")
    var curse_value: Variant = combatant.get("tf_curse_effect", {})
    if curse_value is Dictionary and not (curse_value as Dictionary).is_empty():
        tokens.append("FLUCH")
    if float(combatant.get("tf_atb_pause_remaining", 0.0)) > 0.0:
        tokens.append("PAUSE")
    return tokens
