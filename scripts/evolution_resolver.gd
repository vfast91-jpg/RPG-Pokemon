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
    available_species: Dictionary,
    selected_targets: Dictionary = {}
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

        var target_id: String = ""
        if bool(next_evolution.get("requires_player_choice", false)):
            var selected_target: String = str(selected_targets.get(current_id, ""))
            target_id = resolve_player_evolution_choice(
                current_id,
                selected_target,
                safe_level,
                available_species
            )
            if target_id.is_empty():
                # Branching evolutions must never be chosen implicitly. A player
                # or another explicit caller has to provide the target.
                return ""
        else:
            target_id = str(next_evolution.get("target_species_id", ""))

        if target_id.is_empty() or not available_species.has(target_id):
            # A generated encounter must never fall back to an evolution stage
            # that is already invalid for this level. Missing target data means
            # this family is temporarily unavailable for this level.
            return ""
        current_id = target_id

    push_error("Entwicklungskette überschreitet das Sicherheitslimit: " + species_id)
    return ""


func evolution_choices_for_level(
    species_id: String,
    level: int,
    available_species: Dictionary
) -> Array:
    var rule: Dictionary = _rule_for_species(species_id, available_species)
    if rule.is_empty():
        return []

    var safe_level: int = maxi(1, level)
    var raw_choices: Array = _raw_level_choices(rule)
    var result: Array = []

    for choice_value: Variant in raw_choices:
        if not (choice_value is Dictionary):
            continue
        var choice: Dictionary = choice_value
        var method: String = str(choice.get("method", rule.get("method", "level")))
        if method != "level":
            continue

        var target_id: String = str(choice.get("target", choice.get("evolves_into", "")))
        var required_level: int = int(
            choice.get(
                "level",
                choice.get(
                    "evolution_level",
                    rule.get("level", rule.get("evolution_level", 0))
                )
            )
        )
        if target_id.is_empty() or required_level <= 0 or safe_level < required_level:
            continue

        result.append({
            "target_species_id": target_id,
            "required_level": required_level,
            "mandatory": true,
            "target_available": available_species.has(target_id)
        })

    var requires_choice: bool = result.size() > 1
    for index: int in range(result.size()):
        var normalized: Dictionary = result[index]
        normalized["requires_player_choice"] = requires_choice
        result[index] = normalized

    return result


func requires_player_evolution_choice(
    species_id: String,
    level: int,
    available_species: Dictionary
) -> bool:
    return evolution_choices_for_level(species_id, level, available_species).size() > 1


func resolve_player_evolution_choice(
    species_id: String,
    target_species_id: String,
    level: int,
    available_species: Dictionary
) -> String:
    if target_species_id.is_empty():
        return ""

    for choice_value: Variant in evolution_choices_for_level(
        species_id,
        level,
        available_species
    ):
        if not (choice_value is Dictionary):
            continue
        var choice: Dictionary = choice_value
        if str(choice.get("target_species_id", "")) != target_species_id:
            continue
        if not bool(choice.get("target_available", false)):
            return ""
        return target_species_id

    return ""


func required_level_evolution(
    species_id: String,
    level: int,
    available_species: Dictionary
) -> Dictionary:
    var choices: Array = evolution_choices_for_level(species_id, level, available_species)
    if choices.is_empty():
        return {}

    if choices.size() == 1:
        return (choices[0] as Dictionary).duplicate(true)

    var required_level: int = 0
    for choice_value: Variant in choices:
        if not (choice_value is Dictionary):
            continue
        var choice_level: int = int((choice_value as Dictionary).get("required_level", 0))
        if required_level == 0 or (choice_level > 0 and choice_level < required_level):
            required_level = choice_level

    return {
        "required_level": required_level,
        "mandatory": true,
        "requires_player_choice": true,
        "choices": choices.duplicate(true)
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
        return (explicit_value as Dictionary).duplicate(true)

    # Fallback for species packs that are not present in the explicit rule file.
    # Accept source/detail evolution data as well as the canonical runtime shape
    # produced by the global Pokemon registry.
    var species_value: Variant = available_species.get(species_id, {})
    if not (species_value is Dictionary):
        return {}

    var evolution_value: Variant = (species_value as Dictionary).get("evolution", {})
    if not (evolution_value is Dictionary):
        return {}

    var evolution: Dictionary = evolution_value
    if evolution.has("choices"):
        return evolution.duplicate(true)

    var evolves_into_value: Variant = evolution.get("evolves_into", "")
    if evolves_into_value is Array:
        return evolution.duplicate(true)

    var method: String = str(evolution.get("method", "level"))
    if method != "level":
        return {}

    var target_id: String = str(
        evolution.get("target_species_id", evolves_into_value)
    ).strip_edges()
    var required_level: int = int(
        evolution.get("level", evolution.get("evolution_level", 0))
    )

    return {
        "target": target_id,
        "level": required_level,
        "method": method,
        "mandatory": bool(evolution.get("mandatory", true))
    }


func _raw_level_choices(rule: Dictionary) -> Array:
    var choices_value: Variant = rule.get("choices", [])
    if choices_value is Array and not (choices_value as Array).is_empty():
        return (choices_value as Array).duplicate(true)

    var evolves_into_value: Variant = rule.get("evolves_into", "")
    if evolves_into_value is Array:
        var result: Array = []
        for target_value: Variant in evolves_into_value:
            result.append({
                "target": str(target_value),
                "level": int(rule.get("level", rule.get("evolution_level", 0))),
                "method": str(rule.get("method", "level"))
            })
        return result

    return [rule.duplicate(true)]
