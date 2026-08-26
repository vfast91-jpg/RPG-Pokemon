extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const META_PATH: String = "res://data/pokemon_family_meta_v1.json"
const DETAIL_PATHS: Array[String] = [
	"res://data/gen2_species_families_31_33_v1.json",
	"res://data/gen2_species_families_34_35_v1.json",
	"res://data/gen2_species_families_36_38_v1.json",
	"res://data/gen2_species_families_39_40_v1.json"
]

const EXPECTED_SPECIES_COUNT: int = 266
const EXPECTED_ROOT_COUNT: int = 118
const NEW_ROOTS: Array[String] = [
	"sneasel", "teddiursa", "slugma", "swinub", "corsola",
	"remoraid", "delibird", "mantyke", "skarmory", "houndour"
]
const NEW_SPECIES: Array[String] = [
	"sneasel", "weavile", "teddiursa", "ursaring", "slugma", "magcargo",
	"swinub", "piloswine", "mamoswine", "corsola", "remoraid", "octillery",
	"delibird", "mantyke", "mantine", "skarmory", "houndour", "houndoom"
]


func _initialize() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(int(manifest.get("species_count", -1)) == EXPECTED_SPECIES_COUNT)
	assert(int(manifest.get("route_root_count", -1)) == EXPECTED_ROOT_COUNT)
	for detail_path: String in DETAIL_PATHS:
		assert((manifest.get("species_detail_files", []) as Array).has(detail_path))

	var meta: Dictionary = _read_json(META_PATH)
	var roots: Array = meta.get("route_roots", [])
	assert(roots.size() == EXPECTED_ROOT_COUNT)
	for root_id: String in NEW_ROOTS:
		assert(roots.has(root_id), "Neue Gen-2-Familie fehlt: " + root_id)

	var detail_species: Dictionary = {}
	for detail_path: String in DETAIL_PATHS:
		var detail: Dictionary = _read_json(detail_path)
		var shard_species: Dictionary = detail.get("species", {})
		for species_id_value: Variant in shard_species.keys():
			detail_species[str(species_id_value)] = shard_species[species_id_value]
	assert(detail_species.size() == NEW_SPECIES.size())
	for species_id: String in NEW_SPECIES:
		assert(detail_species.has(species_id), "Gen-2-Pokémon fehlt im Detailpack: " + species_id)

	assert(not detail_species.has("ursaluna"), "Ursaluna bleibt absichtlich zurückgestellt.")

	var sneasel: Dictionary = detail_species.get("sneasel", {})
	assert((sneasel.get("evolution", {}) as Dictionary).get("evolves_into", "") == "weavile")
	assert((sneasel.get("evolution", {}) as Dictionary).get("evolution_level", 0) == 37)

	var ursaring: Dictionary = detail_species.get("ursaring", {})
	assert((ursaring.get("evolution", {}) as Dictionary).get("evolves_into", null) == null)
	assert(not bool((ursaring.get("evolution", {}) as Dictionary).get("mandatory", true)))

	var piloswine: Dictionary = detail_species.get("piloswine", {})
	assert((piloswine.get("evolution", {}) as Dictionary).get("evolves_into", "") == "mamoswine")
	assert((piloswine.get("evolution", {}) as Dictionary).get("evolution_level", 0) == 40)

	var mantyke: Dictionary = detail_species.get("mantyke", {})
	assert((mantyke.get("evolution", {}) as Dictionary).get("evolves_into", "") == "mantine")
	assert((mantyke.get("evolution", {}) as Dictionary).get("evolution_level", 0) == 25)

	var battle = BattleScript.new()
	root.add_child(battle)

	var runtime_species_value: Variant = battle.data.get("species", {})
	assert(runtime_species_value is Dictionary)
	var runtime_species: Dictionary = runtime_species_value
	assert(runtime_species.size() == EXPECTED_SPECIES_COUNT)
	assert(battle.species_ids.size() == EXPECTED_ROOT_COUNT)
	assert(battle.lab_species_ids.size() == EXPECTED_SPECIES_COUNT)

	for species_id: String in NEW_SPECIES:
		assert(runtime_species.has(species_id), "Gen-2-Pokémon fehlt in Runtime: " + species_id)
		assert(battle.lab_species_ids.has(species_id), "Gen-2-Pokémon fehlt im Kampflabor: " + species_id)

	assert(not runtime_species.has("ursaluna"), "Ursaluna bleibt absichtlich zurückgestellt.")

	assert(battle.route_resolve_species_for_level("sneasel", 36) == "sneasel")
	assert(battle.route_resolve_species_for_level("sneasel", 37) == "weavile")
	assert(battle.route_resolve_species_for_level("teddiursa", 29) == "teddiursa")
	assert(battle.route_resolve_species_for_level("teddiursa", 30) == "ursaring")
	assert(battle.route_resolve_species_for_level("teddiursa", 60) == "ursaring")
	assert(battle.route_resolve_species_for_level("slugma", 37) == "slugma")
	assert(battle.route_resolve_species_for_level("slugma", 38) == "magcargo")
	assert(battle.route_resolve_species_for_level("swinub", 32) == "swinub")
	assert(battle.route_resolve_species_for_level("swinub", 33) == "piloswine")
	assert(battle.route_resolve_species_for_level("swinub", 40) == "mamoswine")
	assert(battle.route_resolve_species_for_level("remoraid", 25) == "octillery")
	assert(battle.route_resolve_species_for_level("mantyke", 25) == "mantine")
	assert(battle.route_resolve_species_for_level("houndour", 24) == "houndoom")

	var sneasel_moves: Array = battle.route_moves_for_level("sneasel", 12)
	assert(sneasel_moves.has("scratch"))
	assert(sneasel_moves.has("quick_attack"))

	var houndour_tms: Array = battle._lab_available_tm_moves("houndour")
	assert(houndour_tms.has("protect"))

	print("Gen2 families 31-40 registry/runtime: PASS")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei fehlt/ist leer: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Ungültiges JSON: " + path)
	return parsed as Dictionary
