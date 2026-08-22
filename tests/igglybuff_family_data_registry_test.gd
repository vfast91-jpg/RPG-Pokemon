extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v6.json"
const META_PATH: String = "res://data/gen1_database_meta_v6.json"
const SPECIES_PATH: String = "res://data/gen1_species_v3_igglybuff_family_v1.json"
const MOVE_PATH: String = "res://data/gen1_moves_runtime_v3_24_igglybuff_family.json"
const STATS_PATH: String = "res://data/gen1_species_stat_profiles_v4.json"
const WEIGHTS_PATH: String = "res://data/gen1_species_weights_v1.json"
const ENCOUNTERS_PATH: String = "res://data/gen1_species_encounter_families_v1.json"

var failures: int = 0


func _initialize() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    var meta: Dictionary = _read_json(META_PATH)
    var species_pack: Dictionary = _read_json(SPECIES_PATH)
    var move_pack: Dictionary = _read_json(MOVE_PATH)
    var stats: Dictionary = _read_json(STATS_PATH)
    var weights: Dictionary = _read_json(WEIGHTS_PATH)
    var encounters: Dictionary = _read_json(ENCOUNTERS_PATH)

    _check_equal_int(int(manifest.get("species_count", 0)), 43, "V6-Speziesanzahl ist falsch.")
    _check_equal_int(int(manifest.get("move_count", 0)), 313, "V6-Attackenanzahl ist falsch.")
    _check_equal_int(int(manifest.get("route_root_count", 0)), 16, "V6-Routenfamilienanzahl ist falsch.")

    var species_files: Array = manifest.get("species_files", [])
    var move_files: Array = manifest.get("move_files", [])
    _check(species_files.has(SPECIES_PATH), "Fluffeluff-Speziespaket fehlt im aktiven Manifest.")
    _check(move_files.has(MOVE_PATH), "Fluffeluff-Attackenpaket fehlt im aktiven Manifest.")

    var route_roots: Array = meta.get("route_roots", [])
    _check(route_roots.has("igglybuff"), "Fluffeluff fehlt als Routenfamilienwurzel.")

    var species_value: Variant = species_pack.get("species", {})
    var species: Dictionary = species_value if species_value is Dictionary else {}
    for species_id: String in ["igglybuff", "jigglypuff", "wigglytuff"]:
        _check(species.has(species_id), "Familienmitglied fehlt: " + species_id)

    var iggly: Dictionary = species.get("igglybuff", {})
    var jiggly: Dictionary = species.get("jigglypuff", {})
    var wiggly: Dictionary = species.get("wigglytuff", {})

    _check_stats(iggly, 90, 35, 15, 35, 15, "Fluffeluff")
    _check_stats(jiggly, 115, 45, 20, 45, 20, "Pummeluff")
    _check_stats(wiggly, 140, 80, 45, 70, 45, "Knuddeluff")

    _check_evolution(iggly, "jigglypuff", 16, "Fluffeluff")
    _check_evolution(jiggly, "wigglytuff", 40, "Pummeluff")
    var final_evo_value: Variant = wiggly.get("evolution", {})
    _check(not (final_evo_value is Dictionary) or (final_evo_value as Dictionary).is_empty(), "Knuddeluff darf keine weitere Entwicklung besitzen.")

    _check_tm_list(iggly, 41, "Fluffeluff")
    _check_tm_list(jiggly, 76, "Pummeluff")
    _check_tm_list(wiggly, 80, "Knuddeluff")

    var jiggly_tm: Dictionary = ((jiggly.get("learnset", {}) as Dictionary).get("tm_hm", {}))
    var wiggly_tm: Dictionary = ((wiggly.get("learnset", {}) as Dictionary).get("tm_hm", {}))
    _check(str(jiggly_tm.get("TM228", "")) == "psychic_noise", "Pummeluff muss TM228 Psycholärm lernen können.")
    _check(str(wiggly_tm.get("TM218", "")) == "expanding_force", "Knuddeluff muss TM218 Flächenmacht lernen können.")
    _check(str(wiggly_tm.get("TM228", "")) == "psychic_noise", "Knuddeluff muss TM228 Psycholärm lernen können.")

    var all_moves: Dictionary = _load_manifest_moves(manifest)
    for species_id: String in ["igglybuff", "jigglypuff", "wigglytuff"]:
        _check_all_referenced_moves_resolve(species.get(species_id, {}), all_moves, species_id)

    var new_moves_value: Variant = move_pack.get("moves", {})
    var new_moves: Dictionary = new_moves_value if new_moves_value is Dictionary else {}
    _check_equal_int(new_moves.size(), 5, "Das Fluffeluff-Attackenpaket muss exakt fünf neue Attacken enthalten.")
    for move_id: String in ["covet", "round", "mimic", "expanding_force", "psychic_noise"]:
        _check(new_moves.has(move_id), "Neue Attacke fehlt: " + move_id)
        var move: Dictionary = new_moves.get(move_id, {})
        var runtime: Dictionary = move.get("runtime", {})
        _check(bool(runtime.get("runtime_supported", false)), move_id + " muss runtime_supported sein.")
        _check(bool(runtime.get("strict_contract", false)), move_id + " muss Strict-V4-fähig sein.")
        var behavior_tests: Array = move.get("required_behavior_tests", [])
        _check(not behavior_tests.is_empty(), move_id + " braucht required_behavior_tests.")

    var stat_species: Dictionary = stats.get("species", {})
    _check_stats({"base_stats": stat_species.get("igglybuff", {})}, 90, 35, 15, 35, 15, "Fluffeluff-Statprofil")
    _check_stats({"base_stats": stat_species.get("jigglypuff", {})}, 115, 45, 20, 45, 20, "Pummeluff-Statprofil")
    _check_stats({"base_stats": stat_species.get("wigglytuff", {})}, 140, 80, 45, 70, 45, "Knuddeluff-Statprofil")

    var weight_map: Dictionary = weights.get("weights_kg", {})
    _check_equal_float(float(weight_map.get("igglybuff", 0.0)), 1.0, "Fluffeluff-Gewicht ist falsch.")
    _check_equal_float(float(weight_map.get("jigglypuff", 0.0)), 5.5, "Pummeluff-Gewicht ist falsch.")
    _check_equal_float(float(weight_map.get("wigglytuff", 0.0)), 12.0, "Knuddeluff-Gewicht ist falsch.")

    var families: Dictionary = encounters.get("families", {})
    var family: Dictionary = families.get("igglybuff", {})
    _check(family.get("members", []) == ["igglybuff", "jigglypuff", "wigglytuff"], "Fluffeluff-Familienmitglieder sind falsch registriert.")
    _check_equal_float(float(family.get("family_catch_rate", 0.0)), 130.0, "Fluffeluff-Familien-Fangrate ist falsch.")
    var species_to_family: Dictionary = encounters.get("species_to_family", {})
    for species_id: String in ["igglybuff", "jigglypuff", "wigglytuff"]:
        _check(str(species_to_family.get(species_id, "")) == "igglybuff", "Fangfamilienzuordnung fehlt: " + species_id)

    for display_name: String in ["Fluffeluff", "Pummeluff", "Knuddeluff"]:
        _check(FileAccess.file_exists("res://assets/monsters/" + display_name + ".png"), "Pokémon-Bild fehlt: " + display_name)

    var scene_text: String = FileAccess.get_file_as_string("res://main.tscn")
    _check(scene_text.contains("res://scripts/battle_demo_igglybuff_family.gd"), "main.tscn lädt den Fluffeluff-Runtime-Layer nicht.")

    if failures == 0:
        print("Fluffeluff/Pummeluff/Knuddeluff data registry test: PASS")
        quit(0)
    else:
        push_error("Fluffeluff/Pummeluff/Knuddeluff data registry test: %d Fehler" % failures)
        quit(1)


func _check_stats(entry: Dictionary, hp: int, attack: int, defense: int, special: int, speed: int, label: String) -> void:
    var stats_value: Variant = entry.get("base_stats", {})
    var values: Dictionary = stats_value if stats_value is Dictionary else {}
    _check_equal_int(int(values.get("hp", 0)), hp, label + " KP sind falsch.")
    _check_equal_int(int(values.get("attack", 0)), attack, label + " Angriff ist falsch.")
    _check_equal_int(int(values.get("defense", 0)), defense, label + " Verteidigung ist falsch.")
    _check_equal_int(int(values.get("special", 0)), special, label + " Statuswert ist falsch.")
    _check_equal_int(int(values.get("speed", 0)), speed, label + " Geschwindigkeit ist falsch.")


func _check_evolution(entry: Dictionary, target_id: String, level: int, label: String) -> void:
    var evolution: Dictionary = entry.get("evolution", {})
    _check(str(evolution.get("evolves_into", "")) == target_id, label + " entwickelt sich zum falschen Ziel.")
    _check_equal_int(int(evolution.get("evolution_level", 0)), level, label + " hat das falsche Entwicklungslevel.")
    _check(bool(evolution.get("mandatory", false)), label + "-Entwicklung muss verpflichtend sein.")


func _check_tm_list(entry: Dictionary, expected_count: int, label: String) -> void:
    var learnset: Dictionary = entry.get("learnset", {})
    var tm_value: Variant = learnset.get("tm_hm", {})
    var tms: Dictionary = tm_value if tm_value is Dictionary else {}
    _check_equal_int(tms.size(), expected_count, label + " hat die falsche TM-Anzahl.")
    _check(not tms.values().has("tera_blast"), label + " darf Tera-Ausbruch nicht enthalten.")


func _load_manifest_moves(manifest: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for path_value: Variant in manifest.get("move_files", []):
        var pack: Dictionary = _read_json(str(path_value))
        var entries_value: Variant = pack.get("moves", {})
        if not (entries_value is Dictionary):
            continue
        for move_id_value: Variant in (entries_value as Dictionary).keys():
            result[str(move_id_value)] = (entries_value as Dictionary).get(move_id_value, {})
    return result


func _check_all_referenced_moves_resolve(entry: Dictionary, moves: Dictionary, species_id: String) -> void:
    var learnset: Dictionary = entry.get("learnset", {})
    var referenced: Array[String] = []
    var level_up: Dictionary = learnset.get("level_up", {})
    for level_moves_value: Variant in level_up.values():
        if level_moves_value is Array:
            for move_value: Variant in level_moves_value:
                _append_unique(referenced, str(move_value))
    for key: String in ["evolution_moves", "relearn_lv1"]:
        var move_list_value: Variant = learnset.get(key, [])
        if move_list_value is Array:
            for move_value: Variant in move_list_value:
                _append_unique(referenced, str(move_value))
    var tm_map: Dictionary = learnset.get("tm_hm", {})
    for move_value: Variant in tm_map.values():
        _append_unique(referenced, str(move_value))
    for move_id: String in referenced:
        _check(moves.has(move_id), species_id + " referenziert nicht auflösbare Attacke: " + move_id)


func _append_unique(values: Array[String], value: String) -> void:
    if not value.is_empty() and not values.has(value):
        values.append(value)


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
