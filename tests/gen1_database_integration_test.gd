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
const BEEDRILL_NEW_MOVES: Array[String] = [
    "payback","flash","x_scissor","swagger","cut","defog","rock_smash"
]
const PIDGEY_NEW_MOVES: Array[String] = ["steel_wing"]

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
    assert(moves.size() == int(manifest.get("move_count", -1)) and moves.size() == 229, "Manifest/Attackenzahl muss 229 sein.")
    assert((meta.get("route_roots", []) as Array).size() == 10, "Die Demo braucht zehn Basislinien.")

    _assert_evolution(species,"bulbasaur","ivysaur",16)
    _assert_evolution(species,"ivysaur","venusaur",32)
    _assert_evolution(species,"squirtle","wartortle",16)
    _assert_evolution(species,"wartortle","blastoise",36)
    _assert_evolution(species,"caterpie","metapod",7)
    _assert_evolution(species,"metapod","butterfree",10)
    _assert_evolution(species,"weedle","kakuna",7)
    _assert_evolution(species,"kakuna","beedrill",10)
    _assert_evolution(species,"pidgey","pidgeotto",18)
    _assert_evolution(species,"pidgeotto","pidgeot",36)
    _assert_evolution(species,"pichu","pikachu",15)
    _assert_evolution(species,"pikachu","raichu",30)

    _assert_tm_count(species,"squirtle",35)
    _assert_tm_count(species,"wartortle",35)
    _assert_tm_count(species,"blastoise",52)
    _assert_tm_count(species,"caterpie",1)
    _assert_tm_count(species,"metapod",2)
    _assert_tm_count(species,"butterfree",33)
    _assert_tm_count(species,"weedle",1)
    _assert_tm_count(species,"kakuna",2)
    _assert_tm_count(species,"beedrill",29)
    _assert_tm_count(species,"pidgey",20)
    _assert_tm_count(species,"pidgeotto",20)
    _assert_tm_count(species,"pidgeot",22)

    var blastoise_tms: Dictionary = (((species.get("blastoise", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    for tm_id: String in ["TM046","TM149","TM154","TM158","TM172","TM179"]:
        assert(blastoise_tms.has(tm_id), "Turtok-Korrektur fehlt: " + tm_id)

    var butterfree_tms: Dictionary = (((species.get("butterfree", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    for tm_id: String in ["TM034","TM039","TM040","TM056","TM074","TM076","TM078","TM082","TM087","TM095"]:
        assert(butterfree_tms.has(tm_id), "Smettbo-Korrektur fehlt: " + tm_id)

    var weedle_tms: Dictionary = (((species.get("weedle", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    var kakuna_tms: Dictionary = (((species.get("kakuna", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    assert(weedle_tms.values().has("electroweb"), "Hornliu-Harmonisierung Elektronetz fehlt.")
    assert(kakuna_tms.values().has("electroweb") and kakuna_tms.values().has("iron_defense"), "Kokuna-Harmonisierung Elektronetz + Eisenabwehr fehlt.")

    var pidgey_tms: Dictionary = (((species.get("pidgey", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    var pidgeotto_tms: Dictionary = (((species.get("pidgeotto", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    var pidgeot_tms: Dictionary = (((species.get("pidgeot", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    assert(str(pidgey_tms.get("TM047", "")) == "steel_wing", "Taubsi muss TM047 Stahlflügel lernen können.")
    assert(str(pidgeotto_tms.get("TM047", "")) == "steel_wing", "Tauboga muss TM047 Stahlflügel lernen können.")
    assert(str(pidgeot_tms.get("TM047", "")) == "steel_wing", "Tauboss muss TM047 Stahlflügel lernen können.")

    for move_id: String in SQUIRTLE_NEW_MOVES:
        _assert_runtime_move(moves, move_id, "Schiggy")
    for move_id: String in CATERPIE_NEW_MOVES:
        _assert_runtime_move(moves, move_id, "Raupy")
    for move_id: String in BEEDRILL_NEW_MOVES:
        _assert_runtime_move(moves, move_id, "Bibor")
    for move_id: String in PIDGEY_NEW_MOVES:
        _assert_runtime_move(moves, move_id, "Taubsi")

    for unsupported_id: String in ["belch","electro_ball"]:
        var move: Dictionary = moves.get(unsupported_id, {})
        assert(not bool((move.get("runtime", {}) as Dictionary).get("runtime_supported", true)), unsupported_id + " muss als unabhängige Runtime-Lücke deaktiviert bleiben.")

    var gaps: Dictionary = meta.get("data_gaps", {})
    var missing_tm: Array = gaps.get("missing_tm_move_definitions", [])
    assert(not missing_tm.has("tera_blast"), "Tera-Ausbruch darf nicht als offene Timeflow-TM geführt werden.")
    for move_id: String in SQUIRTLE_NEW_MOVES + CATERPIE_NEW_MOVES + BEEDRILL_NEW_MOVES + PIDGEY_NEW_MOVES:
        assert(not missing_tm.has(move_id), "Implementierte TM darf nicht mehr als Datenlücke geführt werden: " + move_id)

    var partial_rules: Array = gaps.get("runtime_partial_rules", [])
    for rule_value: Variant in partial_rules:
        assert(not str(rule_value).begins_with("pluck:"), "Pflücker ist final itemfrei und darf nicht mehr als Runtime-Teilregel geführt werden.")

    _assert_rettan_stat_profiles()
    for species_value: Variant in species.values():
        var entry: Dictionary = species_value
        var display_name: String = str(entry.get("display_name", ""))
        assert(not display_name.is_empty(), "Jede Spezies braucht einen deutschen Anzeigenamen.")
        assert(ResourceLoader.exists("res://assets/monsters/" + display_name + ".png"), "Fehlendes Pokémon-Bild: " + display_name)

    var scene_text: String = FileAccess.get_file_as_string("res://main.tscn")
    assert(scene_text.contains("res://scripts/battle_demo_route_vitamins_v1.gd"), "main.tscn muss den aktuellen BattleDemo-Einstieg laden.")
    var route_guard_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_route_result_guard.gd")
    assert(route_guard_text.contains("res://scripts/battle_demo_pidgey_family.gd"), "Die aktive BattleDemo-Kette muss die Taubsi-Runtime laden.")
    assert(scene_text.contains("res://scripts/demo_route_cleanup_v1.gd"), "main.tscn muss den aktuellen Demo-Routen-Einstieg laden.")
    print("Gen1 database integration tests: OK")
    quit(0)


func _assert_runtime_move(moves: Dictionary, move_id: String, family_name: String) -> void:
    assert(moves.has(move_id), "Neue " + family_name + "-Familien-TM fehlt: " + move_id)
    var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
    assert(bool(runtime.get("runtime_supported", false)), move_id + " muss aktiv sein.")


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
