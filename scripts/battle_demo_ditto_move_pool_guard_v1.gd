extends "res://scripts/battle_demo_tempo_guard_v1.gd"

# Final Wandler move-pool integrity guard.
#
# Transform itself already copies target["moves"] correctly. The active battle
# stack contains later selection/runtime layers that may temporarily replace an
# AI combatant's moves and restore an older snapshot after the nested action.
# If that happens during Transform, the visible form/stats stay transformed but
# Ditto can fall back to its original ["transform"] pool and become unusable.
#
# Keep this guard deliberately narrow: it repairs only a transformed combatant
# whose live move pool is empty or has fallen back exactly to the pre-Transform
# snapshot. Legitimate later battle-local move changes are otherwise untouched.


func _execute_move(actor: Dictionary, move_id: String) -> void:
    super._execute_move(actor, move_id)
    _ditto_repair_transformed_move_pool(actor)


func _enemy_act(actor: Dictionary) -> void:
    # Repair before AI selection in case an earlier asynchronous/opening path
    # restored the stale pool, then verify once more after the resolved action.
    _ditto_repair_transformed_move_pool(actor)
    super._enemy_act(actor)
    _ditto_repair_transformed_move_pool(actor)


func _finish_opening_phase() -> void:
    # Runde 0 is implemented in an older ancestor and invokes its parent
    # _execute_move directly. Therefore its Transform action can bypass the leaf
    # _execute_move override above. Guard the explicit opening-phase boundary too.
    _ditto_repair_all_transformed_move_pools()
    super._finish_opening_phase()
    _ditto_repair_all_transformed_move_pools()


func _ditto_repair_all_transformed_move_pools() -> void:
    for combatant_value: Variant in combatants:
        if combatant_value is Dictionary:
            _ditto_repair_transformed_move_pool(combatant_value as Dictionary)


func _ditto_repair_transformed_move_pool(actor: Dictionary) -> bool:
    if actor.is_empty() or not bool(actor.get("f64_transformed", false)):
        return false

    var current_value: Variant = actor.get("moves", [])
    var original_value: Variant = actor.get(DITTO_TRANSFORM_ORIGINAL_MOVES_KEY, [])
    if not (current_value is Array) or not (original_value is Array):
        return false

    var current_moves: Array = current_value as Array
    var original_moves: Array = original_value as Array

    # Do not police transformed move pools continuously. Once another mechanic
    # has intentionally changed the copied pool, that battle-local state wins.
    # Only the known regression states are repaired: empty or stale-original.
    if not current_moves.is_empty() and current_moves != original_moves:
        return false

    var target_id: String = str(actor.get("f64_transform_target_id", ""))
    if target_id.is_empty():
        return false

    var target: Dictionary = {}
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value as Dictionary
        if str(candidate.get("id", "")) == target_id:
            target = candidate
            break

    if target.is_empty():
        return false

    var target_moves_value: Variant = target.get("moves", [])
    if not (target_moves_value is Array) or (target_moves_value as Array).is_empty():
        return false

    actor["moves"] = (target_moves_value as Array).duplicate(true)
    return true
