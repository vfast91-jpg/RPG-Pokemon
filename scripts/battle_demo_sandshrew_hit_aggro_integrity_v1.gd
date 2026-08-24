extends "res://scripts/battle_demo_target_marker_clean_v1.gd"

# Final Sandan/Sandamer hit-integrity correction.
#
# Zermalmklaue and Sandgrab both consist of direct damage followed by a harmful
# secondary mechanic. The inherited generic mechanic loop executes the second
# mechanic after accuracy succeeds even when the damage itself was fully blocked
# by protection or type immunity. Snapshot the intended target before resolution
# and require actual HP or Delegator-HP loss before either follow-up may run.
# Delegator damage deliberately counts as a connected hit; the existing central
# Delegator interceptor remains responsible for blocking the harmful follow-up
# from reaching the Pokemon behind it.
#
# Binding also used an old flat +4 effect-Aggro value. Binding's real Timeflow
# effect is its later periodic damage, so no speculative flat Aggro is awarded on
# application. Each binding tick instead credits the source with exactly the KP
# damage that actually happened.

const SAND_HIT_GUARDED_MOVES: Array[String] = ["crush_claw", "sand_tomb"]

var _sand_followup_move_id: String = ""
var _sand_followup_snapshots: Dictionary = {}


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var previous_move_id: String = _sand_followup_move_id
    var previous_snapshots: Dictionary = _sand_followup_snapshots

    if SAND_HIT_GUARDED_MOVES.has(move_id):
        var move: Dictionary = _move_data(move_id)
        _sand_followup_move_id = move_id
        _sand_followup_snapshots = _pika_target_snapshots(actor, move)
    else:
        _sand_followup_move_id = ""
        _sand_followup_snapshots = {}

    super._execute_move(actor, move_id)

    _sand_followup_move_id = previous_move_id
    _sand_followup_snapshots = previous_snapshots


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if (
        _sand_followup_requires_connected_hit(_sand_followup_move_id, kind)
        and not _sand_followup_connected(target)
    ):
        return 0.0
    return super._effect(actor, target, mechanic)


func _sand_followup_requires_connected_hit(move_id: String, mechanic_kind: String) -> bool:
    if move_id == "crush_claw":
        return mechanic_kind == "db_chance_mechanic"
    if move_id == "sand_tomb":
        return mechanic_kind == "binding"
    return false


func _sand_followup_connected(target: Dictionary) -> bool:
    var target_id: String = str(target.get("id", ""))
    if target_id.is_empty():
        return false

    var entry_value: Variant = _sand_followup_snapshots.get(target_id, {})
    if not (entry_value is Dictionary):
        return false
    return _pika_snapshot_target_hit(entry_value)


func _apply_binding(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    # Keep the complete inherited binding state/feedback setup, but remove the
    # historical flat effect-Aggro. Actual residual damage is credited per tick.
    super._apply_binding(actor, target, mechanic)
    return 0.0


func _resolve_binding_tick(target: Dictionary) -> void:
    var binding_value: Variant = target.get("binding_effect", {})
    if not (binding_value is Dictionary) or (binding_value as Dictionary).is_empty():
        super._resolve_binding_tick(target)
        return

    var source: Dictionary = _effect_source_occupant(binding_value as Dictionary)
    var hp_before: int = int(target.get("hp", 0))

    super._resolve_binding_tick(target)

    if source.is_empty():
        return
    _credit_actual_binding_damage_aggro(source, hp_before, int(target.get("hp", 0)))


func _credit_actual_binding_damage_aggro(
    source: Dictionary,
    hp_before: int,
    hp_after: int
) -> int:
    var actual_damage: int = maxi(0, hp_before - hp_after)
    if actual_damage <= 0 or source.is_empty():
        return 0
    source["aggro"] = float(source.get("aggro", 0.0)) + float(actual_damage)
    return actual_damage
