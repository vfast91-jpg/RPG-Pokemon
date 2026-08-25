extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_gen2_moves_v23_v1.gd")

const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
const ACTIVE_SCRIPT_PATH: String = "res://scripts/battle_demo_remaining_gen1_species_v1.gd"
const EXPECTED_MASTER_PATH: String = "res://data/pokemon_species_master_v1.json"
const GEN2_DETAIL_PATH: String = "res://data/gen2_species_families_01_10_v1.json"
const EXPECTED_SPECIES_COUNT: int = 209
const EXPECTED_MOVE_COUNT: int = 314
const EXPECTED_ROOT_COUNT: int = 88

const LATER_GEN1_FAMILY_MEMBERS: Array[String] = [
	"crobat", "pichu", "cleffa", "igglybuff", "bellossom", "politoed", "espeon", "umbreon",
	"slowking", "steelix", "scizor", "kingdra", "porygon2", "tyrogue", "hitmontop", "smoochum",
	"elekid", "magby", "blissey", "mime-jr", "happiny", "munchlax", "magnezone", "lickilicky",
	"rhyperior", "tangrowth", "electivire", "magmortar", "leafeon", "glaceon", "porygon-z",
	"sylveon", "kleavor", "annihilape"
]
const NEW_ROOTS: Array[String] = [
	"chikorita", "cyndaquil", "totodile", "sentret", "hoothoot",
	"ledyba", "spinarak", "chinchou", "togepi", "natu"
]
const NEW_SPECIES: Array[String] = [
	"chikorita", "bayleef", "meganium",
	"cyndaquil", "quilava", "typhlosion",
	"totodile", "croconaw", "feraligatr",
	"sentret", "furret", "hoothoot", "noctowl",
	"ledyba", "ledian", "spinarak", "ariados",
	"chinchou", "lanturn", "togepi", "togetic", "togekiss",
	"natu", "xatu"
]


func _initialize() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(not manifest.is_empty(), "Globales Pokémon-Manifest muss lesbar sein.")
	assert(int(manifest.get("species_count", -1)) == EXPECTED_SPECIES_COUNT, "Globaler Pool muss 209 Pokémon enthalten.")
	assert(int(manifest.get("move_count", -1)) == EXPECTED_MOVE_COUNT, "Manifest muss 314 Basis-Attackendefinitionen deklarieren.")
	assert(int(manifest.get("route_root_count", -1)) == EXPECTED_ROOT_COUNT, "Globaler Familiengraph muss 88 Wurzeln enthalten.")

	var pool_policy_value: Variant = manifest.get("pool_policy", {})
	assert(pool_policy_value is Dictionary, "Das globale Manifest braucht eine Pool-Richtlinie.")
	var pool_policy: Dictionary = pool_policy_value
	assert(str(pool_policy.get("species", "")) == "single_global_pool", "Alle Pokémon müssen in genau einem globalen Pool liegen.")
	assert(str(pool_policy.get("moves", "")) == "single_global_pool", "Alle Attacken müssen in genau einem globalen Pool liegen.")
	assert(bool(pool_policy.get("generation_is_metadata_only", false)), "Generation darf nur Metadatum sein.")
	assert(bool(pool_policy.get("availability_never_gated_by_generation", false)), "Generation darf Pokémon-Verfügbarkeit niemals filtern.")
	assert(bool(pool_policy.get("cross_generation_families_share_one_family_graph", false)), "Generationsübergreifende Entwicklungen müssen in derselben Familie bleiben.")
	assert(bool(pool_policy.get("species_move_access_is_by_learnset_and_tm_compatibility_only", false)), "Attackenzugriff muss über Learnset/TM-Kompatibilität laufen.")

	var master_path: String = str(manifest.get("species_master_file", ""))
	assert(master_path == EXPECTED_MASTER_PATH, "Der Roster muss die generation-neutrale Masterdatei verwenden.")
	var species_files_value: Variant = manifest.get("species_files", [])
	assert(species_files_value is Array, "species_files muss eine Liste sein.")
	var species_files: Array = species_files_value
	assert(species_files.size() == 1 and str(species_files[0]) == master_path, "Roster-Mitgliedschaft darf nur aus der einen Masterdatei stammen.")

	for list_key: String in ["species_files", "species_detail_files", "move_files"]:
		var paths_value: Variant = manifest.get(list_key, [])
		assert(paths_value is Array, list_key + " muss eine Liste sein.")
		for path_value: Variant in paths_value:
			assert(not str(path_value).to_lower().ends_with(".gz"), "Aktiver Datenpfad darf kein GZIP enthalten: " + str(path_value))

	var detail_paths: Array = manifest.get("species_detail_files", [])
	assert(detail_paths.has(GEN2_DETAIL_PATH), "Gen-2-Detailpack 01-10 ist nicht aktiviert.")

	var master_pack: Dictionary = _read_json(master_path)
	var master_species_value: Variant = master_pack.get("species", {})
	assert(master_species_value is Dictionary, "Masterdatei muss ein species-Dictionary enthalten.")
	var master_species: Dictionary = master_species_value
	assert(master_species.size() == EXPECTED_SPECIES_COUNT, "Master und Manifest müssen dieselbe Rostergröße besitzen.")

	var original_dex_seen: Dictionary = {}
	for species_value: Variant in master_species.values():
		assert(species_value is Dictionary, "Jeder Mastereintrag muss ein Dictionary sein.")
		var species: Dictionary = species_value
		var dex_number: int = int(species.get("pokedex_number", 0))
		if dex_number >= 1 and dex_number <= 151:
			assert(not original_dex_seen.has(dex_number), "Doppelte Original-Pokédex-Nummer: " + str(dex_number))
			original_dex_seen[dex_number] = true
	assert(original_dex_seen.size() == 151, "Alle ursprünglichen 151 Pokémon müssen im globalen Master bleiben.")

	for species_id: String in LATER_GEN1_FAMILY_MEMBERS:
		assert(master_species.has(species_id), "Späteres Gen-1-Familienmitglied fehlt im Master: " + species_id)
	for species_id: String in NEW_SPECIES:
		assert(master_species.has(species_id), "Neues Gen-2-Pokémon fehlt im Master: " + species_id)
	assert(not master_species.has("ursaluna"), "Ursaluna soll in diesem Implementierungsschritt noch nicht enthalten sein.")

	# Detaildateien dürfen nur Einträge anreichern, die bereits in der Masterdatei registriert sind.
	for path_value: Variant in detail_paths:
		var path: String = str(path_value)
		var pack: Dictionary = _read_json(path)
		var entries_value: Variant = pack.get("species", {})
		assert(entries_value is Dictionary, "Ungültiges Spezies-Detailpaket: " + path)
		for species_id_value: Variant in (entries_value as Dictionary).keys():
			assert(master_species.has(str(species_id_value)), "Detailpaket darf keine neue Roster-ID einführen: " + str(species_id_value))

	var meta: Dictionary = _read_json(str(manifest.get("species_meta_file", "")))
	var roots_value: Variant = meta.get("route_roots", [])
	assert(roots_value is Array, "Globale Familienmetadaten brauchen route_roots.")
	var roots: Array = roots_value
	assert(roots.size() == EXPECTED_ROOT_COUNT, "Familiengraph und Manifest müssen dieselbe Wurzelzahl besitzen.")
	for root_id: String in NEW_ROOTS:
		assert(roots.has(root_id), "Neue Gen-2-Familienwurzel fehlt: " + root_id)

	var family_members_value: Variant = meta.get("family_members", {})
	assert(family_members_value is Dictionary, "Globale Familienmetadaten brauchen family_members.")
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
	assert(seen_members.size() == EXPECTED_SPECIES_COUNT, "Familiengraph muss alle 209 Pokémon exakt einmal abdecken.")

	var active_script: String = FileAccess.get_file_as_string(ACTIVE_SCRIPT_PATH)
	assert(active_script.contains("pokemon_database_manifest_v1.json"), "Aktiver Spezies-Layer muss das generation-neutrale Manifest laden.")
	assert(active_script.contains("species_master_file"), "Aktiver Spezies-Layer muss die Masterdatei laden.")
	assert(active_script.contains("single_global_pool"), "Aktiver Spezies-Layer muss den globalen Ein-Pool-Vertrag erzwingen.")
	assert(active_script.contains("pokemon_registry_ready"), "Aktiver Spezies-Layer muss einen Runtime-Readiness-Status besitzen.")

	# Tatsächlicher oberster Kampfpfad: alle neuen Pokémon müssen in Runtime und Kampflabor erreichbar sein.
	var battle = BattleScript.new()
	root.add_child(battle)
	assert(battle.pokemon_registry_ready(), "Globaler Pokémon-Roster wurde nicht als bereit markiert.")
	var runtime_species_value: Variant = battle.data.get("species", {})
	assert(runtime_species_value is Dictionary, "Runtime braucht ein species-Dictionary.")
	var runtime_species: Dictionary = runtime_species_value
	assert(runtime_species.size() == EXPECTED_SPECIES_COUNT, "Runtime muss alle 209 Pokémon enthalten.")
	assert(battle.species_ids.size() == EXPECTED_ROOT_COUNT, "Runtime muss 88 Familienwurzeln verwenden.")
	assert(battle.lab_species_ids.size() == EXPECTED_SPECIES_COUNT, "Kampflabor muss alle 209 Pokémon anbieten.")
	for species_id: String in NEW_SPECIES:
		assert(runtime_species.has(species_id), "Gen-2-Pokémon fehlt in Runtime: " + species_id)
		assert(battle.lab_species_ids.has(species_id), "Gen-2-Pokémon fehlt im Kampflabor: " + species_id)

	print("Global Pokemon pool contract passed: 209 species, 88 families, Gen2 families 01-10 active.")
	battle.queue_free()
	quit(0)


func _read_json(path: String) -> Dictionary:
	assert(not path.to_lower().ends_with(".gz"), "GZIP-Dateien sind im aktiven Datenweg verboten: " + path)
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei konnte nicht gelesen werden: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "JSON konnte nicht gelesen werden: " + path)
	return parsed as Dictionary
