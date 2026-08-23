extends "res://scripts/demo_route_landscape_overview_v1.gd"

# Landschaften modifizieren die bestehende Seltenheitsgewichtung, ohne sie zu
# ersetzen. Stark bevorzugte Typen erhalten x8, normale Typen x1, seltene/
# untypische Typen x0.2 und ausgeschlossene Typen x0.
#
# Für die Landschaftskorrelation zählt bei Doppeltypen ausschließlich Typ 1.
# Typ 2 wird vollständig ignoriert. Fangwiese und normale Zufalls-/Boss-
# Selektoren benutzen dieselbe Typ-1-Regel und dieselben Multiplikatoren.

const LANDSCAPE_PREFERRED_MULTIPLIER: float = 8.0
const LANDSCAPE_DEFAULT_MULTIPLIER: float = 1.0
const LANDSCAPE_RARE_MULTIPLIER: float = 0.2
const LANDSCAPE_EXCLUDED_MULTIPLIER: float = 0.0

var _tf_capture_generated_species_by_root: Dictionary = {}


func route_landscape_type_multiplier(species_types: Array, landscape_id: String = "") -> float:
    var resolved_landscape_id: String = landscape_id
    if resolved_landscape_id.is_empty():
        resolved_landscape_id = current_landscape_id

    var landscape: Dictionary = route_landscape(resolved_landscape_id)
    if landscape.is_empty():
        return LANDSCAPE_DEFAULT_MULTIPLIER

    # Nur Typ 1 bestimmt die Landschaftskorrelation. Die Reihenfolge in
    # species_types ist daher spielmechanisch relevant und darf hier nicht
    # normalisiert, sortiert oder mit Typ 2 kombiniert werden.
    if species_types.is_empty():
        return LANDSCAPE_DEFAULT_MULTIPLIER
    var primary_type: String = str(species_types[0]).strip_edges().to_lower()
    if primary_type.is_empty():
        return LANDSCAPE_DEFAULT_MULTIPLIER

    var preferred_value: Variant = landscape.get("preferred_types", [])
    var rare_value: Variant = landscape.get("rare_types", [])
    var excluded_value: Variant = landscape.get("excluded_types", [])
    var preferred: Array = preferred_value if preferred_value is Array else []
    var rare: Array = rare_value if rare_value is Array else []
    var excluded: Array = excluded_value if excluded_value is Array else []

    if excluded.has(primary_type):
        return LANDSCAPE_EXCLUDED_MULTIPLIER
    if rare.has(primary_type):
        return LANDSCAPE_RARE_MULTIPLIER
    if preferred.has(primary_type):
        return LANDSCAPE_PREFERRED_MULTIPLIER
    return LANDSCAPE_DEFAULT_MULTIPLIER


func route_landscape_combined_weight(
    base_weight: float,
    species_types: Array,
    landscape_id: String = ""
) -> float:
    return maxf(0.0, base_weight) * route_landscape_type_multiplier(species_types, landscape_id)


func _tf_species_types(species_id: String) -> Array:
    if battle_demo == null or not battle_demo.has_method("route_species_types"):
        return []
    var value: Variant = battle_demo.call("route_species_types", species_id)
    return (value as Array).duplicate() if value is Array else []


func _tf_landscape_multiplier_for_species(species_id: String) -> float:
    return route_landscape_type_multiplier(_tf_species_types(species_id))


func _weighted_encounter_species(candidates: Array) -> String:
    if candidates.is_empty():
        return ""

    var total_weight: float = 0.0
    var weights: Array[float] = []
    for species_value: Variant in candidates:
        var species_id: String = str(species_value)
        var rarity_weight: float = maxf(0.0, _encounter_species_weight(species_id))
        var landscape_multiplier: float = _tf_landscape_multiplier_for_species(species_id)
        var weight: float = rarity_weight * landscape_multiplier
        weights.append(weight)
        total_weight += weight

    # x0 ist ein echter Landschaftsausschluss. Wenn ein zukünftiger, extrem
    # kleiner Kandidatenpool ausschließlich ausgeschlossene Typen enthält,
    # verletzen wir die Regel nicht still durch einen zufälligen Fallback.
    if total_weight <= 0.0:
        push_error(
            "Landschaft '%s': Kein erlaubtes Begegnungs-Pokémon im aktuellen Kandidatenpool."
            % current_landscape_id
        )
        return ""

    var roll: float = randf() * total_weight
    var cumulative: float = 0.0
    for index: int in range(candidates.size()):
        cumulative += weights[index]
        if roll <= cumulative and weights[index] > 0.0:
            return str(candidates[index])

    for index: int in range(candidates.size() - 1, -1, -1):
        if weights[index] > 0.0:
            return str(candidates[index])
    return ""


func _weighted_capture_root(roots: Array, search_number: int) -> String:
    if roots.is_empty() or battle_demo == null:
        return ""

    # The exact generated branch used for landscape weighting must be the same
    # branch that is shown and offered afterwards. Otherwise an Eevee family
    # could be weighted as one type and then rerolled into another type.
    _tf_capture_generated_species_by_root.clear()

    var unseen: Array[String] = []
    for root_value: Variant in roots:
        var root_id: String = str(root_value)
        var family_id: String = _family_id_for_species(root_id)
        if not _capture_seen_families.has(family_id):
            unseen.append(root_id)

    var selected: String = _tf_weighted_capture_root_from_candidates(unseen, search_number)
    if not selected.is_empty():
        return selected

    # Ist jeder noch ungesehene Familientyp in dieser Landschaft x0, darf eine
    # bereits gesehene, aber erlaubte Familie erneut erscheinen. Das erhält die
    # bestehende Anti-Duplikat-Präferenz, ohne einen Landschaftsausschluss zu brechen.
    var all_roots: Array[String] = []
    for root_value: Variant in roots:
        all_roots.append(str(root_value))
    selected = _tf_weighted_capture_root_from_candidates(all_roots, search_number)
    if selected.is_empty():
        push_error(
            "Landschaft '%s': Keine erlaubte Fangwiesen-Familie für Suche %d verfügbar."
            % [current_landscape_id, search_number]
        )
    return selected


func _tf_generated_capture_species(root_id: String, capture_level: int) -> String:
    var cached: String = str(_tf_capture_generated_species_by_root.get(root_id, ""))
    if not cached.is_empty():
        return cached

    var species_id: String = ""
    if battle_demo != null and battle_demo.has_method("route_resolve_generated_species_for_level"):
        species_id = str(
            battle_demo.call(
                "route_resolve_generated_species_for_level",
                root_id,
                capture_level
            )
        )
    elif battle_demo != null:
        species_id = str(battle_demo.call("route_resolve_species_for_level", root_id, capture_level))

    if not species_id.is_empty():
        _tf_capture_generated_species_by_root[root_id] = species_id
    return species_id


func _resolve_capture_species_for_root(root_id: String, capture_level: int) -> String:
    var cached: String = str(_tf_capture_generated_species_by_root.get(root_id, ""))
    if not cached.is_empty():
        return cached
    return super._resolve_capture_species_for_root(root_id, capture_level)


func _tf_weighted_capture_root_from_candidates(candidates: Array[String], search_number: int) -> String:
    if candidates.is_empty() or battle_demo == null:
        return ""

    var capture_level: int = _capture_level_for_search(search_number)
    var total_weight: float = 0.0
    var weights: Array[float] = []

    for root_id: String in candidates:
        var species_id: String = _tf_generated_capture_species(root_id, capture_level)
        if species_id.is_empty():
            weights.append(0.0)
            continue

        var family_id: String = _family_id_for_species(root_id)
        var rarity_weight: float = maxf(0.0, _capture_family_weight(family_id, search_number))
        var landscape_multiplier: float = _tf_landscape_multiplier_for_species(species_id)
        var weight: float = rarity_weight * landscape_multiplier
        weights.append(weight)
        total_weight += weight

    if total_weight <= 0.0:
        return ""

    var roll: float = randf() * total_weight
    var cumulative: float = 0.0
    for index: int in range(candidates.size()):
        cumulative += weights[index]
        if roll <= cumulative and weights[index] > 0.0:
            return candidates[index]

    for index: int in range(candidates.size() - 1, -1, -1):
        if weights[index] > 0.0:
            return candidates[index]
    return ""
