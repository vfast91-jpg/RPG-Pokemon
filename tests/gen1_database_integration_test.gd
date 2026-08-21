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
    assert(moves.size() == 131, "Es müssen exakt 131 definierte Attacken geladen werden.")
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

    _assert_rettan_moves(moves)
    _assert_rettan_stat_profiles(species)

    var gaps: Dictionary = meta.get("data_gaps", {})
    assert((gaps.get("missing_move_definitions", []) as Array).is_empty(), "Alle regulären Level-Attacken der geladenen Pokémon müssen definiert sein.")
    assert((gaps.get("missing_tm_move_definitions", []) as Array).size() == 116, "Die 116 noch undefinierten TM-Attacken müssen dokumentiert bleiben.")
    var unsupported: Array = gaps.get("runtime_unsupported_moves", [])
    assert(unsupported.size() == 2, "Nur die zwei weiterhin nicht kalibrierten Runtime-Attacken dürfen deaktiviert bleiben.")
    assert(unsupported.has("belch") and unsupported.has("electro_ball"), "Belch und Electro Ball müssen als verbleibende Runtime-Lücken dokumentiert sein.")

    for unsupported_id: String in ["belch", "electro_ball"]:
        var move: Dictionary = moves.get(unsupported_id, {})
        var runtime: Dictionary = move.get("runtime", {})
        assert(not bool(runtime.get("runtime_supported", true)), unsupported_id + " muss bis zur fehlenden Regelkalibrierung deaktiviert bleiben.")

    for supported_id: String in ["roar", "whirlwind"]:
        var move: Dictionary = moves.get(supported_id, {})
        var runtime: Dictionary = move.get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), supported_id + " muss mit der zentralen Status→ATB-Pausenkurve aktiv sein.")

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


func _assert_rettan_moves(moves: Dictionary) -> void:
    var glare: Dictionary = moves.get("glare", {})
    assert(not glare.is_empty(), "Rettans Lv.12-Attacke glare muss definiert sein.")
    assert(str(glare.get("name", "")) == "Schlangenblick", "Glare muss den aktuellen deutschen Namen Schlangenblick anzeigen.")
    assert(int(glare.get("accuracy", 0)) == 100, "Schlangenblick muss Genauigkeit 100 besitzen.")
    assert(int(glare.get("ap", 0)) == 3, "Schlangenblick muss aus 30 Original-AP RPG-AP 3 erhalten.")
    var glare_mechanics: Array = glare.get("mechanics", [])
    assert(not glare_mechanics.is_empty(), "Schlangenblick braucht eine zentrale Paralyse-Mechanik.")
    if not glare_mechanics.is_empty():
        var glare_status: Dictionary = glare_mechanics[0]
        assert(str(glare_status.get("kind", "")) == "status", "Schlangenblick muss die generische Statusmechanik verwenden.")
        assert(str(glare_status.get("status", "")) == "paralysis", "Schlangenblick muss Paralyse anwenden.")

    var screech: Dictionary = moves.get("screech", {})
    assert(not screech.is_empty(), "Rettans Lv.17-Attacke screech muss definiert sein.")
    assert(str(screech.get("name", "")) == "Kreideschrei", "Screech muss Kreideschrei heißen.")
    assert(int(screech.get("accuracy", 0)) == 85, "Kreideschrei muss Genauigkeit 85 besitzen.")
    assert(int(screech.get("ap", 0)) == 1, "Kreideschrei muss aus 40 Original-AP RPG-AP 1 erhalten.")
    var screech_mechanics: Array = screech.get("mechanics", [])
    assert(not screech_mechanics.is_empty(), "Kreideschrei braucht eine Verteidigungs-Debuff-Mechanik.")
    if not screech_mechanics.is_empty():
        var screech_debuff: Dictionary = screech_mechanics[0]
        assert(str(screech_debuff.get("kind", "")) == "incoming_damage_mod", "Kreideschrei muss die zentrale Verteidigungswirkung verwenden.")
        assert(is_equal_approx(float(screech_debuff.get("multiplier_from_special", 0.0)), 2.0), "Kreideschrei muss als starke 2×-Statuswert-Wirkung skaliert werden.")

    var acid: Dictionary = moves.get("acid", {})
    assert(not acid.is_empty(), "Rettans Lv.20-Attacke acid muss definiert sein.")
    assert(str(acid.get("name", "")) == "Säure", "Acid muss Säure heißen.")
    assert(int(acid.get("power", 0)) == 40, "Säure muss Stärke 40 besitzen.")
    assert(int(acid.get("accuracy", 0)) == 100, "Säure muss Genauigkeit 100 besitzen.")
    assert(int(acid.get("ap", 0)) == 3, "Säure muss aus 30 Original-AP RPG-AP 3 erhalten.")
    assert(str(acid.get("target", "")) == "all_enemies" and bool(acid.get("area", false)), "Säure muss im 4v4 alle Gegner treffen.")


func _assert_rettan_stat_profiles(species: Dictionary) -> void:
    var ekans: Dictionary = species.get("ekans", {})
    var ekans_stats: Dictionary = ekans.get("base_stats", {})
    assert(int(ekans_stats.get("hp", 0)) == 35, "Rettan KP-Basiswert muss 35 sein.")
    assert(int(ekans_stats.get("attack", 0)) == 55, "Rettan Angriff-Basiswert muss dem aktuellen Statprofil 55 entsprechen.")
    assert(int(ekans_stats.get("defense", 0)) == 35, "Rettan Verteidigung-Basiswert muss dem aktuellen Statprofil 35 entsprechen.")
    assert(int(ekans_stats.get("special", 0)) == 65, "Rettan Statuswert-Basiswert muss dem aktuellen Statprofil 65 entsprechen.")
    assert(int(ekans_stats.get("speed", 0)) == 55, "Rettan Geschwindigkeit-Basiswert muss 55 sein.")

    var arbok: Dictionary = species.get("arbok", {})
    var arbok_stats: Dictionary = arbok.get("base_stats", {})
    assert(int(arbok_stats.get("hp", 0)) == 60, "Arbok KP-Basiswert muss 60 sein.")
    assert(int(arbok_stats.get("attack", 0)) == 105, "Arbok Angriff-Basiswert muss dem aktuellen Statprofil 105 entsprechen.")
    assert(int(arbok_stats.get("defense", 0)) == 55, "Arbok Verteidigung-Basiswert muss dem aktuellen Statprofil 55 entsprechen.")
    assert(int(arbok_stats.get("special", 0)) == 75, "Arbok Statuswert-Basiswert muss dem aktuellen Statprofil 75 entsprechen.")
    assert(int(arbok_stats.get("speed", 0)) == 80, "Arbok Geschwindigkeit-Basiswert muss 80 sein.")


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
