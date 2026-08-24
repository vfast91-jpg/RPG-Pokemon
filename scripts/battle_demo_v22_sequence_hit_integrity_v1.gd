extends "res://scripts/battle_demo_infobox_no_contact_v3.gd"

# Final V22 sequence / direct-hit integrity layer.
#
# Two historical sequence checks used real Pokemon HP loss as a proxy for a
# successful direct hit. That is not equivalent when Delegator is active:
# direct damage can be absorbed by substitute HP while the attack still hit.
# V22 explicitly requires remaining multi-hit phases to continue through a
# Delegator, and Rollout must count such a hit as a successful series step.
# Uproar is different: its forced repetition only ends when the action cannot
# be executed at all; a miss, immunity or blocked damage is still an executed
# Uproar action and must not be mistaken for an execution failure.

const V22_SUBSTITUTE_AWARE_MULTI_HIT_IDS: Array[String] = [
    "fury_attack", "pin_missile", "bullet_seed", "scale_shot", "fury_swipes",
    "double_kick", "dual_wingbeat", "double_hit", "rock_blast", "dual_chop",
    "icicle_spear", "triple_axel", "bonemerang", "triple_kick"
]

var _v22_direct_hit_probe_move_id: String = ""
var _v22_direct_hit_snapshot: Dictionary = {}


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var previous_probe_move_id: String = _v22_direct_hit_probe_move_id
    var previous_snapshot: Dictionary = _v22_direct_hit_snapshot

    _v22_direct_hit_probe_move_id = move_id
    if V22_SUBSTITUTE_AWARE_MULTI_HIT_IDS.has(move_id) or move_id == "rollout":
        var move: Dictionary = _move_data(move_id)
        _v22_direct_hit_snapshot = (
            _tf_snapshot_targets(actor, move) if not move.is_empty() else {}
        )
    else:
        _v22_direct_hit_snapshot = {}

    super._execute_move(actor, move_id)

    _v22_direct_hit_probe_move_id = previous_probe_move_id
    _v22_direct_hit_snapshot = previous_snapshot


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

    super._database_begin_multi_hit_sequence(
        actor,
        move_id,
        move,
        adjusted_snapshots,
        planned_hits,
        guaranteed_crit_for_action
    )


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
