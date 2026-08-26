extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const GLOBAL_MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const EXTENSION_MANIFEST_PATH: String = "res://data/pokemon_database_extension_41_50_v1.json"
const EXPECTED_BASE_SPECIES_COUNT: int = 266
const EXPECTED_BASE_ROOT_COUNT: int = 118
const EXPECTED_EXTENSION_RUNTIME_SPECIES_COUNT: int = 280
const EXPECTED_EXTENSION_RUNTIME_ROOT_COUNT: int = 128
const EXPECTED_RUNTIME_SPECIES_COUNT: int = 281
const EXPECTED_RUNTIME_ROOT_COUNT: int = 129
const NEW_ROOTS: Array[String] = [
	"phanpy", "stantler", "smeargle", "miltank", "raikou",
	"entei", "suicune", "larvitar", "lugia", "ho-oh"
]
const NEW_SPECIES: Array[String] = [
	"phanpy", "donphan", "stantler", "wyrdeer", "smeargle", "miltank",
	"raikou", "entei", "suicune", "larvitar", "pupitar", "tyranitar",
	"lugia", "ho-oh"
]


func _initialize() -> void:
	var global_manifest: Dictionary = _read_json(GLOBAL_MANIFEST_PATH)
	assert(int(global_manifest.get("species_count", -1)) == EXPECTED_BASE_SPECIES_COUNT)
	assert(int(global_manifest.get("route_root_count", -1)) == EXPECTED_BASE_ROOT_COUNT)
	assert(int(global_manifest.get("runtime_species_count", -1)) == EXPECTED_RUNTIME_SPECIES_COUNT)
	assert(int(global_manifest.get("runtime_route_root_count", -1)) == EXPECTED_RUNTIME_ROOT_COUNT)
	assert((global_manifest.get("species_extension_manifests", []) as Array).has(EXTENSION_MANIFEST_PATH))

	var extension: Dictionary = _read_json(EXTENSION_MANIFEST_PATH)
	assert(int(extension.get("extension_species_count", -1)) == NEW_SPECIES.size())
	assert(int(extension.get("extension_route_root_count", -1)) == NEW_ROOTS.size())
	assert(int(extension.get("runtime_species_count", -1)) == EXPECTED_EXTENSION_RUNTIME_SPECIES_COUNT)
	assert(int(extension.get("runtime_route_root_count", -1)) == EXPECTED_EXTENSION_RUNTIME_ROOT_COUNT)

	var core: Dictionary = _read_json(str(extension.get("species_master_extension_file", "")))
	var core_species: Dictionary = core.get("species", {})
	assert(core_species.size() == NEW_SPECIES.size())
	for species_id: String in NEW_SPECIES:
		assert(core_species.has(species_id), "Gen2-41-50-Core fehlt: " + species_id)
	assert(not core_species.has("celebi"), "Celebi gehört erst in den nächsten Block.")
	assert(not core_species.has("ursaluna"), "Ursaluna bleibt zurückgestellt.")

	var family_meta: Dictionary = _read_json(str(extension.get("family_meta_extension_file", "")))
	var new_roots: Array = family_meta.get("route_roots", [])
	var family_members: Dictionary = family_meta.get("family_members", {})
	assert(new_roots.size() == NEW_ROOTS.size())
	for root_id: String in NEW_ROOTS:
		assert(new_roots.has(root_id), "Gen2-41-50-Familienwurzel fehlt: " + root_id)
		assert(family_members.has(root_id), "Gen2-41-50-Familie fehlt: " + root_id)

	var detail_species: Dictionary = {}
	for path_value: Variant in extension.get("species_detail_files", []):
		var detail: Dictionary = _read_json(str(path_value))
		for species_id_value: Variant in (detail.get("species", {}) as Dictionary).keys():
			var species_id: String = str(species_id_value)
			assert(not detail_species.has(species_id), "Doppelte Detail-ID: " + species_id)
			detail_species[species_id] = (detail.get("species", {}) as Dictionary).get(species_id_value)
	assert(detail_species.size() == NEW_SPECIES.size())

	var phanpy: Dictionary = detail_species.get("phanpy", {})
	assert((phanpy.get("evolution", {}) as Dictionary).get("evolves_into", "") == "donphan")
	assert(int((phanpy.get("evolution", {}) as Dictionary).get("evolution_level", 0)) == 25)
	var stantler: Dictionary = detail_species.get("stantler", {})
	assert((stantler.get("evolution", {}) as Dictionary).get("evolves_into", "") == "wyrdeer")
	assert(int((stantler.get("evolution", {}) as Dictionary).get("evolution_level", 0)) == 40)
	var wyrdeer: Dictionary = detail_species.get("wyrdeer", {})
	assert((wyrdeer.get("learnset", {}) as Dictionary).get("evolution_moves", []).has("psyshield_bash"))
	var larvitar: Dictionary = detail_species.get("larvitar", {})
	assert(int((larvitar.get("evolution", {}) as Dictionary).get("evolution_level", 0)) == 30)
	var pupitar: Dictionary = detail_species.get("pupitar", {})
	assert((pupitar.get("evolution", {}) as Dictionary).get("evolves_into", "") == "tyranitar")
	assert(int((pupitar.get("evolution", {}) as Dictionary).get("evolution_level", 0)) == 55)
	assert((pupitar.get("learnset", {}) as Dictionary).get("evolution_moves", []).has("iron_defense"))
	var smeargle: Dictionary = detail_species.get("smeargle", {})
	assert((smeargle.get("learnset", {}) as Dictionary).get("tm_hm", []).is_empty())

	var battle = BattleScript.new()
	root.add_child(battle)
	assert(battle.pokemon_registry_ready())
	var runtime_species: Dictionary = battle.data.get("species", {})
	assert(runtime_species.size() == EXPECTED_RUNTIME_SPECIES_COUNT)
	assert(battle.species_ids.size() == EXPECTED_RUNTIME_ROOT_COUNT)
	assert(battle.lab_species_ids.size() == EXPECTED_RUNTIME_SPECIES_COUNT)
	for species_id: String in NEW_SPECIES:
		assert(runtime_species.has(species_id), "Gen2-41-50-Pokemon fehlt in Runtime: " + species_id)
		assert(battle.lab_species_ids.has(species_id), "Gen2-41-50-Pokemon fehlt im Kampflabor: " + species_id)
	assert(runtime_species.has("celebi"), "Celebi muss im finalen Gen-2-Runtime-Pool aktiv sein.")
	assert(not runtime_species.has("ursaluna"))

	assert(battle.route_resolve_species_for_level("phanpy", 24) == "phanpy")
	assert(battle.route_resolve_species_for_level("phanpy", 25) == "donphan")
	assert(battle.route_resolve_species_for_level("stantler", 39) == "stantler")
	assert(battle.route_resolve_species_for_level("stantler", 40) == "wyrdeer")
	assert(battle.route_resolve_species_for_level("larvitar", 29) == "larvitar")
	assert(battle.route_resolve_species_for_level("larvitar", 30) == "pupitar")
	assert(battle.route_resolve_species_for_level("larvitar", 55) == "tyranitar")

	var phanpy_tms: Array = battle._lab_available_tm_moves("phanpy")
	assert(phanpy_tms.has("protect"))
	var lugia_tms: Array = battle._lab_available_tm_moves("lugia")
	assert(lugia_tms.has("protect"))

	print("Gen2 families 41-50 append-only roster extension: PASS")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei fehlt/ist leer: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Ungültiges JSON: " + path)
	return parsed as Dictionary
