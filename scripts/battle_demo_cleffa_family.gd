extends "res://scripts/battle_demo_cleffa_family_actions.gd"

# Pii/Piepi/Pixi move dispatcher.

func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    if _cleffa_indirect_call_depth <= 0 and _cleffa_move_is_imprisoned(actor, move_id):
        _database_interrupt_forced_sequence(actor)
        actor["cleffa_meteor_beam_charging"] = false
        actor["cleffa_meteor_beam_firing"] = false
        _cleffa_consume_failed_action(actor, move_id, "🚫 Begrenzer blockiert die Attacke.")
        return

    if _cleffa_gravity_is_active() and _cleffa_move_gravity_blocked(move_id):
        _database_interrupt_forced_sequence(actor)
        actor["cleffa_meteor_beam_charging"] = false
        actor["cleffa_meteor_beam_firing"] = false
        _cleffa_consume_failed_action(actor, move_id, "🌍 Erdanziehung verhindert die Attacke.")
        return

    var original_move: Dictionary = _move_data(move_id)
    if original_move.is_empty():
        super._execute_move(actor, move_id)
        return

    # Triggered moves first consume the AP of the caller, then execute the called
    # move immediately. Their called move never replaces the caller's recovery.
    if move_id == "copycat":
        var copycat_called_id: String = _cleffa_last_resolved_move_id
        _cleffa_active_move_id = move_id
        super._execute_move(actor, move_id)
        _cleffa_active_move_id = ""
        var copycat_caller_cycle: float = float(actor.get("cycle", 1.0))
        if _cleffa_call_move_is_eligible(copycat_called_id, false):
            _cleffa_execute_called_move(actor, copycat_called_id, copycat_caller_cycle)
        return

    if move_id == "metronome":
        _cleffa_active_move_id = move_id
        super._execute_move(actor, move_id)
        _cleffa_active_move_id = ""
        var metronome_caller_cycle: float = float(actor.get("cycle", 1.0))
        var metronome_called_id: String = _cleffa_random_metronome_move()
        if not metronome_called_id.is_empty():
            _cleffa_execute_called_move(actor, metronome_called_id, metronome_caller_cycle)
        return

    var move: Dictionary = original_move.duplicate(true)
    var target_snapshot: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    var first_target: Dictionary = target_snapshot[0] if not target_snapshot.is_empty() and target_snapshot[0] is Dictionary else {}
    var hp_before: Dictionary = {}
    for target_value: Variant in target_snapshot:
        if target_value is Dictionary:
            var t: Dictionary = target_value
            hp_before[str(t.get("id", ""))] = int(t.get("hp", 0))

    # Stored Power translates the five distinct positive Timeflow attributes.
    if move_id == "stored_power":
        move["power"] = 20 + 20 * _cleffa_positive_attribute_count(actor)

    # Gravity is one central battlefield accuracy multiplier.
    if _cleffa_gravity_is_active() and move.get("accuracy", null) != null:
        var accuracy_mult: float = float(_cleffa_gravity.get("accuracy_multiplier", 1.0))
        move["accuracy"] = minf(100.0, float(move.get("accuracy", 100.0)) * accuracy_mult)

    # Misty Explosion checks the terrain and grounded state at resolution.
    if move_id == "misty_explosion" and _cleffa_misty_is_active() and _cleffa_is_grounded(actor):
        move["power"] = 150

    # Meteor Beam phase 1 is a real AP-7 action and a Status-scaled Attack buff.
    if move_id == "meteor_beam" and not bool(actor.get("cleffa_meteor_beam_firing", false)):
        var charge_move: Dictionary = move.duplicate(true)
        charge_move["power"] = null
        charge_move["accuracy"] = null
        charge_move["mechanics"] = []
        charge_move["effects"] = []
        _cleffa_replace_runtime_move(move_id, charge_move)
        _cleffa_active_move_id = move_id
        super._execute_move(actor, move_id)
        _cleffa_active_move_id = ""
        _cleffa_restore_runtime_move(move_id, original_move)
        if _database_move_was_attempted(move_id):
            actor["aggro"] = float(actor.get("aggro", 0.0)) + _cleffa_apply_timed_modifier(actor, actor, "outgoing_damage_mod", 1.0, "Meteorstrahl")
            actor["cleffa_meteor_beam_charging"] = true
            _spawn_feedback_label(actor, "🌠 LÄDT AUF", Color("f2d890"))
        return

    _cleffa_replace_runtime_move(move_id, move)
    _cleffa_active_move_id = move_id
    super._execute_move(actor, move_id)
    _cleffa_active_move_id = ""
    _cleffa_restore_runtime_move(move_id, original_move)

    var attempted: bool = _database_move_was_attempted(move_id)
    var hit_target: Dictionary = _cleffa_first_damaged_target(target_snapshot, hp_before)

    if move_id == "meteor_beam" and bool(actor.get("cleffa_meteor_beam_firing", false)):
        actor["cleffa_meteor_beam_charging"] = false
        actor["cleffa_meteor_beam_firing"] = false

    if attempted:
        match move_id:
            "after_you":
                _cleffa_reset_other_allied_aggro(actor)
            "life_dew":
                _cleffa_life_dew(actor)
            "moonlight":
                _cleffa_moonlight(actor)
            "gravity":
                _cleffa_activate_gravity(actor)
            "meteor_mash":
                if not hit_target.is_empty() and randf() <= 0.20:
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + _cleffa_apply_timed_modifier(actor, actor, "outgoing_damage_mod", 1.0, "Sternenhieb")
            "moonblast":
                if not hit_target.is_empty() and randf() <= 0.30:
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + _cleffa_apply_timed_modifier(actor, hit_target, "outgoing_damage_mod", -1.0, "Mondgewalt")
            "trick":
                if not first_target.is_empty():
                    _cleffa_swap_aggro(actor, first_target)
            "misty_terrain":
                _cleffa_activate_misty_terrain(actor)
            "uproar":
                _cleffa_wake_all_sleepers()
            "imprison":
                _cleffa_activate_imprison(actor)
            "misty_explosion":
                actor["hp"] = 0
                actor["alive"] = false
                _spawn_feedback_label(actor, "💨 K.O.", Color("f0b4c7"))
            "psych_up":
                if not first_target.is_empty():
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + _cleffa_psych_up(actor, first_target)
            "future_sight":
                if not first_target.is_empty():
                    _cleffa_schedule_future_sight(actor, first_target)
            "night_shade":
                if not first_target.is_empty():
                    _cleffa_apply_night_shade(actor, first_target)

        _cleffa_last_resolved_move_id = move_id

    if move_id == "grassy_terrain" and attempted:
        _cleffa_misty_terrain = {}

    _refresh_cards()
    _check_end()
