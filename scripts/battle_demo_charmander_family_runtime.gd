extends "res://scripts/battle_demo_charmander_family_core.gd"

func _execute_move(actor: Dictionary, move_id: String) -> void:
    var original: Dictionary = _move_data(move_id)
    if original.is_empty():
        super._execute_move(actor, move_id)
        return

    var temp: Dictionary = original.duplicate(true)
    var runtime_value: Variant = temp.get("runtime", {})
    var runtime: Dictionary = runtime_value.duplicate(true) if runtime_value is Dictionary else {}

    var was_charged_shot: bool = str(actor.get("db_charge_move", "")) == move_id
    var charge_state: String = str(runtime.get("timeflow_charge_state", ""))

    if _cf_should_force_semi_invulnerable_miss(actor, temp, move_id, runtime, was_charged_shot):
        # Halb-Unverwundbarkeit ist ein echtes Verfehlen: Damit greifen die
        # zentrale Miss-Recovery und Folgeattacken wie Frustflamme korrekt.
        temp["accuracy"] = 0.0
        runtime.erase("always_hit")
        temp["runtime"] = runtime
    var pledge_type: String = _cf_pledge_type(temp)
    var pledge_combo: String = ""
    var pledge_pending: Dictionary = {}

    if move_id == "temper_flare" and CF_TEMPER_FLARE_BOOST_OUTCOMES.has(str(actor.get("tf_last_move_outcome", ""))):
        temp["power"] = 150

    if move_id == "heat_crash":
        var heat_targets: Array = _targets(actor, str(temp.get("target", "enemy_highest_aggro")))
        if not heat_targets.is_empty() and heat_targets[0] is Dictionary:
            var heat_target: Dictionary = heat_targets[0]
            temp["power"] = _cf_heat_crash_power_for_combatants(actor, heat_target)
            if _tf_has_state(heat_target, "minimized"):
                temp["power"] = int(temp.get("power", 40)) * 2
                temp["accuracy"] = null

    if move_id == "scorching_sands":
        _cf_thaw(actor, "🔥 TAUT AUF")

    if not pledge_type.is_empty():
        pledge_pending = _cf_pending_pledge(str(actor.get("side", "")))
        pledge_combo = _cf_pledge_combo_for(actor, pledge_type, pledge_pending)
        if not pledge_combo.is_empty():
            temp["power"] = 150
        # The final family layer owns the approved Pledge translation.
        runtime.erase("bulba_pledge")
        runtime.erase("timeflow_pledge")
        temp["runtime"] = runtime

    if was_charged_shot and not charge_state.is_empty():
        _tf_set_state(actor, charge_state, false)
        _cf_set_sprite_visible(actor, true)

    data["moves"][move_id] = temp
    _cf_active_move_id = move_id
    _cf_spread_move_id = move_id

    var snapshots: Dictionary = _tf_snapshot_targets(actor, temp)
    super._execute_move(actor, move_id)
    var move_attempted: bool = _database_move_was_attempted(move_id)
    var hit_success: bool = _tf_any_target_hit(snapshots)

    if bool(runtime.get("charge_then_fire", false)) and not was_charged_shot:
        if str(actor.get("db_charge_move", "")) == move_id:
            if not charge_state.is_empty():
                _tf_set_state(actor, charge_state, true)
                _cf_set_sprite_visible(actor, false)
            if bool(runtime.get("timeflow_focus_punch", false)):
                actor["cf_focus_punch_active"] = true
                _spawn_feedback_label(actor, "🥊 FOKUS", Color("f1d88d"))

    if was_charged_shot and bool(runtime.get("timeflow_focus_punch", false)):
        actor["cf_focus_punch_active"] = false

    if hit_success:
        _cf_apply_post_hit_runtime(actor, temp, runtime, snapshots)

    if move_id == "scorching_sands" and hit_success:
        _cf_finish_scorching_sands(actor, snapshots)

    if not pledge_type.is_empty():
        if not pledge_combo.is_empty():
            if hit_success:
                _cf_apply_pledge_combo(actor, pledge_combo)
            _cf_set_pending_pledge(str(actor.get("side", "")), {})
        elif move_attempted and hit_success:
            _cf_set_pending_pledge(
                str(actor.get("side", "")),
                {"pledge": pledge_type, "actor_id": str(actor.get("id", ""))}
            )
        else:
            _cf_set_pending_pledge(str(actor.get("side", "")), {})
    else:
        _cf_set_pending_pledge(str(actor.get("side", "")), {})

    if bool(runtime.get("timeflow_dragon_cheer", false)) and move_attempted:
        if not _cf_apply_dragon_cheer(actor):
            actor["tf_last_move_outcome"] = "failed"
            _spawn_feedback_label(actor, "✖ KEIN GÜLTIGES ZIEL", Color("d9a5a5"))

    if move_id == "sandstorm" and battle_weather.current_id() == "sandstorm":
        _cf_sandstorm_next_pulse = CF_SANDSTORM_PULSE_SECONDS

    data["moves"][move_id] = original
    _cf_active_move_id = ""
    _cf_spread_move_id = ""
    _refresh_cards()


func _cf_apply_post_hit_runtime(
    actor: Dictionary,
    move: Dictionary,
    runtime: Dictionary,
    snapshots: Dictionary
) -> void:
    if runtime.has("timeflow_self_attack_buff_chance"):
        var chance: float = _cf_effect_chance(
            actor,
            float(runtime.get("timeflow_self_attack_buff_chance", 0.0))
        )
        if randf() <= chance:
            _cf_apply_self_modifier(
                actor,
                "outgoing_damage_mod",
                absf(float(runtime.get("timeflow_self_attack_buff_weight", 1.0))),
                str(move.get("type", "normal")),
                str(move.get("name", "Attacke"))
            )
            _spawn_feedback_label(actor, "ANGRIFF ↑ · 3 AKTIONEN", Color("b9e2a8"))

    if bool(runtime.get("timeflow_self_speed_buff_on_hit", false)):
        _cf_apply_self_modifier(
            actor,
            "atb_cycle_mod",
            -absf(float(runtime.get("timeflow_self_speed_buff_weight", 1.0))),
            str(move.get("type", "normal")),
            str(move.get("name", "Attacke"))
        )
        _spawn_feedback_label(actor, "GESCHWINDIGKEIT ↑ · 3 AKTIONEN", Color("b9e2a8"))

    if bool(runtime.get("timeflow_atb_pause_on_hit", false)):
        var target: Dictionary = _tf_first_target_from_snapshot(snapshots)
        var entry: Dictionary = _cf_snapshot_entry_for_target(snapshots, target)
        if not target.is_empty() and int(entry.get("substitute_hp", 0)) <= 0:
            var pause_aggro: float = _tf_apply_atb_pause(actor, target)
            actor["aggro"] = float(actor.get("aggro", 0.0)) + pause_aggro

    if bool(runtime.get("timeflow_break_team_barriers_on_hit", false)):
        var barrier_target: Dictionary = _tf_first_target_from_snapshot(snapshots)
        if not barrier_target.is_empty():
            _cf_break_team_barriers(str(barrier_target.get("side", "")))

    if runtime.has("timeflow_self_attack_debuff_on_hit"):
        _cf_apply_self_modifier(
            actor,
            "outgoing_damage_mod",
            float(runtime.get("timeflow_self_attack_debuff_on_hit", -2.0)),
            str(move.get("type", "normal")),
            str(move.get("name", "Attacke"))
        )
        _spawn_feedback_label(actor, "ANGRIFF ↓ · 3 AKTIONEN", Color("d9b0a4"))


func _cf_apply_self_modifier(
    actor: Dictionary,
    kind: String,
    signed_weight: float,
    move_type: String,
    source_move: String
) -> void:
    var multiplier: float = _cf_status_modifier_for_type(
        actor, kind, signed_weight, move_type
    )
    _bulba_refresh_timed_modifier(actor, kind, multiplier, source_move, _actor_name(actor))
    actor["aggro"] = float(actor.get("aggro", 0.0)) + _status_effect_aggro(kind, multiplier)


func _cf_status_modifier_for_type(
    actor: Dictionary,
    kind: String,
    signed_weight: float,
    move_type: String
) -> float:
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var type_bonus: float = TypeSystem.get_same_type_status_multiplier(
        move_type, _type_array(actor.get("types", []))
    )
    var scaled: float = absf(signed_weight) * ratio * type_bonus
    match kind:
        "outgoing_damage_mod":
            return 1.0 + scaled if signed_weight >= 0.0 else 1.0 / (1.0 + scaled)
        "incoming_damage_mod":
            return 1.0 / (1.0 + scaled) if signed_weight >= 0.0 else 1.0 + scaled
        "accuracy_mod":
            return 1.0 + scaled if signed_weight >= 0.0 else 1.0 / (1.0 + scaled)
        "atb_cycle_mod":
            return 1.0 + scaled if signed_weight >= 0.0 else 1.0 / (1.0 + scaled)
    return 1.0


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if not _cf_target_reachable_by_move(target, _cf_current_move_id()):
        return 0.0

    var adjusted: Dictionary = mechanic
    if mechanic.has("chance"):
        var base_chance: float = float(mechanic.get("chance", 1.0))
        if base_chance > 0.0 and base_chance < 1.0:
            adjusted = mechanic.duplicate(true)
            adjusted["chance"] = _cf_effect_chance(actor, base_chance)
    return super._effect(actor, target, adjusted)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var move_id: String = _cf_current_move_id()
    if not _cf_target_reachable_by_move(target, move_id):
        return 0

    var effective_power: int = power
    if _tf_has_state(target, "airborne_fly") and CF_FLY_DOUBLE_HIT_MOVES.has(move_id):
        effective_power *= 2

    var original_attack: Variant = actor.get("attack", 0)
    var original_defense: Variant = target.get("defense", 1)
    var fling_override: bool = move_id == "fling"
    var sandstorm_rock_defense: bool = (
        battle_weather.current_id() == "sandstorm"
        and _type_array(target.get("types", [])).has("rock")
    )

    if fling_override:
        actor["attack"] = float(actor.get("special", actor.get("attack", 0)))
    if sandstorm_rock_defense:
        target["defense"] = float(target.get("defense", 1.0)) * 1.5

    var hp_before: int = int(target.get("hp", 0))
    var damage: int = super._damage(actor, target, effective_power, move_type, category)

    actor["attack"] = original_attack
    target["defense"] = original_defense

    if (
        damage > 0
        and bool(target.get("cf_focus_punch_active", false))
        and str(actor.get("side", "")) != str(target.get("side", ""))
        and str(actor.get("id", "")) != str(target.get("id", ""))
        and not move_id.is_empty()
    ):
        call_deferred("_cf_finalize_focus_interrupt", target, hp_before)

    return damage


func _cf_finalize_focus_interrupt(target: Dictionary, hp_before: int) -> void:
    if not bool(target.get("cf_focus_punch_active", false)):
        return
    if int(target.get("hp", 0)) >= hp_before:
        return
    if str(target.get("db_charge_move", "")) != "focus_punch":
        target["cf_focus_punch_active"] = false
        return

    target["db_charge_move"] = ""
    target["db_charge_target_id"] = ""
    target["db_charge_firing"] = false
    target["cf_focus_punch_active"] = false
    target["tf_last_move_outcome"] = "failed"
    _spawn_feedback_label(target, "💥 FOKUS VERLOREN", Color("d9a5a5"))
    _set_log(_actor_name(target) + " verliert den Fokus für Power-Punch.")
    _refresh_cards()


func _cf_should_force_semi_invulnerable_miss(
    actor: Dictionary,
    move: Dictionary,
    move_id: String,
    runtime: Dictionary,
    was_charged_shot: bool
) -> bool:
    # The preparation action of a two-action move is allowed even if its locked
    # target is currently hidden. Reachability matters when the attack fires.
    if bool(runtime.get("charge_then_fire", false)) and not was_charged_shot:
        return false

    var targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    var has_living_target: bool = false
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if not bool(target.get("alive", false)):
            continue
        has_living_target = true
        if _cf_target_reachable_by_move(target, move_id):
            return false
    return has_living_target


func _cf_target_reachable_by_move(target: Dictionary, move_id: String) -> bool:
    if _tf_has_state(target, "underground"):
        return move_id == "earthquake"
    if _tf_has_state(target, "airborne_fly"):
        return CF_FLY_ALLOWED_MOVES.has(move_id)
    return true


func _cf_current_move_id() -> String:
    if not _cf_active_move_id.is_empty():
        return _cf_active_move_id
    if not str(_database_move_id).is_empty():
        return str(_database_move_id)
    return ""


func _timeflow_spread_damage_scale(target_count: int) -> float:
    if _cf_spread_move_id == "swift" or _cf_current_move_id() == "swift":
        return 1.0
    return super._timeflow_spread_damage_scale(target_count)


func _cf_set_sprite_visible(combatant: Dictionary, visible: bool) -> void:
    var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
    if not (ui_value is Dictionary):
        return
    var sprite: TextureRect = (ui_value as Dictionary).get("texture") as TextureRect
    if sprite != null:
        sprite.visible = visible


func _cf_break_team_barriers(side: String) -> void:
    if side.is_empty():
        return
    var removed: bool = false
    for candidate_value: Variant in _team_for_side(side):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value

        if not str(candidate.get("db_light_screen_source_id", "")).is_empty():
            removed = true
        candidate["db_light_screen_reduction"] = 0.0
        candidate["db_light_screen_source_id"] = ""
        candidate["db_light_screen_expires_source_action"] = 0

        for prefix: String in ["db_reflect", "db_aurora_veil"]:
            var source_key: String = prefix + "_source_id"
            var expires_key: String = prefix + "_expires_source_action"
            var reduction_key: String = prefix + "_reduction"
            if not str(candidate.get(source_key, "")).is_empty():
                removed = true
            candidate[source_key] = ""
            candidate[expires_key] = 0
            candidate[reduction_key] = 0.0

    if removed:
        _spawn_feedback_label(
            _cf_first_living_on_side(side),
            "🧱 BARRIERE ZERBROCHEN",
            Color("f1d88d")
        )


func _cf_first_living_on_side(side: String) -> Dictionary:
    for candidate_value: Variant in _team_for_side(side):
        if candidate_value is Dictionary and bool((candidate_value as Dictionary).get("alive", false)):
            return candidate_value as Dictionary
    return {}


func _cf_finish_scorching_sands(actor: Dictionary, snapshots: Dictionary) -> void:
    for entry_value: Variant in snapshots.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var target_value: Variant = entry.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var hp_hit: bool = int(target.get("hp", 0)) < int(entry.get("hp", 0))
        var substitute_hit: bool = int(target.get("db_substitute_hp", 0)) < int(entry.get("substitute_hp", 0))
        if not hp_hit and not substitute_hit:
            continue
        if int(entry.get("substitute_hp", 0)) > 0:
            continue

        _cf_thaw(target, "🔥 TAUT AUF")
        _effect(actor, target, {"kind":"status", "status":"burn", "chance":0.30})


func _cf_thaw(combatant: Dictionary, feedback: String) -> bool:
    if str(combatant.get("major_status", "")) != "freeze":
        return false
    combatant["major_status"] = ""
    _spawn_feedback_label(combatant, feedback, Color("f5d58b"))
    return true


func _cf_effect_chance(actor: Dictionary, base_chance: float) -> float:
    var chance: float = clampf(base_chance, 0.0, 1.0)
    if int(actor.get("cf_rainbow_actions", 0)) > 0:
        chance = minf(1.0, chance * 2.0)
    return chance


func _cf_snapshot_entry_for_target(snapshots: Dictionary, target: Dictionary) -> Dictionary:
    if target.is_empty():
        return {}
    var value: Variant = snapshots.get(str(target.get("id", "")), {})
    return value if value is Dictionary else {}


func _cf_weight_kg(combatant: Dictionary) -> float:
    return maxf(0.0, float(_cf_weights_kg.get(str(combatant.get("species_id", "")), 0.0)))


func _cf_heat_crash_power_for_combatants(actor: Dictionary, target: Dictionary) -> int:
    return _cf_heat_crash_power(_cf_weight_kg(actor), _cf_weight_kg(target))


func _cf_heat_crash_power(attacker_weight: float, target_weight: float) -> int:
    if attacker_weight <= 0.0 or target_weight <= 0.0:
        return 40
    var ratio: float = target_weight / attacker_weight
    if ratio <= 0.20:
        return 120
    if ratio <= 0.25:
        return 100
    if ratio <= (1.0 / 3.0):
        return 80
    if ratio <= 0.50:
        return 60
    return 40
