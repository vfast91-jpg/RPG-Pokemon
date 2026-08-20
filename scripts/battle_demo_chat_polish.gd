extends "res://scripts/battle_demo_special_mechanics.gd"

signal route_battle_finished(victory: bool, team_state: Array)
signal request_main_menu

# Small player-facing polish layer:
# - Damage move previews always show their power directly in the first line.
# - The player-facing name of the internal `special` stat is "Status".
# - Ruckzuckhieb uses the current opening-move balance value (Stärke 20).
# - Opening/Runde-0 damage moves are audited against the central balance rule.
# - The same battle UI can also serve the persistent ten-stage demo route.

const OPENING_BALANCE_PATH: String = "res://data/rules/opening_move_balance.json"
const FALLBACK_OPENING_POWER_CAP: int = 20
const ROUTE_ACTIVE_MAX: int = 4

var route_mode: bool = false
var _route_team_state: Array = []
var _route_active_indices: Array[int] = []
var _route_enemy_state: Dictionary = {}


func _load_data() -> void:
    super._load_data()
    _apply_current_balance_overrides()
    _audit_opening_damage_balance()


func _build_config(root: Control) -> void:
    super._build_config(root)
    if config_panel == null or config_panel.get_child_count() == 0:
        return

    var outer := config_panel.get_child(0) as VBoxContainer
    if outer == null:
        return

    var menu_button := Button.new()
    menu_button.text = "HAUPTMENÜ"
    menu_button.custom_minimum_size = Vector2(120, 25)
    menu_button.pressed.connect(_on_main_menu_pressed)
    outer.add_child(menu_button)


func _on_main_menu_pressed() -> void:
    battle_active = false
    paused = false
    route_mode = false
    visible = false
    request_main_menu.emit()


func _apply_current_balance_overrides() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return

    var moves: Dictionary = moves_value
    var quick_attack_value: Variant = moves.get("quick_attack", {})
    if quick_attack_value is Dictionary:
        var quick_attack: Dictionary = quick_attack_value
        quick_attack["power"] = 20
        moves["quick_attack"] = quick_attack
        data["moves"] = moves


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    if log_label == null:
        return

    var power_value: Variant = move.get("power", null)
    if power_value == null:
        return

    var marker: String = " · AP "
    if not log_label.text.contains(marker):
        return

    var power: int = int(round(float(power_value)))
    log_label.text = log_label.text.replace(
        marker,
        " · Stärke " + str(power) + marker
    )


func _detail_info(combatant: Dictionary) -> String:
    # Keep the stable internal data key `special`; only the player-facing label changes.
    return super._detail_info(combatant).replace("Spezial ", "Status ")


func _audit_opening_damage_balance() -> void:
    var power_cap: int = _opening_power_cap()
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return

    var moves: Dictionary = moves_value
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            continue

        var move: Dictionary = move_value
        if not bool(move.get("opening", false)):
            continue
        if str(move.get("category", "status")) == "status":
            continue

        var power_value: Variant = move.get("power", null)
        if power_value == null:
            continue
        var power: int = int(round(float(power_value)))
        if power <= power_cap:
            continue

        push_warning(
            "Runde-0-Balance: " + str(move.get("name", move_id))
            + " hat Stärke " + str(power)
            + ", empfohlenes Maximum ist " + str(power_cap)
            + ". Schnelle Eröffnungsattacken müssen deutlich schwächer sein."
        )


func _opening_power_cap() -> int:
    if not FileAccess.file_exists(OPENING_BALANCE_PATH):
        return FALLBACK_OPENING_POWER_CAP

    var file: FileAccess = FileAccess.open(OPENING_BALANCE_PATH, FileAccess.READ)
    if file == null:
        return FALLBACK_OPENING_POWER_CAP

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return FALLBACK_OPENING_POWER_CAP

    return maxi(1, int(parsed.get("default_power_cap", FALLBACK_OPENING_POWER_CAP)))


# -----------------------------------------------------------------------------
# Demo-route bridge
# -----------------------------------------------------------------------------

func route_species_ids() -> Array:
    return species_ids.duplicate()


func route_species_name(species_id: String) -> String:
    return _species_name(species_id)


func route_move_name(move_id: String) -> String:
    var moves_value: Variant = data.get("moves", {})
    if moves_value is Dictionary:
        var move_value: Variant = moves_value.get(move_id, {})
        if move_value is Dictionary:
            return str(move_value.get("name", move_id))
    return move_id


func route_moves_for_level(species_id: String, level: int) -> Array:
    var species_value: Variant = data.get("species", {})
    if not (species_value is Dictionary):
        return []
    var entry_value: Variant = species_value.get(species_id, {})
    if not (entry_value is Dictionary):
        return []
    return _moves_for_level(entry_value, maxi(1, level))


func route_new_member(species_id: String, level: int) -> Dictionary:
    var combatant: Dictionary = _make_combatant(
        "player",
        0,
        {"species_id": species_id, "level": maxi(1, level)}
    )
    return {
        "uid": str(Time.get_ticks_usec()) + "_" + str(randi()),
        "species_id": species_id,
        "name": str(combatant.get("name", species_id)),
        "level": int(combatant.get("level", level)),
        "xp": 0,
        "max_hp": int(combatant.get("max_hp", 1)),
        "hp": int(combatant.get("max_hp", 1)),
        "major_status": ""
    }


func start_route_battle(team_state: Array, enemy_species_id: String, enemy_level: int) -> void:
    route_mode = true
    _route_team_state = team_state.duplicate(true)
    _route_enemy_state = {
        "species_id": enemy_species_id,
        "level": maxi(1, enemy_level),
        "hp": -1,
        "max_hp": -1,
        "major_status": ""
    }
    visible = true
    _route_begin_wave()


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

    enemy_setup.append({
        "species_id": str(_route_enemy_state.get("species_id", "")),
        "level": maxi(1, int(_route_enemy_state.get("level", 1)))
    })

    _start_battle()

    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        var state_value: Variant = _route_team_state[team_index]
        if state_value is Dictionary:
            _route_apply_state(player_team[local_index], state_value)

    if not enemy_team.is_empty() and int(_route_enemy_state.get("hp", -1)) >= 0:
        _route_apply_state(enemy_team[0], _route_enemy_state)

    _refresh_cards()
    _set_log("Der Etappenkampf beginnt. KP und Status bleiben zwischen Kämpfen erhalten.")


func _route_apply_state(combatant: Dictionary, state: Dictionary) -> void:
    var max_hp: int = int(combatant.get("max_hp", 1))
    var hp: int = clampi(int(state.get("hp", max_hp)), 0, max_hp)
    combatant["hp"] = hp
    combatant["alive"] = hp > 0

    var major_status: String = str(state.get("major_status", ""))
    combatant["major_status"] = major_status
    combatant["paralyzed"] = major_status == "paralysis"
    combatant["confused_turns"] = 0
    combatant["attack_mult"] = 1.0
    combatant["defense_mult"] = 1.0
    combatant["accuracy_mult"] = 1.0
    combatant["next_cycle"] = 1.0
    combatant["seed_effect"] = {}
    combatant["binding_effect"] = {}


func _route_store_current_state() -> void:
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

    if not enemy_team.is_empty():
        var enemy_value: Variant = enemy_team[0]
        if enemy_value is Dictionary:
            var enemy: Dictionary = enemy_value
            _route_enemy_state["max_hp"] = int(enemy.get("max_hp", 1))
            _route_enemy_state["hp"] = int(enemy.get("hp", 0))
            _route_enemy_state["major_status"] = str(enemy.get("major_status", ""))


func _route_has_living_member() -> bool:
    for member_value: Variant in _route_team_state:
        if member_value is Dictionary and int(member_value.get("hp", 0)) > 0:
            return true
    return false


func _check_end() -> void:
    if not route_mode:
        super._check_end()
        return

    var own_alive: bool = false
    var enemy_alive: bool = false

    for combatant_value: Variant in player_team:
        if combatant_value is Dictionary and bool(combatant_value.get("alive", false)):
            own_alive = true
            break
    for combatant_value: Variant in enemy_team:
        if combatant_value is Dictionary and bool(combatant_value.get("alive", false)):
            enemy_alive = true
            break

    if own_alive and enemy_alive:
        return

    battle_active = false
    paused = false
    selected_actor = {}
    _force_hide_info()
    _clear_actions()
    _route_store_current_state()

    if not enemy_alive:
        result_title.text = "SIEG!"
        result_panel.visible = true
        await get_tree().create_timer(0.75).timeout
        result_panel.visible = false
        battle_panel.visible = false
        visible = false
        route_mode = false
        route_battle_finished.emit(true, _route_team_state.duplicate(true))
        return

    if _route_has_living_member():
        result_title.text = "RESERVE!"
        result_panel.visible = true
        await get_tree().create_timer(0.75).timeout
        result_panel.visible = false
        _route_begin_wave()
        return

    result_title.text = "NIEDERLAGE"
    result_panel.visible = true
    await get_tree().create_timer(0.9).timeout
    result_panel.visible = false
    battle_panel.visible = false
    visible = false
    route_mode = false
    route_battle_finished.emit(false, _route_team_state.duplicate(true))


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    var requested_level: int = maxi(1, int(setup.get("level", 1)))
    if requested_level <= LEVEL_MAX:
        return combatant

    var species_all: Variant = data.get("species", {})
    if not (species_all is Dictionary):
        return combatant
    var species_value: Variant = species_all.get(str(setup.get("species_id", "")), {})
    if not (species_value is Dictionary):
        return combatant
    var species: Dictionary = species_value
    var base_stats_value: Variant = species.get("base_stats", {})
    if not (base_stats_value is Dictionary):
        return combatant
    var base_stats: Dictionary = base_stats_value

    var hp_base: float = float(base_stats.get("hp", 35))
    var attack_base: float = float(base_stats.get("attack", 40))
    var defense_base: float = float(base_stats.get("defense", 40))
    var special_base: float = float(base_stats.get("special", 40))
    var speed_base: float = float(base_stats.get("speed", 40))

    combatant["level"] = requested_level
    combatant["max_hp"] = int(floor(2.0 * hp_base * float(requested_level) / 100.0)) + requested_level + 10
    combatant["hp"] = int(combatant["max_hp"])
    combatant["attack"] = int(floor(2.0 * attack_base * float(requested_level) / 100.0)) + 5
    combatant["defense"] = int(floor(2.0 * defense_base * float(requested_level) / 100.0)) + 5
    combatant["special"] = int(floor(2.0 * special_base * float(requested_level) / 100.0)) + 5
    combatant["speed"] = int(floor(2.0 * speed_base * float(requested_level) / 100.0)) + 5
    combatant["moves"] = _moves_for_level(species, requested_level)
    combatant["aggro"] = 10.0 + float(requested_level) * 2.0
    return combatant
