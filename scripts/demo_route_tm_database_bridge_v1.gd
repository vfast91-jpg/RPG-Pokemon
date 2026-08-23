extends "res://scripts/demo_route_xp_progress_bonus.gd"

# Central TM database bridge for the active route.
#
# Species data owns only compatibility (which move IDs a Pokemon may learn).
# The battle move registry owns the actual move definitions and mechanics.
# The route reward system joins both databases by move_id; it never needs a
# second per-Pokemon TM implementation table.


func _reload_tm_catalog() -> void:
    _tm_catalog.clear()
    if battle_demo == null:
        return

    # The complete Gen-1-family registry exposes this data-driven compatibility
    # query. Keep the old JSON scanner as a compatibility fallback for isolated
    # legacy tests/scenes that use an older BattleDemo layer.
    if not battle_demo.has_method("species_can_receive_tm_move"):
        super._reload_tm_catalog()
        return

    var runtime_data_value: Variant = battle_demo.get("data")
    if not (runtime_data_value is Dictionary):
        super._reload_tm_catalog()
        return
    var runtime_data: Dictionary = runtime_data_value

    var species_value: Variant = runtime_data.get("species", {})
    var moves_value: Variant = runtime_data.get("moves", {})
    if not (species_value is Dictionary) or not (moves_value is Dictionary):
        super._reload_tm_catalog()
        return

    var runtime_species: Dictionary = species_value
    var runtime_moves: Dictionary = moves_value

    # One catalog entry per move ID. The same entry can point at any number of
    # compatible species. This prevents branching families or duplicated data
    # packs from multiplying the probability of one TM.
    for move_id_value: Variant in runtime_moves.keys():
        var move_id: String = str(move_id_value)
        if move_id.is_empty() or not _tm_runtime_move_available(move_id):
            continue

        var compatible_species: Array = []
        for species_id_value: Variant in runtime_species.keys():
            var species_id: String = str(species_id_value)
            if bool(battle_demo.call("species_can_receive_tm_move", species_id, move_id)):
                compatible_species.append(species_id)

        if compatible_species.is_empty():
            continue

        _tm_catalog[move_id] = {
            # The modern canonical species export stores TM compatibility as
            # move IDs. A historical TM number is optional metadata, not an ID.
            "number": "",
            "move_id": move_id,
            "name": _runtime_move_name(move_id, {}),
            "species_ids": compatible_species
        }


func _tm_runtime_move_available(move_id: String) -> bool:
    if battle_demo == null or move_id.is_empty():
        return false

    var runtime_data_value: Variant = battle_demo.get("data")
    if not (runtime_data_value is Dictionary):
        return false
    var moves_value: Variant = (runtime_data_value as Dictionary).get("moves", {})
    if not (moves_value is Dictionary):
        return false
    var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
    if not (move_value is Dictionary):
        return false

    var runtime_value: Variant = (move_value as Dictionary).get("runtime", {})
    if runtime_value is Dictionary:
        var runtime: Dictionary = runtime_value
        if runtime.has("runtime_supported") and not bool(runtime.get("runtime_supported", true)):
            return false
        if runtime.has("normal_battle_available") and not bool(runtime.get("normal_battle_available", true)):
            return false
    return true


func _member_can_receive_tm(member: Dictionary, entry: Dictionary) -> bool:
    if battle_demo == null:
        return false

    var species_id: String = str(member.get("species_id", ""))
    var move_id: String = str(entry.get("move_id", ""))
    var tm_number: String = str(entry.get("number", ""))
    if species_id.is_empty() or move_id.is_empty():
        return false

    # Compatibility is authoritative in the Pokemon database. The entry's
    # species_ids list is merely a cached presentation index.
    if battle_demo.has_method("species_can_receive_tm_move"):
        if not bool(battle_demo.call("species_can_receive_tm_move", species_id, move_id)):
            return false
    else:
        var compatible_value: Variant = entry.get("species_ids", [])
        if not (compatible_value is Array) or not (compatible_value as Array).has(species_id):
            return false

    # A compatibility reference alone is not enough: the move must have a
    # working central runtime definition before the route may offer it.
    if not _tm_runtime_move_available(move_id):
        return false

    var tm_moves_value: Variant = member.get("tm_moves", [])
    if tm_moves_value is Array and (tm_moves_value as Array).has(move_id):
        return false

    var explicit_moves_value: Variant = member.get("moves", [])
    if explicit_moves_value is Array and (explicit_moves_value as Array).has(move_id):
        return false

    if battle_demo.has_method("route_moves_for_level"):
        var level_moves_value: Variant = battle_demo.call(
            "route_moves_for_level",
            species_id,
            maxi(1, int(member.get("level", 1)))
        )
        if level_moves_value is Array and (level_moves_value as Array).has(move_id):
            return false

    var learned_value: Variant = member.get("learned_tms", [])
    if learned_value is Array:
        for learned_entry_value: Variant in learned_value:
            if learned_entry_value is Dictionary:
                var learned_entry: Dictionary = learned_entry_value
                if str(learned_entry.get("move_id", "")) == move_id:
                    return false
                # Modern entries intentionally have no numeric TM identifier.
                # Never let two empty numbers make every later TM look learned.
                if (
                    not tm_number.is_empty()
                    and str(learned_entry.get("number", "")) == tm_number
                ):
                    return false
            else:
                var learned_text: String = str(learned_entry_value)
                if learned_text == move_id:
                    return false
                if not tm_number.is_empty() and learned_text == tm_number:
                    return false

    return true
