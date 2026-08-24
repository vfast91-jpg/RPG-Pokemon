extends "res://scripts/battle_demo_zf_combat_v1.gd"

# Battle-state rules for the Zubat -> Quapsel attack batch:
# Wonder Room, Freeze/Flame Wheel, Perish Song and Retaliate KO windows.
#
# V22 Freeze is not an open-ended per-action thaw lottery. A newly frozen
# Pokemon loses exactly 1-3 of its own action opportunities unless a central
# thaw interaction cures it earlier.

const ZF_WONDER_ROOM_DURATION_SECONDS: float = 50.0
const ZF_FREEZE_MIN_ACTIONS: int = 1
const ZF_FREEZE_MAX_ACTIONS: int = 3

var _zf_alive_snapshot: Dictionary = {}


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["zf_perish_count"] = 0
    combatant["zf_perish_applied_serial"] = -1
    combatant["zf_freeze_actions"] = 0
    return combatant


func _start_battle() -> void:
    _zf_wonder_room_remaining = 0.0
    _zf_selected_target_id = ""
    _zf_target_selection_move_id = ""
    _zf_alive_snapshot.clear()
    super._start_battle()
    _zf_sync_alive_snapshot()


func _route_begin_wave() -> void:
    super._route_begin_wave()
    # Route state is restored after the inherited battle startup. Re-snapshot
    # afterwards so Pokémon that were already K.O. before this battle do not
    # incorrectly count as a fresh Retaliate trigger.
    _zf_sync_alive_snapshot()


func _process(delta: float) -> void:
    if (
        battle_active
        and not paused
        and not opening_phase_active
        and _zf_wonder_room_remaining > 0.0
    ):
        _zf_wonder_room_remaining = maxf(0.0, _zf_wonder_room_remaining - delta)
    super._process(delta)
    _zf_mark_new_knockouts()


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    if not actor.is_empty():
        actor["zf_ally_ko_since_action"] = false
    _zf_selected_target_id = ""
    _zf_target_selection_move_id = ""
    super._choose_wait()
    _zf_mark_new_knockouts()


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    var move: Dictionary = _move_data(move_id)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if str(actor.get("major_status", "")) == "freeze":
        if bool(runtime.get("thaws_user", false)) or move_id == "flame_wheel":
            _zf_clear_freeze(actor, "🔥 AUFGETAUT")
        else:
            if int(actor.get("zf_freeze_actions", 0)) <= 0:
                # Compatibility for restored/legacy battle states that predate
                # the explicit V22 freeze-action counter.
                actor["zf_freeze_actions"] = _zf_roll_freeze_actions()
            _zf_selected_target_id = ""
            _zf_target_selection_move_id = ""
            _zf_consume_frozen_action(actor)
            return

    var serial_before: int = int(actor.get("action_serial", 0))
    super._execute_move(actor, move_id)
    if int(actor.get("action_serial", 0)) > serial_before:
        _zf_tick_perish_after_action(actor)
    _zf_mark_new_knockouts()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    var status_id: String = str(mechanic.get("status", ""))

    if kind == "zf_wonder_room":
        return _zf_activate_wonder_room(actor)
    if kind == "zf_perish_song":
        return _zf_apply_perish_song(actor)

    # Older database packs may still expose Freeze through the generic status
    # mechanic. Route that through the normalized V22 status implementation and
    # require actual target HP loss, so protection, immunity and Delegator do not
    # leak Freeze onto the real Pokémon behind the blocked hit.
    if kind in ["status", "db_status"] and status_id == "freeze":
        if _zf_actual_damage(target) <= 0:
            return 0.0
        return _zf_apply_status_direct(
            actor,
            target,
            "freeze",
            float(mechanic.get("chance", 1.0))
        )

    # Compiler/runtime packs may represent the central thaw interactions either
    # as runtime flags (handled before the move above) or as explicit mechanics.
    if kind == "thaw":
        _zf_clear_freeze(actor, "🔥 AUFGETAUT")
        return 0.0
    if kind == "thaw_target_if_hit":
        if _zf_actual_damage(target) > 0:
            _zf_clear_freeze(target, "🔥 AUFGETAUT")
        return 0.0

    return super._effect(actor, target, mechanic)


func _zf_apply_status_direct(
    actor: Dictionary,
    target: Dictionary,
    status_id: String,
    chance: float
) -> float:
    var was_frozen: bool = str(target.get("major_status", "")) == "freeze"
    var result: float = super._zf_apply_status_direct(actor, target, status_id, chance)
    if (
        status_id == "freeze"
        and not was_frozen
        and str(target.get("major_status", "")) == "freeze"
    ):
        target["zf_freeze_actions"] = _zf_roll_freeze_actions()
    return result


func _zf_cleanse_major(target: Dictionary) -> float:
    var was_frozen: bool = str(target.get("major_status", "")) == "freeze"
    var result: float = super._zf_cleanse_major(target)
    if was_frozen and str(target.get("major_status", "")) != "freeze":
        target["zf_freeze_actions"] = 0
    return result


func _zf_roll_freeze_actions() -> int:
    return randi_range(ZF_FREEZE_MIN_ACTIONS, ZF_FREEZE_MAX_ACTIONS)


func _zf_consume_freeze_action_budget(actor: Dictionary) -> int:
    var remaining: int = maxi(1, int(actor.get("zf_freeze_actions", 0))) - 1
    actor["zf_freeze_actions"] = remaining
    return remaining


func _zf_activate_wonder_room(actor: Dictionary) -> float:
    _zf_wonder_room_remaining = ZF_WONDER_ROOM_DURATION_SECONDS
    _spawn_feedback_label(actor, "🌀 ANGRIFF ↔ VERTEIDIGUNG", Color("d7c5ff"))
    return 5.0


func _zf_apply_perish_song(actor: Dictionary) -> float:
    var affected: int = 0
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue
        # Recasting never refreshes or resets an existing countdown.
        if int(candidate.get("zf_perish_count", 0)) > 0:
            continue
        candidate["zf_perish_count"] = 3
        candidate["zf_perish_applied_serial"] = int(candidate.get("action_serial", 0))
        affected += 1
        _spawn_feedback_label(candidate, "☠️ ABGESANG 3", Color("d7bfdc"))
    return float(affected) * 3.0


func _zf_tick_perish_after_action(combatant: Dictionary) -> void:
    if not bool(combatant.get("alive", false)):
        return
    var count: int = int(combatant.get("zf_perish_count", 0))
    if count <= 0:
        return
    var current_serial: int = int(combatant.get("action_serial", 0))
    if current_serial <= int(combatant.get("zf_perish_applied_serial", -1)):
        return

    count -= 1
    combatant["zf_perish_count"] = count
    combatant["zf_perish_applied_serial"] = current_serial
    if count > 0:
        _spawn_feedback_label(combatant, "☠️ ABGESANG " + str(count), Color("d7bfdc"))
        return

    combatant["hp"] = 0
    combatant["alive"] = false
    _spawn_feedback_label(combatant, "☠️ ABGESANG · K.O.", Color("e0a9bd"))
    _refresh_cards()
    _check_end()


func _zf_consume_frozen_action(actor: Dictionary) -> void:
    var remaining: int = _zf_consume_freeze_action_budget(actor)
    actor["zf_ally_ko_since_action"] = false
    _begin_counted_action(actor)
    actor["atb"] = 0.0
    actor["cycle"] = 1.0
    actor["accuracy_mult"] = 1.0
    actor["next_cycle"] = 1.0
    _expire_finished_modifiers(actor)
    _spawn_feedback_label(actor, "❄️ EINGEFROREN", Color("bfe9ff"))
    _set_log(_actor_name(actor) + " ist eingefroren und kann nicht handeln.")

    if bool(actor.get("alive", false)):
        _resolve_after_action_effects(actor)
    _zf_tick_perish_after_action(actor)
    _zf_mark_new_knockouts()

    if remaining <= 0 and str(actor.get("major_status", "")) == "freeze":
        _zf_clear_freeze(actor, "❄️ AUFGETAUT")

    _refresh_cards()
    _check_end()


func _zf_clear_freeze(actor: Dictionary, feedback: String) -> void:
    if str(actor.get("major_status", "")) == "freeze":
        actor["major_status"] = ""
        actor["zf_freeze_actions"] = 0
        _spawn_feedback_label(actor, feedback, Color("bfe9ff"))


func _zf_sync_alive_snapshot() -> void:
    _zf_alive_snapshot.clear()
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            _zf_alive_snapshot[str(candidate.get("id", ""))] = bool(candidate.get("alive", false))


func _zf_mark_new_knockouts() -> void:
    if _zf_alive_snapshot.is_empty():
        _zf_sync_alive_snapshot()
        return

    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        var candidate_id: String = str(candidate.get("id", ""))
        var alive_now: bool = bool(candidate.get("alive", false))
        var alive_before: bool = bool(_zf_alive_snapshot.get(candidate_id, alive_now))
        if alive_before and not alive_now:
            var side: String = str(candidate.get("side", ""))
            for ally_value: Variant in _team_for_side(side):
                if not (ally_value is Dictionary):
                    continue
                var ally: Dictionary = ally_value
                if (
                    bool(ally.get("alive", false))
                    and str(ally.get("id", "")) != candidate_id
                ):
                    ally["zf_ally_ko_since_action"] = true
        _zf_alive_snapshot[candidate_id] = alive_now


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if str(combatant.get("major_status", "")) == "freeze":
        tokens.append("❄️ GFR")
    var perish: int = int(combatant.get("zf_perish_count", 0))
    if perish > 0:
        tokens.append("☠️ " + str(perish))
    if _zf_wonder_room_remaining > 0.01:
        tokens.append("🌀 WUNDER")
    return tokens
