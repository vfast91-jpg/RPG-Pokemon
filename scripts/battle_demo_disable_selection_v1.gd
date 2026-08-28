extends "res://scripts/battle_demo_boss_reinforcement_stability_v2.gd"

# Final move-selection and runtime bridge for Timeflow Disable (Aussetzer).
# Selection, AI legality and the runtime application all share the same single
# three-own-action state from move_disable_state.gd.

const MoveDisableState = preload("res://scripts/battle/move_disable_state.gd")


func _tf_move_is_selectable(actor: Dictionary, move_id: String) -> bool:
    return not MoveDisableState.blocks_move_id(actor, move_id)


func _prompt_player(actor: Dictionary) -> void:
    super._prompt_player(actor)
    _tf_refresh_disable_move_buttons(actor)


func _tf_refresh_disable_move_buttons(actor: Dictionary) -> void:
    if action_grid == null:
        return

    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        return

    var actor_moves: Array = moves_value as Array
    var move_index: int = 0
    for child: Node in action_grid.get_children():
        if move_index >= actor_moves.size():
            break
        if not (child is Button):
            continue

        var button: Button = child as Button
        var move_id: String = str(actor_moves[move_index])
        move_index += 1

        if _tf_move_is_selectable(actor, move_id):
            continue

        button.disabled = true
        button.text += " · 🚫 AUSSETZER"
        var remaining: int = MoveDisableState.remaining_actions(actor)
        button.tooltip_text += (
            "\nAussetzer: Diese Attacke ist noch für %d eigene Aktion%s gesperrt."
            % [remaining, "" if remaining == 1 else "en"]
        )


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return

    var actor: Dictionary = selected_actor
    if not _tf_move_is_selectable(actor, move_id):
        var move: Dictionary = _move_data(move_id)
        _set_log(
            _actor_name(actor) + " kann "
            + str(move.get("name", move_id))
            + " wegen Aussetzer nicht einsetzen."
        )
        _tf_refresh_disable_move_buttons(actor)
        return

    super._choose_move(move_id)


func _enemy_act(actor: Dictionary) -> void:
    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array) or (moves_value as Array).is_empty():
        super._enemy_act(actor)
        return

    var original_moves: Array = (moves_value as Array).duplicate()
    var legal_moves: Array = []
    for move_value: Variant in original_moves:
        var move_id: String = str(move_value)
        if _tf_move_is_selectable(actor, move_id):
            legal_moves.append(move_id)

    if legal_moves.size() == original_moves.size():
        super._enemy_act(actor)
        return

    if legal_moves.is_empty():
        # Warten remains legal and, through the existing central wait path,
        # counts as exactly one own action. This guarantees that Disable can
        # expire even when it temporarily blocks the AI's only move.
        selected_actor = actor
        super._choose_wait()
        return

    # Reuse the complete existing AI path with a temporary legal candidate
    # list. Restore the combatant's real learned move list immediately after
    # selection so Disable never deletes or rewrites moves.
    actor["moves"] = legal_moves
    super._enemy_act(actor)
    actor["moves"] = original_moves


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var previous_last_move: String = str(actor.get("db_last_move", ""))
    var resolved_move_id: String = _tf_resolved_move_id(actor, move_id)
    var move: Dictionary = _move_data(resolved_move_id)
    var runtime_value: Variant = move.get("runtime", {}) if not move.is_empty() else {}
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var disable_target_ids: Array[String] = []
    if bool(runtime.get("timeflow_disable", false)):
        disable_target_ids = _tf_target_ids(actor, move)

    var before_log: String = log_label.get_parsed_text() if log_label != null else ""
    super._execute_move(actor, move_id)

    var successful_use: bool = _tf_move_was_successfully_used(
        resolved_move_id,
        move,
        before_log
    )

    # The database sequence currently records a move after an accuracy miss as
    # db_last_move as well. Disable needs the last successfully used move, so a
    # miss must leave the previous successful value intact. Likewise a technical
    # action such as recharge must not erase an already known successful move.
    if _tf_move_was_missed(resolved_move_id, move, before_log):
        actor["db_last_move"] = previous_last_move
    elif str(actor.get("db_last_move", "")).is_empty() and not previous_last_move.is_empty():
        actor["db_last_move"] = previous_last_move

    if successful_use and bool(runtime.get("timeflow_disable", false)):
        _tf_apply_disable(disable_target_ids)


func _tf_resolved_move_id(actor: Dictionary, requested_move_id: String) -> String:
    var forced_move_id: String = str(actor.get("db_forced_move_id", ""))
    if not forced_move_id.is_empty() and forced_move_id != requested_move_id:
        return forced_move_id
    return requested_move_id


func _tf_target_ids(actor: Dictionary, move: Dictionary) -> Array[String]:
    var result: Array[String] = []
    if move.is_empty():
        return result

    for target_value: Variant in _targets(
        actor,
        str(move.get("target", "enemy_highest_aggro"))
    ):
        if not (target_value is Dictionary):
            continue
        var target_id: String = str((target_value as Dictionary).get("id", ""))
        if not target_id.is_empty() and not result.has(target_id):
            result.append(target_id)
    return result


func _tf_move_was_successfully_used(
    move_id: String,
    move: Dictionary,
    before_log: String
) -> bool:
    if log_label == null or move.is_empty():
        return false
    var after_log: String = log_label.get_parsed_text()
    if after_log == before_log:
        return false
    var move_name: String = str(move.get("name", move_id))
    if after_log.contains("verfehlt") and after_log.contains(move_name):
        return false
    return after_log.contains("nutzt") and after_log.contains(move_name)


func _tf_move_was_missed(
    move_id: String,
    move: Dictionary,
    before_log: String
) -> bool:
    if log_label == null or move.is_empty():
        return false
    var after_log: String = log_label.get_parsed_text()
    if after_log == before_log:
        return false
    var move_name: String = str(move.get("name", move_id))
    return after_log.contains("verfehlt") and after_log.contains(move_name)


func _tf_apply_disable(target_ids: Array[String]) -> void:
    for target_id: String in target_ids:
        var target: Dictionary = _tf_combatant_by_id(target_id)
        if target.is_empty():
            continue

        var last_move_id: String = str(target.get("db_last_move", ""))
        if not _tf_disable_candidate_is_valid(target, last_move_id):
            continue

        # apply() owns replacement/refresh semantics: there is always exactly
        # one Disable state per Pokemon and its expiry is current own serial + 3.
        MoveDisableState.apply(target, last_move_id, 3)


func _tf_disable_candidate_is_valid(target: Dictionary, move_id: String) -> bool:
    if move_id.is_empty():
        return false

    var moves_value: Variant = target.get("moves", [])
    if not (moves_value is Array) or not (moves_value as Array).has(move_id):
        return false

    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return false

    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary and (runtime_value as Dictionary).has("runtime_supported"):
        if not bool((runtime_value as Dictionary).get("runtime_supported", true)):
            return false
    return true


func _tf_combatant_by_id(combatant_id: String) -> Dictionary:
    if combatant_id.is_empty():
        return {}
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value as Dictionary
        if str(combatant.get("id", "")) == combatant_id:
            return combatant
    return {}
