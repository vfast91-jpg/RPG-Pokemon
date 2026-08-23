extends "res://scripts/battle_demo_ad_status_support_v1.gd"

# Lifecycle and move execution for the Abra -> Dodri batch.

func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["ad_hidden_cycle"] = false
    combatant["ad_short_charging"] = false
    combatant["ad_short_charge_move"] = ""
    combatant["ad_revenge_was_hit"] = false
    combatant["ad_shared_protect_chain"] = int(combatant.get("db_protect_chain", 0))
    combatant["ad_drowsy_trigger_serial"] = -1
    combatant["ad_magnet_rise_expires"] = -1
    combatant["ad_mirror_expires_before_serial"] = -1
    combatant["ad_mirror_pending_damage"] = 0
    combatant["ad_mirror_pending_attacker_id"] = ""
    combatant["ad_mute_expires_before_serial"] = -1
    combatant["ad_lock_on_target_id"] = ""
    return combatant


func _start_battle() -> void:
    _ad_psychic_terrain.clear()
    _ad_trick_room_remaining = 0.0
    _ad_pending_short_charges.clear()
    _ad_active_move_id = ""
    _ad_self_ally_picker_move_id = ""
    if has_meta("ad_gravity_source_id"):
        remove_meta("ad_gravity_source_id")
    if has_meta("ad_gravity_expires_after_action"):
        remove_meta("ad_gravity_expires_after_action")
    super._start_battle()


func open_config() -> void:
    _ad_psychic_terrain.clear()
    _ad_trick_room_remaining = 0.0
    _ad_pending_short_charges.clear()
    if has_meta("ad_gravity_source_id"):
        remove_meta("ad_gravity_source_id")
    if has_meta("ad_gravity_expires_after_action"):
        remove_meta("ad_gravity_expires_after_action")
    super.open_config()


func _process(delta: float) -> void:
    var can_advance: bool = (
        battle_active
        and not paused
        and not opening_phase_active
    )

    if can_advance:
        if _ad_trick_room_remaining > 0.0:
            _ad_trick_room_remaining = maxf(
                0.0, _ad_trick_room_remaining - delta
            )
        _ad_advance_short_charges(delta)

    var original_speeds: Dictionary = {}
    if _ad_trick_room_remaining > 0.0:
        original_speeds = _ad_apply_trick_room_speed_mirror()

    super._process(delta)

    if not original_speeds.is_empty():
        _ad_restore_speeds(original_speeds)

    _ad_cleanup_field_states()


func _prompt_player(actor: Dictionary) -> void:
    if bool(actor.get("ad_short_charging", false)):
        actor["atb"] = 0.0
        return
    _ad_return_from_hidden_cycle(actor)
    _ad_clear_expired_actor_states(actor)
    super._prompt_player(actor)
    _ad_disable_muted_sound_buttons(actor)


func _enemy_act(actor: Dictionary) -> void:
    if bool(actor.get("ad_short_charging", false)):
        actor["atb"] = 0.0
        return
    _ad_return_from_hidden_cycle(actor)
    _ad_clear_expired_actor_states(actor)

    if _ad_mute_active(actor):
        var has_forced_state: bool = (
            bool(actor.get("db_recharge_pending", false))
            or not str(actor.get("db_charge_move", "")).is_empty()
            or (
                not str(actor.get("db_forced_move_id", "")).is_empty()
                and int(actor.get("db_forced_actions_left", 0)) > 0
            )
        )
        if not has_forced_state:
            var allowed: Array[String] = []
            var move_values: Variant = actor.get("moves", [])
            if move_values is Array:
                for move_value: Variant in move_values:
                    var move_id: String = str(move_value)
                    if not _ad_is_sound_move(_move_data(move_id)):
                        allowed.append(move_id)
            if not allowed.is_empty():
                _execute_move(actor, allowed.pick_random())
                return

    super._enemy_act(actor)


func _choose_move(move_id: String) -> void:
    if not selected_actor.is_empty():
        _ad_clear_expired_actor_states(selected_actor)
        if _ad_mute_active(selected_actor) and _ad_is_sound_move(_move_data(move_id)):
            _set_log(
                "[b]" + _actor_name(selected_actor)
                + "[/b] ist stumm und kann keine Schallattacke einsetzen."
            )
            _ad_disable_muted_sound_buttons(selected_actor)
            return
    super._choose_move(move_id)


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    if not actor.is_empty():
        actor["ad_shared_protect_chain"] = 0
        actor["db_protect_chain"] = 0
    super._choose_wait()
    if not actor.is_empty():
        _ad_after_counted_action(actor)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    _ad_clear_expired_actor_states(actor)

    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if _ad_mute_active(actor) and _ad_is_sound_move(move):
        _spawn_feedback_label(actor, "🔇 STUMM", Color("d9c2d9"))
        if str(actor.get("side", "")) == "player":
            _set_log(_actor_name(actor) + " kann während Halsabschneider keine Schallattacke einsetzen.")
            return
        actor["atb"] = 0.0
        actor["cycle"] = 1.0
        return

    if (
        runtime.has("ad_short_charge")
        and not bool(actor.get("ad_short_charge_resolving", false))
    ):
        _ad_begin_short_charge(actor, move_id, runtime)
        return

    if move_id != "protect" and move_id != "detect":
        actor["ad_shared_protect_chain"] = 0
        actor["db_protect_chain"] = 0
    elif move_id == "protect":
        actor["db_protect_chain"] = int(actor.get("ad_shared_protect_chain", 0))

    if move_id == "magnet_rise" and _ad_gravity_active():
        _spawn_feedback_label(actor, "✖ ERDANZIEHUNG", Color("d9a5a5"))
        _ad_execute_empty_action(actor, move_id, move)
        return

    if bool(runtime.get("ad_thaw_user", false)) and str(actor.get("major_status", "")) == "freeze":
        actor["major_status"] = ""
        _spawn_feedback_label(actor, "♨️ AUFGETAUT", Color("bfe9ff"))

    if runtime.has("ad_requires_target_status"):
        var required_status: String = str(runtime.get("ad_requires_target_status", ""))
        var status_targets: Array = _targets(
            actor, str(move.get("target", "enemy_highest_aggro"))
        )
        if (
            status_targets.is_empty()
            or not (status_targets[0] is Dictionary)
            or str((status_targets[0] as Dictionary).get("major_status", "")) != required_status
        ):
            _spawn_feedback_label(actor, "✖ BEDINGUNG FEHLT", Color("d9a5a5"))
            _ad_execute_empty_action(actor, move_id, move)
            return

    var original_move: Dictionary = move.duplicate(true)
    var temp_move: Dictionary = move.duplicate(true)
    var changed_move: bool = false

    var dynamic_kind: String = str(runtime.get("ad_dynamic_power", ""))
    if dynamic_kind == "heavy_slam":
        var heavy_targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
        if not heavy_targets.is_empty() and heavy_targets[0] is Dictionary:
            temp_move["power"] = _ad_heavy_slam_power(actor, heavy_targets[0] as Dictionary)
            changed_move = true
    elif dynamic_kind == "hard_press":
        var press_targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
        if not press_targets.is_empty() and press_targets[0] is Dictionary:
            var press_target: Dictionary = press_targets[0]
            var max_hp: int = maxi(1, int(press_target.get("max_hp", 1)))
            var hp: int = clampi(int(press_target.get("hp", 0)), 0, max_hp)
            temp_move["power"] = maxi(1, int(floor(100.0 * float(hp) / float(max_hp))))
            changed_move = true

    if (
        move_id == "revenge"
        and bool(actor.get("ad_revenge_power_bonus", false))
    ):
        temp_move["power"] = 120
        changed_move = true

    if bool(runtime.get("ad_guaranteed_crit", false)):
        actor["db_guaranteed_crit"] = true

    if move_id == "blizzard" and _ad_snow_active():
        temp_move["accuracy"] = null
        changed_move = true

    var lock_target_id: String = str(actor.get("ad_lock_on_target_id", ""))
    if (
        not lock_target_id.is_empty()
        and temp_move.get("power", null) != null
        and not bool(temp_move.get("area", false))
        and str(temp_move.get("target", "")) == "enemy_highest_aggro"
    ):
        var lock_targets: Array = _targets(actor, "enemy_highest_aggro")
        if (
            not lock_targets.is_empty()
            and lock_targets[0] is Dictionary
            and str((lock_targets[0] as Dictionary).get("id", "")) == lock_target_id
        ):
            temp_move["accuracy"] = null
            temp_move["runtime"] = (
                (temp_move.get("runtime", {}) as Dictionary).duplicate(true)
                if temp_move.get("runtime", {}) is Dictionary
                else {}
            )
            (temp_move["runtime"] as Dictionary)["ad_lock_on_consumed"] = true
            changed_move = true
        else:
            # Zielschuss gilt nur für die nächste passende Einzelziel-Schadensattacke.
            # Ist das markierte Pokémon dann nicht das legale aktuelle Ziel, verfällt die Marke.
            actor["ad_lock_on_target_id"] = ""

    if changed_move:
        _ad_replace_runtime_move(move_id, temp_move)

    var pre_targets: Array = _targets(
        actor, str(temp_move.get("target", "enemy_highest_aggro"))
    )
    var had_valid_target: bool = not pre_targets.is_empty()
    var hp_before: Dictionary = _ad_snapshot_hp()
    var serial_before: int = int(actor.get("action_serial", 0))

    _ad_active_move_id = move_id
    super._execute_move(actor, move_id)
    _ad_active_move_id = ""

    if changed_move:
        _ad_replace_runtime_move(move_id, original_move)

    if move_id == "protect":
        actor["ad_shared_protect_chain"] = int(actor.get("db_protect_chain", 0))
    elif move_id == "detect":
        actor["db_protect_chain"] = int(actor.get("ad_shared_protect_chain", 0))

    if bool(runtime.get("ad_self_ko_after_move", false)) and int(actor.get("action_serial", 0)) > serial_before:
        _ad_self_ko(actor)

    if runtime.has("ad_fixed_self_cost_fraction") and had_valid_target and int(actor.get("action_serial", 0)) > serial_before:
        _ad_apply_fixed_self_cost(
            actor, float(runtime.get("ad_fixed_self_cost_fraction", 0.0))
        )

    if runtime.has("ad_crash_on_failure_fraction") and had_valid_target and int(actor.get("action_serial", 0)) > serial_before:
        if not _ad_any_target_lost_hp(pre_targets, hp_before):
            _ad_apply_fixed_self_cost(
                actor, float(runtime.get("ad_crash_on_failure_fraction", 0.0)),
                "💥 FEHLSCHLAG"
            )

    if (
        temp_move.get("runtime", {}) is Dictionary
        and bool((temp_move.get("runtime", {}) as Dictionary).get("ad_lock_on_consumed", false))
        and int(actor.get("action_serial", 0)) > serial_before
    ):
        actor["ad_lock_on_target_id"] = ""

    var multi_hit_value: Variant = runtime.get("multi_hit", null)
    if not (multi_hit_value is Dictionary):
        _ad_trigger_mirror_pending_on_all()

    if move_id == "gravity" and int(actor.get("action_serial", 0)) > serial_before:
        _ad_cancel_all_magnet_rise()
        set_meta("ad_gravity_source_id", str(actor.get("id", "")))
        set_meta("ad_gravity_expires_after_action", int(actor.get("action_serial", 0)) + 3)

    if int(actor.get("action_serial", 0)) > serial_before:
        _ad_after_counted_action(actor)

    actor["ad_revenge_power_bonus"] = false
    _refresh_cards()
    _check_end()
