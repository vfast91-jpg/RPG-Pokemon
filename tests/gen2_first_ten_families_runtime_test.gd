extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const META_PATH: String = "res://data/pokemon_family_meta_v1.json"
const DETAIL_PATH: String = "res://data/gen2_species_families_01_10_v1.json"

const EXPECTED_SPECIES_COUNT: int = 266
const EXPECTED_ROOT_COUNT: int = 118
const NEW_ROOTS: Array[String] = [
	"chikorita", "cyndaquil", "totodile", "sentret", "hoothoot",
	"ledyba", "spinarak", "chinchou", "togepi", "natu"
]
const NEW_SPECIES: Array[String] = [
	"chikorita", "bayleef", "meganium",
	"cyndaquil", "quilava", "typhlosion",
	"totodile", "croconaw", "feraligatr",
	"sentret", "furret",
	"hoothoot", "noctowl",
	"ledyba", "ledian",
	"spinarak", "ariados",
	"chinchou", "lanturn",
	"togepi", "togetic", "togekiss",
	"natu", "xatu"
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

	var chikorita: Dictionary = detail_species.get("chikorita", {})
	assert((chikorita.get("base_stats", {}) as Dictionary).get("hp", 0) == 45)
	assert((chikorita.get("evolution", {}) as Dictionary).get("evolves_into", "") == "bayleef")
	assert((chikorita.get("learnset", {}) as Dictionary).get("tm_hm", []).has("protect"))

	var togetic: Dictionary = detail_species.get("togetic", {})
	assert((togetic.get("evolution", {}) as Dictionary).get("evolves_into", "") == "togekiss")
	assert(int((togetic.get("evolution", {}) as Dictionary).get("evolution_level", 0)) == 40)

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

	assert(battle.route_resolve_species_for_level("chikorita", 15) == "chikorita")
	assert(battle.route_resolve_species_for_level("chikorita", 16) == "bayleef")
	assert(battle.route_resolve_species_for_level("chikorita", 32) == "meganium")
	assert(battle.route_resolve_species_for_level("togepi", 19) == "togepi")
	assert(battle.route_resolve_species_for_level("togepi", 20) == "togetic")
	assert(battle.route_resolve_species_for_level("togepi", 40) == "togekiss")

	var chikorita_moves: Array = battle.route_moves_for_level("chikorita", 12)
	assert(chikorita_moves.has("tackle"))
	assert(chikorita_moves.has("razor_leaf"))
	assert(chikorita_moves.has("synthesis"))

	var chikorita_tms: Array = battle._lab_available_tm_moves("chikorita")
	assert(chikorita_tms.has("protect"))

	print("Gen2 first ten families registry/runtime: PASS")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei fehlt/ist leer: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Ungültiges JSON: " + path)
	return parsed as Dictionary
