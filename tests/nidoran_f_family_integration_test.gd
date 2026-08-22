extends SceneTree

const MoveContractScript = preload("res://scripts/battle/move_contract.gd")
const SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_nidoran_f_family_v1.json"
const MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_20_nidoran_f_family.json"
const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v4.json"

func _initialize() -> void:
    var species: Dictionary = _read_json(SPECIES_PACK_PATH).get("species", {})
    assert(species.size() == 3)
    assert((species.get("nidoran_f", {}) as Dictionary).get("base_stats", {}) == {"hp":55,"attack":48,"defense":55,"special":48,"speed":44})
    assert((species.get("nidorina", {}) as Dictionary).get("base_stats", {}) == {"hp":70,"attack":62,"defense":70,"special":58,"speed":55})
    assert((species.get("nidoqueen", {}) as Dictionary).get("base_stats", {}) == {"hp":90,"attack":92,"defense":90,"special":82,"speed":76})
    assert(int(((species.get("nidoran_f", {}) as Dictionary).get("evolution", {}) as Dictionary).get("evolution_level", 0)) == 16)
    assert(int(((species.get("nidorina", {}) as Dictionary).get("evolution", {}) as Dictionary).get("evolution_level", 0)) == 36)

    for species_id: String in ["nidoran_f","nidorina","nidoqueen"]:
        var entry: Dictionary = species.get(species_id, {})
        var asset_path: String = "res://assets/monsters/" + str(entry.get("display_name", "")) + ".png"
        assert(ResourceLoader.exists(asset_path), "Nidoran♀-Familien-Sprite fehlt: " + asset_path)

    var moves: Dictionary = _read_json(MOVE_PACK_PATH).get("moves", {})
    assert(moves.size() == 5)
    for move_id: String in ["double_kick","flatter","superpower","drain_punch","megahorn"]:
        var move: Dictionary = moves.get(move_id, {})
        assert(not move.is_empty(), "Attacke fehlt: " + move_id)
        var report: Dictionary = MoveContractScript.validate_move(move_id, move, true)
        assert(bool(report.get("ok", false)), move_id + " verletzt Strict-V4: " + str(report.get("errors", [])))

    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    assert(int(manifest.get("species_count", 0)) == 36)
    assert(int(manifest.get("move_count", 0)) == 273)
    assert(int(manifest.get("route_root_count", 0)) == 13)
    assert((manifest.get("species_files", []) as Array).has(SPECIES_PACK_PATH))
    assert((manifest.get("move_files", []) as Array).has(MOVE_PACK_PATH))

    var type_help_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_type_help_button_polish.gd")
    var male_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_database_nidoran_m_family.gd")
    var female_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_database_nidoran_f_family.gd")
    assert(type_help_text.contains("res://scripts/battle_demo_database_nidoran_m_family.gd"))
    assert(male_text.contains("res://scripts/battle_demo_database_nidoran_f_family.gd"))
    assert(female_text.contains("res://scripts/battle_demo_database_sandshrew_family.gd"))

    print("Nidoran♀/Nidorina/Nidoqueen family integration test: PASS")
    quit(0)

func _read_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
