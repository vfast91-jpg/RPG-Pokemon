extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v3.json"
const STAT_PROFILE_PATH: String = "res://data/gen1_species_stat_profiles_v4.json"
const SQUIRTLE_NEW_MOVES: Array[String] = [
    "chilling_water","icy_wind","mud_shot","zen_headbutt","ice_punch","liquidation","surf","ice_spinner","ice_beam","blizzard",
    "water_pledge","gyro_ball","flip_turn","whirlpool","muddy_water","avalanche","body_press","dark_pulse","aura_sphere","hydro_cannon","smack_down"
]
const CATERPIE_NEW_MOVES: Array[String] = [
    "thief","snore","attract","u_turn","echoed_voice","draining_kiss",
    "psychic","baton_pass","shadow_ball","skill_swap","pollen_puff"
]

func _initialize() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    assert(not manifest.is_empty(), "Kanonisches Datenbank-Manifest muss lesbar sein.")
    var meta: Dictionary = _read_json(str(manifest.get("species_meta_file", "")))
    assert(not meta.is_empty(), "Kanonische Datenbank-Metadaten müssen lesbar sein.")

    var species: Dictionary = {}
    for path_value: Variant in manifest.get("species_files", []):
        var pack: Dictionary = _read_json(str(path_value))
        var entries: Dictionary = pack.get("species", {})
        for species_id_value: Variant in entries.keys():
            species[str(species_id_value)] = entries[species_id_value]

    var moves: Dictionary = {}
    for path_value: Variant in manifest.get("move_files", []):
        var pack: Dictionary = _read_json(str(path_value))
        var entries: Dictionary = pack.get("moves", {})
        for move_id_value: Variant in entries.keys():
            moves[str(move_id_value)] = entries[move_id_value]

    assert(species.size() == int(manifest.get("species_count", -1)) and species.size() == 27, "Manifest/Spezieszahl muss 27 sein.")
    assert(moves.size() == int(manifest.get("move_count", -1)) and moves.size() == 221, "Manifest/Attackenzahl muss 221 sein.")
    assert((meta.get("route_roots", []) as Array).size() == 10, "Die Demo braucht zehn Basislinien.")

    _assert_evolution(species,"bulbasaur","ivysaur",16)
    _assert_evolution(species,"ivysaur","venusaur",32)
    _assert_evolution(species,"squirtle","wartortle",16)
    _assert_evolution(species,"wartortle","blastoise",36)
    _assert_evolution(species,"caterpie","metapod",7)
    _assert_evolution(species,"metapod","butterfree",10)
    _assert_evolution(species,"pichu","pikachu",15)
    _assert_evolution(species,"pikachu","raichu",30)

    _assert_tm_count(species,"squirtle",35)
    _assert_tm_count(species,"wartortle",35)
    _assert_tm_count(species,"blastoise",52)
    _assert_tm_count(species,"caterpie",1)
    _assert_tm_count(species,"metapod",2)
    _assert_tm_count(species,"butterfree",33)
    var blastoise_tms: Dictionary = (((species.get("blastoise", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    for tm_id: String in ["TM046","TM149","TM154","TM158","TM172","TM179"]:
        assert(blastoise_tms.has(tm_id), "Turtok-Korrektur fehlt: " + tm_id)
    var butterfree_tms: Dictionary = (((species.get("butterfree", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    for tm_id: String in ["TM034","TM039","TM040","TM056","TM074","TM076","TM078","TM082","TM087","TM095"]:
        assert(butterfree_tms.has(tm_id), "Smettbo-Korrektur fehlt: " + tm_id)

    for move_id: String in SQUIRTLE_NEW_MOVES:
        assert(moves.has(move_id), "Neue Schiggy-Familien-TM fehlt: " + move_id)
        var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss aktiv sein.")
    for move_id: String in CATERPIE_NEW_MOVES:
        assert(moves.has(move_id), "Neue Raupy-Familien-TM fehlt: " + move_id)
        var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss aktiv sein.")

    for unsupported_id: String in ["belch","electro_ball"]:
        var move: Dictionary = moves.get(unsupported_id, {})
        assert(not bool((move.get("runtime", {}) as Dictionary).get("runtime_supported", true)), unsupported_id + " muss als unabhängige Runtime-Lücke deaktiviert bleiben.")

    var gaps: Dictionary = meta.get("data_gaps", {})
    var missing_tm: Array = gaps.get("missing_tm_move_definitions", [])
    assert(not missing_tm.has("tera_blast"), "Tera-Ausbruch darf nicht als offene Timeflow-TM geführt werden.")
    for move_id: String in SQUIRTLE_NEW_MOVES:
        assert(not missing_tm.has(move_id), "Implementierte Schiggy-TM darf nicht mehr als Datenlücke geführt werden: " + move_id)
    for move_id: String in CATERPIE_NEW_MOVES:
        assert(not missing_tm.has(move_id), "Implementierte Raupy-TM darf nicht mehr als Datenlücke geführt werden: " + move_id)

    _assert_rettan_stat_profiles()
    for species_value: Variant in species.values():
        var entry: Dictionary = species_value
        var display_name: String = str(entry.get("display_name", ""))
        assert(not display_name.is_empty(), "Jede Spezies braucht einen deutschen Anzeigenamen.")
        assert(ResourceLoader.exists("res://assets/monsters/" + display_name + ".png"), "Fehlendes Pokémon-Bild: " + display_name)

    var scene_text: String = FileAccess.get_file_as_string("res://main.tscn")
    assert(scene_text.contains("res://scripts/battle_demo_caterpie_family_ui.gd"), "main.tscn muss die finale Raupy-Familien-UI-/Runtime-Layer laden.")
    assert(scene_text.contains("res://scripts/demo_route_levelup_evolution_order_fix.gd"), "main.tscn muss den aktuellen Demo-Routen-Einstieg laden.")
    print("Gen1 database integration tests: OK")
    quit(0)

func _assert_tm_count(species: Dictionary, species_id: String, expected_count: int) -> void:
    var entry: Dictionary = species.get(species_id, {})
    var tms: Dictionary = ((entry.get("learnset", {}) as Dictionary).get("tm_hm", {}))
    assert(tms.size() == expected_count, "%s muss exakt %d Nicht-Tera-TMs besitzen." % [species_id,expected_count])
    assert(not tms.values().has("tera_blast"), species_id + " darf Tera-Ausbruch nicht enthalten.")

func _assert_rettan_stat_profiles() -> void:
    var profiles: Dictionary = _read_json(STAT_PROFILE_PATH).get("species", {})
    var ekans_stats: Dictionary = profiles.get("ekans", {})
    assert(int(ekans_stats.get("hp",0)) == 35 and int(ekans_stats.get("attack",0)) == 55)
    assert(int(ekans_stats.get("special",0)) == 65 and int(ekans_stats.get("speed",0)) == 55)
    var arbok_stats: Dictionary = profiles.get("arbok", {})
    assert(int(arbok_stats.get("hp",0)) == 60 and int(arbok_stats.get("attack",0)) == 105)
    assert(int(arbok_stats.get("special",0)) == 75 and int(arbok_stats.get("speed",0)) == 80)

func _assert_evolution(species: Dictionary, source_id: String, target_id: String, level: int) -> void:
    var evolution: Dictionary = ((species.get(source_id,{}) as Dictionary).get("evolution", {}))
    assert(str(evolution.get("evolves_into","")) == target_id)
    assert(int(evolution.get("evolution_level",0)) == level)
    assert(bool(evolution.get("mandatory",false)))

func _read_json(path: String) -> Dictionary:
    if path.is_empty():
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
