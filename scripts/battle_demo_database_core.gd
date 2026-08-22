extends "res://scripts/battle_demo_forced_evolution.gd"

# Canonical database bridge.
# Loads the 2026-08-20 Pokémon/attack database export after all legacy demo
# layers so the spreadsheet data is authoritative without deleting the older
# compatibility code in one risky migration.

const CANONICAL_MANIFEST_PATH: String = "res://data/gen1_database_manifest_v3.json"

var _canonical_pack: Dictionary = {}
var _database_active_move: Dictionary = {}
var _database_move_id: String = ""


func _load_data() -> void:
    super._load_data()
    _load_canonical_database()


func _load_canonical_database() -> void:
    # Implemented by the final integration layer.
    pass


func _database_read_json_dictionary(path: String) -> Dictionary:
    if path.is_empty():
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}


func _canonical_species_runtime(source: Dictionary) -> Dictionary:
    var type_list: Array = []
    var types_value: Variant = source.get("types", {})
    if types_value is Dictionary:
        var primary: String = str((types_value as Dictionary).get("primary", ""))
        var secondary: String = str((types_value as Dictionary).get("secondary", ""))
        if not primary.is_empty():
            type_list.append(primary)
        if not secondary.is_empty() and secondary != "null":
            type_list.append(secondary)

    var base_stats_value: Variant = source.get("base_stats", {})
    var base_stats: Dictionary = base_stats_value if base_stats_value is Dictionary else {}
    var result: Dictionary = {
        "id": str(source.get("species_id", "")),
        "name": str(source.get("display_name", source.get("species_id", ""))),
        "asset_id": str(source.get("asset_id", source.get("species_id", ""))),
        "types": type_list,
        "base_stats": base_stats.duplicate(true),
        "learnset": _canonical_learnset_array(source.get("learnset", {})),
        "source_learnset": (source.get("learnset", {}) as Dictionary).duplicate(true) if source.get("learnset", {}) is Dictionary else {}
    }

    var evolution_value: Variant = source.get("evolution", {})
    if evolution_value is Dictionary:
        var evolution: Dictionary = evolution_value
        var target_id: String = str(evolution.get("evolves_into", ""))
        var level_value: Variant = evolution.get("evolution_level", 0)
        var level: int = 0
        if level_value is int or level_value is float:
            level = int(level_value)
        elif level_value is String and (level_value as String).is_valid_int():
            level = int(level_value)
        if not target_id.is_empty() and level > 0:
            result["evolution"] = {
                "target_species_id": target_id,
                "level": level,
                "mandatory": bool(evolution.get("mandatory", true))
            }
    return result


func _canonical_learnset_array(learnset_value: Variant) -> Array:
    var result: Array = []
    if not (learnset_value is Dictionary):
        return result
    var learnset: Dictionary = learnset_value
    var by_level: Dictionary = {}

    _append_moves_to_level(by_level, 1, learnset.get("relearn_lv1", []))
    _append_moves_to_level(by_level, 1, learnset.get("evolution_moves", []))

    var level_up_value: Variant = learnset.get("level_up", {})
    if level_up_value is Dictionary:
        for level_key: Variant in (level_up_value as Dictionary).keys():
            _append_moves_to_level(by_level, maxi(1, int(str(level_key))), (level_up_value as Dictionary).get(level_key, []))

    var levels: Array[int] = []
    for level_value: Variant in by_level.keys():
        levels.append(int(level_value))
    levels.sort()

    for level: int in levels:
        var usable: Array = []
        var move_values: Variant = by_level.get(level, [])
        if move_values is Array:
            for move_value: Variant in move_values:
                var move_id: String = str(move_value)
                if _database_move_is_runtime_usable(move_id) and not usable.has(move_id):
                    usable.append(move_id)
        if not usable.is_empty():
            result.append({"level": level, "moves": usable})
    return result


func _append_moves_to_level(by_level: Dictionary, level: int, move_values: Variant) -> void:
    if not (move_values is Array):
        return
    var current: Array = by_level.get(level, [])
    for move_value: Variant in move_values:
        var move_id: String = str(move_value)
        if not current.has(move_id):
            current.append(move_id)
    by_level[level] = current


func _database_move_is_runtime_usable(move_id: String) -> bool:
    var moves_value: Variant = _canonical_pack.get("moves", {})
    if not (moves_value is Dictionary):
        return false
    var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
    if not (move_value is Dictionary):
        return false
    var runtime_value: Variant = (move_value as Dictionary).get("runtime", {})
    if runtime_value is Dictionary and (runtime_value as Dictionary).has("runtime_supported"):
        return bool((runtime_value as Dictionary).get("runtime_supported", true))
    return true


func _audit_canonical_database() -> void:
    var gaps_value: Variant = _canonical_pack.get("data_gaps", {})
    if gaps_value is Dictionary:
        var missing_value: Variant = (gaps_value as Dictionary).get("missing_move_definitions", [])
        if missing_value is Array and not (missing_value as Array).is_empty():
            push_warning("Datenbank-Audit: Level-Attacken ohne Definition: " + ", ".join(missing_value as Array))
        var uncalibrated_value: Variant = (gaps_value as Dictionary).get("runtime_uncalibrated_moves", [])
        if uncalibrated_value is Array and not (uncalibrated_value as Array).is_empty():
            push_warning("Datenbank-Audit: Noch nicht numerisch kalibrierte Attacken werden ausgeblendet: " + ", ".join(uncalibrated_value as Array))
        var partial_value: Variant = (gaps_value as Dictionary).get("runtime_partial_rules", [])
        if partial_value is Array:
            for note_value: Variant in partial_value:
                push_warning("Datenbank-Audit: " + str(note_value))

    var species_value: Variant = data.get("species", {})
    if not (species_value is Dictionary):
        return
    for species_id_value: Variant in (species_value as Dictionary).keys():
        var species_id: String = str(species_id_value)
        var species: Dictionary = (species_value as Dictionary)[species_id]
        var sprite_name: String = str(species.get("name", ""))
        var sprite_path: String = "res://assets/monsters/" + sprite_name + ".png"
        if not ResourceLoader.exists(sprite_path):
            push_warning("Sprite-Audit: " + species_id + " erwartet " + sprite_path)


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var resolved_setup: Dictionary = setup.duplicate(true)
    var requested_species: String = str(resolved_setup.get("species_id", ""))
    var requested_level: int = maxi(1, int(resolved_setup.get("level", 1)))
    if not requested_species.is_empty():
        var resolved_species: String = route_resolve_species_for_level(requested_species, requested_level)
        if not resolved_species.is_empty():
            resolved_setup["species_id"] = resolved_species

    var combatant: Dictionary = super._make_combatant(side, index, resolved_setup)
    combatant["db_status_immunities"] = []
    combatant["db_incoming_accuracy_mult"] = 1.0
    combatant["db_incoming_accuracy_expires"] = 0
    combatant["db_redirect_expires"] = 0
    combatant["db_block_positive_expires"] = 0
    combatant["db_guaranteed_crit"] = false
    combatant["db_stockpile"] = 0
    combatant["db_removed_type"] = ""
    combatant["db_removed_type_until_action"] = 0
    combatant["db_protect_chain"] = 0
    combatant["db_last_move"] = ""
    combatant["db_fury_cutter_chain"] = 0
    combatant["db_charge_move"] = ""
    combatant["db_charge_target_id"] = ""
    combatant["db_charge_firing"] = false
    combatant["db_forced_move_id"] = ""
    combatant["db_forced_actions_left"] = 0
    combatant["db_recharge_pending"] = false
    combatant["db_light_screen_source_id"] = ""
    combatant["db_light_screen_expires_source_action"] = 0

    var known_value: Variant = setup.get("known_moves", null)
    if known_value is Array:
        var merged: Array = []
        for move_value: Variant in known_value:
            var move_id: String = str(move_value)
            if _runtime_has_move(move_id) and not merged.has(move_id):
                merged.append(move_id)
        var existing_value: Variant = combatant.get("moves", [])
        if existing_value is Array:
            for move_value: Variant in existing_value:
                var move_id: String = str(move_value)
                if _runtime_has_move(move_id) and not merged.has(move_id):
                    merged.append(move_id)
        combatant["moves"] = merged
    else:
        combatant["moves"] = _filter_runtime_moves(combatant.get("moves", []))
    return combatant


func _filter_runtime_moves(move_values: Variant) -> Array:
    var result: Array = []
    if not (move_values is Array):
        return result
    for move_value: Variant in move_values:
        var move_id: String = str(move_value)
        if _runtime_has_move(move_id) and not result.has(move_id):
            result.append(move_id)
    return result


func _runtime_has_move(move_id: String) -> bool:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary) or not (moves_value as Dictionary).has(move_id):
        return false
    var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
    if not (move_value is Dictionary):
        return false
    var runtime_value: Variant = (move_value as Dictionary).get("runtime", {})
    if runtime_value is Dictionary and (runtime_value as Dictionary).has("runtime_supported"):
        return bool((runtime_value as Dictionary).get("runtime_supported", true))
    return true


func route_new_member(species_id: String, level: int) -> Dictionary:
    var member: Dictionary = super.route_new_member(species_id, level)
    member["known_moves"] = route_moves_for_level(species_id, level)
    member["tm_moves"] = []
    member["learned_tms"] = []
    return member


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
        if not (state_value is Dictionary):
            continue
        var known_value: Variant = (state_value as Dictionary).get("known_moves", [])
        var combatant_value: Variant = player_team[local_index]
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var merged: Array = _filter_runtime_moves(combatant.get("moves", []))
        if known_value is Array:
            for move_value: Variant in known_value:
                var move_id: String = str(move_value)
                if _runtime_has_move(move_id) and not merged.has(move_id):
                    merged.append(move_id)
        combatant["moves"] = merged


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
        if member_value is Dictionary and combatant_value is Dictionary:
            var member: Dictionary = member_value
            member["known_moves"] = _filter_runtime_moves((combatant_value as Dictionary).get("moves", []))
            _route_team_state[team_index] = member


func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == "all_allies":
        var result: Array = []
        for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
            if candidate_value is Dictionary and bool((candidate_value as Dictionary).get("alive", false)):
                result.append(candidate_value)
        return result
    if rule == "all_other_active_pokemon":
        var others: Array = []
        for candidate_value: Variant in combatants:
            if candidate_value is Dictionary:
                var candidate: Dictionary = candidate_value
                if bool(candidate.get("alive", false)) and str(candidate.get("id", "")) != str(actor.get("id", "")):
                    others.append(candidate)
        return others
    if rule == "enemy_field":
        return [actor]
    if rule == "enemy_highest_aggro":
        if bool(actor.get("db_charge_firing", false)):
            var locked_id: String = str(actor.get("db_charge_target_id", ""))
            for candidate_value: Variant in combatants:
                if candidate_value is Dictionary:
                    var candidate: Dictionary = candidate_value
                    if str(candidate.get("id", "")) == locked_id and bool(candidate.get("alive", false)):
                        return [candidate]
            return []
        var redirected: Dictionary = _database_redirect_target(actor)
        if not redirected.is_empty():
            return [redirected]
    return super._targets(actor, rule)


func _database_redirect_target(actor: Dictionary) -> Dictionary:
    for candidate_value: Variant in _living_opponents(actor):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if int(candidate.get("action_serial", 0)) < int(candidate.get("db_redirect_expires", 0)):
            return candidate
    return {}
