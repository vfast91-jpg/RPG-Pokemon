extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const META_PATH: String = "res://data/pokemon_family_meta_v1.json"
const URSALUNA_EXTENSION_PATH: String = "res://data/pokemon_database_extension_ursaluna_v1.json"
const DETAIL_PATHS: Array[String] = [
	"res://data/gen2_species_families_31_33_v1.json",
	"res://data/gen2_species_families_34_35_v1.json",
	"res://data/gen2_species_families_36_38_v1.json",
	"res://data/gen2_species_families_39_40_v1.json"
]

const EXPECTED_SPECIES_COUNT: int = 266
const EXPECTED_ROOT_COUNT: int = 118
const EXPECTED_RUNTIME_SPECIES_COUNT: int = 282
const EXPECTED_RUNTIME_ROOT_COUNT: int = 129
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
	assert(int(manifest.get("runtime_species_count", -1)) == EXPECTED_RUNTIME_SPECIES_COUNT)
	assert(int(manifest.get("runtime_route_root_count", -1)) == EXPECTED_RUNTIME_ROOT_COUNT)
	assert((manifest.get("species_extension_manifests", []) as Array).has(URSALUNA_EXTENSION_PATH))
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
	assert(not detail_species.has("ursaluna"), "Ursaluna wird append-only über das Familien-Extensionpaket aktiviert.")

	var sneasel: Dictionary = detail_species.get("sneasel", {})
	assert((sneasel.get("evolution", {}) as Dictionary).get("evolves_into", "") == "weavile")
	assert((sneasel.get("evolution", {}) as Dictionary).get("evolution_level", 0) == 37)

	var base_ursaring: Dictionary = detail_species.get("ursaring", {})
	assert((base_ursaring.get("evolution", {}) as Dictionary).get("evolves_into", null) == null)

	var ursaluna_extension: Dictionary = _read_json(URSALUNA_EXTENSION_PATH)
	assert(ursaluna_extension.get("family_root", "") == "teddiursa")
	assert((ursaluna_extension.get("family_members", []) as Array) == ["teddiursa", "ursaring", "ursaluna"])
	var extension_evolution: Dictionary = ursaluna_extension.get("ursaring_evolution", {})
	assert(extension_evolution.get("evolves_into", "") == "ursaluna")
	assert(int(extension_evolution.get("evolution_level", 0)) == 50)
	assert(bool(extension_evolution.get("mandatory", false)))
	var extension_species: Dictionary = ursaluna_extension.get("species_detail", {})
	var ursaluna_source: Dictionary = extension_species.get("ursaluna", {})
	assert(not ursaluna_source.is_empty())
	assert((ursaluna_source.get("types", {}) as Dictionary).get("primary", "") == "ground")
	assert((ursaluna_source.get("types", {}) as Dictionary).get("secondary", "") == "normal")
	assert((ursaluna_source.get("base_stats", {}) as Dictionary) == {"hp":130,"attack":140,"defense":105,"special":33,"speed":50})
	assert((ursaluna_source.get("learnset", {}) as Dictionary).get("evolution_moves", []).is_empty())
	assert(not str(ursaluna_source).contains("headlong_rush"), "Schmetterramme bleibt in diesem Schritt ausdrücklich unberührt.")

	var piloswine: Dictionary = detail_species.get("piloswine", {})
	assert((piloswine.get("evolution", {}) as Dictionary).get("evolves_into", "") == "mamoswine")
	assert((piloswine.get("evolution", {}) as Dictionary).get("evolution_level", 0) == 40)

	var mantyke: Dictionary = detail_species.get("mantyke", {})
	assert((mantyke.get("evolution", {}) as Dictionary).get("evolves_into", "") == "mantine")
	assert((mantyke.get("evolution", {}) as Dictionary).get("evolution_level", 0) == 25)

	var battle = BattleScript.new()
	root.add_child(battle)
	assert(battle.pokemon_registry_ready())

	var runtime_species_value: Variant = battle.data.get("species", {})
	assert(runtime_species_value is Dictionary)
	var runtime_species: Dictionary = runtime_species_value
	assert(runtime_species.size() == EXPECTED_RUNTIME_SPECIES_COUNT)
	assert(battle.species_ids.size() == EXPECTED_RUNTIME_ROOT_COUNT)
	assert(battle.lab_species_ids.size() == EXPECTED_RUNTIME_SPECIES_COUNT)

	for species_id: String in NEW_SPECIES:
		assert(runtime_species.has(species_id), "Gen-2-Pokémon fehlt in Runtime: " + species_id)
		assert(battle.lab_species_ids.has(species_id), "Gen-2-Pokémon fehlt im Kampflabor: " + species_id)
	assert(runtime_species.has("ursaluna"), "Ursaluna fehlt im Runtime-Pool.")
	assert(battle.lab_species_ids.has("ursaluna"), "Ursaluna fehlt im Kampflabor.")
	assert((battle._canonical_pack.get("family_members", {}) as Dictionary).get("teddiursa", []) == ["teddiursa", "ursaring", "ursaluna"])

	assert(battle.route_resolve_species_for_level("sneasel", 36) == "sneasel")
	assert(battle.route_resolve_species_for_level("sneasel", 37) == "weavile")
	assert(battle.route_resolve_species_for_level("teddiursa", 29) == "teddiursa")
	assert(battle.route_resolve_species_for_level("teddiursa", 30) == "ursaring")
	assert(battle.route_resolve_species_for_level("teddiursa", 49) == "ursaring")
	assert(battle.route_resolve_species_for_level("teddiursa", 50) == "ursaluna")
	assert(battle.route_resolve_species_for_level("ursaring", 50) == "ursaluna")
	assert(battle.route_resolve_species_for_level("ursaluna", 100) == "ursaluna")
	assert(battle.route_resolve_species_for_level("slugma", 37) == "slugma")
	assert(battle.route_resolve_species_for_level("slugma", 38) == "magcargo")
	assert(battle.route_resolve_species_for_level("swinub", 32) == "swinub")
	assert(battle.route_resolve_species_for_level("swinub", 33) == "piloswine")
	assert(battle.route_resolve_species_for_level("swinub", 40) == "mamoswine")
	assert(battle.route_resolve_species_for_level("remoraid", 25) == "octillery")
	assert(battle.route_resolve_species_for_level("mantyke", 25) == "mantine")
	assert(battle.route_resolve_species_for_level("houndour", 24) == "houndoom")

	var ursaluna_moves: Array = battle.route_moves_for_level("ursaluna", 64)
	assert(ursaluna_moves.has("scratch"))
	assert(ursaluna_moves.has("high_horsepower"))
	assert(ursaluna_moves.has("thrash"))
	assert(ursaluna_moves.has("hammer_arm"))
	assert(not ursaluna_moves.has("headlong_rush"))
	var ursaluna_tms: Array = battle._lab_available_tm_moves("ursaluna")
	assert(ursaluna_tms.has("protect"))
	assert(ursaluna_tms.has("earthquake"))

	var sneasel_moves: Array = battle.route_moves_for_level("sneasel", 12)
	assert(sneasel_moves.has("scratch"))
	assert(sneasel_moves.has("quick_attack"))

	var houndour_tms: Array = battle._lab_available_tm_moves("houndour")
	assert(houndour_tms.has("protect"))

	print("Gen2 families 31-40 + Ursaluna family extension: PASS")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei fehlt/ist leer: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Ungültiges JSON: " + path)
	return parsed as Dictionary
