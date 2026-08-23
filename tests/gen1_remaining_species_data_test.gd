extends SceneTree

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v7.json"
const ACTIVE_SCENE_PATH: String = "res://main.tscn"
const PACK_MAX_BYTES: int = 2_000_000


func _initialize() -> void:
	var manifest: Dictionary = _read_json(MANIFEST_PATH)
	assert(not manifest.is_empty(), "V7-Manifest muss lesbar sein.")
	assert(int(manifest.get("species_count", -1)) == 153, "V7 muss 153 registrierte Spezies enthalten.")
	assert(int(manifest.get("move_count", -1)) == 313, "Dieser Batch darf keine Attackendefinitionen hinzufügen.")

	var species: Dictionary = {}
	for path_value: Variant in manifest.get("species_files", []):
		var path: String = str(path_value)
		var pack: Dictionary = _read_json(path)
		var entries_value: Variant = pack.get("species", {})
		assert(entries_value is Dictionary, "Ungültiges Speziespaket: " + path)
		for species_id_value: Variant in (entries_value as Dictionary).keys():
			species[str(species_id_value)] = (entries_value as Dictionary)[species_id_value]

	assert(species.size() == 153, "Zusammengeführte V7-Spezieszahl muss 153 sein.")
	assert(species.has("zubat"), "Zubat (#041) fehlt.")
	assert(species.has("mewtwo"), "Mewtu (#150) fehlt.")
	assert(not species.has("mew"), "Mew (#151) gehört nicht zu diesem Batch.")

	var dex_seen: Dictionary = {}
	var remaining_count: int = 0
	for species_value: Variant in species.values():
		if not (species_value is Dictionary):
			continue
		var entry: Dictionary = species_value
		var dex_number: int = int(entry.get("dex_number", 0))
		if dex_number < 41 or dex_number > 150:
			continue

		remaining_count += 1
		assert(not dex_seen.has(dex_number), "Doppelte Pokédex-Nummer im Bereich 041-150: " + str(dex_number))
		dex_seen[dex_number] = true
		_assert_species_move_references(entry)

	assert(remaining_count == 110, "Es müssen exakt 110 Spezies von #041 bis #150 vorhanden sein.")
	for dex_number: int in range(41, 151):
		assert(dex_seen.has(dex_number), "Pokédex-Nummer fehlt: " + str(dex_number))

	var zubat: Dictionary = species["zubat"]
	var zubat_level_up: Dictionary = (zubat.get("learnset", {}) as Dictionary).get("level_up", {})
	assert((zubat_level_up.get("1", []) as Array).has("absorb"), "Zubat muss Absorber auf Lv. 1 referenzieren.")
	assert((zubat_level_up.get("1", []) as Array).has("supersonic"), "Zubat muss Superschall auf Lv. 1 referenzieren.")
	assert(((zubat.get("learnset", {}) as Dictionary).get("tm_hm", []) as Array).has("protect"), "Zubats TM-Liste muss Schutzschild enthalten.")

	var mewtwo: Dictionary = species["mewtwo"]
	var mewtwo_level_up: Dictionary = (mewtwo.get("learnset", {}) as Dictionary).get("level_up", {})
	assert((mewtwo_level_up.get("72", []) as Array).has("psystrike"), "Mewtu muss Psychostoß auf Lv. 72 referenzieren.")

	_assert_branch_count(species, "gloom", 2)
	_assert_branch_count(species, "poliwhirl", 2)
	_assert_branch_count(species, "slowpoke", 2)
	_assert_branch_count(species, "eevee", 8)

	var scene_text: String = FileAccess.get_file_as_string(ACTIVE_SCENE_PATH)
	assert(
		scene_text.contains("battle_demo_remaining_gen1_species_v1.gd"),
		"Der neue Spezies-Layer muss im aktiven main.tscn verdrahtet sein."
	)

	print("Remaining Gen1 species data test passed: Zubat #041 through Mewtwo #150.")
	quit(0)


func _assert_species_move_references(entry: Dictionary) -> void:
	var species_id: String = str(entry.get("species_id", ""))
	var learnset_value: Variant = entry.get("learnset", {})
	assert(learnset_value is Dictionary, species_id + ": Lernliste fehlt.")
	var learnset: Dictionary = learnset_value

	var level_up_value: Variant = learnset.get("level_up", {})
	assert(level_up_value is Dictionary, species_id + ": Level-Up-Lernliste muss ein Dictionary sein.")
	for moves_value: Variant in (level_up_value as Dictionary).values():
		assert(moves_value is Array, species_id + ": Level-Up-Eintrag muss eine Liste sein.")
		for move_value: Variant in moves_value:
			assert(not str(move_value).is_empty(), species_id + ": Leere Level-Up-Attacken-ID.")

	var relearn_value: Variant = learnset.get("relearn_lv1", [])
	assert(relearn_value is Array, species_id + ": RELEARN/Lv1 muss eine Liste sein.")
	for move_value: Variant in relearn_value:
		assert(not str(move_value).is_empty(), species_id + ": Leere RELEARN/Lv1-Attacken-ID.")

	var tm_value: Variant = learnset.get("tm_hm", [])
	assert(tm_value is Array, species_id + ": Neue TM-Liste muss als Attacken-ID-Liste gespeichert sein.")
	for move_value: Variant in tm_value:
		var move_id: String = str(move_value)
		assert(not move_id.is_empty(), species_id + ": Leere TM-Attacken-ID.")
		assert(move_id != "tera_blast", species_id + ": Tera-Ausbruch muss ausgeschlossen bleiben.")


func _assert_branch_count(species: Dictionary, species_id: String, expected: int) -> void:
	var entry: Dictionary = species.get(species_id, {})
	var evolution: Dictionary = entry.get("evolution", {})
	var choices_value: Variant = evolution.get("choices", [])
	assert(choices_value is Array, species_id + ": Verzweigte Entwicklung muss choices besitzen.")
	assert((choices_value as Array).size() == expected, species_id + ": Falsche Anzahl Entwicklungsoptionen.")


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
