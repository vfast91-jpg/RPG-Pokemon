class_name EvolutionResolver
extends RefCounted

const DEFAULT_RULES_PATH: String = "res://data/rules/evolution_chains.json"
const MAX_CHAIN_HOPS: int = 8

var _level_rules: Dictionary = {}


func _init(rules_path: String = DEFAULT_RULES_PATH) -> void:
    _load_rules(rules_path)


func _load_rules(path: String) -> void:
    _level_rules.clear()
    if not FileAccess.file_exists(path):
        push_error("Entwicklungsregeln fehlen: " + path)
        return

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Entwicklungsregeln konnten nicht geöffnet werden: " + path)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Entwicklungsregeln sind ungültig: " + path)
        return

    var rules_value: Variant = (parsed as Dictionary).get("level_evolutions", {})
    if rules_value is Dictionary:
        _level_rules = (rules_value as Dictionary).duplicate(true)


func resolve_species_for_level(
    species_id: String,
    level: int,
    available_species: Dictionary
) -> String:
    var current_id: String = species_id
    var safe_level: int = maxi(1, level)
    var visited: Dictionary = {}

    for _hop: int in range(MAX_CHAIN_HOPS):
        if current_id.is_empty() or visited.has(current_id):
            return ""
        if not available_species.has(current_id):
            return ""

        visited[current_id] = true
        var next_evolution: Dictionary = required_level_evolution(
            current_id,
            safe_level,
            available_species
        )
        if next_evolution.is_empty():
            return current_id

        var target_id: String = str(next_evolution.get("target_species_id", ""))
        if target_id.is_empty() or not available_species.has(target_id):
            # A generated encounter must never fall back to an evolution stage
            # that is already invalid for this level. Missing target data means
            # this family is temporarily unavailable for this level.
            return ""
        current_id = target_id

    push_error("Entwicklungskette überschreitet das Sicherheitslimit: " + species_id)
    return ""


func required_level_evolution(
    species_id: String,
    level: int,
    available_species: Dictionary
) -> Dictionary:
    var rule: Dictionary = _rule_for_species(species_id, available_species)
    if rule.is_empty():
        return {}

    var target_id: String = str(rule.get("target", rule.get("evolves_into", "")))
    var required_level: int = int(rule.get("level", rule.get("evolution_level", 0)))
    if target_id.is_empty() or required_level <= 0:
        return {}
    if maxi(1, level) < required_level:
        return {}

    return {
        "target_species_id": target_id,
        "required_level": required_level,
        "mandatory": true
    }


func family_is_available_through_level(
    species_id: String,
    max_level: int,
    available_species: Dictionary
) -> bool:
    return not resolve_species_for_level(species_id, maxi(1, max_level), available_species).is_empty()


func _rule_for_species(species_id: String, available_species: Dictionary) -> Dictionary:
    var explicit_value: Variant = _level_rules.get(species_id, {})
    if explicit_value is Dictionary and not (explicit_value as Dictionary).is_empty():
        return explicit_value

    # Fallback for future species packs: use their evolution target/level, but
    # deliberately ignore old optional/prevent flags. Level evolution is now
    # globally mandatory.
    var species_value: Variant = available_species.get(species_id, {})
    if not (species_value is Dictionary):
        return {}

    var evolution_value: Variant = (species_value as Dictionary).get("evolution", {})
    if not (evolution_value is Dictionary):
        return {}

    var evolution: Dictionary = evolution_value
    var method: String = str(evolution.get("method", "level"))
    if method != "level":
        return {}

    return {
        "target": str(evolution.get("evolves_into", "")),
        "level": int(evolution.get("evolution_level", 0))
    }
