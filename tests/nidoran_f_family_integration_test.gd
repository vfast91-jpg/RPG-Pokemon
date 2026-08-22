extends SceneTree
const MoveContractScript = preload("res://scripts/battle/move_contract.gd")
const NidoRuntimeScript = preload("res://scripts/battle_demo_database_nidoran_f_family.gd")
const SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_nidoran_f_family_v1.json"
const MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_20_nidoran_f_family.json"
const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v4.json"
const META_PATH: String = "res://data/gen1_database_meta_v4.json"
const REQUIRED_MOVES: Array[String] = [
    "double_kick", "flatter", "superpower", "drain_punch", "megahorn"
]
func _initialize() -> void:
    _test_species()
    _test_moves()
    _test_support_indices()
    _test_runtime_chain()
    print("Nidoran♀/Nidorina/Nidoqueen family integration test: PASS")
    quit(0)
func _test_species() -> void:
    var pack: Dictionary = _read_json(SPECIES_PACK_PATH)
    var species: Dictionary = pack.get("species", {})
    assert(species.size() == 3)
    var nidoran: Dictionary = species.get("nidoran_f", {})
    var nidorina: Dictionary = species.get("nidorina", {})
    var nidoqueen: Dictionary = species.get("nidoqueen", {})
    assert(nidoran.get("base_stats", {}) == {"hp":55,"attack":48,"defense":55,"special":48,"speed":44})
    assert(nidorina.get("base_stats", {}) == {"hp":70,"attack":62,"defense":70,"special":58,"speed":55})
    assert(nidoqueen.get("base_stats", {}) == {"hp":90,"attack":92,"defense":90,"special":82,"speed":76})
    var evolution_1: Dictionary = nidoran.get("evolution", {})
    assert(str(evolution_1.get("evolves_into", "")) == "nidorina")
    assert(int(evolution_1.get("evolution_level", 0)) == 16)
    assert(bool(evolution_1.get("mandatory", false)))
    var evolution_2: Dictionary = nidorina.get("evolution", {})
    assert(str(evolution_2.get("evolves_into", "")) == "nidoqueen")
    assert(int(evolution_2.get("evolution_level", 0)) == 36)
    assert(bool(evolution_2.get("mandatory", false)))
    var nidoran_learnset: Dictionary = nidoran.get("learnset", {})
    var nidorina_learnset: Dictionary = nidorina.get("learnset", {})
    var nidoqueen_learnset: Dictionary = nidoqueen.get("learnset", {})
    assert(((nidoran_learnset.get("level_up", {}) as Dictionary).get("12", []) as Array).has("double_kick"))
    assert(((nidoran_learnset.get("level_up", {}) as Dictionary).get("32", []) as Array).has("flatter"))
    assert(((nidorina_learnset.get("level_up", {}) as Dictionary).get("48", []) as Array).has("superpower"))
    assert((nidoqueen_learnset.get("evolution_moves", []) as Array).has("earth_power"))
    assert(((nidoqueen_learnset.get("level_up", {}) as Dictionary).get("60", []) as Array).has("megahorn"))
    assert((nidoran_learnset.get("tm_hm", {}) as Dictionary).size() == 20)
    assert((nidorina_learnset.get("tm_hm", {}) as Dictionary).size() == 29)
    assert((nidoqueen_learnset.get("tm_hm", {}) as Dictionary).size() == 58)
    for entry: Dictionary in [nidoran, nidorina, nidoqueen]:
        var display_name: String = str(entry.get("display_name", ""))
        var asset_path: String = "res://assets/monsters/" + display_name + ".png"
        assert(
            ResourceLoader.exists(asset_path),
            "Nidoran-Familien-Sprite fehlt: " + asset_path
        )
func _test_moves() -> void:
    var pack: Dictionary = _read_json(MOVE_PACK_PATH)
    var moves: Dictionary = pack.get("moves", {})
    assert(moves.size() == 5)
    var expected_ap: Dictionary = {
        "double_kick": 3,
        "flatter": 6,
        "superpower": 8,
        "drain_punch": 7,
        "megahorn": 7
    }
    for move_id: String in REQUIRED_MOVES:
        assert(moves.has(move_id), "Attacke fehlt: " + move_id)
        var move: Dictionary = moves.get(move_id, {})
        assert(int(move.get("ap", 0)) == int(expected_ap.get(move_id, 0)))
        var runtime: Dictionary = move.get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)))
        assert(bool(runtime.get("strict_contract", false)))
        var report: Dictionary = MoveContractScript.validate_move(move_id, move, true)
        if not bool(report.get("ok", false)):
            push_error(move_id + " verletzt Strict-V4: " + str(report.get("errors", [])))
        assert(bool(report.get("ok", false)))
    var double_kick: Dictionary = moves.get("double_kick", {})
    var multi_hit: Dictionary = (double_kick.get("runtime", {}) as Dictionary).get("multi_hit", {})
    assert(int(multi_hit.get("min", 0)) == 2)
    assert(int(multi_hit.get("max", 0)) == 2)
    var flatter: Dictionary = moves.get("flatter", {})
    assert(str(flatter.get("type", "")) == "dark")
    assert(bool((flatter.get("runtime", {}) as Dictionary).get("manual_single_ally", false)))
    var drain_punch: Dictionary = moves.get("drain_punch", {})
    var drain_mechanics: Array = drain_punch.get("mechanics", [])
    assert(drain_mechanics.size() == 2)
    assert(str((drain_mechanics[1] as Dictionary).get("kind", "")) == "db_drain_from_damage")
    assert(is_equal_approx(float((drain_mechanics[1] as Dictionary).get("fraction", 0.0)), 0.5))
    assert(not bool((drain_punch.get("aggro", {}) as Dictionary).get("from_healing", true)))
    var runtime = NidoRuntimeScript.new()
    assert(is_equal_approx(runtime._nido_status_ratio(0.0), 0.0))
    assert(is_equal_approx(runtime._nido_status_ratio(75.0), 0.5))
    runtime.free()
func _test_support_indices() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    assert(int(manifest.get("species_count", 0)) == 33)
    assert(int(manifest.get("move_count", 0)) == 271)
    assert(int(manifest.get("route_root_count", 0)) == 12)
    assert((manifest.get("species_files", []) as Array).has(SPECIES_PACK_PATH))
    assert((manifest.get("move_files", []) as Array).has(MOVE_PACK_PATH))
    var meta: Dictionary = _read_json(META_PATH)
    assert((meta.get("route_roots", []) as Array).has("nidoran_f"))
    var weights: Dictionary = _read_json("res://data/gen1_species_weights_v1.json").get("weights_kg", {})
    assert(is_equal_approx(float(weights.get("nidoran_f", 0.0)), 7.0))
    assert(is_equal_approx(float(weights.get("nidorina", 0.0)), 20.0))
    assert(is_equal_approx(float(weights.get("nidoqueen", 0.0)), 60.0))
    var profiles: Dictionary = _read_json("res://data/gen1_species_stat_profiles_v4.json").get("species", {})
    assert(profiles.get("nidoran_f", {}) == {"hp":55,"attack":48,"defense":55,"special":48,"speed":44})
    assert(profiles.get("nidorina", {}) == {"hp":70,"attack":62,"defense":70,"special":58,"speed":55})
    assert(profiles.get("nidoqueen", {}) == {"hp":90,"attack":92,"defense":90,"special":82,"speed":76})
    var families: Dictionary = _read_json("res://data/gen1_species_encounter_families_v1.json").get("families", {})
    var nido_family: Dictionary = families.get("nidoran_f", {})
    assert((nido_family.get("members", []) as Array) == ["nidoran_f","nidorina","nidoqueen"])
    assert(is_equal_approx(float(nido_family.get("family_catch_rate", 0.0)), 133.33333333333334))
    var progression: Dictionary = _read_json("res://data/gen1_species_progression_v1.json").get("species", {})
    for species_id: String in ["nidoran_f","nidorina","nidoqueen"]:
        assert(str((progression.get(species_id, {}) as Dictionary).get("experience_curve", "")) == "medium_slow")
func _test_runtime_chain() -> void:
    var nido_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_database_nidoran_f_family.gd")
    assert(nido_text.contains("res://scripts/battle_demo_database_sandshrew_family.gd"))
    assert(nido_text.contains("res://data/gen1_database_manifest_v4.json"))
    var type_help_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_type_help_button_polish.gd")
    assert(type_help_text.contains("res://scripts/battle_demo_database_nidoran_f_family.gd"))
    assert(type_help_text.contains("res://scripts/battle_demo_database_sandshrew_family.gd"))
func _read_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
