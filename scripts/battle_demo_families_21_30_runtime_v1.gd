extends "res://scripts/battle_demo_families_21_30_special_support_v1.gd"

func _process(delta: float) -> void:
    _f30_advance_hail(delta)
    super._process(delta)
    _f30_enforce_mean_look_locks()
    _f30_cleanup_minimized_states()

func _prompt_player(actor: Dictionary) -> void:
    _f30_expire_destiny_bond_at_action_opportunity(actor)
    super._prompt_player(actor)

func _enemy_act(actor: Dictionary) -> void:
    _f30_expire_destiny_bond_at_action_opportunity(actor)
    super._enemy_act(actor)

func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    var serial_before: int = int(actor.get("action_serial", 0)) if not actor.is_empty() else -1
    super._choose_wait()
    if not actor.is_empty() and int(actor.get("action_serial", 0)) > serial_before:
        actor["f30_destiny_recast_block"] = false
        _f30_trigger_aqua_ring_after_action(actor)

func _database_consume_recharge(actor: Dictionary) -> void:
    var serial_before: int = int(actor.get("action_serial", 0))
    super._database_consume_recharge(actor)
    if int(actor.get("action_serial", 0)) > serial_before:
        actor["f30_destiny_recast_block"] = false
        _f30_trigger_aqua_ring_after_action(actor)

func _execute_move(actor: Dictionary, move_id: String) -> void:
    if actor.is_empty():
        return

    var original: Dictionary = _move_data(move_id)
    if original.is_empty():
        super._execute_move(actor, move_id)
        return

    var runtime_value: Variant = original.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var was_charged_shot: bool = str(actor.get("db_charge_move", "")) == move_id
    var serial_before: int = int(actor.get("action_serial", 0))
    var temp: Dictionary = original.duplicate(true)
    var changed_move: bool = false

    _f30_active_move_id = move_id
    _f30_memento_any_effect = false
    _f30_destiny_activation_succeeded = false
    _f30_wide_guard_consumed_sides.clear()

    if (
        move_id == "counter"
        and not bool(actor.get("ad_short_charge_resolving", false))
    ):
        actor["f30_counter_damage"] = 0
        actor["f30_counter_source_id"] = ""
        actor["f30_counter_source_serial"] = -1
        actor["f30_counter_source_move_id"] = ""

    if move_id == "triple_axel":
        actor["f30_triple_axel_hit_index"] = 0
        actor["f30_triple_axel_failed"] = false

    var dynamic_power: String = str(runtime.get("f30_dynamic_power", ""))
    if dynamic_power == "brine":
        var brine_target: Dictionary = _f30_first_target(actor, original)
        if not brine_target.is_empty():
            var max_hp: int = maxi(1, int(brine_target.get("max_hp", 1)))
            var hp: int = clampi(int(brine_target.get("hp", 0)), 0, max_hp)
            temp["power"] = 130 if hp * 2 <= max_hp else 65
            changed_move = true
    elif dynamic_power == "flail":
        temp["power"] = _f30_flail_power(actor)
        changed_move = true

    if move_id == "blizzard" and _f30_hail_active():
        temp["accuracy"] = null
        changed_move = true

    var phantom_guard_target: Dictionary = {}
    var phantom_guard_was_active: bool = false
    var phantom_guard_should_be_consumed: bool = false
    if (
        move_id == "phantom_force"
        and was_charged_shot
        and bool(runtime.get("f30_break_protect_on_fire", false))
    ):
        phantom_guard_target = _f30_first_target(actor, original)
        if not phantom_guard_target.is_empty():
            phantom_guard_was_active = bool(phantom_guard_target.get("protective_guard", false))
            if phantom_guard_was_active:
                var multiplier: float = TypeSystem.get_multiplier(
                    str(original.get("type", "ghost")),
                    _type_array(phantom_guard_target.get("types", []))
                )
                if multiplier > 0.0:
                    phantom_guard_target["protective_guard"] = false
                    phantom_guard_should_be_consumed = true
                    _spawn_feedback_label(
                        phantom_guard_target, "🌑 SCHUTZ DURCHBROCHEN", Color("c8b7ef")
                    )

    if changed_move:
        _ad_replace_runtime_move(move_id, temp)

    super._execute_move(actor, move_id)

    if changed_move:
        _ad_replace_runtime_move(move_id, original)

    if (
        phantom_guard_was_active
        and not phantom_guard_should_be_consumed
        and not phantom_guard_target.is_empty()
    ):
        phantom_guard_target["protective_guard"] = true

    var action_completed: bool = int(actor.get("action_serial", 0)) > serial_before

    if move_id == "memento" and _f30_memento_any_effect and action_completed:
        _ad_self_ko(actor)

    if (
        move_id == "skull_bash"
        and not was_charged_shot
        and str(actor.get("db_charge_move", "")) == "skull_bash"
        and bool(runtime.get("f30_skull_bash_defense_on_charge", false))
    ):
        var buff_aggro: float = _f30_apply_exact_modifier(
            actor, actor, "incoming_damage_mod", 1.0, "Schädelwumme"
        )
        actor["aggro"] = float(actor.get("aggro", 0.0)) + buff_aggro
        _spawn_feedback_label(actor, "🛡️ VERTEIDIGUNG ↑ · 3 AKTIONEN", Color("b9e2a8"))

    if action_completed:
        if move_id == "destiny_bond":
            actor["f30_destiny_recast_block"] = _f30_destiny_activation_succeeded
        else:
            actor["f30_destiny_recast_block"] = false
        _f30_trigger_aqua_ring_after_action(actor)

    _f30_consume_wide_guards()

    _f30_active_move_id = ""
    _refresh_cards()
    _check_end()

func _database_finish_multi_hit_sequence(state: Dictionary) -> void:
    super._database_finish_multi_hit_sequence(state)
    if str(state.get("move_id", "")) == "triple_axel":
        var actor_value: Variant = state.get("actor", {})
        if actor_value is Dictionary:
            var actor: Dictionary = actor_value
            actor["f30_triple_axel_hit_index"] = 0
            actor["f30_triple_axel_failed"] = false

func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    match kind:
        "f30_aqua_ring":
            return _f30_aqua_ring(actor)
        "f30_modifier_on_damage":
            return _f30_modifier_on_damage(actor, target, mechanic)
        "f30_sheer_cold":
            return _f30_ohko(actor, target, "sheer_cold")
        "f30_guillotine":
            return _f30_ohko(actor, target, "guillotine")
        "f30_poison_gas":
            return _f30_poison_gas(actor, target)
        "f30_minimize":
            return _f30_minimize(actor)
        "f30_memento":
            return _f30_memento(actor, target)
        "f30_mean_look":
            return _f30_mean_look(actor, target)
        "f30_destiny_bond":
            return _f30_destiny_bond(actor)
        "f30_ancient_power_on_damage":
            return _f30_ancient_power(actor, target, mechanic)
        "f30_self_speed_on_damage":
            return _f30_self_speed_on_damage(actor, target, mechanic)
        "f30_wide_guard":
            return _f30_wide_guard(actor)
        "f30_counter":
            return _f30_counter(actor)
        "f30_final_gambit":
            return _f30_final_gambit(actor, target)
        _:
            return super._effect(actor, target, mechanic)

func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    var move_id: String = _f30_current_move_id()
    var move: Dictionary = _move_data(move_id)

    if _f30_wide_guard_blocks(target, move):
        _f30_wide_guard_consumed_sides[str(target.get("side", ""))] = true
        _f30_award_wide_guard_prevention_aggro(actor, target, power, move_type, category)
        _spawn_feedback_label(target, "🛡️ RUNDUMSCHUTZ", Color("b8d9ff"))
        return 0

    var effective_power: int = power
    if _tf_has_state(target, "underwater") and move_id in ["surf", "whirlpool"]:
        effective_power *= 2

    if move_id == "triple_axel":
        var hit_index: int = clampi(int(actor.get("f30_triple_axel_hit_index", 0)), 0, 2)
        if bool(actor.get("f30_triple_axel_failed", false)):
            return 0
        if hit_index > 0 and randf() > 0.90:
            actor["f30_triple_axel_failed"] = true
            actor["f30_triple_axel_hit_index"] = hit_index + 1
            _spawn_feedback_label(target, "✖ VERFEHLT", Color("d9a5a5"))
            return 0
        effective_power = [20, 40, 60][hit_index]
        actor["f30_triple_axel_hit_index"] = hit_index + 1

    var hp_before: int = int(target.get("hp", 0))
    var damage: int = super._damage(actor, target, effective_power, move_type, category)

    if damage > 0:
        if (
            bool(target.get("ad_short_charging", false))
            and str(target.get("ad_short_charge_move", "")) == "counter"
            and category == "physical"
            and str(actor.get("side", "")) != str(target.get("side", ""))
        ):
            call_deferred(
                "_f30_capture_counter_damage",
                target,
                actor,
                hp_before,
                int(actor.get("action_serial", 0)),
                move_id
            )

        if (
            bool(target.get("f30_destiny_bond_active", false))
            and str(actor.get("side", "")) != str(target.get("side", ""))
        ):
            call_deferred(
                "_f30_resolve_destiny_bond_damage",
                target,
                actor,
                hp_before
            )

    return damage

func _cf_target_reachable_by_move(target: Dictionary, move_id: String) -> bool:
    if _tf_has_state(target, "underwater"):
        return move_id in ["surf", "whirlpool", "low_kick"]
    if _tf_has_state(target, "phantom_hidden"):
        var move: Dictionary = _move_data(move_id)
        var runtime_value: Variant = move.get("runtime", {}) if not move.is_empty() else {}
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        return bool(runtime.get("f30_hits_phantom_hidden", false))
    return super._cf_target_reachable_by_move(target, move_id)

func _semi_is_charge_state(state: String) -> bool:
    # Phantomkraft uses the shared hidden-state targeting contract, but V20
    # explicitly keeps its Aggro while vanished. Therefore it must not opt into
    # the central semi-charge Aggro reset used by Fly/Dig/Dive.
    return super._semi_is_charge_state(state)

func _semi_hidden_from_normal_targeting(combatant: Dictionary) -> bool:
    if _tf_has_state(combatant, "phantom_hidden"):
        return true
    return super._semi_hidden_from_normal_targeting(combatant)

func _weather_effect_lines(weather_id: String) -> Array[String]:
    var lines: Array[String] = super._weather_effect_lines(weather_id)
    if weather_id == "hail":
        lines.append("Nicht-Eis-Pokémon: alle 10 s 1/16 Max-KP Schaden")
        lines.append("Blizzard: trifft sicher")
    return lines

func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if bool(combatant.get("f30_aqua_ring_active", false)):
        tokens.append("💍 WASSERRING")
    if _tf_has_state(combatant, "minimized"):
        tokens.append("🤏 KOMPRIMIERT")
    if _tf_has_state(combatant, "underwater"):
        tokens.append("🤿 UNTER WASSER")
    if _tf_has_state(combatant, "phantom_hidden"):
        tokens.append("🌑 PHANTOM")
    if bool(combatant.get("f30_destiny_bond_active", false)):
        tokens.append("🔗 ABGANGSBUND")
    if not str(combatant.get("f30_mean_look_source_id", "")).is_empty():
        tokens.append("👁️ AGGRO-LOCK")
    if (
        bool(combatant.get("ad_short_charging", false))
        and str(combatant.get("ad_short_charge_move", "")) == "counter"
    ):
        tokens.append("🥊 KONTER")
    return tokens
