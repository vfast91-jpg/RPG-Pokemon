extends "res://scripts/battle_demo_cleffa_family_base.gd"

# Pii/Piepi/Pixi helper mechanics.

func _cleffa_replace_runtime_move(move_id: String, move: Dictionary) -> void:
    var moves_value: Variant = data.get("moves", {})
    if moves_value is Dictionary:
        (moves_value as Dictionary)[move_id] = move
        data["moves"] = moves_value

func _cleffa_restore_runtime_move(move_id: String, move: Dictionary) -> void:
    _cleffa_replace_runtime_move(move_id, move)

func _cleffa_consume_failed_action(actor: Dictionary, move_id: String, message: String) -> void:
    var move: Dictionary = _move_data(move_id)
    _begin_counted_action(actor)
    actor["atb"] = 0.0
    actor["cycle"] = _ap_cycle(int(move.get("ap", 1)))
    _expire_finished_modifiers(actor)
    _set_log(_actor_name(actor) + ": " + message)
    _refresh_cards()

func _cleffa_execute_called_move(actor: Dictionary, move_id: String, caller_cycle: float) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty(): return
    if str(move.get("target", "")) == "single_ally":
        var allies: Array = _bulba_living_other_allies(actor)
        if allies.is_empty(): return
        var ally: Dictionary = allies.pick_random()
        _bulba_selected_ally_id = str(ally.get("id", ""))
    _cleffa_indirect_call_depth += 1
    _execute_move(actor, move_id)
    _cleffa_indirect_call_depth -= 1
    actor["cycle"] = caller_cycle
    _cleffa_last_resolved_move_id = move_id

func _cleffa_call_move_is_eligible(move_id: String, metronome: bool) -> bool:
    if move_id.is_empty() or CLEFFA_COPY_CALL_EXCLUDED.has(move_id): return false
    var move: Dictionary = _move_data(move_id)
    if move.is_empty(): return false
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    if runtime.has("runtime_supported") and not bool(runtime.get("runtime_supported", true)): return false
    var key: String = "metronome_eligible" if metronome else "copycat_eligible"
    return not (runtime.has(key) and not bool(runtime.get(key, true)))

func _cleffa_random_metronome_move() -> String:
    var candidates: Array[String] = []
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary): return ""
    for move_id_value: Variant in (moves_value as Dictionary).keys():
        var move_id := str(move_id_value)
        if _cleffa_call_move_is_eligible(move_id, true): candidates.append(move_id)
    return "" if candidates.is_empty() else candidates.pick_random()

func _cleffa_positive_attribute_count(actor: Dictionary) -> int:
    var count := 0
    if _combined_timed_modifier(actor, "outgoing_damage_mod") > 1.0001: count += 1
    if _combined_timed_modifier(actor, "incoming_damage_mod") > 1.0001: count += 1
    if _combined_timed_modifier(actor, "accuracy_mod") > 1.0001: count += 1
    if _combined_timed_modifier(actor, "atb_cycle_mod") < 0.9999: count += 1
    if float(actor.get("db_status_effectiveness_mult", 1.0)) > 1.0001: count += 1
    return mini(5, count)

func _cleffa_apply_timed_modifier(source: Dictionary, target: Dictionary, kind: String, signed_weight: float, label: String) -> float:
    var mechanic := {"multiplier_from_special": signed_weight}
    var multiplier: float = _status_modifier_multiplier(source, mechanic, kind, false, false)
    _add_timed_modifier(target, kind, multiplier, label, _actor_name(source))
    return _status_effect_aggro(kind, multiplier)

func _cleffa_first_damaged_target(targets: Array, hp_before: Dictionary) -> Dictionary:
    for target_value: Variant in targets:
        if target_value is Dictionary:
            var target: Dictionary = target_value
            var target_id := str(target.get("id", ""))
            if int(target.get("hp", 0)) < int(hp_before.get(target_id, int(target.get("hp", 0)))): return target
    return {}

func _cleffa_reset_other_allied_aggro(actor: Dictionary) -> void:
    for ally_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if ally_value is Dictionary:
            var ally: Dictionary = ally_value
            if str(ally.get("id", "")) != str(actor.get("id", "")) and bool(ally.get("alive", false)): ally["aggro"] = 0.0
    _spawn_feedback_label(actor, "🙋 AGGRO ÜBERNOMMEN", Color("f3d7ef"))

func _cleffa_life_dew(actor: Dictionary) -> void:
    var ratio := 0.5 * _status_ratio(float(actor.get("special", 0.0)))
    var total_heal := 0
    for ally_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (ally_value is Dictionary): continue
        var ally: Dictionary = ally_value
        if not bool(ally.get("alive", false)): continue
        var missing := maxi(0, int(ally.get("max_hp", 1)) - int(ally.get("hp", 0)))
        if missing <= 0: continue
        var amount := mini(missing, maxi(1, int(floor(float(ally.get("max_hp", 1)) * ratio))))
        ally["hp"] = int(ally.get("hp", 0)) + amount
        total_heal += amount
        _spawn_feedback_label(ally, "💧 +" + str(amount) + " KP", Color("9ce5e8"))
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(total_heal)

func _cleffa_moonlight(actor: Dictionary) -> void:
    var ratio := _status_ratio(float(actor.get("special", 0.0)))
    var weather_id := str(battle_weather.snapshot().get("weather_id", ""))
    var weather_mult := 4.0 / 3.0 if weather_id == "sun" else (0.5 if weather_id in ["rain", "sandstorm", "snow"] else 1.0)
    var missing := maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    if missing <= 0: return
    var amount := mini(missing, maxi(1, int(floor(float(actor.get("max_hp", 1)) * ratio * weather_mult))))
    actor["hp"] = int(actor.get("hp", 0)) + amount
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(amount)
    _spawn_feedback_label(actor, "🌙 +" + str(amount) + " KP", Color("e4d7ff"))

func _cleffa_activate_gravity(actor: Dictionary) -> void:
    _cleffa_gravity = {"source_id":str(actor.get("id", "")),"expires_after_action":int(actor.get("action_serial",0))+3,"accuracy_multiplier":1.0+_status_ratio(float(actor.get("special",0.0)))}
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            if str(candidate.get("db_charge_move", "")) in ["fly", "bounce"]:
                candidate["db_charge_move"] = ""
                candidate["db_charge_target_id"] = ""
    _spawn_feedback_label(actor, "🌍 ERDANZIEHUNG · 3 AKTIONEN", Color("d2c1a5"))

func _cleffa_activate_misty_terrain(actor: Dictionary) -> void:
    _cleffa_misty_terrain = {"source_id":str(actor.get("id", "")),"expires_after_action":int(actor.get("action_serial",0))+3,"dragon_reduction":_status_ratio(float(actor.get("special",0.0)))}
    _bulba_grassy_terrain = {}
    _spawn_feedback_label(actor, "🌫️ NEBELFELD · 3 AKTIONEN", Color("e5d5ef"))

func _cleffa_wake_all_sleepers() -> void:
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            if str(candidate.get("major_status", "")) == "sleep":
                candidate["major_status"] = ""
                candidate["db_sleep_actions"] = 0
                _spawn_feedback_label(candidate, "📣 AUFGEWACHT", Color("f2cc8f"))

func _cleffa_swap_aggro(actor: Dictionary, ally: Dictionary) -> void:
    if str(actor.get("id", "")) == str(ally.get("id", "")): return
    var actor_aggro := float(actor.get("aggro", 0.0))
    actor["aggro"] = float(ally.get("aggro", 0.0))
    ally["aggro"] = actor_aggro
    _spawn_feedback_label(actor, "🔄 AGGRO GETAUSCHT", Color("c9d7ff"))

func _cleffa_activate_imprison(actor: Dictionary) -> void:
    actor["cleffa_imprison_active"] = true
    var common_count := 0
    var own_moves_value: Variant = actor.get("moves", [])
    var own_moves: Array = own_moves_value if own_moves_value is Array else []
    for opponent_value: Variant in _living_opponents(actor):
        if not (opponent_value is Dictionary): continue
        var opponent: Dictionary = opponent_value
        var opponent_moves_value: Variant = opponent.get("moves", [])
        if not (opponent_moves_value is Array): continue
        var blocked_for_target := 0
        for move_value: Variant in opponent_moves_value:
            if own_moves.has(str(move_value)): blocked_for_target += 1
        common_count += blocked_for_target
        actor["aggro"] = float(actor.get("aggro", 0.0)) + float(opponent.get("max_hp", 1)) * 0.04 * float(blocked_for_target)
    if common_count > 0: _spawn_feedback_label(actor, "🚫 " + str(common_count) + " ATTACKEN BLOCKIERT", Color("edc2c2"))

func _cleffa_psych_up(actor: Dictionary, target: Dictionary) -> float:
    var allowed: Array[String] = ["outgoing_damage_mod","incoming_damage_mod","accuracy_mod","atb_cycle_mod"]
    var kept: Array = []
    var actor_mods_value: Variant = actor.get("timed_modifiers", [])
    if actor_mods_value is Array:
        for mod_value: Variant in actor_mods_value:
            if mod_value is Dictionary and not allowed.has(str((mod_value as Dictionary).get("kind", ""))): kept.append((mod_value as Dictionary).duplicate(true))
    var aggro_gain := 0.0
    var target_mods_value: Variant = target.get("timed_modifiers", [])
    if target_mods_value is Array:
        for mod_value: Variant in target_mods_value:
            if not (mod_value is Dictionary): continue
            var mod: Dictionary = mod_value
            var kind := str(mod.get("kind", ""))
            if not allowed.has(kind): continue
            var remaining := maxi(0, int(mod.get("expires_after_action", 0)) - int(target.get("action_serial", 0)))
            if remaining <= 0: continue
            var copy: Dictionary = mod.duplicate(true)
            copy["expires_after_action"] = int(actor.get("action_serial", 0)) + remaining
            copy["source_move"] = "Psycho-Plus"
            copy["source_actor"] = _actor_name(actor)
            kept.append(copy)
            aggro_gain += _status_effect_aggro(kind, float(copy.get("multiplier", 1.0)))
    actor["timed_modifiers"] = kept
    return aggro_gain

func _cleffa_schedule_future_sight(actor: Dictionary, target: Dictionary) -> void:
    var target_side := str(target.get("side", ""))
    var target_team: Array = _team_for_side(target_side)
    var slot := target_team.find(target)
    if slot < 0: return
    for event_value: Variant in _cleffa_future_sight_events:
        if event_value is Dictionary:
            var event: Dictionary = event_value
            if str(event.get("source_side", "")) == str(actor.get("side", "")) and str(event.get("target_side", "")) == target_side and int(event.get("slot", -1)) == slot:
                _spawn_feedback_label(actor, "👁️ POSITION BEREITS BELEGT", Color("d9a5a5")); return
    var speed := maxf(0.0, float(actor.get("speed", 10.0)))
    if bool(actor.get("paralyzed", false)): speed *= 0.5
    var ap1_cycle := _ap_cycle(1) * _combined_timed_modifier(actor, "atb_cycle_mod")
    var delay := 2.0 * 100.0 / maxf(0.01, (12.0 + speed * 0.62) / maxf(0.01, ap1_cycle))
    _cleffa_future_sight_events.append({"source_id":str(actor.get("id","")),"source_side":str(actor.get("side","")),"target_side":target_side,"slot":slot,"remaining":delay,"snapshot_actor":actor.duplicate(true)})
    _spawn_feedback_label(actor, "👁️ SEHER VORBEREITET", Color("d2c7ff"))

func _cleffa_resolve_future_sight(event: Dictionary) -> void:
    var target_team: Array = _team_for_side(str(event.get("target_side", "")))
    var slot := int(event.get("slot", -1))
    if slot < 0 or slot >= target_team.size(): return
    var target_value: Variant = target_team[slot]
    if not (target_value is Dictionary): return
    var target: Dictionary = target_value
    if not bool(target.get("alive", false)): return
    var snapshot_value: Variant = event.get("snapshot_actor", {})
    if not (snapshot_value is Dictionary): return
    var old_active := _cleffa_active_move_id
    _cleffa_active_move_id = "future_sight"
    var damage := _damage(snapshot_value as Dictionary, target, 120, "psychic", "special")
    _cleffa_active_move_id = old_active
    if damage <= 0: return
    damage = mini(damage, int(target.get("hp", 0)))
    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
    target["aggro"] = float(target.get("aggro", 0.0)) * 0.5
    if int(target.get("hp", 0)) <= 0: target["alive"] = false
    var source := _cleffa_find_combatant(str(event.get("source_id", "")))
    if not source.is_empty(): source["aggro"] = float(source.get("aggro", 0.0)) + float(damage)
    _spawn_feedback_label(target, "👁️ −" + str(damage) + " KP", Color("d2c7ff"))
    _refresh_cards(); _check_end()

func _cleffa_apply_night_shade(actor: Dictionary, target: Dictionary) -> void:
    if is_zero_approx(TypeSystem.get_multiplier("ghost", _type_array(target.get("types", [])))):
        _spawn_feedback_label(target, "🛡️ IMMUN", Color("b8d9ff")); return
    var damage := mini(maxi(1, int(actor.get("level", 1))), int(target.get("hp", 0)))
    if damage <= 0: return
    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
    target["aggro"] = float(target.get("aggro", 0.0)) * 0.5
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(damage)
    if int(target.get("hp", 0)) <= 0: target["alive"] = false
    _spawn_feedback_label(target, "🌑 −" + str(damage) + " KP", Color("bcb0d8"))
