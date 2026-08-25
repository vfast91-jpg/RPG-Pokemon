extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const ACTIVE_SCRIPT_PATH: String = "res://scripts/battle_demo_remaining_gen1_species_v1.gd"
const EXPECTED_MASTER_PATH: String = "res://data/pokemon_species_master_v1.json"
const GEN2_DETAIL_PATHS: Array[String] = [
	"res://data/gen2_species_families_01_10_v1.json",
	"res://data/gen2_species_families_11_20_v1.json"
]
const EXPECTED_SPECIES_COUNT: int = 232
const EXPECTED_MOVE_COUNT: int = 314
const EXPECTED_ROOT_COUNT: int = 98

const LATER_GEN1_FAMILY_MEMBERS: Array[String] = [
	"crobat", "pichu", "cleffa", "igglybuff", "bellossom", "politoed", "espeon", "umbreon",
	"slowking", "steelix", "scizor", "kingdra", "porygon2", "tyrogue", "hitmontop", "smoochum",
	"elekid", "magby", "blissey", "mime-jr", "happiny", "munchlax", "magnezone", "lickilicky",
	"rhyperior", "tangrowth", "electivire", "magmortar", "leafeon", "glaceon", "porygon-z",
	"sylveon", "kleavor", "annihilape"
]
const GEN2_ROOTS: Array[String] = [
	"chikorita", "cyndaquil", "totodile", "sentret", "hoothoot",
	"ledyba", "spinarak", "chinchou", "togepi", "natu",
	"mareep", "azurill", "bonsly", "hoppip", "aipom",
	"sunkern", "yanma", "wooper", "murkrow", "misdreavus"
]
const GEN2_SPECIES: Array[String] = [
	"chikorita", "bayleef", "meganium", "cyndaquil", "quilava",
	"typhlosion", "totodile", "croconaw", "feraligatr", "sentret",
	"furret", "hoothoot", "noctowl", "ledyba", "ledian",
	"spinarak", "ariados", "chinchou", "lanturn", "togepi",
	"togetic", "togekiss", "natu", "xatu", "mareep",
	"flaaffy", "ampharos", "azurill", "marill", "azumarill",
	"bonsly", "sudowoodo", "hoppip", "skiploom", "jumpluff",
	"aipom", "ambipom", "sunkern", "sunflora", "yanma",
	"yanmega", "wooper", "quagsire", "murkrow", "honchkrow",
	"misdreavus", "mismagius"
]


func _initialize() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(not manifest.is_empty(), "Globales Pokémon-Manifest muss lesbar sein.")
	assert(int(manifest.get("species_count", -1)) == EXPECTED_SPECIES_COUNT, "Globaler Pool muss 232 Pokémon enthalten.")
	assert(int(manifest.get("move_count", -1)) == EXPECTED_MOVE_COUNT, "Manifest muss 314 Basis-Attackendefinitionen deklarieren.")
	assert(int(manifest.get("route_root_count", -1)) == EXPECTED_ROOT_COUNT, "Globaler Familiengraph muss 98 Wurzeln enthalten.")

	var pool_policy_value: Variant = manifest.get("pool_policy", {})
	assert(pool_policy_value is Dictionary, "Das globale Manifest braucht eine Pool-Richtlinie.")
	var pool_policy: Dictionary = pool_policy_value
	assert(str(pool_policy.get("species", "")) == "single_global_pool")
	assert(str(pool_policy.get("moves", "")) == "single_global_pool")
	assert(bool(pool_policy.get("generation_is_metadata_only", false)))
	assert(bool(pool_policy.get("availability_never_gated_by_generation", false)))
	assert(bool(pool_policy.get("cross_generation_families_share_one_family_graph", false)))
	assert(bool(pool_policy.get("species_move_access_is_by_learnset_and_tm_compatibility_only", false)))

	var master_path: String = str(manifest.get("species_master_file", ""))
	assert(master_path == EXPECTED_MASTER_PATH)
	var species_files: Array = manifest.get("species_files", [])
	assert(species_files.size() == 1 and str(species_files[0]) == master_path)

	for list_key: String in ["species_files", "species_detail_files", "move_files"]:
		var paths_value: Variant = manifest.get(list_key, [])
		assert(paths_value is Array)
		for path_value: Variant in paths_value:
			assert(not str(path_value).to_lower().ends_with(".gz"))

	var detail_paths: Array = manifest.get("species_detail_files", [])
	for required_path: String in GEN2_DETAIL_PATHS:
		assert(detail_paths.has(required_path), "Gen-2-Detailpack ist nicht aktiviert: " + required_path)

	var master_pack: Dictionary = _read_json(master_path)
	var master_species_value: Variant = master_pack.get("species", {})
	assert(master_species_value is Dictionary)
	var master_species: Dictionary = master_species_value
	assert(master_species.size() == EXPECTED_SPECIES_COUNT)

	var original_dex_seen: Dictionary = {}
	for species_value: Variant in master_species.values():
		assert(species_value is Dictionary)
		var species: Dictionary = species_value
		var dex_number: int = int(species.get("pokedex_number", 0))
		if dex_number >= 1 and dex_number <= 151:
			assert(not original_dex_seen.has(dex_number))
			original_dex_seen[dex_number] = true
	assert(original_dex_seen.size() == 151)

	for species_id: String in LATER_GEN1_FAMILY_MEMBERS:
		assert(master_species.has(species_id))
	for species_id: String in GEN2_SPECIES:
		assert(master_species.has(species_id), "Gen-2-Pokémon fehlt im Master: " + species_id)
	assert(not master_species.has("ursaluna"), "Ursaluna soll in diesem Implementierungsschritt noch nicht enthalten sein.")

	for path_value: Variant in detail_paths:
		var path: String = str(path_value)
		var pack: Dictionary = _read_json(path)
		var entries_value: Variant = pack.get("species", {})
		assert(entries_value is Dictionary)
		for species_id_value: Variant in (entries_value as Dictionary).keys():
			assert(master_species.has(str(species_id_value)), "Detailpaket darf keine neue Roster-ID einführen: " + str(species_id_value))

	var meta: Dictionary = _read_json(str(manifest.get("species_meta_file", "")))
	var roots: Array = meta.get("route_roots", [])
	assert(roots.size() == EXPECTED_ROOT_COUNT)
	for root_id: String in GEN2_ROOTS:
		assert(roots.has(root_id), "Gen-2-Familienwurzel fehlt: " + root_id)

	var family_members_value: Variant = meta.get("family_members", {})
	assert(family_members_value is Dictionary)
	var family_members: Dictionary = family_members_value
	var seen_members: Dictionary = {}
	for root_id_value: Variant in roots:
		var root_id: String = str(root_id_value)
		var members_value: Variant = family_members.get(root_id, [])
		assert(members_value is Array and not (members_value as Array).is_empty(), "Familie fehlt/ist leer: " + root_id)
		for member_value: Variant in members_value:
			var member_id: String = str(member_value)
			assert(master_species.has(member_id), "Familienmitglied fehlt im Master: " + member_id)
			assert(not seen_members.has(member_id), "Pokémon ist in mehreren Familien registriert: " + member_id)
			seen_members[member_id] = true
	assert(seen_members.size() == EXPECTED_SPECIES_COUNT, "Familiengraph muss alle 232 Pokémon exakt einmal abdecken.")

	var active_script: String = FileAccess.get_file_as_string(ACTIVE_SCRIPT_PATH)
	assert(active_script.contains("pokemon_database_manifest_v1.json"))
	assert(active_script.contains("species_master_file"))
	assert(active_script.contains("single_global_pool"))
	assert(active_script.contains("pokemon_registry_ready"))

	var battle = BattleScript.new()
	root.add_child(battle)
	assert(battle.pokemon_registry_ready())
	var runtime_species_value: Variant = battle.data.get("species", {})
	assert(runtime_species_value is Dictionary)
	var runtime_species: Dictionary = runtime_species_value
	assert(runtime_species.size() == EXPECTED_SPECIES_COUNT)
	assert(battle.species_ids.size() == EXPECTED_ROOT_COUNT)
	assert(battle.lab_species_ids.size() == EXPECTED_SPECIES_COUNT)
	for species_id: String in GEN2_SPECIES:
		assert(runtime_species.has(species_id), "Gen-2-Pokémon fehlt in Runtime: " + species_id)
		assert(battle.lab_species_ids.has(species_id), "Gen-2-Pokémon fehlt im Kampflabor: " + species_id)

	print("Global Pokemon pool contract passed: 232 species, 98 families, Gen2 families 01-20 active.")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	assert(not path.to_lower().ends_with(".gz"))
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei konnte nicht gelesen werden: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "JSON konnte nicht gelesen werden: " + path)
	return parsed as Dictionary
