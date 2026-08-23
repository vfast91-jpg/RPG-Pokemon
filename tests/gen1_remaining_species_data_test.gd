extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v8.json"
const EVOLUTION_PATH: String = "res://data/rules/evolution_chains.json"
const ACTIVE_SCRIPT_PATH: String = "res://scripts/battle_demo_remaining_gen1_species_v1.gd"
const EXPECTED_MASTER_PATH: String = "res://data/gen1_species_roster_master_v8.json"

const LATER_FAMILY_MEMBERS: Array[String] = ["crobat", "pichu", "cleffa", "igglybuff", "bellossom", "politoed", "espeon", "umbreon", "slowking", "steelix", "scizor", "kingdra", "porygon2", "tyrogue", "hitmontop", "smoochum", "elekid", "magby", "blissey", "mime-jr", "happiny", "munchlax", "magnezone", "lickilicky", "rhyperior", "tangrowth", "electivire", "magmortar", "leafeon", "glaceon", "porygon-z", "sylveon", "kleavor", "annihilape"]
const LATE_SENTINELS: Array[String] = ["lapras", "snorlax", "articuno", "zapdos", "moltres", "dragonite", "mewtwo", "mew"]


func _initialize() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(not manifest.is_empty(), "V8-Manifest muss lesbar sein.")
	assert(int(manifest.get("species_count", -1)) == 185, "V8 muss 185 registrierte Spezies enthalten.")
	assert(int(manifest.get("move_count", -1)) == 313, "Das Manifest muss weiterhin 313 bekannte Attackendefinitionen deklarieren.")
	assert(int(manifest.get("route_root_count", -1)) == 78, "Es müssen 78 vollständige Familienwurzeln registriert sein.")

	var master_path: String = str(manifest.get("species_master_file", ""))
	assert(master_path == EXPECTED_MASTER_PATH, "Der vollständige Roster muss genau eine feste Masterdatei verwenden.")
	var species_files_value: Variant = manifest.get("species_files", [])
	assert(species_files_value is Array, "species_files muss eine Liste sein.")
	var species_files: Array = species_files_value
	assert(species_files.size() == 1, "Roster-Mitgliedschaft darf nur aus einer einzigen Masterdatei stammen.")
	assert(str(species_files[0]) == master_path, "species_files muss exakt auf die Masterdatei verweisen.")

	for list_key: String in ["species_files", "species_detail_files", "move_files"]:
		var paths_value: Variant = manifest.get(list_key, [])
		assert(paths_value is Array, list_key + " muss eine Liste sein.")
		for path_value: Variant in paths_value:
			assert(not str(path_value).to_lower().ends_with(".gz"), "Aktiver V8-Datenpfad darf kein GZIP mehr enthalten: " + str(path_value))

	var meta: Dictionary = _read_json(str(manifest.get("species_meta_file", "")))
	assert(not meta.is_empty(), "V8-Metadaten müssen lesbar sein.")

	var master_pack: Dictionary = _read_json(master_path)
	var master_species_value: Variant = master_pack.get("species", {})
	assert(master_species_value is Dictionary, "Masterdatei muss ein species-Dictionary enthalten.")
	var master_species: Dictionary = master_species_value
	assert(master_species.size() == 185, "Die eine Masterdatei muss exakt 185 Pokémon enthalten.")

	# All original 151 must be present exactly once in the one master.
	var original_dex_seen: Dictionary = {}
	for species_value: Variant in master_species.values():
		assert(species_value is Dictionary, "Jeder Mastereintrag muss ein Dictionary sein.")
		var species: Dictionary = species_value
		var dex_number: int = int(species.get("pokedex_number", 0))
		if dex_number >= 1 and dex_number <= 151:
			assert(not original_dex_seen.has(dex_number), "Doppelte Original-Pokédex-Nummer: " + str(dex_number))
			original_dex_seen[dex_number] = true
	assert(original_dex_seen.size() == 151, "Alle ursprünglichen 151 Pokémon müssen in der einen Masterdatei vorhanden sein.")
	for dex_number: int in range(1, 152):
		assert(original_dex_seen.has(dex_number), "Original-Pokédex-Nummer fehlt: " + str(dex_number))

	assert(LATER_FAMILY_MEMBERS.size() == 34, "Die Quelle muss 34 spätere Familienmitglieder enthalten.")
	for species_id: String in LATER_FAMILY_MEMBERS:
		assert(master_species.has(species_id), "Späteres Familienmitglied fehlt im Master: " + species_id)
	for species_id: String in LATE_SENTINELS:
		assert(master_species.has(species_id), "Spätes/legendäres Pflicht-Pokémon fehlt im Master: " + species_id)

	# Detail files are optional for availability but should currently enrich the
	# master with the approved source learnsets/TMs. Merge them without letting
	# them create new roster identities.
	var detailed_species: Dictionary = master_species.duplicate(true)
	for path_value: Variant in manifest.get("species_detail_files", []):
		var path: String = str(path_value)
		var pack: Dictionary = _read_json(path)
		var entries_value: Variant = pack.get("species", {})
		assert(entries_value is Dictionary, "Ungültiges Spezies-Detailpaket: " + path)
		for species_id_value: Variant in (entries_value as Dictionary).keys():
			var species_id: String = str(species_id_value)
			assert(master_species.has(species_id), "Detailpaket darf keine neue Roster-ID einführen: " + species_id)
			var detail_value: Variant = (entries_value as Dictionary).get(species_id_value, {})
			if detail_value is Dictionary:
				detailed_species[species_id] = _merge_top_level(
					detailed_species.get(species_id, {}) as Dictionary,
					detail_value as Dictionary
				)
	assert(detailed_species.size() == 185, "Detailanreicherung darf die Rostergröße niemals verändern.")

	var crobat: Dictionary = detailed_species.get("crobat", {})
	assert(int(crobat.get("pokedex_number", 0)) == 169, "Iksbat muss als #169 registriert sein.")
	var crobat_stats: Dictionary = crobat.get("base_stats", {})
	assert(int(crobat_stats.get("hp", 0)) == 85, "Iksbat-KP müssen aus der Quelle übernommen werden.")
	assert(int(crobat_stats.get("speed", 0)) == 130, "Iksbat-Geschwindigkeit muss 130 sein.")
	var crobat_learnset: Dictionary = crobat.get("learnset", {})
	assert((crobat_learnset.get("relearn_lv1", []) as Array).has("poison_fang"), "Iksbat-Relearn-Liste fehlt.")
	assert((crobat_learnset.get("tm_hm", []) as Array).has("protect"), "Iksbat-TM-Liste muss Schutzschild enthalten.")

	var mew: Dictionary = detailed_species.get("mew", {})
	assert(int(mew.get("pokedex_number", 0)) == 151, "Mew muss als #151 registriert sein.")
	var mew_learnset: Dictionary = mew.get("learnset", {})
	assert(str(mew_learnset.get("tm_rule", "")) == "all_gen9_tm_minus_tera", "Mews vollständige TM-Regel muss semantisch erhalten bleiben.")
	assert(not (mew_learnset.get("tm_hm", []) as Array).has("tera_blast"), "Tera-Ausbruch muss bei Mew ausgeschlossen bleiben.")

	var family_members: Dictionary = meta.get("family_members", {})
	_assert_family_members(family_members, "zubat", ["zubat", "golbat", "crobat"])
	_assert_family_members(family_members, "scyther", ["scyther", "scizor", "kleavor"])
	_assert_family_members(family_members, "tyrogue", ["hitmonlee", "hitmonchan", "tyrogue", "hitmontop"])
	_assert_family_members(family_members, "eevee", ["eevee", "vaporeon", "jolteon", "flareon", "espeon", "umbreon", "leafeon", "glaceon", "sylveon"])
	_assert_family_members(family_members, "porygon", ["porygon", "porygon2", "porygon-z"])

	var roots: Array = meta.get("route_roots", [])
	assert(roots.size() == 78, "Metadaten müssen exakt 78 Familienwurzeln besitzen.")
	for root_id: String in ["tyrogue", "smoochum", "elekid", "magby", "happiny", "mime-jr", "munchlax", "mew"]:
		assert(roots.has(root_id), "Vollständige Familienwurzel fehlt: " + root_id)

	var evolutions: Dictionary = _read_json(EVOLUTION_PATH)
	var rules: Dictionary = evolutions.get("level_evolutions", {})
	_assert_evolution(rules, "golbat", "crobat", 40)
	_assert_evolution(rules, "porygon2", "porygon-z", 45)
	_assert_evolution(rules, "smoochum", "jynx", 30)
	_assert_evolution(rules, "elekid", "electabuzz", 30)
	_assert_evolution(rules, "magby", "magmar", 30)
	_assert_evolution(rules, "happiny", "chansey", 20)
	_assert_evolution(rules, "mime-jr", "mr-mime", 32)
	_assert_evolution(rules, "munchlax", "snorlax", 30)
	_assert_branch_rule(rules, "tyrogue", ["hitmonlee", "hitmonchan", "hitmontop"], 20)
	_assert_branch_rule(rules, "eevee", ["vaporeon", "jolteon", "flareon", "espeon", "umbreon", "leafeon", "glaceon", "sylveon"], 30)

	var active_script: String = FileAccess.get_file_as_string(ACTIVE_SCRIPT_PATH)
	assert(active_script.contains("species_master_file"), "Der aktive Spezies-Layer muss die eine Masterdatei laden.")
	assert(active_script.contains("pokemon_registry_ready"), "Der aktive Spezies-Layer muss einen harten Runtime-Readiness-Status besitzen.")
	assert(not active_script.contains("COMPRESSION_GZIP"), "Der aktive Spezies-Layer darf keinen GZIP-Entpacker mehr enthalten.")

	print("Complete Gen1 master registry test passed: one master = 151 originals + 34 later family members = 185 species.")
	quit(0)


func _merge_top_level(base: Dictionary, detail: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key_value: Variant in detail.keys():
		var value: Variant = detail.get(key_value)
		if value is Dictionary:
			result[key_value] = (value as Dictionary).duplicate(true)
		elif value is Array:
			result[key_value] = (value as Array).duplicate(true)
		else:
			result[key_value] = value
	return result


func _assert_family_members(families: Dictionary, root_id: String, expected_members: Array) -> void:
	var members_value: Variant = families.get(root_id, [])
	assert(members_value is Array, "Familienliste fehlt: " + root_id)
	var members: Array = members_value
	for species_id: String in expected_members:
		assert(members.has(species_id), root_id + ": Familienmitglied fehlt: " + species_id)


func _assert_evolution(rules: Dictionary, source_id: String, target_id: String, level: int) -> void:
	var rule_value: Variant = rules.get(source_id, {})
	assert(rule_value is Dictionary, "Entwicklungsregel fehlt: " + source_id)
	var rule: Dictionary = rule_value
	assert(str(rule.get("target", "")) == target_id, source_id + ": falsches Entwicklungsziel.")
	assert(int(rule.get("level", 0)) == level, source_id + ": falsches Entwicklungslevel.")


func _assert_branch_rule(rules: Dictionary, source_id: String, targets: Array, level: int) -> void:
	var rule_value: Variant = rules.get(source_id, {})
	assert(rule_value is Dictionary, "Verzweigte Entwicklungsregel fehlt: " + source_id)
	var choices_value: Variant = (rule_value as Dictionary).get("choices", [])
	assert(choices_value is Array, source_id + ": choices fehlt.")
	var seen: Array[String] = []
	for choice_value: Variant in choices_value:
		assert(choice_value is Dictionary, source_id + ": ungültige choice.")
		var choice: Dictionary = choice_value
		assert(int(choice.get("level", 0)) == level, source_id + ": falsches Wahl-Level.")
		seen.append(str(choice.get("target", "")))
	for target_id: String in targets:
		assert(seen.has(target_id), source_id + ": Entwicklungswahl fehlt: " + target_id)


func _read_json(path: String) -> Dictionary:
	assert(not path.to_lower().ends_with(".gz"), "GZIP-Dateien sind im aktiven V8-Datenweg verboten: " + path)
	var text: String = FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Datei konnte nicht gelesen werden: " + path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "JSON konnte nicht gelesen werden: " + path)
	return parsed as Dictionary
