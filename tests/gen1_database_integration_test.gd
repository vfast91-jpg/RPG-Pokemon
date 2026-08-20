extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v3.json"


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

    assert(species.size() == 27, "Es müssen exakt 27 entworfene Pokémon-Formen geladen werden.")
    assert(moves.size() == 128, "Es müssen exakt 128 definierte Attacken geladen werden.")
    assert((meta.get("route_roots", []) as Array).size() == 10, "Die Demo braucht exakt zehn Basislinien.")

    _assert_evolution(species, "caterpie", "metapod", 7)
    _assert_evolution(species, "metapod", "butterfree", 10)
    _assert_evolution(species, "pichu", "pikachu", 15)
    _assert_evolution(species, "pikachu", "raichu", 30)

    var quick_attack: Dictionary = moves.get("quick_attack", {})
    assert(int(quick_attack.get("power", 0)) == 30, "Ruckzuckhieb muss Datenbank-Stärke 30 verwenden.")
    assert(int(quick_attack.get("ap", 0)) == 8, "Ruckzuckhieb muss RPG-AP 8 verwenden.")
    assert(bool(quick_attack.get("opening", false)), "Ruckzuckhieb muss in Runde 0 verfügbar sein.")
    var quick_runtime: Dictionary = quick_attack.get("runtime", {})
    assert(not bool(quick_runtime.get("normal_battle_available", true)), "Ruckzuckhieb darf außerhalb Runde 0 nicht angeboten werden.")

    assert(not moves.has("acid"), "Säure darf ohne Attackendefinition nicht erfunden werden.")
    assert(not moves.has("glare"), "Giftblick darf ohne Attackendefinition nicht erfunden werden.")
    assert(not moves.has("screech"), "Kreideschrei darf ohne Attackendefinition nicht erfunden werden.")

    var gaps: Dictionary = meta.get("data_gaps", {})
    assert((gaps.get("missing_move_definitions", []) as Array).size() == 3, "Die drei bekannten Level-Attacken-Lücken müssen dokumentiert bleiben.")
    assert((gaps.get("missing_tm_move_definitions", []) as Array).size() == 116, "Die 116 noch undefinierten TM-Attacken müssen dokumentiert bleiben.")

    for unsupported_id: String in ["belch", "electro_ball", "roar", "whirlwind"]:
        var move: Dictionary = moves.get(unsupported_id, {})
        var runtime: Dictionary = move.get("runtime", {})
        assert(not bool(runtime.get("runtime_supported", true)), unsupported_id + " muss bis zur fehlenden Regelkalibrierung deaktiviert bleiben.")

    for species_value: Variant in species.values():
        var entry: Dictionary = species_value
        var display_name: String = str(entry.get("display_name", ""))
        assert(not display_name.is_empty(), "Jede Spezies braucht einen deutschen Anzeigenamen.")
        var sprite_path: String = "res://assets/monsters/" + display_name + ".png"
        assert(ResourceLoader.exists(sprite_path), "Fehlendes Pokémon-Bild: " + sprite_path)

    var scene_text: String = FileAccess.get_file_as_string("res://main.tscn")
    assert(scene_text.contains("res://scripts/battle_demo_database.gd"), "main.tscn muss den kanonischen Kampf-Runtime laden.")
    assert(scene_text.contains("res://scripts/demo_route_database.gd"), "main.tscn muss die kanonische TM-Route laden.")

    print("Gen1 database integration tests: OK")
    quit(0)


func _assert_evolution(species: Dictionary, source_id: String, target_id: String, level: int) -> void:
    var source: Dictionary = species.get(source_id, {})
    var evolution: Dictionary = source.get("evolution", {})
    assert(str(evolution.get("evolves_into", "")) == target_id, source_id + " muss sich zu " + target_id + " entwickeln.")
    assert(int(evolution.get("evolution_level", 0)) == level, source_id + " hat ein falsches Entwicklungslevel.")
    assert(bool(evolution.get("mandatory", false)), source_id + " muss sich verpflichtend entwickeln.")


func _read_json(path: String) -> Dictionary:
    if path.is_empty():
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
