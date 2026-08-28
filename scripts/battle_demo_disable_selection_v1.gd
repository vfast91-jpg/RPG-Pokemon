extends "res://scripts/battle_demo_boss_reinforcement_stability_v2.gd"

# Final move-selection legality layer for Timeflow Disable (Aussetzer).
# It deliberately changes selection only: applying Disable remains owned by the
# dedicated runtime step that follows this integration.

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
