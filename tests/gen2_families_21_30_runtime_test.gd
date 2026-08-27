extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const META_PATH: String = "res://data/pokemon_family_meta_v1.json"
const DETAIL_PATH: String = "res://data/gen2_species_families_21_30_v1.json"

const EXPECTED_SPECIES_COUNT: int = 266
const EXPECTED_ROOT_COUNT: int = 118
const EXPECTED_RUNTIME_SPECIES_COUNT: int = 282
const EXPECTED_RUNTIME_ROOT_COUNT: int = 129
const NEW_ROOTS: Array[String] = [
	"unown", "wynaut", "girafarig", "pineco", "dunsparce",
	"gligar", "snubbull", "qwilfish", "shuckle", "heracross"
]
const NEW_SPECIES: Array[String] = [
	"unown", "wynaut", "wobbuffet", "girafarig", "farigiraf",
	"pineco", "forretress", "dunsparce", "dudunsparce", "gligar",
	"gliscor", "snubbull", "granbull", "qwilfish", "shuckle", "heracross"
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

	var unown: Dictionary = detail_species.get("unown", {})
	assert((unown.get("base_stats", {}) as Dictionary).get("hp", 0) == 48)
	assert((unown.get("learnset", {}) as Dictionary).get("level_up", {}).get("1", []).has("hidden_power"))
	assert((unown.get("learnset", {}) as Dictionary).get("tm_hm", []).is_empty())

	var wynaut: Dictionary = detail_species.get("wynaut", {})
	assert((wynaut.get("evolution", {}) as Dictionary).get("evolves_into", "") == "wobbuffet")
	assert((wynaut.get("evolution", {}) as Dictionary).get("evolution_level", 0) == 15)

	var farigiraf: Dictionary = detail_species.get("farigiraf", {})
	assert((farigiraf.get("learnset", {}) as Dictionary).get("evolution_moves", []).has("twin_beam"))

	var qwilfish: Dictionary = detail_species.get("qwilfish", {})
	assert((qwilfish.get("evolution", {}) as Dictionary).get("evolves_into", null) == null)

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

	assert(battle.route_resolve_species_for_level("wynaut", 14) == "wynaut")
	assert(battle.route_resolve_species_for_level("wynaut", 15) == "wobbuffet")
	assert(battle.route_resolve_species_for_level("girafarig", 31) == "girafarig")
	assert(battle.route_resolve_species_for_level("girafarig", 32) == "farigiraf")
	assert(battle.route_resolve_species_for_level("dunsparce", 31) == "dunsparce")
	assert(battle.route_resolve_species_for_level("dunsparce", 32) == "dudunsparce")
	assert(battle.route_resolve_species_for_level("gligar", 36) == "gligar")
	assert(battle.route_resolve_species_for_level("gligar", 37) == "gliscor")
	assert(battle.route_resolve_species_for_level("snubbull", 22) == "snubbull")
	assert(battle.route_resolve_species_for_level("snubbull", 23) == "granbull")

	var girafarig_moves: Array = battle.route_moves_for_level("girafarig", 10)
	assert(girafarig_moves.has("tackle"))
	assert(girafarig_moves.has("confusion"))

	var girafarig_tms: Array = battle._lab_available_tm_moves("girafarig")
	assert(girafarig_tms.has("protect"))
	assert(runtime_species.has("ursaluna"), "Ursaluna muss als Familienerweiterung im finalen Runtime-Pool aktiv sein.")

	print("Gen2 families 21-30 registry/runtime: PASS")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei fehlt/ist leer: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Ungültiges JSON: " + path)
	return parsed as Dictionary
