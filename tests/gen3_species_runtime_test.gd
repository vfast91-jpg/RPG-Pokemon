extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen3_species_v1.gd")

const GLOBAL_MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const EXTENSION_MANIFEST_PATH: String = "res://data/pokemon_database_extension_gen3_v1.json"
const ACTIVE_CHAIN_PATH: String = "res://scripts/battle_demo_boss_aggro_lock_v1.gd"
const EXPECTED_BASE_SPECIES_COUNT: int = 282
const EXPECTED_BASE_ROOT_COUNT: int = 129
const EXPECTED_GEN3_SPECIES_COUNT: int = 146
const EXPECTED_GEN3_ROOT_COUNT: int = 73
const EXPECTED_RUNTIME_SPECIES_COUNT: int = 428
const EXPECTED_RUNTIME_ROOT_COUNT: int = 202


func _initialize() -> void:
	var global_manifest: Dictionary = _read_json(GLOBAL_MANIFEST_PATH)
	assert(int(global_manifest.get("runtime_species_count", -1)) == EXPECTED_RUNTIME_SPECIES_COUNT)
	assert(int(global_manifest.get("runtime_route_root_count", -1)) == EXPECTED_RUNTIME_ROOT_COUNT)
	assert((global_manifest.get("species_extension_manifests", []) as Array).has(EXTENSION_MANIFEST_PATH))

	var active_chain_text: String = FileAccess.get_file_as_string(ACTIVE_CHAIN_PATH)
	assert(
		active_chain_text.begins_with("extends \"res://scripts/battle_demo_gen3_species_v1.gd\""),
		"Der aktive Kampfstack muss die Gen3-Roster-Erweiterung laden."
	)

	var extension: Dictionary = _read_json(EXTENSION_MANIFEST_PATH)
	assert(int(extension.get("expected_base_species_count", -1)) == EXPECTED_BASE_SPECIES_COUNT)
	assert(int(extension.get("expected_base_route_root_count", -1)) == EXPECTED_BASE_ROOT_COUNT)
	assert(int(extension.get("extension_species_count", -1)) == EXPECTED_GEN3_SPECIES_COUNT)
	assert(int(extension.get("extension_route_root_count", -1)) == EXPECTED_GEN3_ROOT_COUNT)
	assert(int(extension.get("runtime_species_count", -1)) == EXPECTED_RUNTIME_SPECIES_COUNT)
	assert(int(extension.get("runtime_route_root_count", -1)) == EXPECTED_RUNTIME_ROOT_COUNT)

	var core: Dictionary = _read_json(str(extension.get("species_master_extension_file", "")))
	var core_species: Dictionary = core.get("species", {})
	assert(core_species.size() == EXPECTED_GEN3_SPECIES_COUNT)

	var family_meta: Dictionary = _read_json(str(extension.get("family_meta_extension_file", "")))
	var new_roots: Array = family_meta.get("route_roots", [])
	var family_members: Dictionary = family_meta.get("family_members", {})
	assert(new_roots.size() == EXPECTED_GEN3_ROOT_COUNT)
	assert(family_members.size() == EXPECTED_GEN3_ROOT_COUNT)

	var detail_species: Dictionary = {}
	for path_value: Variant in extension.get("species_detail_files", []):
		var detail: Dictionary = _read_json(str(path_value))
		for species_id_value: Variant in (detail.get("species", {}) as Dictionary).keys():
			var species_id: String = str(species_id_value)
			assert(not detail_species.has(species_id), "Doppelte Gen3-Detail-ID: " + species_id)
			detail_species[species_id] = (detail.get("species", {}) as Dictionary).get(species_id_value)
	assert(detail_species.size() == EXPECTED_GEN3_SPECIES_COUNT)

	for species_id_value: Variant in core_species.keys():
		var species_id: String = str(species_id_value)
		assert(detail_species.has(species_id), "Gen3-Detaildatensatz fehlt: " + species_id)
		var core_entry: Dictionary = core_species.get(species_id, {})
		var display_name: String = str(core_entry.get("display_name", ""))
		var sprite_path: String = "res://assets/monsters/" + display_name + ".png"
		assert(
			FileAccess.file_exists(sprite_path),
			"Gen3-Sprite fehlt oder ist falsch benannt: " + sprite_path
		)

	for root_value: Variant in new_roots:
		var root_id: String = str(root_value)
		assert(family_members.has(root_id), "Gen3-Familie fehlt: " + root_id)
		assert((family_members.get(root_id, []) as Array).has(root_id), "Gen3-Familienwurzel fehlt in eigener Familie: " + root_id)

	# Repräsentative Daten- und Sonderfallprüfungen.
	assert(str((core_species.get("treecko", {}) as Dictionary).get("display_name", "")) == "Geckarbor")
	assert(core_species.has("rayquaza"))
	assert(core_species.has("castform-sunny"))
	assert(core_species.has("deoxys-speed"))

	var wurmple: Dictionary = detail_species.get("wurmple", {})
	var wurmple_evolution: Dictionary = wurmple.get("evolution", {})
	assert((wurmple_evolution.get("evolves_into", []) as Array).size() == 2)
	assert((wurmple_evolution.get("choices", []) as Array).size() == 2)
	assert(int(wurmple_evolution.get("evolution_level", 0)) == 7)

	var kirlia: Dictionary = detail_species.get("kirlia", {})
	var kirlia_evolution: Dictionary = kirlia.get("evolution", {})
	assert((kirlia_evolution.get("choices", []) as Array).size() == 2)
	assert(str(kirlia_evolution.get("requirement", "")).contains("gender ignored"))

	var battle = BattleScript.new()
	root.add_child(battle)
	# Adding the battle node schedules its _ready() after this initialization
	# callback. Wait one frame so the complete inherited data-loader chain has
	# published the Gen-3 registry before checking it.
	await process_frame
	assert(battle.pokemon_registry_ready(), "Gen3-Roster konnte nicht in die Runtime geladen werden.")
	var runtime_species: Dictionary = battle.data.get("species", {})
	assert(runtime_species.size() == EXPECTED_RUNTIME_SPECIES_COUNT)
	assert(battle.species_ids.size() == EXPECTED_RUNTIME_ROOT_COUNT)
	assert(battle.lab_species_ids.size() == EXPECTED_RUNTIME_SPECIES_COUNT)

	for species_id_value: Variant in core_species.keys():
		var species_id: String = str(species_id_value)
		assert(runtime_species.has(species_id), "Gen3-Pokemon fehlt in Runtime: " + species_id)
		assert(battle.lab_species_ids.has(species_id), "Gen3-Pokemon fehlt im Kampflabor: " + species_id)

	assert(battle.route_resolve_species_for_level("treecko", 15) == "treecko")
	assert(battle.route_resolve_species_for_level("treecko", 16) == "grovyle")
	assert(battle.route_resolve_species_for_level("treecko", 36) == "sceptile")

	print("Generation 3 Pokemon roster runtime integration: PASS")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei fehlt/ist leer: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Ungueltiges JSON: " + path)
	return parsed as Dictionary
