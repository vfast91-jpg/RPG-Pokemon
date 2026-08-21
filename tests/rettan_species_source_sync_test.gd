extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v3.json"
const STAT_PROFILE_PATH: String = "res://data/gen1_species_stat_profiles_v4.json"
const CORRECTION_PACK_PATH: String = "res://data/gen1_species_v3_4_rettan_arbok_v4.json"


func _initialize() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    assert(not manifest.is_empty(), "Kanonisches Datenbank-Manifest muss lesbar sein.")

    var species_files: Array = manifest.get("species_files", [])
    assert(species_files.has(CORRECTION_PACK_PATH), "Der kanonische Rettan/Arbok-V4-Snapshot muss im Manifest geladen werden.")
    assert(str(species_files.back()) == CORRECTION_PACK_PATH, "Der Rettan/Arbok-V4-Snapshot muss nach den älteren Species-Paketen geladen werden.")

    var merged_species: Dictionary = {}
    for path_value: Variant in species_files:
        var pack: Dictionary = _read_json(str(path_value))
        var entries: Dictionary = pack.get("species", {})
        for species_id_value: Variant in entries.keys():
            merged_species[str(species_id_value)] = entries[species_id_value]

    var profile_pack: Dictionary = _read_json(STAT_PROFILE_PATH)
    assert(not profile_pack.is_empty(), "V4-Statprofil-Datei muss lesbar sein.")
    var profiles: Dictionary = profile_pack.get("species", {})

    _assert_species_matches_profile(merged_species, profiles, "ekans")
    _assert_species_matches_profile(merged_species, profiles, "arbok")

    var ekans: Dictionary = merged_species.get("ekans", {})
    var ekans_learnset: Dictionary = ekans.get("learnset", {})
    var ekans_level_up: Dictionary = ekans_learnset.get("level_up", {})
    assert((ekans_level_up.get("12", []) as Array).has("glare"), "Rettans Lv.12-Schlangenblick darf beim Stat-Sync nicht verloren gehen.")
    assert((ekans_level_up.get("17", []) as Array).has("screech"), "Rettans Lv.17-Kreideschrei darf beim Stat-Sync nicht verloren gehen.")
    assert((ekans_level_up.get("20", []) as Array).has("acid"), "Rettans Lv.20-Säure darf beim Stat-Sync nicht verloren gehen.")

    var arbok: Dictionary = merged_species.get("arbok", {})
    var arbok_learnset: Dictionary = arbok.get("learnset", {})
    assert((arbok_learnset.get("evolution_moves", []) as Array).has("crunch"), "Arboks Entwicklungsattacke Knirscher darf beim Stat-Sync nicht verloren gehen.")

    print("Rettan/Arbok species source sync test: OK")
    quit(0)


func _assert_species_matches_profile(species: Dictionary, profiles: Dictionary, species_id: String) -> void:
    var entry: Dictionary = species.get(species_id, {})
    assert(not entry.is_empty(), species_id + " muss im kanonischen Species-Merge existieren.")
    var actual: Dictionary = entry.get("base_stats", {})
    var expected: Dictionary = profiles.get(species_id, {})
    assert(not expected.is_empty(), species_id + " muss ein V4-Statprofil besitzen.")

    for key: String in ["hp", "attack", "defense", "special", "speed"]:
        assert(
            int(actual.get(key, -1)) == int(expected.get(key, -2)),
            species_id + ": kanonischer JSON-Wert für " + key + " muss exakt dem V4-Statprofil entsprechen."
        )


func _read_json(path: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
