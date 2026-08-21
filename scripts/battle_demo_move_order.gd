extends "res://scripts/battle_demo_status_curve_final.gd"

# Route-only presentation bridge: the move order chosen in the between-battle
# team view is applied after the normal combatant setup (including TM moves).
# No combat rules or move availability are changed.


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not route_mode or not battle_active:
        return

    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        if team_index < 0 or team_index >= _route_team_state.size():
            continue

        var combatant_value: Variant = player_team[local_index]
        var member_value: Variant = _route_team_state[team_index]
        if combatant_value is Dictionary and member_value is Dictionary:
            _apply_route_move_order(combatant_value as Dictionary, member_value as Dictionary)

    _refresh_cards()


func _apply_route_move_order(combatant: Dictionary, member_state: Dictionary) -> void:
    var current_value: Variant = combatant.get("moves", [])
    if not (current_value is Array):
        return

    var current: Array[String] = []
    for move_value: Variant in current_value:
        var move_id: String = str(move_value)
        if not move_id.is_empty() and not current.has(move_id):
            current.append(move_id)

    var ordered: Array[String] = []
    var stored_value: Variant = member_state.get("move_order", [])
    if stored_value is Array:
        for move_value: Variant in stored_value:
            var move_id: String = str(move_value)
            if current.has(move_id) and not ordered.has(move_id):
                ordered.append(move_id)

    # Newly learned or newly acquired TM moves that are not in the saved order
    # are appended, so the player never loses access to an attack.
    for move_id: String in current:
        if not ordered.has(move_id):
            ordered.append(move_id)

    combatant["moves"] = ordered
