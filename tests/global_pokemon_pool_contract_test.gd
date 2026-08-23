extends SceneTree

const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const LOADER_PATH: String = "res://scripts/battle_demo_remaining_gen1_species_v1.gd"


func _initialize() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(not manifest.is_empty(), "Generation-neutrales Pokémon-Manifest fehlt.")

	var policy_value: Variant = manifest.get("pool_policy", {})
	assert(policy_value is Dictionary, "Pool-Richtlinie fehlt.")
	var policy: Dictionary = policy_value
	assert(str(policy.get("species", "")) == "single_global_pool", "Es darf nur einen Pokémon-Pool geben.")
	assert(str(policy.get("moves", "")) == "single_global_pool", "Es darf nur einen Attackenpool geben.")
	assert(bool(policy.get("generation_is_metadata_only", false)), "Generation darf nur Metadatum sein.")
	assert(bool(policy.get("availability_never_gated_by_generation", false)), "Generation darf Verfügbarkeit nicht filtern.")
	assert(bool(policy.get("cross_generation_families_share_one_family_graph", false)), "Familien dürfen nicht an Generationsgrenzen getrennt werden.")
	assert(bool(policy.get("species_move_access_is_by_learnset_and_tm_compatibility_only", false)), "Pokémon greifen über Learnset/TM-Kompatibilität auf den gemeinsamen Attackenpool zu.")

	var master_path: String = str(manifest.get("species_master_file", ""))
	assert(master_path == "res://data/pokemon_species_master_v1.json", "Der aktive Pokémon-Master muss generation-neutral benannt sein.")
	var meta_path: String = str(manifest.get("species_meta_file", ""))
	assert(meta_path == "res://data/pokemon_family_meta_v1.json", "Der aktive Familiengraph muss generation-neutral benannt sein.")

	var species_files_value: Variant = manifest.get("species_files", [])
	assert(species_files_value is Array, "species_files fehlt.")
	var species_files: Array = species_files_value
	assert(species_files.size() == 1 and str(species_files[0]) == master_path, "Alle Pokémon müssen aus genau einer Masterdatei stammen.")
	assert(str(manifest.get("move_pool_mode", "")) == "single_global_runtime_dictionary_merged_from_plain_json_sources", "Alle Attackendateien müssen in ein gemeinsames Runtime-Dictionary fließen.")

	var master: Dictionary = _read_json(master_path)
	var species_value: Variant = master.get("species", {})
	assert(species_value is Dictionary, "Globaler Pokémon-Master braucht ein species-Dictionary.")
	var species: Dictionary = species_value
	assert(species.size() == int(manifest.get("species_count", -1)), "Manifest und globaler Pokémon-Master müssen dieselbe Größe deklarieren.")

	var meta: Dictionary = _read_json(meta_path)
	var roots_value: Variant = meta.get("route_roots", [])
	assert(roots_value is Array, "Globaler Familiengraph braucht route_roots.")
	assert((roots_value as Array).size() == int(manifest.get("route_root_count", -1)), "Manifest und globaler Familiengraph müssen dieselbe Familienzahl deklarieren.")

	var loader_text: String = FileAccess.get_file_as_string(LOADER_PATH)
	assert(loader_text.contains("pokemon_database_manifest_v1.json"), "Aktiver Loader muss das generation-neutrale Manifest verwenden.")
	assert(loader_text.contains("manifest.get(\"species_count\""), "Der Loader muss die Rostergröße dynamisch aus dem Manifest lesen.")
	assert(loader_text.contains("manifest.get(\"route_root_count\""), "Der Loader muss die Familienzahl dynamisch aus dem Manifest lesen.")
	assert(not loader_text.contains("REMAINING_EXPECTED_SPECIES_COUNT"), "Der Loader darf nicht dauerhaft auf 185 Pokémon fest verdrahtet sein.")
	assert(not loader_text.contains("REMAINING_EXPECTED_ROUTE_ROOT_COUNT"), "Der Loader darf nicht dauerhaft auf 78 Familien fest verdrahtet sein.")
	assert(loader_text.contains("single_global_pool"), "Der Loader muss den Ein-Pool-Vertrag aktiv erzwingen.")

	print("Global Pokemon pool future-generation contract: PASS")
	quit(0)


func _read_json(path: String) -> Dictionary:
	assert(not path.to_lower().ends_with(".gz"), "Aktive globale Daten dürfen nicht komprimiert sein: " + path)
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei konnte nicht gelesen werden: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "JSON konnte nicht gelesen werden: " + path)
	return parsed as Dictionary
