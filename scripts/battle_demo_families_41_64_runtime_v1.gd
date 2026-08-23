extends "res://scripts/battle_demo_families_41_64_effects_v1.gd"

# Runtime hooks for the final Gen-1 family batch.
# This layer handles action-opportunity timing, Torment legality, Wish timing,
# Stealth Rock contact triggers and the few damage-calculation exceptions.

var _f64_active_move_id: String = ""


func _prompt_player(actor: Dictionary) -> void:
    _f64_prepare_action_opportunity(actor)
    if not bool(actor.get("alive", false)):
        _check_end()
        return
    super._prompt_player(actor)


func _enemy_act(actor: Dictionary) -> void:
    _f64_prepare_action_opportunity(actor)
    if not bool(actor.get("alive", false)):
        _check_end()
        return

    if _f64_torment_active(actor):
        var last_move: String = str(actor.get("f64_last_action_move", ""))
        if not last_move.is_empty():
            var original_value: Variant = actor.get("moves", [])
            if original_value is Array:
                var filtered: Array = []
                for move_value: Variant in original_value:
                    if str(move_value) != last_move:
                        filtered.append(move_value)

                if filtered.is_empty():
                    _f64_enemy_wait(actor)
                    return

                actor["moves"] = filtered
                super._enemy_act(actor)
                actor["moves"] = original_value
                return

    super._enemy_act(actor)


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    var actor: Dictionary = selected_actor
    if (
        _f64_torment_active(actor)
        and move_id == str(actor.get("f64_last_action_move", ""))
    ):
        _spawn_feedback_label(actor, "💢 ATTACKE GESPERRT", Color("d9a5c8"))
        _set_log("Folterknecht verhindert die direkte Wiederholung dieser Attacke. Warten bleibt erlaubt.")
        return
    super._choose_move(move_id)


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    super._choose_wait()
    if not actor.is_empty():
        actor["f64_last_action_move"] = ""


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return

    var original: Dictionary = _move_data(move_id)
    if original.is_empty():
        super._execute_move(actor, move_id)
        return

    if _f64_trigger_stealth_rock_for_contact_action(actor, original):
        return

    var temp: Dictionary = original.duplicate(true)
    var changed_move: bool = false

    if move_id == "dragon_rush":
        var target: Dictionary = _f30_first_target(actor, original)
        if not target.is_empty() and _tf_has_state(target, "minimized"):
            temp["accuracy"] = null
            changed_move = true

    if changed_move:
        _ad_replace_runtime_move(move_id, temp)

    var serial_before: int = int(actor.get("action_serial", 0))
    var used_type: String = _f64_actual_move_type(actor, original)
    _f64_active_move_id = move_id

    super._execute_move(actor, move_id)

    if changed_move:
        _ad_replace_runtime_move(move_id, original)

    var action_completed: bool = int(actor.get("action_serial", 0)) > serial_before
    if action_completed:
        actor["f64_last_action_move"] = move_id
        actor["f64_last_used_move_type"] = used_type
        if move_id == "rapid_spin":
            _f64_clear_stealth_rock_side(str(actor.get("side", "")), actor)
        elif move_id == "defog":
            _f64_clear_all_stealth_rock(actor)

    _f64_active_move_id = ""
    _refresh_cards()
    _check_end()


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    var move_id: String = _f64_active_move_id
    var effective_power: int = power

    if move_id == "dragon_rush" and _tf_has_state(target, "minimized"):
        effective_power *= 2

    if move_id == "psystrike":
        return _f64_psystrike_damage(
            actor, target, effective_power, move_type, category
        )

    var damage: int = super._damage(
        actor, target, effective_power, move_type, category
    )
    if damage <= 0:
        return damage

    if move_id == "freeze_dry" and _type_array(target.get("types", [])).has("water"):
        # Normal Ice -> Water is 0.5x. Freeze-Dry replaces that component with
        # 2.0x, therefore the already calculated result is multiplied by four.
        damage = maxi(1, int(round(float(damage) * 4.0)))

    return damage


func _f64_psystrike_damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    var original_value: Variant = target.get("timed_modifiers", [])
    if not (original_value is Array):
        return super._damage(actor, target, power, move_type, category)

    var filtered: Array = []
    for modifier_value: Variant in original_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if (
            str(modifier.get("kind", "")) == "incoming_damage_mod"
            and float(modifier.get("multiplier", 1.0)) < 1.0
        ):
            continue
        filtered.append(modifier)

    target["timed_modifiers"] = filtered
    var damage: int = super._damage(actor, target, power, move_type, category)
    target["timed_modifiers"] = original_value
    return damage


func _f64_prepare_action_opportunity(actor: Dictionary) -> void:
    if actor.is_empty():
        return
    _f64_restore_guard_split_if_expired(actor)
    _f64_cleanup_expired_binary_effects(actor)
    _f64_resolve_wish(actor)


func _f64_restore_guard_split_if_expired(actor: Dictionary) -> void:
    if not bool(actor.get("f64_guard_split_active", false)):
        return
    var expiry: int = int(actor.get("f64_guard_split_expires_serial", -1))
    if expiry < 0 or int(actor.get("action_serial", 0)) < expiry:
        return

    actor["defense"] = maxi(
        1,
        int(actor.get("f64_guard_split_original_defense", actor.get("defense", 1)))
    )
    actor["f64_guard_split_active"] = false
    actor["f64_guard_split_expires_serial"] = -1
    _spawn_feedback_label(actor, "⚖️ SCHUTZTEILER ENDET", Color("d8d2e5"))


func _f64_cleanup_expired_binary_effects(actor: Dictionary) -> void:
    var serial: int = int(actor.get("action_serial", 0))
    if (
        int(actor.get("f64_torment_expires_serial", -1)) >= 0
        and serial >= int(actor.get("f64_torment_expires_serial", -1))
    ):
        actor["f64_torment_expires_serial"] = -1

    if (
        int(actor.get("f64_mist_expires_serial", -1)) >= 0
        and serial >= int(actor.get("f64_mist_expires_serial", -1))
    ):
        actor["f64_mist_expires_serial"] = -1


func _f64_torment_active(actor: Dictionary) -> bool:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return false
    var expiry: int = int(actor.get("f64_torment_expires_serial", -1))
    return expiry >= 0 and int(actor.get("action_serial", 0)) < expiry


func _f64_resolve_wish(actor: Dictionary) -> void:
    if not bool(actor.get("f64_wish_pending", false)):
        return
    if not bool(actor.get("alive", false)):
        actor["f64_wish_pending"] = false
        actor["f64_wish_amount"] = 0
        return

    var trigger: int = int(actor.get("f64_wish_trigger_serial", -1))
    if trigger < 0 or int(actor.get("action_serial", 0)) < trigger:
        return

    var requested: int = maxi(0, int(actor.get("f64_wish_amount", 0)))
    actor["f64_wish_pending"] = false
    actor["f64_wish_trigger_serial"] = -1
    actor["f64_wish_amount"] = 0

    if requested <= 0:
        return
    if _f40_heal_block_active(actor):
        _f40_heal_block_feedback(actor)
        return

    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var missing: int = maxi(0, max_hp - int(actor.get("hp", 0)))
    var healed: int = mini(missing, requested)
    if healed <= 0:
        return

    actor["hp"] = int(actor.get("hp", 0)) + healed
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(healed)
    _spawn_feedback_label(actor, "🌠 +" + str(healed) + " KP", Color("f1df9f"))


func _f64_trigger_stealth_rock_for_contact_action(
    actor: Dictionary,
    move: Dictionary
) -> bool:
    var side: String = str(actor.get("side", ""))
    if side.is_empty() or not _f64_stealth_rock_by_side.has(side):
        return false
    if str(move.get("category", "")) != "physical" or not bool(move.get("contact", false)):
        return false

    var effectiveness: float = TypeSystem.get_multiplier(
        "rock", _type_array(actor.get("types", []))
    )
    if effectiveness <= 0.0:
        return false

    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var requested: int = maxi(
        1,
        int(round(float(max_hp) * 0.125 * effectiveness))
    )
    var dealt: int = mini(requested, maxi(0, int(actor.get("hp", 0))))
    if dealt <= 0:
        return false

    actor["hp"] = maxi(0, int(actor.get("hp", 0)) - dealt)
    var hazard_value: Variant = _f64_stealth_rock_by_side.get(side, {})
    if hazard_value is Dictionary:
        var source: Dictionary = _zf_find_combatant(
            str((hazard_value as Dictionary).get("source_id", ""))
        )
        if not source.is_empty():
            source["aggro"] = float(source.get("aggro", 0.0)) + float(dealt)

    _spawn_feedback_label(actor, "🪨 −" + str(dealt) + " KP", Color("d6c5ae"))
    if int(actor.get("hp", 0)) > 0:
        _refresh_cards()
        return false

    actor["alive"] = false
    actor["aggro"] = 0.0
    actor["atb"] = 0.0
    _spawn_feedback_label(actor, "🪨 K.O. DURCH TARNSTEINE", Color("d9a5a5"))
    _refresh_cards()
    _check_end()
    return true


func _f64_clear_stealth_rock_side(side: String, actor: Dictionary) -> void:
    if side.is_empty() or not _f64_stealth_rock_by_side.has(side):
        return
    _f64_stealth_rock_by_side.erase(side)
    _spawn_feedback_label(actor, "🌀 TARNSTEINE ENTFERNT", Color("c9d7ff"))


func _f64_clear_all_stealth_rock(actor: Dictionary) -> void:
    if _f64_stealth_rock_by_side.is_empty():
        return
    _f64_stealth_rock_by_side.clear()
    _spawn_feedback_label(actor, "🌬️ TARNSTEINE ENTFERNT", Color("c9d7ff"))


func _f64_enemy_wait(actor: Dictionary) -> void:
    _begin_counted_action(actor)
    actor["aggro"] = float(actor.get("aggro", 0.0)) * 0.55
    actor["atb"] = 0.0
    actor["cycle"] = 0.70
    actor["f64_last_action_move"] = ""
    _expire_finished_modifiers(actor)
    _f30_trigger_aqua_ring_after_action(actor)
    _set_log(_actor_name(actor) + " wartet wegen Folterknecht.")
    _refresh_cards()


func _f64_actual_move_type(_actor: Dictionary, move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if move_id == "weather_ball" and battle_weather.is_active():
        match battle_weather.current_id():
            "sun":
                return "fire"
            "rain":
                return "water"
            "sandstorm":
                return "rock"
            "snow", "hail":
                return "ice"
    return str(move.get("type", "normal"))


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if _f64_torment_active(combatant):
        tokens.append("💢 FOLTER")
    if _f64_mist_active(combatant):
        tokens.append("🌫️ NEBEL")
    if bool(combatant.get("f64_wish_pending", false)):
        tokens.append("🌠 WUNSCH")
    if bool(combatant.get("f64_guard_split_active", false)):
        tokens.append("⚖️ SCHUTZTEILER")
    if bool(combatant.get("f64_transformed", false)):
        tokens.append("🧬 WANDLER")
    return tokens
