extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v6.json"
const META_PATH: String = "res://data/gen1_database_meta_v6.json"
const STATS_PATH: String = "res://data/gen1_species_stat_profiles_v4.json"
const WEIGHTS_PATH: String = "res://data/gen1_species_weights_v1.json"
const ENCOUNTERS_PATH: String = "res://data/gen1_species_encounter_families_v1.json"

var failures: int = 0


func _initialize() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    var meta: Dictionary = _read_json(META_PATH)
    var stats: Dictionary = _read_json(STATS_PATH)
    var weights: Dictionary = _read_json(WEIGHTS_PATH)
    var encounters: Dictionary = _read_json(ENCOUNTERS_PATH)

    _check_equal_int(int(manifest.get("species_count", 0)), 43, "V6-Speziesanzahl ist falsch.")
    _check_equal_int(int(manifest.get("move_count", 0)), 313, "V6-Attackenanzahl ist falsch.")
    _check_equal_int(int(manifest.get("route_root_count", 0)), 16, "V6-Routenfamilienanzahl ist falsch.")

    var species_files_value: Variant = manifest.get("species_files", [])
    var species_files: Array = species_files_value if species_files_value is Array else []
    var move_files_value: Variant = manifest.get("move_files", [])
    var move_files: Array = move_files_value if move_files_value is Array else []
    _check(species_files.has("res://data/gen1_species_v3_vulpix_family_v1.json"), "Vulpix-Speziespaket fehlt im V6-Manifest.")
    _check(move_files.has("res://data/gen1_moves_runtime_v3_23_vulpix_family.json"), "Vulpix-Attackenpaket fehlt im V6-Manifest.")

    var route_roots_value: Variant = meta.get("route_roots", [])
    var route_roots: Array = route_roots_value if route_roots_value is Array else []
    _check(route_roots.has("vulpix"), "Vulpix fehlt als Routenfamilienwurzel in V6.")

    var stat_species_value: Variant = stats.get("species", {})
    var stat_species: Dictionary = stat_species_value if stat_species_value is Dictionary else {}
    var vulpix_stats_value: Variant = stat_species.get("vulpix", {})
    var ninetales_stats_value: Variant = stat_species.get("ninetales", {})
    var vulpix_stats: Dictionary = vulpix_stats_value if vulpix_stats_value is Dictionary else {}
    var ninetales_stats: Dictionary = ninetales_stats_value if ninetales_stats_value is Dictionary else {}
    _check_equal_int(int(vulpix_stats.get("special", 0)), 60, "Vulpix-Statuswertprofil ist falsch.")
    _check_equal_int(int(ninetales_stats.get("speed", 0)), 100, "Vulnona-Geschwindigkeitsprofil ist falsch.")

    var weight_map_value: Variant = weights.get("weights_kg", {})
    var weight_map: Dictionary = weight_map_value if weight_map_value is Dictionary else {}
    _check_equal_float(float(weight_map.get("vulpix", 0.0)), 9.9, "Vulpix-Gewicht ist falsch.")
    _check_equal_float(float(weight_map.get("ninetales", 0.0)), 19.9, "Vulnona-Gewicht ist falsch.")

    var families_value: Variant = encounters.get("families", {})
    var families: Dictionary = families_value if families_value is Dictionary else {}
    var vulpix_family_value: Variant = families.get("vulpix", {})
    var vulpix_family: Dictionary = vulpix_family_value if vulpix_family_value is Dictionary else {}
    var members_value: Variant = vulpix_family.get("members", [])
    var members: Array = members_value if members_value is Array else []
    _check(members == ["vulpix", "ninetales"], "Vulpix-Familienmitglieder sind falsch registriert.")
    _check_equal_float(float(vulpix_family.get("family_catch_rate", 0.0)), 132.5, "Vulpix-Familien-Fangrate ist falsch.")

    var species_to_family_value: Variant = encounters.get("species_to_family", {})
    var species_to_family: Dictionary = species_to_family_value if species_to_family_value is Dictionary else {}
    _check(str(species_to_family.get("vulpix", "")) == "vulpix", "Vulpix-Familienzuordnung fehlt.")
    _check(str(species_to_family.get("ninetales", "")) == "vulpix", "Vulnona-Familienzuordnung fehlt.")

    if failures == 0:
        print("Vulpix/Vulnona data registry test: PASS")
        quit(0)
    else:
        push_error("Vulpix/Vulnona data registry test: %d Fehler" % failures)
        quit(1)


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        _fail("Datei fehlt: " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        _fail("JSON konnte nicht gelesen werden: " + path)
        return {}
    return parsed as Dictionary


func _check(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _check_equal_int(actual: int, expected: int, message: String) -> void:
    if actual != expected:
        _fail(message + " Erwartet %d, erhalten %d." % [expected, actual])


func _check_equal_float(actual: float, expected: float, message: String) -> void:
    if not is_equal_approx(actual, expected):
        _fail(message + " Erwartet %.2f, erhalten %.2f." % [expected, actual])


func _fail(message: String) -> void:
    failures += 1
    push_error(message)