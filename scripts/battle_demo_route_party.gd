extends "res://scripts/battle_demo_chat_polish.gd"

# Demo-route extension for real 1–4 vs. 1–4 encounters.
# The normal configurable test battle remains unchanged.

var _route_enemy_party: Array = []


func start_route_battle_party(team_state: Array, enemy_party: Array) -> void:
    route_mode = true
    _route_team_state = team_state.duplicate(true)
    _route_enemy_party = enemy_party.duplicate(true)
    _route_enemy_state = {}
    visible = true
    _route_begin_wave()


func route_stat_snapshot(species_id: String, level: int) -> Dictionary:
    var combatant: Dictionary = _make_combatant(
        "player",
        0,
        {"species_id": species_id, "level": maxi(1, level)}
    )
    return {
        "max_hp": int(combatant.get("max_hp", 1)),
        "attack": int(combatant.get("attack", 1)),
        "defense": int(combatant.get("defense", 1)),
        "special": int(combatant.get("special", 1)),
        "speed": int(combatant.get("speed", 1))
    }


func _route_begin_wave() -> void:
    _route_active_indices.clear()
    player_setup.clear()
    enemy_setup.clear()

    for index: int in range(_route_team_state.size()):
        var member_value: Variant = _route_team_state[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue
        _route_active_indices.append(index)
        player_setup.append({
            "species_id": str(member.get("species_id", "")),
            "level": maxi(1, int(member.get("level", 1)))
        })
        if player_setup.size() >= ROUTE_ACTIVE_MAX:
            break

    if player_setup.is_empty():
        route_mode = false
        visible = false
        route_battle_finished.emit(false, _route_team_state.duplicate(true))
        return

    for enemy_value: Variant in _route_enemy_party:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        enemy_setup.append({
            "species_id": str(enemy.get("species_id", "")),
            "level": maxi(1, int(enemy.get("level", 1)))
        })
        if enemy_setup.size() >= ROUTE_ACTIVE_MAX:
            break

    if enemy_setup.is_empty():
        route_mode = false
        visible = false
        route_battle_finished.emit(true, _route_team_state.duplicate(true))
        return

    _start_battle()

    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        var state_value: Variant = _route_team_state[team_index]
        if state_value is Dictionary:
            _route_apply_state(player_team[local_index], state_value)

    _refresh_cards()
    _set_log(
        "Der Etappenkampf beginnt: %d gegen %d. KP und Status bleiben zwischen Kämpfen erhalten."
        % [player_team.size(), enemy_team.size()]
    )


func _route_store_current_state() -> void:
    # Only the travelling team persists between route encounters.
    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        var combatant_value: Variant = player_team[local_index]
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var member_value: Variant = _route_team_state[team_index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        member["level"] = int(combatant.get("level", member.get("level", 1)))
        member["max_hp"] = int(combatant.get("max_hp", member.get("max_hp", 1)))
        member["hp"] = int(combatant.get("hp", 0))
        member["major_status"] = str(combatant.get("major_status", ""))
        _route_team_state[team_index] = member
