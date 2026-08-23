extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v8.json"
const EVOLUTION_PATH: String = "res://data/rules/evolution_chains.json"
const ACTIVE_SCRIPT_PATH: String = "res://scripts/battle_demo_remaining_gen1_species_v1.gd"
const PACK_MAX_BYTES: int = 2_000_000

const LATER_FAMILY_MEMBERS: Array[String] = ["crobat", "pichu", "cleffa", "igglybuff", "bellossom", "politoed", "espeon", "umbreon", "slowking", "steelix", "scizor", "kingdra", "porygon2", "tyrogue", "hitmontop", "smoochum", "elekid", "magby", "blissey", "mime-jr", "happiny", "munchlax", "magnezone", "lickilicky", "rhyperior", "tangrowth", "electivire", "magmortar", "leafeon", "glaceon", "porygon-z", "sylveon", "kleavor", "annihilape"]
const ADDED_BY_CORRECTION: Array[String] = ["mew", "crobat", "bellossom", "politoed", "espeon", "umbreon", "slowking", "steelix", "scizor", "kingdra", "porygon2", "tyrogue", "hitmontop", "smoochum", "elekid", "magby", "blissey", "mime-jr", "happiny", "munchlax", "magnezone", "lickilicky", "rhyperior", "tangrowth", "electivire", "magmortar", "leafeon", "glaceon", "porygon-z", "sylveon", "kleavor", "annihilape"]


func _initialize() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(not manifest.is_empty(), "V8-Manifest muss lesbar sein.")
	assert(int(manifest.get("species_count", -1)) == 185, "V8 muss 185 registrierte Spezies enthalten.")
	assert(int(manifest.get("move_count", -1)) == 313, "Dieser Batch darf keine Attackendefinitionen hinzufügen.")
	assert(int(manifest.get("route_root_count", -1)) == 78, "Es müssen 78 vollständige Familienwurzeln registriert sein.")

	var meta: Dictionary = _read_json(str(manifest.get("species_meta_file", "")))
	assert(not meta.is_empty(), "V8-Metadaten müssen lesbar sein.")

	var species: Dictionary = {}
	for path_value: Variant in manifest.get("species_files", []):
		var path: String = str(path_value)
		var pack: Dictionary = _read_json(path)
		var entries_value: Variant = pack.get("species", {})
		assert(entries_value is Dictionary, "Ungültiges Speziespaket: " + path)
		for species_id_value: Variant in (entries_value as Dictionary).keys():
			species[str(species_id_value)] = (entries_value as Dictionary)[species_id_value]

	assert(species.size() == 185, "Zusammengeführte V8-Spezieszahl muss 185 sein.")

	# Alle ursprünglichen 151 müssen lückenlos vorhanden sein.
	var original_dex_seen: Dictionary = {}
	for species_value: Variant in species.values():
		if not (species_value is Dictionary):
			continue
		var dex_number: int = int((species_value as Dictionary).get("dex_number", 0))
		if dex_number >= 1 and dex_number <= 151:
			assert(not original_dex_seen.has(dex_number), "Doppelte Original-Pokédex-Nummer: " + str(dex_number))
			original_dex_seen[dex_number] = true
	assert(original_dex_seen.size() == 151, "Alle ursprünglichen 151 Pokémon müssen vorhanden sein.")
	for dex_number: int in range(1, 152):
		assert(original_dex_seen.has(dex_number), "Original-Pokédex-Nummer fehlt: " + str(dex_number))

	# Alle 34 später ergänzten Vor-/Weiterentwicklungen müssen ebenfalls existieren.
	assert(LATER_FAMILY_MEMBERS.size() == 34, "Die Quelle muss 34 spätere Familienmitglieder enthalten.")
	for species_id: String in LATER_FAMILY_MEMBERS:
		assert(species.has(species_id), "Späteres Familienmitglied fehlt: " + species_id)
	assert(ADDED_BY_CORRECTION.size() == 32, "Diese Korrektur muss 32 zuvor fehlende Spezies hinzufügen.")

	var crobat: Dictionary = species.get("crobat", {})
	assert(int(crobat.get("dex_number", 0)) == 169, "Iksbat muss als #169 registriert sein.")
	assert(str(crobat.get("family_id", "")) == "zubat", "Iksbat muss zur Zubat-Familie gehören.")
	var crobat_stats: Dictionary = crobat.get("base_stats", {})
	assert(int(crobat_stats.get("hp", 0)) == 85, "Iksbat-KP müssen aus der Quelle übernommen werden.")
	assert(int(crobat_stats.get("speed", 0)) == 130, "Iksbat-Geschwindigkeit muss 130 sein.")
	var crobat_learnset: Dictionary = crobat.get("learnset", {})
	assert((crobat_learnset.get("relearn_lv1", []) as Array).has("poison_fang"), "Iksbat-Relearn-Liste fehlt.")
	assert((crobat_learnset.get("tm_hm", []) as Array).has("protect"), "Iksbat-TM-Liste muss Schutzschild enthalten.")

	var mew: Dictionary = species.get("mew", {})
	assert(int(mew.get("dex_number", 0)) == 151, "Mew muss als #151 registriert sein.")
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
	for root_id: String in ["tyrogue", "smoochum", "elekid", "magby", "happiny", "mime-jr", "munchlax", "mew"]:
		assert(roots.has(root_id), "Vollständige Familienwurzel fehlt: " + root_id)
	for obsolete_root: String in ["hitmonlee", "hitmonchan", "jynx", "electabuzz", "magmar", "chansey", "mr-mime", "snorlax"]:
		assert(not roots.has(obsolete_root), "Spätere Vorentwicklung muss Familienwurzel ersetzen: " + obsolete_root)

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
	assert(active_script.contains("gen1_database_manifest_v8.json"), "Der aktive Spezies-Layer muss V8 laden.")
	assert(active_script.contains("family_members"), "Der aktive Spezies-Layer muss vollständige Familienzuordnung verwenden.")
	assert(active_script.contains("all_gen9_tm_minus_tera"), "Der aktive Spezies-Layer muss Mews semantische TM-Regel verstehen.")

	print("Complete Gen1 family registry test passed: 151 originals + 34 later family members = 185 species.")
	quit(0)


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
	var text: String = ""
	if path.ends_with(".gz"):
		var compressed: PackedByteArray = FileAccess.get_file_as_bytes(path)
		assert(not compressed.is_empty(), "Komprimierte Datei konnte nicht geöffnet werden: " + path)
		var raw: PackedByteArray = compressed.decompress_dynamic(PACK_MAX_BYTES, FileAccess.COMPRESSION_GZIP)
		assert(not raw.is_empty(), "GZIP-Daten konnten nicht entpackt werden: " + path)
		text = raw.get_string_from_utf8()
	else:
		text = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "JSON konnte nicht gelesen werden: " + path)
	return parsed as Dictionary
