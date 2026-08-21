extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v3.json"
const STAT_PROFILE_PATH: String = "res://data/gen1_species_stat_profiles_v4.json"

const FAMILY_NEW_MOVES: Array[String] = [
    "false_swipe","body_slam","leaf_storm","toxic","knock_off","weather_ball",
    "grassy_glide","curse","bulldoze","stomping_tantrum","amnesia","earth_power",
    "earthquake","frenzy_plant"
]


func _initialize() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    assert(not manifest.is_empty(), "Kanonisches Datenbank-Manifest muss lesbar sein.")

    var meta: Dictionary = _read_json(str(manifest.get("species_meta_file", "")))
    assert(not meta.is_empty(), "Kanonische Datenbank-Metadaten müssen lesbar sein.")

    var species: Dictionary = {}
    for path_value: Variant in manifest.get("species_files", []):
        var pack: Dictionary = _read_json(str(path_value))
        var entries_value: Variant = pack.get("species", {})
        assert(entries_value is Dictionary, "Ungültiges Pokémon-Paket: " + str(path_value))
        for species_id_value: Variant in (entries_value as Dictionary).keys():
            species[str(species_id_value)] = (entries_value as Dictionary)[species_id_value]

    var moves: Dictionary = {}
    for path_value: Variant in manifest.get("move_files", []):
        var pack: Dictionary = _read_json(str(path_value))
        var entries_value: Variant = pack.get("moves", {})
        assert(entries_value is Dictionary, "Ungültiges Attacken-Paket: " + str(path_value))
        for move_id_value: Variant in (entries_value as Dictionary).keys():
            moves[str(move_id_value)] = (entries_value as Dictionary)[move_id_value]

    assert(species.size() == 27, "Es müssen exakt 27 entworfene Pokémon-Formen geladen werden.")
    assert(moves.size() == 159, "Nach der kanonischen Bisasam-TM-Migration müssen exakt 159 Attacken geladen werden.")
    assert((meta.get("route_roots", []) as Array).size() == 10, "Die Demo braucht exakt zehn Basislinien.")

    _assert_evolution(species, "bulbasaur", "ivysaur", 16)
    _assert_evolution(species, "ivysaur", "venusaur", 32)
    _assert_evolution(species, "caterpie", "metapod", 7)
    _assert_evolution(species, "metapod", "butterfree", 10)
    _assert_evolution(species, "pichu", "pikachu", 15)
    _assert_evolution(species, "pikachu", "raichu", 30)

    _assert_family_tm_count(species, "bulbasaur", 33)
    _assert_family_tm_count(species, "ivysaur", 34)
    _assert_family_tm_count(species, "venusaur", 44)

    for move_id: String in FAMILY_NEW_MOVES:
        assert(moves.has(move_id), "Kanonische neue Familien-TM fehlt: " + move_id)
        var runtime_value: Variant = (moves[move_id] as Dictionary).get("runtime", {})
        assert(runtime_value is Dictionary and bool((runtime_value as Dictionary).get("runtime_supported", false)), "Neue Familien-TM ist nicht aktiv: " + move_id)

    var quick_attack: Dictionary = moves.get("quick_attack", {})
    assert(int(quick_attack.get("power", 0)) == 30, "Ruckzuckhieb muss Stärke 30 verwenden.")
    assert(int(quick_attack.get("ap", 0)) == 8, "Ruckzuckhieb muss RPG-AP 8 verwenden.")
    assert(bool(quick_attack.get("opening", false)), "Ruckzuckhieb muss in Runde 0 verfügbar sein.")
    assert(not bool((quick_attack.get("runtime", {}) as Dictionary).get("normal_battle_available", true)), "Ruckzuckhieb darf außerhalb Runde 0 nicht angeboten werden.")

    for supported_id: String in ["roar", "whirlwind"]:
        var move: Dictionary = moves.get(supported_id, {})
        assert(bool((move.get("runtime", {}) as Dictionary).get("runtime_supported", false)), supported_id + " muss mit der zentralen Statuswert→Zeitleisten-Pause aktiv sein.")

    for unsupported_id: String in ["belch", "electro_ball"]:
        var move: Dictionary = moves.get(unsupported_id, {})
        assert(not bool((move.get("runtime", {}) as Dictionary).get("runtime_supported", true)), unsupported_id + " muss als bestehende unabhängige Runtime-Lücke deaktiviert bleiben.")

    var gaps: Dictionary = meta.get("data_gaps", {})
    var missing_tm: Array = gaps.get("missing_tm_move_definitions", [])
    assert(missing_tm.size() == 88, "Nach der Bisasam-Familien-Migration müssen 88 andere, noch offene TM-Definitionen dokumentiert bleiben.")
    assert(not missing_tm.has("tera_blast"), "Tera-Ausbruch ist bewusst ausgeschlossen und darf nicht als offene Timeflow-TM geführt werden.")
    for move_id: String in FAMILY_NEW_MOVES:
        assert(not missing_tm.has(move_id), "Implementierte Familien-TM darf nicht mehr als Datenlücke geführt werden: " + move_id)

    _assert_rettan_basics(moves)
    _assert_rettan_stat_profiles()

    for species_value: Variant in species.values():
        var entry: Dictionary = species_value
        var display_name: String = str(entry.get("display_name", ""))
        assert(not display_name.is_empty(), "Jede Spezies braucht einen deutschen Anzeigenamen.")
        assert(ResourceLoader.exists("res://assets/monsters/" + display_name + ".png"), "Fehlendes Pokémon-Bild: " + display_name)

    var scene_text: String = FileAccess.get_file_as_string("res://main.tscn")
    assert(scene_text.contains("res://scripts/battle_demo_periodic_wait_fix.gd"), "main.tscn muss die vollständige Familien-TM-Runtime inklusive Warteticks laden.")
    assert(scene_text.contains("res://scripts/demo_route_tm_decline_xp.gd"), "main.tscn muss den aktuellen Demo-Routen-Einstieg laden.")

    print("Gen1 database integration tests: OK")
    quit(0)


func _assert_family_tm_count(species: Dictionary, species_id: String, expected_count: int) -> void:
    var entry: Dictionary = species.get(species_id, {})
    var learnset: Dictionary = entry.get("learnset", {})
    var tm_map: Dictionary = learnset.get("tm_hm", {})
    assert(tm_map.size() == expected_count, "%s muss exakt %d Nicht-Tera-TMs besitzen." % [species_id, expected_count])
    assert(not tm_map.values().has("tera_blast"), species_id + " darf Tera-Ausbruch nicht enthalten.")


func _assert_rettan_basics(moves: Dictionary) -> void:
    var glare: Dictionary = moves.get("glare", {})
    assert(str(glare.get("name", "")) == "Schlangenblick", "Glare muss Schlangenblick heißen.")
    assert(int(glare.get("accuracy", 0)) == 100 and int(glare.get("ap", 0)) == 3, "Schlangenblick-Daten sind inkonsistent.")

    var screech: Dictionary = moves.get("screech", {})
    assert(str(screech.get("name", "")) == "Kreideschrei", "Screech muss Kreideschrei heißen.")
    assert(int(screech.get("accuracy", 0)) == 85 and int(screech.get("ap", 0)) == 1, "Kreideschrei-Daten sind inkonsistent.")

    var acid: Dictionary = moves.get("acid", {})
    assert(str(acid.get("name", "")) == "Säure", "Acid muss Säure heißen.")
    assert(str(acid.get("target", "")) == "all_enemies" and bool(acid.get("area", false)), "Säure muss alle Gegner treffen.")


func _assert_rettan_stat_profiles() -> void:
    var profiles: Dictionary = _read_json(STAT_PROFILE_PATH).get("species", {})
    var ekans_stats: Dictionary = profiles.get("ekans", {})
    assert(int(ekans_stats.get("hp", 0)) == 35 and int(ekans_stats.get("attack", 0)) == 55, "Rettan-Statprofil ist inkonsistent.")
    assert(int(ekans_stats.get("special", 0)) == 65 and int(ekans_stats.get("speed", 0)) == 55, "Rettan-Statuswert/Geschwindigkeit sind inkonsistent.")
    var arbok_stats: Dictionary = profiles.get("arbok", {})
    assert(int(arbok_stats.get("hp", 0)) == 60 and int(arbok_stats.get("attack", 0)) == 105, "Arbok-Statprofil ist inkonsistent.")
    assert(int(arbok_stats.get("special", 0)) == 75 and int(arbok_stats.get("speed", 0)) == 80, "Arbok-Statuswert/Geschwindigkeit sind inkonsistent.")


func _assert_evolution(species: Dictionary, source_id: String, target_id: String, level: int) -> void:
    var source: Dictionary = species.get(source_id, {})
    var evolution: Dictionary = source.get("evolution", {})
    assert(str(evolution.get("evolves_into", "")) == target_id, source_id + " muss sich zu " + target_id + " entwickeln.")
    assert(int(evolution.get("evolution_level", 0)) == level, source_id + " hat ein falsches Entwicklungslevel.")
    assert(bool(evolution.get("mandatory", false)), source_id + " muss sich verpflichtend entwickeln.")


func _read_json(path: String) -> Dictionary:
    if path.is_empty():
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
