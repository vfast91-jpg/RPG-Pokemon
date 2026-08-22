extends SceneTree

const MoveContractScript = preload("res://scripts/battle/move_contract.gd")
const FlinchRules = preload("res://scripts/battle/flinch_rules.gd")
const MaleRuntimeScript = preload("res://scripts/battle_demo_database_nidoran_m_family.gd")
const SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_nidoran_m_family_v1.json"
const MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_21_nidoran_m_family.json"
const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v4.json"
const META_PATH: String = "res://data/gen1_database_meta_v4.json"

func _initialize() -> void:
    _test_species()
    _test_moves()
    _test_all_referenced_moves_exist()
    _test_support_indices()
    _test_runtime_chain()
    print("Nidoran♂/Nidorino/Nidoking family integration test: PASS")
    quit(0)

func _test_species() -> void:
    var species: Dictionary = _read_json(SPECIES_PACK_PATH).get("species", {})
    assert(species.size() == 3)
    var nidoran: Dictionary = species.get("nidoran_m", {})
    var nidorino: Dictionary = species.get("nidorino", {})
    var nidoking: Dictionary = species.get("nidoking", {})

    assert(nidoran.get("base_stats", {}) == {"hp":46,"attack":60,"defense":42,"special":40,"speed":50})
    assert(nidorino.get("base_stats", {}) == {"hp":61,"attack":76,"defense":60,"special":52,"speed":65})
    assert(nidoking.get("base_stats", {}) == {"hp":81,"attack":108,"defense":78,"special":72,"speed":85})

    var evo_1: Dictionary = nidoran.get("evolution", {})
    assert(str(evo_1.get("evolves_into", "")) == "nidorino")
    assert(int(evo_1.get("evolution_level", 0)) == 16)
    assert(bool(evo_1.get("mandatory", false)))
    var evo_2: Dictionary = nidorino.get("evolution", {})
    assert(str(evo_2.get("evolves_into", "")) == "nidoking")
    assert(int(evo_2.get("evolution_level", 0)) == 36)
    assert(bool(evo_2.get("mandatory", false)))

    var nidoran_learnset: Dictionary = nidoran.get("learnset", {})
    var nidorino_learnset: Dictionary = nidorino.get("learnset", {})
    var nidoking_learnset: Dictionary = nidoking.get("learnset", {})
    assert(((nidoran_learnset.get("level_up", {}) as Dictionary).get("16", []) as Array).has("horn_attack"))
    assert(((nidorino_learnset.get("level_up", {}) as Dictionary).get("36", []) as Array).has("poison_jab"))
    assert((nidoking_learnset.get("evolution_moves", []) as Array).has("megahorn"))
    assert(((nidoking_learnset.get("level_up", {}) as Dictionary).get("44", []) as Array).has("drill_run"))
    assert((nidoran_learnset.get("tm_hm", {}) as Dictionary).size() == 20)
    assert((nidorino_learnset.get("tm_hm", {}) as Dictionary).size() == 29)
    assert((nidoking_learnset.get("tm_hm", {}) as Dictionary).size() == 58)
    assert((nidoking_learnset.get("tm_hm", {}) as Dictionary).values().has("iron_head"))

    for entry: Dictionary in [nidoran, nidorino, nidoking]:
        var asset_path: String = "res://assets/monsters/" + str(entry.get("display_name", "")) + ".png"
        assert(ResourceLoader.exists(asset_path), "Nidoran♂-Familien-Sprite fehlt: " + asset_path)

func _test_moves() -> void:
    var moves: Dictionary = _read_json(MOVE_PACK_PATH).get("moves", {})
    assert(moves.size() == 3)

    var expected_ap: Dictionary = {"horn_attack":4,"iron_head":6,"drill_run":7}
    for move_id: String in expected_ap.keys():
        var move: Dictionary = moves.get(move_id, {})
        assert(not move.is_empty(), "Attacke fehlt: " + move_id)
        assert(int(move.get("ap", 0)) == int(expected_ap.get(move_id, 0)))
        var report: Dictionary = MoveContractScript.validate_move(move_id, move, true)
        assert(bool(report.get("ok", false)), move_id + " verletzt Strict-V4: " + str(report.get("errors", [])))

    var horn: Dictionary = moves.get("horn_attack", {})
    assert(int(horn.get("power", 0)) == 65)
    assert(is_equal_approx(float(horn.get("accuracy", 0.0)), 100.0))

    var iron: Dictionary = moves.get("iron_head", {})
    assert(int(iron.get("power", 0)) == 80)
    var iron_mechanics: Array = iron.get("mechanics", [])
    assert(iron_mechanics.size() == 2)
    var flinch: Dictionary = iron_mechanics[1]
    assert(str(flinch.get("kind", "")) == "atb_knockback")
    assert(is_equal_approx(float(flinch.get("chance", 0.0)), 0.30))
    var forced_target: Dictionary = {"atb":73.0}
    assert(FlinchRules.apply(forced_target, 1.0, 0.0))
    assert(is_zero_approx(float(forced_target.get("atb", -1.0))))

    var drill: Dictionary = moves.get("drill_run", {})
    assert(int(drill.get("power", 0)) == 80)
    assert(is_equal_approx(float(drill.get("accuracy", 0.0)), 95.0))
    assert(bool((drill.get("runtime", {}) as Dictionary).get("high_crit", false)))

func _test_all_referenced_moves_exist() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    var all_moves: Dictionary = {}
    for path_value: Variant in manifest.get("move_files", []):
        var pack: Dictionary = _read_json(str(path_value))
        var pack_moves: Dictionary = pack.get("moves", {})
        for move_id_value: Variant in pack_moves.keys():
            all_moves[str(move_id_value)] = pack_moves.get(move_id_value)

    var species: Dictionary = _read_json(SPECIES_PACK_PATH).get("species", {})
    for species_id_value: Variant in species.keys():
        var entry: Dictionary = species.get(species_id_value, {})
        var learnset: Dictionary = entry.get("learnset", {})
        for level_moves_value: Variant in (learnset.get("level_up", {}) as Dictionary).values():
            for move_id_value: Variant in level_moves_value:
                assert(all_moves.has(str(move_id_value)), str(species_id_value) + ": Level-Attacke fehlt im Runtime-Katalog: " + str(move_id_value))
        for move_id_value: Variant in learnset.get("evolution_moves", []):
            assert(all_moves.has(str(move_id_value)), str(species_id_value) + ": Entwicklungsattacke fehlt: " + str(move_id_value))
        for move_id_value: Variant in learnset.get("relearn_lv1", []):
            assert(all_moves.has(str(move_id_value)), str(species_id_value) + ": Relearn-Attacke fehlt: " + str(move_id_value))
        for move_id_value: Variant in (learnset.get("tm_hm", {}) as Dictionary).values():
            assert(all_moves.has(str(move_id_value)), str(species_id_value) + ": TM-Attacke fehlt im Runtime-Katalog: " + str(move_id_value))

func _test_support_indices() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    assert(int(manifest.get("species_count", 0)) == 36)
    assert(int(manifest.get("move_count", 0)) == 274)
    assert(int(manifest.get("route_root_count", 0)) == 13)
    assert((manifest.get("species_files", []) as Array).has(SPECIES_PACK_PATH))
    assert((manifest.get("move_files", []) as Array).has(MOVE_PACK_PATH))

    var meta: Dictionary = _read_json(META_PATH)
    assert((meta.get("route_roots", []) as Array).has("nidoran_m"))

    var weights: Dictionary = _read_json("res://data/gen1_species_weights_v1.json").get("weights_kg", {})
    assert(is_equal_approx(float(weights.get("nidoran_m", 0.0)), 9.0))
    assert(is_equal_approx(float(weights.get("nidorino", 0.0)), 19.5))
    assert(is_equal_approx(float(weights.get("nidoking", 0.0)), 62.0))

    var profiles: Dictionary = _read_json("res://data/gen1_species_stat_profiles_v4.json").get("species", {})
    assert(profiles.get("nidoran_m", {}) == {"hp":46,"attack":60,"defense":42,"special":40,"speed":50})
    assert(profiles.get("nidorino", {}) == {"hp":61,"attack":76,"defense":60,"special":52,"speed":65})
    assert(profiles.get("nidoking", {}) == {"hp":81,"attack":108,"defense":78,"special":72,"speed":85})

    var families: Dictionary = _read_json("res://data/gen1_species_encounter_families_v1.json").get("families", {})
    var family: Dictionary = families.get("nidoran_m", {})
    assert((family.get("members", []) as Array) == ["nidoran_m","nidorino","nidoking"])
    assert(is_equal_approx(float(family.get("family_catch_rate", 0.0)), 133.33333333333334))

    var progression: Dictionary = _read_json("res://data/gen1_species_progression_v1.json").get("species", {})
    for species_id: String in ["nidoran_m","nidorino","nidoking"]:
        assert(str((progression.get(species_id, {}) as Dictionary).get("experience_curve", "")) == "medium_slow")

func _test_runtime_chain() -> void:
    var runtime = MaleRuntimeScript.new()
    runtime.free()
    var male_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_database_nidoran_m_family.gd")
    assert(male_text.contains("res://scripts/battle_demo_database_nidoran_f_family.gd"))
    var type_help_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_type_help_button_polish.gd")
    assert(type_help_text.contains("res://scripts/battle_demo_database_nidoran_m_family.gd"))

func _read_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
