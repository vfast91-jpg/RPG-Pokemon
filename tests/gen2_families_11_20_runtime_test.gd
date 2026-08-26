extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const META_PATH: String = "res://data/pokemon_family_meta_v1.json"
const DETAIL_PATH: String = "res://data/gen2_species_families_11_20_v1.json"

const EXPECTED_SPECIES_COUNT: int = 266
const EXPECTED_ROOT_COUNT: int = 118
const EXPECTED_RUNTIME_SPECIES_COUNT: int = 280
const EXPECTED_RUNTIME_ROOT_COUNT: int = 128
const NEW_ROOTS: Array[String] = [
	"mareep", "azurill", "bonsly", "hoppip", "aipom",
	"sunkern", "yanma", "wooper", "murkrow", "misdreavus"
]
const NEW_SPECIES: Array[String] = [
	"mareep", "flaaffy", "ampharos", "azurill", "marill",
	"azumarill", "bonsly", "sudowoodo", "hoppip", "skiploom",
	"jumpluff", "aipom", "ambipom", "sunkern", "sunflora",
	"yanma", "yanmega", "wooper", "quagsire", "murkrow",
	"honchkrow", "misdreavus", "mismagius"
]


func _initialize() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(int(manifest.get("species_count", -1)) == EXPECTED_SPECIES_COUNT)
	assert(int(manifest.get("route_root_count", -1)) == EXPECTED_ROOT_COUNT)
	assert((manifest.get("species_detail_files", []) as Array).has(DETAIL_PATH))

	var meta: Dictionary = _read_json(META_PATH)
	var roots: Array = meta.get("route_roots", [])
	assert(roots.size() == EXPECTED_ROOT_COUNT)
	for root_id: String in NEW_ROOTS:
		assert(roots.has(root_id), "Neue Gen-2-Familie fehlt: " + root_id)

	var detail: Dictionary = _read_json(DETAIL_PATH)
	var detail_species: Dictionary = detail.get("species", {})
	assert(detail_species.size() == NEW_SPECIES.size())
	for species_id: String in NEW_SPECIES:
		assert(detail_species.has(species_id), "Gen-2-Pokémon fehlt im Detailpack: " + species_id)

	var mareep: Dictionary = detail_species.get("mareep", {})
	assert((mareep.get("base_stats", {}) as Dictionary).get("hp", 0) == 55)
	assert((mareep.get("evolution", {}) as Dictionary).get("evolves_into", "") == "flaaffy")
	assert((mareep.get("learnset", {}) as Dictionary).get("tm_hm", []).has("protect"))

	var ampharos: Dictionary = detail_species.get("ampharos", {})
	assert((ampharos.get("learnset", {}) as Dictionary).get("evolution_moves", []).has("thunder_punch"))

	var battle = BattleScript.new()
	root.add_child(battle)

	var runtime_species_value: Variant = battle.data.get("species", {})
	assert(runtime_species_value is Dictionary)
	var runtime_species: Dictionary = runtime_species_value
	assert(runtime_species.size() == EXPECTED_RUNTIME_SPECIES_COUNT)
	assert(battle.species_ids.size() == EXPECTED_RUNTIME_ROOT_COUNT)
	assert(battle.lab_species_ids.size() == EXPECTED_RUNTIME_SPECIES_COUNT)

	for species_id: String in NEW_SPECIES:
		assert(runtime_species.has(species_id), "Gen-2-Pokémon fehlt in Runtime: " + species_id)
		assert(battle.lab_species_ids.has(species_id), "Gen-2-Pokémon fehlt im Kampflabor: " + species_id)

	assert(battle.route_resolve_species_for_level("mareep", 14) == "mareep")
	assert(battle.route_resolve_species_for_level("mareep", 15) == "flaaffy")
	assert(battle.route_resolve_species_for_level("mareep", 30) == "ampharos")
	assert(battle.route_resolve_species_for_level("azurill", 14) == "azurill")
	assert(battle.route_resolve_species_for_level("azurill", 15) == "marill")
	assert(battle.route_resolve_species_for_level("azurill", 18) == "azumarill")
	assert(battle.route_resolve_species_for_level("misdreavus", 39) == "misdreavus")
	assert(battle.route_resolve_species_for_level("misdreavus", 40) == "mismagius")

	var mareep_moves: Array = battle.route_moves_for_level("mareep", 12)
	assert(mareep_moves.has("tackle"))
	assert(mareep_moves.has("thunder_wave"))
	assert(mareep_moves.has("thunder_shock"))
	assert(mareep_moves.has("cotton_spore"))

	var mareep_tms: Array = battle._lab_available_tm_moves("mareep")
	assert(mareep_tms.has("protect"))

	assert(not runtime_species.has("ursaluna"), "Ursaluna bleibt absichtlich zurückgestellt.")

	print("Gen2 families 11-20 registry/runtime: PASS")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei fehlt/ist leer: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Ungültiges JSON: " + path)
	return parsed as Dictionary
