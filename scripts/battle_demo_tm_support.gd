extends "res://scripts/battle_demo_weather.gd"

# Runtime bridge for route-earned TMs.
#
# The route stores learned TM moves on the individual Pokémon. This layer adds
# those moves to the combatant when a persistent route battle starts and
# implements the two mechanics currently needed by Bisasam's TM data:
# recoil (Bodycheck) and a one-use protective guard (Schutzschild).

var _tm_blocked_target_ids: Dictionary = {}


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["protective_guard"] = false
    return combatant


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
        var state_value: Variant = _route_team_state[team_index]
        var combatant_value: Variant = player_team[local_index]
        if state_value is Dictionary and combatant_value is Dictionary:
            _apply_route_tm_moves(combatant_value, state_value)


func _apply_route_tm_moves(combatant: Dictionary, member_state: Dictionary) -> void:
    var tm_moves_value: Variant = member_state.get("tm_moves", [])
    if not (tm_moves_value is Array):
        return

    var runtime_data_value: Variant = get("data")
    if not (runtime_data_value is Dictionary):
        return
    var runtime_moves_value: Variant = (runtime_data_value as Dictionary).get("moves", {})
    if not (runtime_moves_value is Dictionary):
        return
    var runtime_moves: Dictionary = runtime_moves_value

    var moves_value: Variant = combatant.get("moves", [])
    var moves: Array = moves_value.duplicate() if moves_value is Array else []
    for move_value: Variant in tm_moves_value:
        var move_id: String = str(move_value)
        if runtime_moves.has(move_id) and not moves.has(move_id):
            moves.append(move_id)
    combatant["moves"] = moves


func _execute_move(actor: Dictionary, move_id: String) -> void:
    _tm_blocked_target_ids.clear()
    super._execute_move(actor, move_id)
    _tm_blocked_target_ids.clear()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    var resolved_target: Dictionary = target
    if str(mechanic.get("scope", "")) == "self":
        resolved_target = actor

    if kind == "protective_guard":
        resolved_target["protective_guard"] = true
        _spawn_feedback_label(resolved_target, "🛡️ SCHUTZSCHILD", Color("9fe7bd"))
        return 4.0

    if kind == "recoil":
        # Recoil is based on actual damage and is therefore resolved in _damage.
        return 0.0

    if _tm_guard_blocks(actor, resolved_target):
        return 0.0

    return super._effect(actor, target, mechanic)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    if _tm_guard_blocks(actor, target):
        return 0

    var hp_before: int = maxi(0, int(target.get("hp", 0)))
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0:
        return damage

    var actual_damage: int = mini(damage, hp_before)
    if actual_damage > 0 and str(actor.get("id", "")) != str(target.get("id", "")):
        _apply_tm_recoil(actor, actual_damage)
    return damage


func _tm_guard_blocks(actor: Dictionary, target: Dictionary) -> bool:
    if str(actor.get("side", "")) == str(target.get("side", "")):
        return false

    var target_id: String = str(target.get("id", ""))
    if target_id.is_empty():
        return false
    if bool(_tm_blocked_target_ids.get(target_id, false)):
        return true
    if not bool(target.get("protective_guard", false)):
        return false

    target["protective_guard"] = false
    _tm_blocked_target_ids[target_id] = true
    _spawn_feedback_label(target, "🛡️ GEBLOCKT", Color("9fe7bd"))
    return true


func _apply_tm_recoil(actor: Dictionary, actual_damage: int) -> void:
    if actual_damage <= 0:
        return

    var move_value: Variant = _active_special_move
    if not (move_value is Dictionary):
        return
    var move: Dictionary = move_value
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return

    var fraction: float = 0.0
    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        if str(mechanic.get("kind", "")) == "recoil":
            fraction = maxf(0.0, float(mechanic.get("fraction", 0.25)))
            break

    if fraction <= 0.0:
        return

    var current_hp: int = maxi(0, int(actor.get("hp", 0)))
    if current_hp <= 0:
        return
    var requested: int = maxi(1, int(round(float(actual_damage) * fraction)))
    var recoil: int = mini(requested, current_hp)
    actor["hp"] = current_hp - recoil
    _spawn_feedback_label(actor, "💢 RÜCKSTOSS −" + str(recoil), Color("ffb08c"))
    if int(actor.get("hp", 0)) <= 0:
        actor["alive"] = false


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if bool(combatant.get("protective_guard", false)):
        tokens.append("🛡️ SCHUTZ")
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var detail: String = super._detail_info(combatant)
    if bool(combatant.get("protective_guard", false)):
        detail += "\n\n🛡️ Schutzschild: blockiert die nächste gegnerische Attacke, die dieses Pokémon betrifft."
    return detail
