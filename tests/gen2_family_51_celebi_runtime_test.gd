extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const GLOBAL_MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const EXTENSION_MANIFEST_PATH: String = "res://data/pokemon_database_extension_51_v1.json"
const EXPECTED_BASE_SPECIES_COUNT: int = 280
const EXPECTED_BASE_ROOT_COUNT: int = 128
const EXPECTED_CELEBI_EXTENSION_RUNTIME_SPECIES_COUNT: int = 281
const EXPECTED_CELEBI_EXTENSION_RUNTIME_ROOT_COUNT: int = 129
const EXPECTED_FINAL_RUNTIME_SPECIES_COUNT: int = 282
const EXPECTED_FINAL_RUNTIME_ROOT_COUNT: int = 129


func _initialize() -> void:
	var global_manifest: Dictionary = _read_json(GLOBAL_MANIFEST_PATH)
	assert(int(global_manifest.get("runtime_species_count", -1)) == EXPECTED_FINAL_RUNTIME_SPECIES_COUNT)
	assert(int(global_manifest.get("runtime_route_root_count", -1)) == EXPECTED_FINAL_RUNTIME_ROOT_COUNT)
	assert((global_manifest.get("species_extension_manifests", []) as Array).has(EXTENSION_MANIFEST_PATH))

	var extension: Dictionary = _read_json(EXTENSION_MANIFEST_PATH)
	assert(int(extension.get("expected_base_species_count", -1)) == EXPECTED_BASE_SPECIES_COUNT)
	assert(int(extension.get("expected_base_route_root_count", -1)) == EXPECTED_BASE_ROOT_COUNT)
	assert(int(extension.get("extension_species_count", -1)) == 1)
	assert(int(extension.get("extension_route_root_count", -1)) == 1)
	assert(int(extension.get("runtime_species_count", -1)) == EXPECTED_CELEBI_EXTENSION_RUNTIME_SPECIES_COUNT)
	assert(int(extension.get("runtime_route_root_count", -1)) == EXPECTED_CELEBI_EXTENSION_RUNTIME_ROOT_COUNT)

	var core: Dictionary = _read_json(str(extension.get("species_master_extension_file", "")))
	var core_species: Dictionary = core.get("species", {})
	assert(core_species.size() == 1)
	assert(core_species.has("celebi"))
	var core_celebi: Dictionary = core_species.get("celebi", {})
	assert(int(core_celebi.get("pokedex_number", 0)) == 251)
	assert((core_celebi.get("types", {}) as Dictionary).get("primary", "") == "psychic")
	assert((core_celebi.get("types", {}) as Dictionary).get("secondary", "") == "grass")
	for stat_name: String in ["hp", "attack", "defense", "special", "speed"]:
		assert(int((core_celebi.get("base_stats", {}) as Dictionary).get(stat_name, 0)) == 100)

	var family_meta: Dictionary = _read_json(str(extension.get("family_meta_extension_file", "")))
	assert((family_meta.get("route_roots", []) as Array) == ["celebi"])
	assert((family_meta.get("family_members", {}) as Dictionary).get("celebi", []) == ["celebi"])

	var detail_paths: Array = extension.get("species_detail_files", [])
	assert(detail_paths.size() == 1)
	var detail: Dictionary = _read_json(str(detail_paths[0]))
	var celebi: Dictionary = (detail.get("species", {}) as Dictionary).get("celebi", {})
	assert(not celebi.is_empty())
	assert(int(celebi.get("rpg_basis_sum", 0)) == 500)
	assert(int(celebi.get("catch_rate", 0)) == 3)
	assert(str(celebi.get("experience_curve", "")) == "medium_slow")
	var evolution: Dictionary = celebi.get("evolution", {})
	assert(evolution.get("evolves_into", null) == null)
	assert(not bool(evolution.get("mandatory", true)))
	assert(str(evolution.get("method", "")) == "none")
	var learnset: Dictionary = celebi.get("learnset", {})
	var level_up: Dictionary = learnset.get("level_up", {})
	assert((level_up.get("1", []) as Array).has("confusion"))
	assert((level_up.get("1", []) as Array).has("heal_bell"))
	assert((level_up.get("100", []) as Array).has("perish_song"))
	var tms: Array = learnset.get("tm_hm", [])
	assert(tms.has("protect"))
	assert(tms.has("psychic"))
	assert(tms.has("giga_drain"))
	assert(tms.has("future_sight"))

	var battle = BattleScript.new()
	root.add_child(battle)
	assert(battle.pokemon_registry_ready())
	var runtime_species: Dictionary = battle.data.get("species", {})
	assert(runtime_species.size() == EXPECTED_FINAL_RUNTIME_SPECIES_COUNT)
	assert(battle.species_ids.size() == EXPECTED_FINAL_RUNTIME_ROOT_COUNT)
	assert(battle.lab_species_ids.size() == EXPECTED_FINAL_RUNTIME_SPECIES_COUNT)
	assert(runtime_species.has("celebi"))
	assert(battle.species_ids.has("celebi"))
	assert(battle.lab_species_ids.has("celebi"))
	assert(battle.route_resolve_species_for_level("celebi", 1) == "celebi")
	assert(battle.route_resolve_species_for_level("celebi", 100) == "celebi")
	assert(runtime_species.has("ursaluna"), "Ursaluna muss nach Celebi als Teddiursa-Familienerweiterung aktiv sein.")

	var route_moves: Array = battle.route_moves_for_level("celebi", 30)
	assert(route_moves.has("confusion"))
	assert(route_moves.has("heal_bell"))
	assert(route_moves.has("magical_leaf"))
	assert(route_moves.has("baton_pass"))
	assert(route_moves.has("ancient_power"))
	var runtime_tms: Array = battle._lab_available_tm_moves("celebi")
	assert(runtime_tms.has("protect"))

	print("Celebi family 51 + final Ursaluna extension registry/runtime: PASS")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei fehlt/ist leer: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Ungültiges JSON: " + path)
	return parsed as Dictionary
