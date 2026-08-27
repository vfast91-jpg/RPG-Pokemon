extends "res://scripts/battle_demo_attack_text_final.gd"

# Pichu/Pikachu/Raichu Gate-2 runtime bridge.
# All mechanics are generic Timeflow mechanics; the species only reference them
# through move data. This layer also enforces the global Runde-0 AP-8 rule.

const PIKA_VOLT_SWITCH_AGGRO_MULTIPLIER: float = 0.0
const PIKA_VOLT_SWITCH_NEXT_CYCLE_MULTIPLIER: float = 0.70
const PIKA_TERRAIN_MAX_BONUS: float = 0.30
const PIKA_REFLECT_MAX_REDUCTION: float = 0.50

var _pika_terrain_id: String = ""
var _pika_terrain_strength: float = 0.0
var _pika_terrain_source_id: String = ""
var _pika_terrain_expires_source_action: int = 0


func _load_data() -> void:
    super._load_data()
    _pika_enforce_opening_ap8()


func _start_battle() -> void:
    _pika_reset_battlefield_state()
    super._start_battle()


func open_config() -> void:
    _pika_reset_battlefield_state()
    super.open_config()


func _pika_reset_battlefield_state() -> void:
    _pika_terrain_id = ""
    _pika_terrain_strength = 0.0
    _pika_terrain_source_id = ""
    _pika_terrain_expires_source_action = 0


func _pika_enforce_opening_ap8() -> void:
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
        var is_opening: bool = bool(move.get("opening", false)) or bool(move.get("opening_phase", false))
        if is_opening and int(move.get("priority", move.get("priority_reference", 0))) > 0:
            move["ap"] = 8
            move["rpg_ap"] = 8
            moves[move_id] = move
    data["moves"] = moves


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["pika_reflect_reduction"] = 0.0
    combatant["pika_reflect_source_id"] = ""
    combatant["pika_reflect_expires_source_action"] = 0
    combatant["pika_electric_charged"] = false
    combatant["pika_charge_guard_reduction"] = 0.0
    combatant["pika_charge_guard_expires_action"] = 0
    combatant["pika_last_successful_repeatable_move"] = ""
    combatant["pika_attribute_raised_since_own_action"] = false
    combatant["pika_current_move_failed"] = false
    combatant["pika_opening_cancelled"] = false
    combatant["pika_opening_resolved"] = false
    return combatant


func _begin_counted_action(actor: Dictionary) -> void:
    actor["pika_attribute_raised_since_own_action"] = false
    super._begin_counted_action(actor)


func _add_timed_modifier(
    target: Dictionary,
    kind: String,
    multiplier: float,
    source_move: String,
    source_actor: String
) -> void:
    super._add_timed_modifier(target, kind, multiplier, source_move, source_actor)
    var raised: bool = false
    match kind:
        "outgoing_damage_mod":
            raised = multiplier > 1.0001
        "incoming_damage_mod":
            raised = multiplier > 1.0001
        "accuracy_mod":
            raised = multiplier > 1.0001
        "atb_cycle_mod":
            raised = multiplier < 0.9999
    if raised:
        target["pika_attribute_raised_since_own_action"] = true


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var original: Dictionary = _move_data(move_id)
    if original.is_empty():
        super._execute_move(actor, move_id)
        return

    actor["pika_current_move_failed"] = false
    var temp: Dictionary = original.duplicate(true)
    var runtime_value: Variant = temp.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if bool(runtime.get("timeflow_effective_speed_power", false)):
        var targets: Array = _targets(actor, str(temp.get("target", "enemy_highest_aggro")))
        if not targets.is_empty() and targets[0] is Dictionary:
            temp["power"] = _pika_electro_ball_power(actor, targets[0])

    if bool(runtime.get("timeflow_hp_ratio_power", false)):
        temp["power"] = _pika_reversal_power(actor)

    data["moves"][move_id] = temp
    var snapshots: Dictionary = _pika_target_snapshots(actor, temp)
    var charged_electric: bool = (
        bool(actor.get("pika_electric_charged", false))
        and str(temp.get("type", "")) == "electric"
        and str(temp.get("category", "")) != "status"
        and _pika_move_has_damage(temp)
    )

    super._execute_move(actor, move_id)

    var attempted: bool = _database_move_was_attempted(move_id)
    var hit_success: bool = _pika_any_target_hit(snapshots)

    if charged_electric and attempted:
        actor["pika_electric_charged"] = false
        _spawn_feedback_label(actor, "🔋 LADUNG VERBRAUCHT", Color("f0dc76"))

    if bool(runtime.get("timeflow_volt_switch_retreat", false)) and hit_success:
        actor["aggro"] = float(actor.get("aggro", 0.0)) * PIKA_VOLT_SWITCH_AGGRO_MULTIPLIER
        actor["cycle"] = float(actor.get("cycle", 1.0)) * PIKA_VOLT_SWITCH_NEXT_CYCLE_MULTIPLIER
        _spawn_feedback_label(actor, "⚡ RÜCKZUG", Color("a9d8ff"))

    if bool(runtime.get("timeflow_alluring_voice", false)) and hit_success:
        for entry_value: Variant in snapshots.values():
            if not (entry_value is Dictionary):
                continue
            var entry: Dictionary = entry_value
            var target_value: Variant = entry.get("target", {})
            if not (target_value is Dictionary):
                continue
            var target: Dictionary = target_value
            if bool(target.get("pika_attribute_raised_since_own_action", false)) and _pika_snapshot_target_hit(entry):
                _effect(actor, target, {"kind":"status", "status":"confusion", "chance":1.0})

    if bool(runtime.get("timeflow_break_team_barriers_on_hit", false)) and hit_success:
        var first_target: Dictionary = _pika_first_snapshot_target(snapshots)
        if not first_target.is_empty():
            _pika_break_team_barriers(str(first_target.get("side", "")))

    if attempted and _pika_move_was_successful(actor, temp, hit_success):
        if _pika_move_repeatable(temp):
            actor["pika_last_successful_repeatable_move"] = move_id

    data["moves"][move_id] = original
    _refresh_cards()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    if kind == "status" or kind == "db_status":
        var status_id: String = str(mechanic.get("status", ""))
        if status_id == "sleep" and _pika_electric_terrain_active() and _pika_is_grounded(target):
            _spawn_feedback_label(target, "⚡ SCHLAF BLOCKIERT", Color("f1dc75"))
            return 0.0

    match kind:
        "db_reflect":
            var reduction: float = clampf(float(actor.get("special", 0.0)) / 100.0, 0.0, PIKA_REFLECT_MAX_REDUCTION)
            target["pika_reflect_reduction"] = reduction
            target["pika_reflect_source_id"] = str(actor.get("id", ""))
            target["pika_reflect_expires_source_action"] = (
                int(actor.get("action_serial", 0))
                + maxi(1, int(mechanic.get("duration_actions", 3)))
            )
            return reduction * 10.0

        "db_encore":
            var last_move_id: String = str(target.get("pika_last_successful_repeatable_move", ""))
            var last_move: Dictionary = _move_data(last_move_id)
            if last_move_id.is_empty() or last_move.is_empty() or not _pika_move_repeatable(last_move):
                actor["pika_current_move_failed"] = true
                _spawn_feedback_label(target, "✖ KEINE ZUGABE", Color("d9a5a5"))
                return 0.0
            target["db_forced_move_id"] = last_move_id
            target["db_forced_actions_left"] = maxi(1, int(mechanic.get("duration_actions", 3)))
            _spawn_feedback_label(target, "👏 ZUGABE · 3 AKTIONEN", Color("e5c6ff"))
            return 8.0

        "db_electric_terrain":
            _pika_terrain_id = "electric"
            _pika_terrain_strength = clampf(float(actor.get("special", 0.0)) / 100.0, 0.0, PIKA_TERRAIN_MAX_BONUS)
            _pika_terrain_source_id = str(actor.get("id", ""))
            _pika_terrain_expires_source_action = (
                int(actor.get("action_serial", 0))
                + maxi(1, int(mechanic.get("duration_actions", 3)))
            )
            _spawn_feedback_label(actor, "⚡ ELEKTROFELD", Color("f1dc75"))
            return _pika_terrain_strength * 10.0

        "db_charge":
            actor["pika_electric_charged"] = true
            actor["pika_charge_guard_reduction"] = _status_ratio(float(actor.get("special", 0.0)))
            actor["pika_charge_guard_expires_action"] = (
                int(actor.get("action_serial", 0))
                + maxi(1, int(mechanic.get("duration_actions", 3)))
            )
            _spawn_feedback_label(actor, "🔋 AUFGELADEN", Color("f1dc75"))
            return float(actor.get("pika_charge_guard_reduction", 0.0)) * 10.0

        "db_break_team_barriers":
            _pika_break_team_barriers(str(target.get("side", "")))
            return 5.0

    return super._effect(actor, target, mechanic)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0:
        return damage

    if (
        move_type == "electric"
        and _pika_electric_terrain_active()
        and _pika_is_grounded(actor)
    ):
        damage = maxi(1, int(round(float(damage) * (1.0 + _pika_terrain_strength))))

    if (
        bool(actor.get("pika_electric_charged", false))
        and move_type == "electric"
        and category != "status"
    ):
        damage *= 2

    if category == "physical" and _pika_reflect_active(target):
        damage = maxi(
            1,
            int(round(float(damage) * (1.0 - clampf(
                float(target.get("pika_reflect_reduction", 0.0)),
                0.0,
                PIKA_REFLECT_MAX_REDUCTION
            ))))
        )

    if category == "special" and _pika_charge_guard_active(target):
        damage = maxi(
            1,
            int(round(float(damage) * (1.0 - clampf(
                float(target.get("pika_charge_guard_reduction", 0.0)),
                0.0,
                0.95
            ))))
        )

    return damage


func _resolve_opening_actions_async() -> void:
    if _opening_choices.is_empty():
        _finish_opening_phase()
        return

    for choice_value: Variant in _opening_choices:
        if not battle_active:
            return
        if not (choice_value is Dictionary):
            continue

        var choice: Dictionary = choice_value
        var actor_value: Variant = choice.get("actor", {})
        if not (actor_value is Dictionary):
            continue
        var actor: Dictionary = actor_value
        if not bool(actor.get("alive", false)):
            continue

        var move_id: String = str(choice.get("move_id", ""))
        if move_id.is_empty():
            continue
        var move: Dictionary = _move_data(move_id)

        if bool(actor.get("pika_opening_cancelled", false)):
            actor["pika_opening_cancelled"] = false
            actor["pika_opening_resolved"] = true
            _begin_counted_action(actor)
            actor["cycle"] = _ap_cycle(8)
            actor["atb"] = 0.0
            _set_log("[b]RUNDE 0[/b] · " + _actor_name(actor) + "s vorbereitete Attacke wurde annulliert.")
            _spawn_feedback_label(actor, "✋ KONTER", Color("e7c89b"))
            await get_tree().create_timer(SHORT_ACTION_FEEDBACK_SECONDS).timeout
            continue

        paused = true
        _set_log(
            "[b]RUNDE 0[/b] · " + _actor_name(actor)
            + " setzt " + str(move.get("name", move_id)) + " ein."
        )

        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        if bool(runtime.get("timeflow_upper_hand", false)):
            var upper_targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
            var upper_target: Dictionary = {}
            if not upper_targets.is_empty() and upper_targets[0] is Dictionary:
                upper_target = upper_targets[0]

            if upper_target.is_empty() or not _pika_has_pending_opening(upper_target):
                _begin_counted_action(actor)
                actor["cycle"] = _ap_cycle(8)
                actor["atb"] = 0.0
                actor["pika_current_move_failed"] = true
                _set_log(_actor_name(actor) + "s [b]Schnellkonter[/b] schlägt fehl.")
                _spawn_feedback_label(actor, "✖ KEIN KONTERZIEL", Color("d9a5a5"))
            else:
                var before: Dictionary = _pika_single_target_snapshot(upper_target)
                _execute_move(actor, move_id)
                if _pika_snapshot_target_hit(before):
                    upper_target["pika_opening_cancelled"] = true
                    _spawn_feedback_label(upper_target, "✋ ANNULLIERT", Color("e7c89b"))
        else:
            _execute_move(actor, move_id)

        actor["pika_opening_resolved"] = true
        await get_tree().create_timer(SHORT_ACTION_FEEDBACK_SECONDS).timeout
        if not battle_active:
            return
        paused = true

    _finish_opening_phase()


func _pika_has_pending_opening(target: Dictionary) -> bool:
    if bool(target.get("pika_opening_resolved", false)) or bool(target.get("pika_opening_cancelled", false)):
        return false
    var target_id: String = str(target.get("id", ""))
    for choice_value: Variant in _opening_choices:
        if not (choice_value is Dictionary):
            continue
        var choice: Dictionary = choice_value
        var actor_value: Variant = choice.get("actor", {})
        if actor_value is Dictionary and str((actor_value as Dictionary).get("id", "")) == target_id:
            return not str(choice.get("move_id", "")).is_empty()
    return false


func _pika_electro_ball_power(actor: Dictionary, target: Dictionary) -> int:
    var actor_rate: float = _pika_effective_speed_rate(actor)
    var target_rate: float = maxf(0.0001, _pika_effective_speed_rate(target))
    var ratio: float = actor_rate / target_rate
    if ratio >= 4.0:
        return 150
    if ratio >= 3.0:
        return 120
    if ratio >= 2.0:
        return 80
    if ratio >= 1.0:
        return 60
    return 40


func _pika_effective_speed_rate(combatant: Dictionary) -> float:
    var effective_speed: float = maxf(0.0, float(combatant.get("speed", 10.0)))
    if bool(combatant.get("paralyzed", false)):
        effective_speed *= 0.5
    var tempo_multiplier: float = maxf(0.0001, _combined_timed_modifier(combatant, "atb_cycle_mod"))
    return _raw_speed_charge_rate(effective_speed) / tempo_multiplier


func _pika_reversal_power(actor: Dictionary) -> int:
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


func _pika_move_has_damage(move: Dictionary) -> bool:
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "damage":
                return true
    return int(move.get("power", 0)) > 0


func _pika_move_repeatable(move: Dictionary) -> bool:
    if move.is_empty():
        return false
    if bool(move.get("opening_only", false)):
        return false
    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary and not bool((runtime_value as Dictionary).get("runtime_supported", true)):
        return false
    return true


func _pika_move_was_successful(actor: Dictionary, move: Dictionary, hit_success: bool) -> bool:
    if bool(actor.get("pika_current_move_failed", false)):
        return false
    if _pika_move_has_damage(move):
        return hit_success
    var outcome: String = str(actor.get("tf_last_move_outcome", ""))
    return not ["miss", "immune", "failed", "blocked"].has(outcome)


func _pika_target_snapshots(actor: Dictionary, move: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for target_value: Variant in _targets(actor, str(move.get("target", "enemy_highest_aggro"))):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        result[str(target.get("id", ""))] = _pika_single_target_snapshot(target)
    return result


func _pika_single_target_snapshot(target: Dictionary) -> Dictionary:
    return {
        "target": target,
        "hp": int(target.get("hp", 0)),
        "substitute_hp": int(target.get("db_substitute_hp", 0))
    }


func _pika_snapshot_target_hit(entry: Dictionary) -> bool:
    var target_value: Variant = entry.get("target", {})
    if not (target_value is Dictionary):
        return false
    var target: Dictionary = target_value
    return (
        int(target.get("hp", 0)) < int(entry.get("hp", 0))
        or int(target.get("db_substitute_hp", 0)) < int(entry.get("substitute_hp", 0))
    )


func _pika_any_target_hit(snapshots: Dictionary) -> bool:
    for entry_value: Variant in snapshots.values():
        if entry_value is Dictionary and _pika_snapshot_target_hit(entry_value):
            return true
    return false


func _pika_first_snapshot_target(snapshots: Dictionary) -> Dictionary:
    for entry_value: Variant in snapshots.values():
        if entry_value is Dictionary:
            var target_value: Variant = (entry_value as Dictionary).get("target", {})
            if target_value is Dictionary:
                return target_value
    return {}


func _pika_reflect_active(target: Dictionary) -> bool:
    var source_id: String = str(target.get("pika_reflect_source_id", ""))
    if source_id.is_empty():
        return false
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if str(candidate.get("id", "")) != source_id:
            continue
        return (
            bool(candidate.get("alive", false))
            and int(candidate.get("action_serial", 0))
                < int(target.get("pika_reflect_expires_source_action", 0))
        )
    return false


func _pika_charge_guard_active(target: Dictionary) -> bool:
    return (
        float(target.get("pika_charge_guard_reduction", 0.0)) > 0.0
        and int(target.get("action_serial", 0))
            < int(target.get("pika_charge_guard_expires_action", 0))
    )


func _pika_electric_terrain_active() -> bool:
    if _pika_terrain_id != "electric" or _pika_terrain_source_id.is_empty():
        return false
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if str(candidate.get("id", "")) != _pika_terrain_source_id:
            continue
        if not bool(candidate.get("alive", false)):
            return false
        return int(candidate.get("action_serial", 0)) < _pika_terrain_expires_source_action
    return false


func _pika_is_grounded(combatant: Dictionary) -> bool:
    return (
        not _pika_has_state(combatant, "airborne_fly")
        and not _pika_has_state(combatant, "airborne_bounce")
    )


func _pika_has_state(combatant: Dictionary, state_id: String) -> bool:
    if has_method("_tf_has_state"):
        return bool(call("_tf_has_state", combatant, state_id))
    return bool(combatant.get("tf_state_" + state_id, false))


func _pika_break_team_barriers(side: String) -> void:
    if side.is_empty():
        return
    for candidate_value: Variant in _team_for_side(side):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        candidate["db_light_screen_reduction"] = 0.0
        candidate["db_light_screen_source_id"] = ""
        candidate["db_light_screen_expires_source_action"] = 0
        candidate["pika_reflect_reduction"] = 0.0
        candidate["pika_reflect_source_id"] = ""
        candidate["pika_reflect_expires_source_action"] = 0
        candidate["db_reflect_reduction"] = 0.0
        candidate["db_reflect_source_id"] = ""
        candidate["db_reflect_expires_source_action"] = 0
        candidate["db_aurora_veil_reduction"] = 0.0
        candidate["db_aurora_veil_source_id"] = ""
        candidate["db_aurora_veil_expires_source_action"] = 0
    _refresh_cards()


func _timeflow_spread_damage_scale(target_count: int) -> float:
    if str(_database_move_id) == "disarming_voice":
        return 1.0
    return super._timeflow_spread_damage_scale(target_count)


func _move_tooltip(move: Dictionary) -> String:
    var text: String = super._move_tooltip(move)
    var move_id: String = str(move.get("id", ""))
    if selected_actor.is_empty():
        return text
    if move_id == "reversal":
        text += "\nAktuelle Stärke: " + str(_pika_reversal_power(selected_actor))
    elif move_id == "electro_ball":
        var targets: Array = _targets(selected_actor, str(move.get("target", "enemy_highest_aggro")))
        if not targets.is_empty() and targets[0] is Dictionary:
            text += "\nAktuelle Stärke gegen Ziel: " + str(_pika_electro_ball_power(selected_actor, targets[0]))
    return text
