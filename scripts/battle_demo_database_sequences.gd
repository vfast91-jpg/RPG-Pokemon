extends "res://scripts/battle_demo_database_core.gd"

# Canonical database action-sequence layer:
# charge/recharge, forced sequences, persistent move state and accuracy bridges.
# Multi-hit attacks are resolved as real, visible hit sequences. The move-level
# accuracy/action gate happens once; damage and explicitly per-hit mechanics are
# then resolved once per hit, including a fresh critical-hit roll.

const DATABASE_MULTI_HIT_FIRST_GAP_SECONDS: float = 0.44
const DATABASE_MULTI_HIT_BETWEEN_GAP_SECONDS: float = 0.12

var _database_multi_hit_serial: int = 0


func _prompt_player(actor: Dictionary) -> void:
    if _database_run_forced_action(actor):
        return
    super._prompt_player(actor)


func _enemy_act(actor: Dictionary) -> void:
    if _database_run_forced_action(actor):
        return
    super._enemy_act(actor)


func _database_run_forced_action(actor: Dictionary) -> bool:
    if bool(actor.get("db_recharge_pending", false)):
        _database_consume_recharge(actor)
        return true
    var charge_move: String = str(actor.get("db_charge_move", ""))
    if not charge_move.is_empty():
        _execute_move(actor, charge_move)
        return true
    var forced_move: String = str(actor.get("db_forced_move_id", ""))
    if not forced_move.is_empty() and int(actor.get("db_forced_actions_left", 0)) > 0:
        _execute_move(actor, forced_move)
        return true
    return false


func _choose_wait() -> void:
    if not selected_actor.is_empty():
        var actor: Dictionary = selected_actor
        actor["db_protect_chain"] = 0
        actor["db_fury_cutter_chain"] = 0
        actor["db_guaranteed_crit"] = false
        actor["db_charge_move"] = ""
        actor["db_charge_target_id"] = ""
        actor["db_charge_firing"] = false
        _database_interrupt_forced_sequence(actor)
        _database_restore_removed_type(actor)
    super._choose_wait()


func _database_consume_recharge(actor: Dictionary) -> void:
    actor["db_recharge_pending"] = false
    _database_restore_removed_type(actor)
    _database_interrupt_forced_sequence(actor)
    actor["db_protect_chain"] = 0
    actor["db_fury_cutter_chain"] = 0
    var fake_id: String = "__database_recharge"
    var runtime_moves: Dictionary = data.get("moves", {})
    var previous_value: Variant = runtime_moves.get(fake_id, null)
    runtime_moves[fake_id] = {"id":fake_id,"name":"Aufladen","description":"Die vorherige Attacke zwingt zu einer Nachladeaktion.","emoji":"⏳","type":"normal","category":"status","power":null,"accuracy":null,"ap":1,"target":"self","area":false,"priority":0,"opening":false,"mechanics":[]}
    data["moves"] = runtime_moves
    super._execute_move(actor, fake_id)
    if previous_value == null:
        runtime_moves.erase(fake_id)
    else:
        runtime_moves[fake_id] = previous_value
    data["moves"] = runtime_moves
    _set_log(_actor_name(actor) + " muss nachladen und kann noch nicht angreifen.")
    _spawn_feedback_label(actor, "⏳ NACHLADEN", Color("f0d78b"))


func _database_consume_sleep_action(actor: Dictionary) -> void:
    var fake_id: String = "__database_sleep"
    var runtime_moves: Dictionary = data.get("moves", {})
    var previous_value: Variant = runtime_moves.get(fake_id, null)
    runtime_moves[fake_id] = {"id":fake_id,"name":"Schlaf","description":"Das Pokémon verschläft diese eigene Aktion.","emoji":"💤","type":"normal","category":"status","power":null,"accuracy":null,"ap":1,"target":"self","area":false,"priority":0,"opening":false,"mechanics":[]}
    data["moves"] = runtime_moves
    super._execute_move(actor, fake_id)
    if previous_value == null:
        runtime_moves.erase(fake_id)
    else:
        runtime_moves[fake_id] = previous_value
    data["moves"] = runtime_moves


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return
    # Any new action invalidates a still-pending hit timer from an older action.
    _database_multi_hit_serial += 1
    _database_restore_removed_type(actor)
    if move_id != "protect":
        actor["db_protect_chain"] = 0
    if str(actor.get("major_status", "")) == "sleep":
        _database_interrupt_forced_sequence(actor)
        var sleep_left: int = int(actor.get("db_sleep_actions", 0))
        if sleep_left > 0:
            _database_consume_sleep_action(actor)
            actor["db_sleep_actions"] = sleep_left - 1
            if sleep_left - 1 <= 0:
                actor["major_status"] = ""
                _set_log(_actor_name(actor) + " wacht auf.")
            else:
                _set_log(_actor_name(actor) + " schläft und kann nicht handeln.")
            _refresh_cards()
            return

    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    if runtime.has("runtime_supported") and not bool(runtime.get("runtime_supported", true)):
        push_error("Nicht ausführbare Datenbank-Attacke wurde ausgewählt: " + move_id)
        return

    var original_move: Dictionary = move.duplicate(true)
    var temp_move: Dictionary = move.duplicate(true)
    var had_guaranteed_crit: bool = bool(actor.get("db_guaranteed_crit", false))
    var was_forced_sequence: bool = (
        str(actor.get("db_forced_move_id", "")) == move_id
        and int(actor.get("db_forced_actions_left", 0)) > 0
    )
    var was_charged_shot: bool = str(actor.get("db_charge_move", "")) == move_id

    if bool(runtime.get("charge_then_fire", false)) and not was_charged_shot and not _database_sun_is_active(runtime):
        var charge_targets: Array = _targets(actor, str(temp_move.get("target", "enemy_highest_aggro")))
        var locked_target_id: String = ""
        if not charge_targets.is_empty() and charge_targets[0] is Dictionary:
            locked_target_id = str((charge_targets[0] as Dictionary).get("id", ""))
        temp_move["mechanics"] = []
        temp_move["power"] = null
        temp_move["accuracy"] = null
        data["moves"][move_id] = temp_move
        _database_active_move = temp_move
        _database_move_id = move_id
        super._execute_move(actor, move_id)
        var charged_successfully: bool = _database_move_was_attempted(move_id)
        data["moves"][move_id] = original_move
        _database_active_move = {}
        _database_move_id = ""
        if charged_successfully:
            actor["db_charge_move"] = move_id
            actor["db_charge_target_id"] = locked_target_id
            actor["db_charge_firing"] = false
            actor["db_last_move"] = move_id
            _spawn_feedback_label(actor, "☀️ LÄDT AUF", Color("f5df8b"))
        if had_guaranteed_crit:
            actor["db_guaranteed_crit"] = false
        return

    actor["db_charge_firing"] = was_charged_shot
    if bool(runtime.get("always_hit", false)):
        temp_move["accuracy"] = null
    if bool(runtime.get("fails_at_full_hp", false)) and int(actor.get("hp", 0)) >= int(actor.get("max_hp", 1)):
        temp_move["mechanics"] = []
        temp_move["power"] = null
    if runtime.has("conditional_power"):
        var spec: Dictionary = runtime.get("conditional_power", {})
        var conditional_targets: Array = _targets(actor, str(temp_move.get("target", "enemy_highest_aggro")))
        if not conditional_targets.is_empty() and conditional_targets[0] is Dictionary:
            var target: Dictionary = conditional_targets[0]
            var statuses_value: Variant = spec.get("status", [])
            if statuses_value is Array and (statuses_value as Array).has(str(target.get("major_status", ""))):
                temp_move["power"] = int(spec.get("power", temp_move.get("power", 0)))
    if runtime.has("consecutive_power_chain"):
        var chain_value: Variant = runtime.get("consecutive_power_chain", [])
        if chain_value is Array and not (chain_value as Array).is_empty():
            var chain_index: int = int(actor.get("db_fury_cutter_chain", 0))
            if str(actor.get("db_last_move", "")) != move_id:
                chain_index = 0
            chain_index = clampi(chain_index, 0, (chain_value as Array).size() - 1)
            temp_move["power"] = int((chain_value as Array)[chain_index])

    # Resolve the hit count once for the whole action. We deliberately do NOT
    # duplicate damage mechanics anymore: follow-up hits are executed as their
    # own timed hit phases below, so every hit has an animation, damage roll and
    # critical-hit roll of its own.
    var multi_hit_count: int = 1
    if runtime.has("multi_hit"):
        var multi_hit_spec: Dictionary = runtime.get("multi_hit", {})
        multi_hit_count = _database_multi_hit_count(multi_hit_spec)

    _database_apply_incoming_accuracy_to_move(actor, temp_move)
    data["moves"][move_id] = temp_move
    _database_active_move = temp_move
    _database_move_id = move_id

    var target_snapshots: Dictionary = {}
    for target_value: Variant in _targets(actor, str(temp_move.get("target", "enemy_highest_aggro"))):
        if target_value is Dictionary:
            var target: Dictionary = target_value
            target_snapshots[str(target.get("id", ""))] = {
                "target": target,
                "hp": int(target.get("hp", 0)),
                "alive": bool(target.get("alive", false))
            }

    super._execute_move(actor, move_id)
    var move_attempted: bool = _database_move_was_attempted(move_id)
    var target_damaged: bool = _database_any_target_damaged(target_snapshots)

    if multi_hit_count > 1 and move_attempted and target_damaged:
        _database_begin_multi_hit_sequence(
            actor,
            move_id,
            temp_move,
            target_snapshots,
            multi_hit_count,
            had_guaranteed_crit
        )

    if runtime.has("consecutive_power_chain"):
        if move_attempted and target_damaged:
            actor["db_fury_cutter_chain"] = mini(2, int(actor.get("db_fury_cutter_chain", 0)) + 1)
        else:
            actor["db_fury_cutter_chain"] = 0
    elif move_id != "fury_cutter":
        actor["db_fury_cutter_chain"] = 0

    if bool(runtime.get("recharge_on_success", false)) and target_damaged:
        actor["db_recharge_pending"] = true
        _spawn_feedback_label(actor, "⏳ NACHLADEN FOLGT", Color("f0d78b"))

    if runtime.has("forced_sequence"):
        var sequence_spec: Dictionary = runtime.get("forced_sequence", {})
        if not was_forced_sequence:
            if move_attempted:
                var total_actions: int = randi_range(
                    maxi(1, int(sequence_spec.get("min", 2))),
                    maxi(1, int(sequence_spec.get("max", 3)))
                )
                actor["db_forced_move_id"] = move_id
                actor["db_forced_actions_left"] = maxi(0, total_actions - 1)
        elif move_attempted:
            actor["db_forced_actions_left"] = maxi(0, int(actor.get("db_forced_actions_left", 0)) - 1)
        else:
            _database_interrupt_forced_sequence(actor)
        if (
            move_attempted
            and str(actor.get("db_forced_move_id", "")) == move_id
            and int(actor.get("db_forced_actions_left", 0)) <= 0
        ):
            actor["db_forced_move_id"] = ""
            if bool(sequence_spec.get("confuse_after", false)) and bool(actor.get("alive", false)):
                actor["confused_turns"] = randi_range(1, 4)
                _spawn_feedback_label(actor, "💫 VERWIRRT", Color("dcb7ff"))

    if had_guaranteed_crit:
        actor["db_guaranteed_crit"] = false
    if was_charged_shot:
        if move_attempted:
            actor["db_charge_move"] = ""
            actor["db_charge_target_id"] = ""
        actor["db_charge_firing"] = false

    _database_trigger_toxic_spikes_if_defined(actor, temp_move, move_attempted)
    actor["db_last_move"] = move_id
    data["moves"][move_id] = original_move
    _database_active_move = {}
    _database_move_id = ""


func _database_begin_multi_hit_sequence(
    actor: Dictionary,
    move_id: String,
    move: Dictionary,
    target_snapshots: Dictionary,
    planned_hits: int,
    guaranteed_crit_for_action: bool
) -> void:
    var active_targets: Array = []
    var first_hit_damage: int = 0

    for snapshot_value: Variant in target_snapshots.values():
        if not (snapshot_value is Dictionary):
            continue
        var snapshot: Dictionary = snapshot_value
        var target_value: Variant = snapshot.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var damage: int = maxi(0, int(snapshot.get("hp", 0)) - int(target.get("hp", 0)))
        if damage <= 0:
            continue
        first_hit_damage += damage
        active_targets.append(target)
        _database_spawn_multi_hit_feedback(target, 1, planned_hits, damage)

    if active_targets.is_empty():
        return

    var state: Dictionary = {
        "serial": _database_multi_hit_serial,
        "actor": actor,
        "move_id": move_id,
        "move": move.duplicate(true),
        "targets": active_targets,
        "planned_hits": planned_hits,
        "next_hit": 2,
        "executed_hits": 1,
        "total_damage": first_hit_damage,
        "guaranteed_crit": guaranteed_crit_for_action
    }

    _database_set_multi_hit_log(state, 1, first_hit_damage, false)
    get_tree().create_timer(DATABASE_MULTI_HIT_FIRST_GAP_SECONDS).timeout.connect(
        _database_launch_multi_hit.bind(state)
    )


func _database_launch_multi_hit(state: Dictionary) -> void:
    if not _database_multi_hit_state_is_valid(state):
        return

    var actor_value: Variant = state.get("actor", {})
    if not (actor_value is Dictionary):
        return
    var actor: Dictionary = actor_value
    var move_value: Variant = state.get("move", {})
    if not (move_value is Dictionary):
        return
    var move: Dictionary = move_value
    var move_id: String = str(state.get("move_id", ""))
    var hit_index: int = int(state.get("next_hit", 2))

    var has_live_target: bool = false
    for target_value: Variant in state.get("targets", []):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if not bool(target.get("alive", false)):
            continue
        has_live_target = true
        # The normal move animation helper intentionally de-duplicates targets.
        # A multi-hit sequence is the one place where the same target must be
        # animated again, so release that visual guard before every new hit.
        _visual_animated_targets.erase(str(target.get("id", "")))
        _animate_move_emoji_once(actor, target, move_id, move)

    if not has_live_target:
        _database_finish_multi_hit_sequence(state)
        return

    get_tree().create_timer(MOVE_EMOJI_TRAVEL_SECONDS).timeout.connect(
        _database_apply_multi_hit.bind(state, hit_index)
    )


func _database_apply_multi_hit(state: Dictionary, hit_index: int) -> void:
    if not _database_multi_hit_state_is_valid(state):
        return

    var actor_value: Variant = state.get("actor", {})
    var move_value: Variant = state.get("move", {})
    if not (actor_value is Dictionary) or not (move_value is Dictionary):
        return
    var actor: Dictionary = actor_value
    var move: Dictionary = move_value
    var move_id: String = str(state.get("move_id", ""))
    var hit_damage: int = 0
    var hit_effect: float = 0.0
    var any_target_alive: bool = false

    var previous_guaranteed_crit: bool = bool(actor.get("db_guaranteed_crit", false))
    if bool(state.get("guaranteed_crit", false)):
        actor["db_guaranteed_crit"] = true

    _database_active_move = move
    _database_move_id = move_id

    for target_value: Variant in state.get("targets", []):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if not bool(target.get("alive", false)):
            continue

        var target_damage: int = 0
        var target_effect: float = 0.0
        for mechanic_value: Variant in _database_multi_hit_repeat_mechanics(move):
            if not (mechanic_value is Dictionary):
                continue
            var mechanic: Dictionary = mechanic_value
            var kind: String = str(mechanic.get("kind", ""))
            if kind == "damage":
                var damage: int = _damage(
                    actor,
                    target,
                    int(move.get("power", 0)),
                    str(move.get("type", "normal")),
                    str(move.get("category", "physical"))
                )
                target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
                target_damage += damage
                if int(target.get("hp", 0)) <= 0:
                    target["alive"] = false
            else:
                target_effect += _effect(actor, target, mechanic)

        if target_damage > 0:
            target["aggro"] = float(target.get("aggro", 0.0)) * 0.5
            _database_spawn_multi_hit_feedback(
                target,
                hit_index,
                int(state.get("planned_hits", hit_index)),
                target_damage
            )

        hit_damage += target_damage
        hit_effect += target_effect
        if bool(target.get("alive", false)):
            any_target_alive = true

    actor["db_guaranteed_crit"] = previous_guaranteed_crit
    _database_active_move = {}
    _database_move_id = ""

    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(hit_damage) + hit_effect
    state["total_damage"] = int(state.get("total_damage", 0)) + hit_damage
    state["executed_hits"] = hit_index
    state["next_hit"] = hit_index + 1

    _database_set_multi_hit_log(state, hit_index, hit_damage, false)
    _refresh_cards()
    _check_end()

    var planned_hits: int = int(state.get("planned_hits", hit_index))
    if hit_index >= planned_hits or not any_target_alive or not battle_active:
        _database_finish_multi_hit_sequence(state)
        return

    get_tree().create_timer(DATABASE_MULTI_HIT_BETWEEN_GAP_SECONDS).timeout.connect(
        _database_launch_multi_hit.bind(state)
    )


func _database_multi_hit_repeat_mechanics(move: Dictionary) -> Array:
    var result: Array = []
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var spec_value: Variant = runtime.get("multi_hit", {})
    var spec: Dictionary = spec_value if spec_value is Dictionary else {}
    var repeat_kinds_value: Variant = spec.get("repeat_kinds", ["damage"])
    var repeat_kinds: Array = repeat_kinds_value if repeat_kinds_value is Array else ["damage"]

    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return result
    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        var kind: String = str(mechanic.get("kind", ""))
        if repeat_kinds.has(kind) or bool(mechanic.get("per_hit", false)):
            result.append(mechanic)
    return result


func _database_multi_hit_state_is_valid(state: Dictionary) -> bool:
    if not battle_active:
        return false
    if int(state.get("serial", -1)) != _database_multi_hit_serial:
        return false
    var actor_value: Variant = state.get("actor", {})
    return actor_value is Dictionary and bool((actor_value as Dictionary).get("alive", false))


func _database_finish_multi_hit_sequence(state: Dictionary) -> void:
    if int(state.get("serial", -1)) != _database_multi_hit_serial:
        return
    var executed_hits: int = int(state.get("executed_hits", 1))
    var total_damage: int = int(state.get("total_damage", 0))
    _database_set_multi_hit_log(state, executed_hits, total_damage, true)


func _database_set_multi_hit_log(
    state: Dictionary,
    hit_index: int,
    damage: int,
    final_summary: bool
) -> void:
    var actor_value: Variant = state.get("actor", {})
    var move_value: Variant = state.get("move", {})
    if not (actor_value is Dictionary) or not (move_value is Dictionary):
        return
    var actor: Dictionary = actor_value
    var move: Dictionary = move_value
    var move_name: String = str(move.get("name", state.get("move_id", "Attacke")))
    if final_summary:
        _set_log(
            _actor_name(actor) + " nutzt [b]" + move_name + "[/b]"
            + " → " + str(hit_index) + " Treffer, " + str(damage) + " Schaden insgesamt."
        )
        return
    _set_log(
        _actor_name(actor) + " nutzt [b]" + move_name + "[/b]"
        + " · Treffer " + str(hit_index) + "/" + str(state.get("planned_hits", hit_index))
        + " → " + str(damage) + " Schaden."
    )


func _database_spawn_multi_hit_feedback(
    target: Dictionary,
    hit_index: int,
    planned_hits: int,
    damage: int
) -> void:
    if battle_panel == null:
        return
    var ui_value: Variant = cards.get(str(target.get("id", "")), {})
    if not (ui_value is Dictionary):
        return
    var ui: Dictionary = ui_value
    var card: Control = ui.get("card") as Control
    if card == null:
        return

    var label: Label = Label.new()
    label.text = "TREFFER " + str(hit_index) + "/" + str(planned_hits) + " · −" + str(damage) + " KP"
    label.position = card.global_position + Vector2(8.0, -34.0)
    label.z_index = 90
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", Color("ffb0a4"))
    label.add_theme_color_override("font_outline_color", Color("18211f"))
    label.add_theme_constant_override("outline_size", 4)
    battle_panel.add_child(label)

    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "position:y", label.position.y - 14.0, 0.62)
    tween.tween_property(label, "modulate:a", 0.0, 0.24).set_delay(0.38)
    tween.chain().tween_callback(label.queue_free)


func _database_move_was_attempted(move_id: String) -> bool:
    if log_label == null:
        return true
    var move_name: String = str(_move_data(move_id).get("name", move_id))
    var resolved_log: String = log_label.get_parsed_text().strip_edges()
    return (
        (resolved_log.contains("nutzt") and resolved_log.contains(move_name))
        or (resolved_log.contains("verfehlt") and resolved_log.contains(move_name))
    )


func _database_sun_is_active(runtime: Dictionary) -> bool:
    if not bool(runtime.get("sun_skips_charge", false)):
        return false
    return str(battle_weather.snapshot().get("weather_id", "")) == "sun"


func _database_restore_removed_type(actor: Dictionary) -> void:
    var removed_type: String = str(actor.get("db_removed_type", ""))
    if removed_type.is_empty():
        return
    var types: Array = _type_array(actor.get("types", []))
    if not types.has(removed_type):
        types.append(removed_type)
    actor["types"] = types
    actor["db_removed_type"] = ""
    actor["db_removed_type_until_action"] = 0


func _database_interrupt_forced_sequence(actor: Dictionary) -> void:
    actor["db_forced_move_id"] = ""
    actor["db_forced_actions_left"] = 0


func _database_apply_incoming_accuracy_to_move(actor: Dictionary, temp_move: Dictionary) -> void:
    if temp_move.get("accuracy", null) == null or str(temp_move.get("target", "")) != "enemy_highest_aggro":
        return
    var targets: Array = _targets(actor, "enemy_highest_aggro")
    if targets.is_empty() or not (targets[0] is Dictionary):
        return
    var target: Dictionary = targets[0]
    var current_action: int = int(target.get("action_serial", 0))
    if current_action >= int(target.get("db_incoming_accuracy_expires", 0)):
        target["db_incoming_accuracy_mult"] = 1.0
        return
    temp_move["accuracy"] = clampf(
        float(temp_move.get("accuracy", 100.0)) * float(target.get("db_incoming_accuracy_mult", 1.0)),
        1.0,
        100.0
    )


func _database_trigger_toxic_spikes_if_defined(
    actor: Dictionary,
    move: Dictionary,
    move_attempted: bool
) -> void:
    if (
        not move_attempted
        or str(move.get("category", "")) != "physical"
        or not bool(move.get("contact", false))
        or _type_array(actor.get("types", [])).has("flying")
    ):
        return
    var own_side: String = str(actor.get("side", ""))
    if int(get_meta("db_toxic_spikes_" + own_side, 0)) > 0:
        _spawn_feedback_label(actor, "☠️ GIFTSPITZEN AKTIV", Color("c7a2dd"))


func route_move_is_runtime_usable(move_id: String) -> bool:
    return _runtime_has_move(move_id)


func _database_multi_hit_count(spec: Dictionary) -> int:
    var min_hits: int = maxi(1, int(spec.get("min", 2)))
    var max_hits: int = maxi(min_hits, int(spec.get("max", 5)))
    var weights_value: Variant = spec.get("weights", [])
    if weights_value is Array and (weights_value as Array).size() == max_hits - min_hits + 1:
        var total: int = 0
        for weight_value: Variant in weights_value:
            total += maxi(0, int(weight_value))
        if total > 0:
            var roll: int = randi_range(1, total)
            var running: int = 0
            for index: int in range((weights_value as Array).size()):
                running += maxi(0, int((weights_value as Array)[index]))
                if roll <= running:
                    return min_hits + index
    return randi_range(min_hits, max_hits)


func _database_any_target_damaged(snapshots: Dictionary) -> bool:
    for snapshot_value: Variant in snapshots.values():
        if snapshot_value is Dictionary:
            var target_value: Variant = (snapshot_value as Dictionary).get("target", {})
            if (
                target_value is Dictionary
                and int((target_value as Dictionary).get("hp", 0)) < int((snapshot_value as Dictionary).get("hp", 0))
            ):
                return true
    return false
