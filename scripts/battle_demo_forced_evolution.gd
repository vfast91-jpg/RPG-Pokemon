extends "res://scripts/battle_demo_tm_support.gd"

const EvolutionResolverScript = preload("res://scripts/evolution_resolver.gd")
const SPECIES_DATA_DIR: String = "res://data"

var _mandatory_evolution = EvolutionResolverScript.new()


func _load_data() -> void:
    super._load_data()
    _merge_species_data_packs()


func route_resolve_species_for_level(species_id: String, level: int) -> String:
    return _mandatory_evolution.resolve_species_for_level(
        species_id,
        maxi(1, level),
        _runtime_species()
    )


func route_species_ids_for_level(level: int) -> Array:
    var result: Array = []
    for species_value: Variant in species_ids:
        var resolved_id: String = route_resolve_species_for_level(str(species_value), level)
        if not resolved_id.is_empty() and not result.has(resolved_id):
            result.append(resolved_id)
    return result


func route_species_ids_valid_through_level(max_level: int) -> Array:
    var result: Array = []
    var runtime_species: Dictionary = _runtime_species()
    for species_value: Variant in species_ids:
        var species_id: String = str(species_value)
        if _mandatory_evolution.family_is_available_through_level(
            species_id,
            maxi(1, max_level),
            runtime_species
        ):
            result.append(species_id)
    return result


func route_required_evolution(species_id: String, level: int) -> Dictionary:
    return _mandatory_evolution.required_level_evolution(
        species_id,
        maxi(1, level),
        _runtime_species()
    )


func route_evolution_choices(species_id: String, level: int) -> Array:
    return _mandatory_evolution.evolution_choices_for_level(
        species_id,
        maxi(1, level),
        _runtime_species()
    )


func route_requires_evolution_choice(species_id: String, level: int) -> bool:
    return _mandatory_evolution.requires_player_evolution_choice(
        species_id,
        maxi(1, level),
        _runtime_species()
    )


func route_resolve_evolution_choice(
    species_id: String,
    target_species_id: String,
    level: int
) -> String:
    return _mandatory_evolution.resolve_player_evolution_choice(
        species_id,
        target_species_id,
        maxi(1, level),
        _runtime_species()
    )


func route_species_is_available(species_id: String) -> bool:
    return _runtime_species().has(species_id)


func start_route_battle_party(team_state: Array, enemy_party: Array) -> void:
    var normalized_enemy_party: Array = []
    for enemy_value: Variant in enemy_party:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = (enemy_value as Dictionary).duplicate(true)
        var level: int = maxi(1, int(enemy.get("level", 1)))
        var resolved_id: String = route_resolve_species_for_level(
            str(enemy.get("species_id", "")),
            level
        )
        if resolved_id.is_empty():
            push_warning(
                "Begegnung verworfen: Für %s Lv.%d fehlt eine eindeutig auflösbare verpflichtende Entwicklungsform."
                % [str(enemy.get("species_id", "")), level]
            )
            continue
        enemy["species_id"] = resolved_id
        normalized_enemy_party.append(enemy)

    super.start_route_battle_party(team_state, normalized_enemy_party)


func _runtime_species() -> Dictionary:
    var species_value: Variant = data.get("species", {})
    return species_value if species_value is Dictionary else {}


func _merge_species_data_packs() -> void:
    var runtime_species: Dictionary = _runtime_species()
    if runtime_species.is_empty():
        return

    var directory := DirAccess.open(SPECIES_DATA_DIR)
    if directory == null:
        return

    directory.list_dir_begin()
    var file_name: String = directory.get_next()
    while not file_name.is_empty():
        if not directory.current_is_dir() and file_name.to_lower().ends_with(".json"):
            _merge_species_pack(SPECIES_DATA_DIR + "/" + file_name, runtime_species)
        file_name = directory.get_next()
    directory.list_dir_end()

    data["species"] = runtime_species


func _merge_species_pack(path: String, runtime_species: Dictionary) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return

    var pack: Dictionary = parsed
    var species_value: Variant = pack.get("species", {})
    if not (species_value is Dictionary):
        return

    var source_species: Dictionary = species_value
    if source_species.has("species_id") or source_species.has("id"):
        _merge_species_entry(source_species, runtime_species)
        return

    for entry_value: Variant in source_species.values():
        if entry_value is Dictionary:
            _merge_species_entry(entry_value, runtime_species)


func _merge_species_entry(source: Dictionary, runtime_species: Dictionary) -> void:
    var species_id: String = str(source.get("species_id", source.get("id", "")))
    if species_id.is_empty() or runtime_species.has(species_id):
        return

    var base_stats_value: Variant = source.get("base_stats", {})
    if not (base_stats_value is Dictionary):
        return

    var types: Array = []
    var types_value: Variant = source.get("types", [])
    if types_value is Array:
        types = (types_value as Array).duplicate()
    elif types_value is Dictionary:
        var primary: String = str((types_value as Dictionary).get("primary", ""))
        var secondary: String = str((types_value as Dictionary).get("secondary", ""))
        if not primary.is_empty():
            types.append(primary)
        if not secondary.is_empty():
            types.append(secondary)

    var normalized: Dictionary = {
        "id": species_id,
        "name": str(source.get("display_name", source.get("name", species_id.capitalize()))),
        "types": types,
        "base_stats": (base_stats_value as Dictionary).duplicate(true),
        "learnset": _normalize_level_learnset(source.get("learnset", []))
    }

    var evolution_value: Variant = source.get("evolution", {})
    if evolution_value is Dictionary:
        normalized["evolution"] = (evolution_value as Dictionary).duplicate(true)

    runtime_species[species_id] = normalized


func _normalize_level_learnset(learnset_value: Variant) -> Array:
    if learnset_value is Array:
        return (learnset_value as Array).duplicate(true)
    if not (learnset_value is Dictionary):
        return []

    var learnset: Dictionary = learnset_value
    var level_up_value: Variant = learnset.get("level_up", {})
    if not (level_up_value is Dictionary):
        return []

    var levels: Array[int] = []
    for level_key: Variant in (level_up_value as Dictionary).keys():
        var level_text: String = str(level_key)
        if level_text.is_valid_int():
            levels.append(int(level_text))
    levels.sort()

    var result: Array = []
    for level: int in levels:
        var moves_value: Variant = (level_up_value as Dictionary).get(str(level), [])
        if moves_value is Array:
            result.append({"level": level, "moves": (moves_value as Array).duplicate()})
    return result
