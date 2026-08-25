extends "res://scripts/battle_demo_boss_aggro_lock_v1.gd"

# Gen-2 / V23 attack integration.
#
# This leaf layer deliberately sits above the complete active battle stack. It
# injects the eleven V23 definitions into runtime + canonical dictionaries and
# owns only mechanics that cannot be represented by the existing central
# systems. Existing damage, accuracy, protection, substitute, critical-hit,
# Status soft-cap, healing-block, Aggro and multi-hit systems remain authoritative.

const V23_MOVE_PACK_PATH: String = "res://data/gen2_moves_runtime_v23_11.json"
const V23_HIDDEN_POWER_TYPES: Array[String] = [
    "fire", "water", "electric", "grass", "ice", "fighting", "poison", "ground",
    "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel"
]
const V23_SKETCH_UNCOPYABLE: Array[String] = [
    "sketch", "mimic", "copycat", "metronome", "sleep_talk", "struggle",
    "assist", "mirror_move", "me_first"
]
const V23_SKETCH_MAX_COPIES: int = 4

var _v23_active_move_id: String = ""


func _load_data() -> void:
    super._load_data()
    _v23_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _v23_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(V23_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("V23-Attackenpaket konnte nicht gelesen werden: " + V23_MOVE_PACK_PATH)
        return
    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("V23-Attackenpaket besitzt kein moves-Dictionary.")
        return

    var runtime_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var canonical_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_value if canonical_value is Dictionary else {}

    for move_id_value: Variant in (entries_value as Dictionary).keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
        if not (move_value is Dictionary):
            continue
        runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
        canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)

    data["moves"] = runtime_moves
    _canonical_pack["moves"] = canonical_moves


func route_new_member(species_id: String, level: int) -> Dictionary:
    var member: Dictionary = super.route_new_member(species_id, level)
    member["v23_hidden_power_type"] = _v23_roll_hidden_power_type()
    member["v23_sketch_learned_moves"] = []
    return member


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)

    var stored_type: String = str(
        setup.get("v23_hidden_power_type", setup.get("hidden_power_type", ""))
    )
    combatant["v23_hidden_power_type"] = (
        stored_type if _v23_hidden_power_type_valid(stored_type)
        else _v23_roll_hidden_power_type()
    )

    var learned: Array[String] = _v23_string_array(
        setup.get("v23_sketch_learned_moves", [])
    )
    combatant["v23_sketch_learned_moves"] = learned
    _v23_merge_sketch_moves(combatant)
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
        if not (state_value is Dictionary) or not (combatant_value is Dictionary):
            continue

        var state: Dictionary = state_value
        var combatant: Dictionary = combatant_value
        var stored_type: String = str(state.get("v23_hidden_power_type", ""))
        if _v23_hidden_power_type_valid(stored_type):
            combatant["v23_hidden_power_type"] = stored_type
        else:
            stored_type = str(combatant.get("v23_hidden_power_type", ""))
            if not _v23_hidden_power_type_valid(stored_type):
                stored_type = _v23_roll_hidden_power_type()
                combatant["v23_hidden_power_type"] = stored_type
            state["v23_hidden_power_type"] = stored_type

        combatant["v23_sketch_learned_moves"] = _v23_string_array(
            state.get("v23_sketch_learned_moves", [])
        )
        _v23_merge_sketch_moves(combatant)
        _route_team_state[team_index] = state


func _route_store_current_state() -> void:
    super._route_store_current_state()
    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        if team_index < 0 or team_index >= _route_team_state.size():
            continue
        var member_value: Variant = _route_team_state[team_index]
        var combatant_value: Variant = player_team[local_index]
        if not (member_value is Dictionary) or not (combatant_value is Dictionary):
            continue
        var member: Dictionary = member_value
        var combatant: Dictionary = combatant_value
        member["v23_hidden_power_type"] = str(combatant.get("v23_hidden_power_type", ""))
        member["v23_sketch_learned_moves"] = _v23_string_array(
            combatant.get("v23_sketch_learned_moves", [])
        )
        _route_team_state[team_index] = member


func _prompt_player(actor: Dictionary) -> void:
    var backup: Dictionary = _v23_patch_hidden_power_for_actor(actor)
    super._prompt_player(actor)
    _v23_restore_runtime_move("hidden_power", backup)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        super._execute_move(actor, move_id)
        return

    var backup: Dictionary = move.duplicate(true)
    var patched: Dictionary = move.duplicate(true)

    if move_id == "hidden_power":
        patched = _v23_hidden_power_move(actor, patched)
    elif move_id == "beat_up":
        patched = _v23_beat_up_move(actor, patched)
    elif move_id == "present":
        patched = _v23_present_move(patched)

    _v23_set_runtime_move(move_id, patched)
    var previous_move_id: String = _v23_active_move_id
    _v23_active_move_id = move_id
    super._execute_move(actor, move_id)
    _v23_active_move_id = previous_move_id
    _v23_set_runtime_move(move_id, backup)


func _database_apply_multi_hit(state: Dictionary, hit_index: int) -> void:
    if str(state.get("move_id", "")) == "beat_up":
        var move_value: Variant = state.get("move", {})
        if move_value is Dictionary:
            var move: Dictionary = move_value
            var runtime_value: Variant = move.get("runtime", {})
            if runtime_value is Dictionary:
                var powers_value: Variant = (runtime_value as Dictionary).get("v23_beat_up_powers", [])
                if powers_value is Array:
                    var power_index: int = hit_index - 1
                    if power_index >= 0 and power_index < (powers_value as Array).size():
                        move["power"] = int((powers_value as Array)[power_index])
                        state["move"] = move
    super._database_apply_multi_hit(state, hit_index)


func _critical_chance(combatant: Dictionary) -> float:
    var move_id: String = _v23_active_move_id
    if move_id.is_empty():
        move_id = _database_move_id
    if move_id == "aeroblast":
        return 0.125
    return super._critical_chance(combatant)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    match str(mechanic.get("kind", "")):
        "v23_octazooka_accuracy":
            return _v23_octazooka_accuracy(actor, target, mechanic)
        "v23_present_heal":
            return _v23_present_heal(target)
        "v23_sacred_fire_burn":
            return _v23_sacred_fire_burn(actor, target, mechanic)
        "v23_sketch":
            return _v23_sketch(actor, target)
        _:
            return super._effect(actor, target, mechanic)


func _v23_hidden_power_move(actor: Dictionary, move: Dictionary) -> Dictionary:
    var result: Dictionary = move.duplicate(true)
    var move_type: String = str(actor.get("v23_hidden_power_type", ""))
    if not _v23_hidden_power_type_valid(move_type):
        move_type = _v23_roll_hidden_power_type()
        actor["v23_hidden_power_type"] = move_type
    result["type"] = move_type
    result["name"] = "Kraftreserve · " + _v23_type_display_name(move_type)
    return result


func _v23_patch_hidden_power_for_actor(actor: Dictionary) -> Dictionary:
    var move: Dictionary = _move_data("hidden_power")
    if move.is_empty():
        return {}
    var backup: Dictionary = move.duplicate(true)
    _v23_set_runtime_move("hidden_power", _v23_hidden_power_move(actor, move))
    return backup


func _v23_restore_runtime_move(move_id: String, backup: Dictionary) -> void:
    if move_id.is_empty() or backup.is_empty():
        return
    _v23_set_runtime_move(move_id, backup)


func _v23_set_runtime_move(move_id: String, move: Dictionary) -> void:
    var moves_value: Variant = data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}
    moves[move_id] = move.duplicate(true)
    data["moves"] = moves


func _v23_beat_up_move(actor: Dictionary, move: Dictionary) -> Dictionary:
    var result: Dictionary = move.duplicate(true)
    var powers: Array[int] = _v23_beat_up_powers(actor)
    if powers.is_empty():
        # A normal action is still consumed, but no hit can resolve.
        result["power"] = null
        result["mechanics"] = []
        return result

    result["power"] = powers[0]
    var runtime_value: Variant = result.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true)
        if runtime_value is Dictionary else {}
    )
    runtime["multi_hit"] = {
        "min": powers.size(),
        "max": powers.size(),
        "repeat_kinds": ["damage"]
    }
    runtime["v23_beat_up_powers"] = powers
    result["runtime"] = runtime
    return result


func _v23_beat_up_powers(actor: Dictionary) -> Array[int]:
    var result: Array[int] = []
    for member_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if not bool(member.get("alive", false)) or int(member.get("hp", 0)) <= 0:
            continue
        if _v23_has_major_status(member):
            continue
        var base_attack: int = _v23_species_base_attack(member)
        result.append(maxi(1, int(floor(5.0 + float(base_attack) / 10.0))))
        if result.size() >= 4:
            break
    return result


func _v23_species_base_attack(combatant: Dictionary) -> int:
    var species_id: String = str(combatant.get("species_id", ""))
    var species_value: Variant = _canonical_pack.get("species", {})
    if species_value is Dictionary:
        var source_value: Variant = (species_value as Dictionary).get(species_id, {})
        if source_value is Dictionary:
            var source: Dictionary = source_value
            var base_stats_value: Variant = source.get("base_stats", {})
            if base_stats_value is Dictionary:
                var base_stats: Dictionary = base_stats_value
                for key: String in ["attack", "atk", "angriff"]:
                    if base_stats.has(key):
                        return maxi(1, int(base_stats.get(key, 1)))
            for key: String in ["base_attack", "attack", "atk"]:
                if source.has(key):
                    return maxi(1, int(source.get(key, 1)))
    if combatant.has("base_attack"):
        return maxi(1, int(combatant.get("base_attack", 1)))
    return maxi(1, int(combatant.get("attack", 1)))


func _v23_present_move(move: Dictionary) -> Dictionary:
    var result: Dictionary = move.duplicate(true)
    var roll: float = randf()
    if roll < 0.40:
        result["power"] = 40
        result["mechanics"] = [{"kind": "damage"}]
    elif roll < 0.70:
        result["power"] = 80
        result["mechanics"] = [{"kind": "damage"}]
    elif roll < 0.80:
        result["power"] = 120
        result["mechanics"] = [{"kind": "damage"}]
    else:
        result["power"] = null
        result["mechanics"] = [{"kind": "v23_present_heal"}]
    return result


func _v23_present_heal(target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0
    if _f40_heal_block_active(target):
        if int(target.get("hp", 0)) < int(target.get("max_hp", 1)):
            _f40_heal_block_feedback(target)
        return 0.0
    var max_hp: int = maxi(1, int(target.get("max_hp", 1)))
    var missing: int = maxi(0, max_hp - int(target.get("hp", 0)))
    if missing <= 0:
        return 0.0
    var requested: int = maxi(1, int(round(float(max_hp) * 0.25)))
    var healed: int = mini(missing, requested)
    target["hp"] = int(target.get("hp", 0)) + healed
    _spawn_feedback_label(target, "🎁 +" + str(healed) + " KP", Color("8fe39b"))
    # Geschenk-Heilung am gegnerischen Ziel erzeugt ausdrücklich keine Heilungs-Aggro.
    return 0.0


func _v23_octazooka_accuracy(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > clampf(float(mechanic.get("chance", 0.5)), 0.0, 1.0):
        return 0.0
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    target["db_incoming_accuracy_mult"] = clampf(1.0 - ratio, 0.05, 1.0)
    target["db_incoming_accuracy_expires"] = int(target.get("action_serial", 0)) + 3
    _spawn_feedback_label(target, "🐙 GENAUIGKEIT ↓ · 3 AKTIONEN", Color("b8d9ff"))
    return 0.0


func _v23_sacred_fire_burn(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > clampf(float(mechanic.get("chance", 0.5)), 0.0, 1.0):
        return 0.0
    # Reuse the central major-status legality/immunity path, but intentionally
    # discard its Aggro return: V23 gives Läuterfeuer Aggro from damage only.
    super._effect(actor, target, {"kind": "status", "status": "burn", "chance": 1.0})
    return 0.0


func _v23_sketch(actor: Dictionary, target: Dictionary) -> float:
    if actor.is_empty() or target.is_empty() or not bool(actor.get("alive", false)):
        return 0.0
    var learned: Array[String] = _v23_string_array(
        actor.get("v23_sketch_learned_moves", [])
    )
    if learned.size() >= V23_SKETCH_MAX_COPIES:
        _v23_exhaust_sketch(actor)
        return 0.0

    var copied_id: String = str(target.get("db_last_move", ""))
    if not _v23_sketch_copyable(copied_id) or learned.has(copied_id):
        _spawn_feedback_label(actor, "🎨 NICHT KOPIERBAR", Color("d9a5a5"))
        return 0.0

    learned.append(copied_id)
    actor["v23_sketch_learned_moves"] = learned
    var moves: Array = _v23_string_array(actor.get("moves", []))
    if not moves.has(copied_id):
        moves.append(copied_id)
    actor["moves"] = moves

    var copied_name: String = str(_move_data(copied_id).get("name", copied_id))
    _spawn_feedback_label(actor, "🎨 " + copied_name.to_upper(), Color("d9c6ff"))
    if learned.size() >= V23_SKETCH_MAX_COPIES:
        _v23_exhaust_sketch(actor)
    return 4.0


func _v23_exhaust_sketch(actor: Dictionary) -> void:
    var moves: Array = _v23_string_array(actor.get("moves", []))
    moves.erase("sketch")
    actor["moves"] = moves


func _v23_merge_sketch_moves(combatant: Dictionary) -> void:
    var learned: Array[String] = _v23_string_array(
        combatant.get("v23_sketch_learned_moves", [])
    )
    if learned.size() > V23_SKETCH_MAX_COPIES:
        learned.resize(V23_SKETCH_MAX_COPIES)
    combatant["v23_sketch_learned_moves"] = learned

    var moves: Array = _v23_string_array(combatant.get("moves", []))
    for move_id: String in learned:
        if _runtime_has_move(move_id) and not moves.has(move_id):
            moves.append(move_id)
    if learned.size() >= V23_SKETCH_MAX_COPIES:
        moves.erase("sketch")
    combatant["moves"] = moves


func _v23_sketch_copyable(move_id: String) -> bool:
    return (
        not move_id.is_empty()
        and not V23_SKETCH_UNCOPYABLE.has(move_id)
        and _runtime_has_move(move_id)
    )


func _v23_has_major_status(combatant: Dictionary) -> bool:
    if not str(combatant.get("major_status", "")).is_empty():
        return true
    return (
        bool(combatant.get("paralyzed", false))
        or int(combatant.get("db_sleep_actions", 0)) > 0
    )


func _v23_hidden_power_type_valid(type_id: String) -> bool:
    return V23_HIDDEN_POWER_TYPES.has(type_id)


func _v23_roll_hidden_power_type() -> String:
    return str(V23_HIDDEN_POWER_TYPES.pick_random())


func _v23_string_array(value: Variant) -> Array[String]:
    var result: Array[String] = []
    if not (value is Array):
        return result
    for entry: Variant in value:
        var text: String = str(entry)
        if not text.is_empty() and not result.has(text):
            result.append(text)
    return result


func _v23_type_display_name(type_id: String) -> String:
    var names: Dictionary = {
        "fire": "Feuer", "water": "Wasser", "electric": "Elektro", "grass": "Pflanze",
        "ice": "Eis", "fighting": "Kampf", "poison": "Gift", "ground": "Boden",
        "flying": "Flug", "psychic": "Psycho", "bug": "Käfer", "rock": "Gestein",
        "ghost": "Geist", "dragon": "Drache", "dark": "Unlicht", "steel": "Stahl"
    }
    return str(names.get(type_id, type_id.capitalize()))
