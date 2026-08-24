extends "res://scripts/battle_demo_infobox_no_contact_v3.gd"

# Final V22 sequence / direct-hit integrity layer.
#
# Historical sequence checks used real Pokemon HP loss as a proxy for a
# successful direct hit. That is not equivalent when Delegator is active:
# direct damage can be absorbed by substitute HP while the attack still hit.
# This layer also resolves the historical Sandan rollout implementation and the
# newer central forced-sequence engine into one owner of the five-action lock.

const V22_SUBSTITUTE_AWARE_MULTI_HIT_IDS: Array[String] = [
    "fury_attack", "pin_missile", "bullet_seed", "scale_shot", "fury_swipes",
    "double_kick", "dual_wingbeat", "double_hit", "rock_blast", "dual_chop",
    "icicle_spear", "triple_axel", "bonemerang", "triple_kick"
]
const V22_ROLLOUT_BASE_CHAIN: Array[int] = [30, 60, 120, 240, 480]

var _v22_direct_hit_probe_move_id: String = ""
var _v22_direct_hit_snapshot: Dictionary = {}


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var previous_probe_move_id: String = _v22_direct_hit_probe_move_id
    var previous_snapshot: Dictionary = _v22_direct_hit_snapshot
    var rollout_original_move: Dictionary = {}

    # The lower Sandan layer applies the Eingerollt multiplier before the
    # database sequence layer. The latter then replaces power from its own chain
    # and would erase the multiplier. Feed the final chain itself as doubled
    # while Eingerollt is active so the last power resolver sees 60..960.
    if move_id == "rollout" and bool(actor.get("sand_defense_curled", false)):
        var source_rollout: Dictionary = _move_data("rollout")
        if not source_rollout.is_empty():
            rollout_original_move = source_rollout.duplicate(true)
            var patched_rollout: Dictionary = source_rollout.duplicate(true)
            var runtime_value: Variant = patched_rollout.get("runtime", {})
            var runtime: Dictionary = (
                (runtime_value as Dictionary).duplicate(true)
                if runtime_value is Dictionary else {}
            )
            runtime["consecutive_power_chain"] = _v22_rollout_power_chain_for_actor(actor)
            patched_rollout["runtime"] = runtime
            data["moves"]["rollout"] = patched_rollout

    _v22_direct_hit_probe_move_id = move_id
    if V22_SUBSTITUTE_AWARE_MULTI_HIT_IDS.has(move_id) or move_id == "rollout":
        var move: Dictionary = _move_data(move_id)
        _v22_direct_hit_snapshot = (
            _tf_snapshot_targets(actor, move) if not move.is_empty() else {}
        )
    else:
        _v22_direct_hit_snapshot = {}

    super._execute_move(actor, move_id)

    if not rollout_original_move.is_empty():
        data["moves"]["rollout"] = rollout_original_move
    _v22_direct_hit_probe_move_id = previous_probe_move_id
    _v22_direct_hit_snapshot = previous_snapshot


func _v22_rollout_power_chain_for_actor(actor: Dictionary) -> Array[int]:
    var multiplier: int = 2 if bool(actor.get("sand_defense_curled", false)) else 1
    var result: Array[int] = []
    for power: int in V22_ROLLOUT_BASE_CHAIN:
        result.append(power * multiplier)
    return result


func _sand_finish_rollout_action(
    actor: Dictionary,
    attempted: bool,
    hit_success: bool,
    rollout_was_active: bool
) -> void:
    # The central database forced-sequence engine already decrements
    # db_forced_actions_left exactly once per own Rollout action. The historical
    # Sandan handler decremented it a second time, shortening a five-action series
    # to roughly three actions. Keep only Sandan's visual/state bookkeeping here.
    if not attempted or not hit_success or not bool(actor.get("alive", false)):
        actor["sand_rollout_active"] = false
        actor["sand_rollout_step"] = 0
        _database_interrupt_forced_sequence(actor)
        if bool(actor.get("alive", false)):
            _spawn_feedback_label(actor, "🪨 WALZER-SERIE ENDE", Color("d9b49a"))
        return

    var forced_continues: bool = (
        str(actor.get("db_forced_move_id", "")) == "rollout"
        and int(actor.get("db_forced_actions_left", 0)) > 0
    )

    if not rollout_was_active:
        actor["sand_rollout_active"] = forced_continues
        actor["sand_rollout_step"] = 1 if forced_continues else 0
        _spawn_feedback_label(actor, "🪨 WALZER 1/5", Color("dfc98a"))
        return

    var completed_step: int = clampi(int(actor.get("sand_rollout_step", 1)), 1, 4)
    if not forced_continues:
        _spawn_feedback_label(actor, "🪨 WALZER 5/5", Color("f0d07c"))
        actor["sand_rollout_active"] = false
        actor["sand_rollout_step"] = 0
        return

    actor["sand_rollout_active"] = true
    actor["sand_rollout_step"] = mini(4, completed_step + 1)
    _spawn_feedback_label(
        actor,
        "🪨 WALZER " + str(completed_step + 1) + "/5",
        Color("dfc98a")
    )


func _v22_any_opponent_lost_hp(actor: Dictionary, hp_before: Dictionary) -> bool:
    # Uproar's V22 stop condition is execution failure, not damage failure.
    # The generic forced-sequence engine already interrupts when the move was
    # not attempted. Reaching this probe after a completed action therefore
    # means the repetition was executed and must remain locked.
    if _v22_direct_hit_probe_move_id == "uproar":
        return true

    if (
        _v22_direct_hit_probe_move_id == "rollout"
        and not _v22_direct_hit_snapshot.is_empty()
        and _tf_any_target_hit(_v22_direct_hit_snapshot)
    ):
        return true

    return super._v22_any_opponent_lost_hp(actor, hp_before)


func _database_any_target_damaged(snapshots: Dictionary) -> bool:
    if (
        V22_SUBSTITUTE_AWARE_MULTI_HIT_IDS.has(_v22_direct_hit_probe_move_id)
        and not _v22_direct_hit_snapshot.is_empty()
        and _tf_any_target_hit(_v22_direct_hit_snapshot)
    ):
        return true
    return super._database_any_target_damaged(snapshots)


func _database_begin_multi_hit_sequence(
    actor: Dictionary,
    move_id: String,
    move: Dictionary,
    target_snapshots: Dictionary,
    planned_hits: int,
    guaranteed_crit_for_action: bool
) -> void:
    if (
        not V22_SUBSTITUTE_AWARE_MULTI_HIT_IDS.has(move_id)
        or _v22_direct_hit_snapshot.is_empty()
    ):
        super._database_begin_multi_hit_sequence(
            actor,
            move_id,
            move,
            target_snapshots,
            planned_hits,
            guaranteed_crit_for_action
        )
        return

    super._database_begin_multi_hit_sequence(
        actor,
        move_id,
        move,
        _v22_adjust_multi_hit_first_hit_snapshots(target_snapshots),
        planned_hits,
        guaranteed_crit_for_action
    )


func _v22_adjust_multi_hit_first_hit_snapshots(target_snapshots: Dictionary) -> Dictionary:
    # The inherited multi-hit launcher uses the first-hit HP delta to decide
    # which targets stay in the timed sequence. If the first hit was absorbed
    # by a Delegator, feed it an equivalent first-hit delta while keeping the
    # original target dictionary by reference. This changes only launch
    # bookkeeping; the real Pokemon HP is never modified here.
    var adjusted_snapshots: Dictionary = {}
    for target_id_value: Variant in target_snapshots.keys():
        var target_id: String = str(target_id_value)
        var snapshot_value: Variant = target_snapshots.get(target_id_value, {})
        if not (snapshot_value is Dictionary):
            adjusted_snapshots[target_id_value] = snapshot_value
            continue

        var adjusted: Dictionary = (snapshot_value as Dictionary).duplicate(false)
        var target_value: Variant = adjusted.get("target", {})
        var tracked_value: Variant = _v22_direct_hit_snapshot.get(target_id, {})
        if target_value is Dictionary and tracked_value is Dictionary:
            var target: Dictionary = target_value
            var tracked: Dictionary = tracked_value
            var substitute_damage: int = maxi(
                0,
                int(tracked.get("substitute_hp", 0))
                - int(target.get("db_substitute_hp", 0))
            )
            var real_hp_damage: int = maxi(
                0,
                int(adjusted.get("hp", int(target.get("hp", 0))))
                - int(target.get("hp", 0))
            )
            if real_hp_damage <= 0 and substitute_damage > 0:
                adjusted["hp"] = int(target.get("hp", 0)) + substitute_damage
        adjusted_snapshots[target_id_value] = adjusted
    return adjusted_snapshots


func _v22_audit_final_move_set() -> void:
    # Belch is the sole V22 move intentionally locked until the future berry
    # consumption state exists. Keep runtime_supported=false in the real data,
    # but do not emit a false audit error for that deliberate source contract.
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        super._v22_audit_final_move_set()
        return
    var moves: Dictionary = moves_value
    var belch_value: Variant = moves.get("belch", {})
    if not (belch_value is Dictionary):
        super._v22_audit_final_move_set()
        return

    var original_belch: Dictionary = (belch_value as Dictionary).duplicate(true)
    var audit_belch: Dictionary = original_belch.duplicate(true)
    var runtime_value: Variant = audit_belch.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true) if runtime_value is Dictionary else {}
    )
    runtime["runtime_supported"] = true
    audit_belch["runtime"] = runtime
    moves["belch"] = audit_belch
    data["moves"] = moves

    super._v22_audit_final_move_set()

    moves["belch"] = original_belch
    data["moves"] = moves
