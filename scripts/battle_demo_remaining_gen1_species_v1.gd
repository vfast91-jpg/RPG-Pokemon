extends "res://scripts/battle_demo_struggle_fallback_v1.gd"

# Complete Gen-1-family species registry.
# "Gen 1" means the full evolution families of the original 151: all Kanto
# species plus later-added pre-evolutions/evolutions from the authoritative
# workbook. This layer also loads the move snapshot already declared by the
# v8 manifest; it does not invent move definitions or mechanics beyond it.
# Missing runtime move IDs stay stored in the species source data and are
# filtered by the established runtime until the attack batch implements them.

const REMAINING_GEN1_MANIFEST_PATH: String = "res://data/gen1_database_manifest_v8.json"
const REMAINING_PACK_MAX_BYTES: int = 2_000_000

var _remaining_tm_move_universe: Dictionary = {}


func _load_data() -> void:
	super._load_data()
	_remaining_load_expanded_species_registry()


func _remaining_load_expanded_species_registry() -> void:
	var manifest: Dictionary = _remaining_read_json_dictionary(REMAINING_GEN1_MANIFEST_PATH)
	if manifest.is_empty():
		push_error("Vollständiges Gen-1-Familien-Manifest fehlt: " + REMAINING_GEN1_MANIFEST_PATH)
		return

	var meta_path: String = str(manifest.get("species_meta_file", ""))
	var meta: Dictionary = _remaining_read_json_dictionary(meta_path)
	if meta.is_empty():
		push_error("Vollständige Gen-1-Familien-Metadaten fehlen: " + meta_path)
		return

	var merged_species: Dictionary = {}
	var species_files_value: Variant = manifest.get("species_files", [])
	if not (species_files_value is Array):
		push_error("Gen-1-Familien-Manifest braucht species_files.")
		return

	for path_value: Variant in species_files_value:
		var path: String = str(path_value)
		var pack: Dictionary = _remaining_read_json_dictionary(path)
		var entries_value: Variant = pack.get("species", {})
		if not (entries_value is Dictionary):
			push_error("Pokémon-Datenpaket ist ungültig: " + path)
			return
		for species_id_value: Variant in (entries_value as Dictionary).keys():
			var species_id: String = str(species_id_value)
			var entry_value: Variant = (entries_value as Dictionary).get(species_id_value, {})
			if entry_value is Dictionary:
				merged_species[species_id] = _remaining_sanitize_species_source(entry_value as Dictionary)

	var runtime_species: Dictionary = {}
	for species_id_value: Variant in merged_species.keys():
		var species_id: String = str(species_id_value)
		var source_value: Variant = merged_species.get(species_id_value, {})
		if source_value is Dictionary:
			runtime_species[species_id] = _canonical_species_runtime(source_value as Dictionary)

	# The inherited canonical database still starts from the older v3 manifest.
	# Merge the v8 move files here so the manifest's move_count actually describes
	# what this top-level registry loaded. Runtime-only system moves (notably
	# Verzweifler) are preserved and therefore deliberately excluded from the
	# manifest count audit below.
	var manifest_moves: Dictionary = {}
	var move_files_value: Variant = manifest.get("move_files", [])
	if not (move_files_value is Array):
		push_error("Gen-1-Familien-Manifest braucht move_files.")
		return

	for path_value: Variant in move_files_value:
		var path: String = str(path_value)
		var pack: Dictionary = _remaining_read_json_dictionary(path)
		var entries_value: Variant = pack.get("moves", {})
		if not (entries_value is Dictionary):
			push_error("Attacken-Datenpaket ist ungültig: " + path)
			return
		for move_id_value: Variant in (entries_value as Dictionary).keys():
			var move_id: String = str(move_id_value)
			var entry_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
			if entry_value is Dictionary:
				manifest_moves[move_id] = (entry_value as Dictionary).duplicate(true)

	var runtime_moves_value: Variant = data.get("moves", {})
	var runtime_moves: Dictionary = (
		(runtime_moves_value as Dictionary).duplicate(true)
		if runtime_moves_value is Dictionary
		else {}
	)
	var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
	var canonical_moves: Dictionary = (
		(canonical_moves_value as Dictionary).duplicate(true)
		if canonical_moves_value is Dictionary
		else {}
	)

	for move_id_value: Variant in manifest_moves.keys():
		var move_id: String = str(move_id_value)
		var move_value: Variant = manifest_moves.get(move_id_value, {})
		if move_value is Dictionary:
			var move_copy: Dictionary = (move_value as Dictionary).duplicate(true)
			runtime_moves[move_id] = move_copy.duplicate(true)
			canonical_moves[move_id] = move_copy

	# Keep runtime-only entries that an inherited layer intentionally mirrored
	# only into data["moves"].
	for move_id_value: Variant in runtime_moves.keys():
		var move_id: String = str(move_id_value)
		if not canonical_moves.has(move_id):
			var move_value: Variant = runtime_moves.get(move_id_value, {})
			if move_value is Dictionary:
				canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)

	_canonical_pack = meta.duplicate(true)
	_canonical_pack["species"] = merged_species
	_canonical_pack["moves"] = canonical_moves
	_canonical_pack["manifest"] = manifest.duplicate(true)

	data["species"] = runtime_species
	data["moves"] = runtime_moves

	var roots_value: Variant = meta.get("route_roots", [])
	species_ids = (roots_value as Array).duplicate() if roots_value is Array else []
	data["species_order"] = species_ids.duplicate()

	# The route continues to use one root per complete family, while the combat
	# lab can directly select every registered form for testing.
	lab_species_ids = merged_species.keys()
	_remaining_rebuild_tm_move_universe()

	if runtime_species.size() != int(manifest.get("species_count", runtime_species.size())):
		push_error("Gen-1-Familien-Datenbank: Pokémon-Anzahl stimmt nicht mit Manifest überein.")
	if manifest_moves.size() != int(manifest.get("move_count", manifest_moves.size())):
		push_error("Gen-1-Familien-Datenbank: Attackenzahl stimmt nicht mit Manifest überein.")
	if species_ids.size() != int(manifest.get("route_root_count", species_ids.size())):
		push_error("Gen-1-Familien-Datenbank: Familienanzahl stimmt nicht mit Manifest überein.")

	_audit_canonical_database()


func _remaining_read_json_dictionary(path: String) -> Dictionary:
	if path.is_empty():
		return {}

	var text: String = ""
	if path.ends_with(".gz"):
		var compressed: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if compressed.size() < 18:
			push_error("GZIP-Datenpaket ist leer oder zu kurz: " + path)
			return {}

		# Standard-GZIP stores the uncompressed byte size (ISIZE) in the final
		# four little-endian bytes. Supplying that exact size avoids Godot's
		# dynamic decompressor path that failed on the externally generated packs.
		var expected_size: int = compressed.decode_u32(compressed.size() - 4)
		if expected_size <= 0 or expected_size > REMAINING_PACK_MAX_BYTES:
			push_error("GZIP-Datenpaket meldet eine ungültige Entpackgröße: " + path)
			return {}

		var raw: PackedByteArray = compressed.decompress(
			expected_size,
			FileAccess.COMPRESSION_GZIP
		)
		if raw.size() != expected_size:
			push_error("GZIP-Datenpaket konnte nicht vollständig entpackt werden: " + path)
			return {}
		text = raw.get_string_from_utf8()
	else:
		text = FileAccess.get_file_as_string(path)

	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _remaining_sanitize_species_source(source: Dictionary) -> Dictionary:
	var sanitized: Dictionary = source.duplicate(true)

	# Some spreadsheet exports serialize an empty secondary type as the literal
	# string "<null>". It is not a Pokémon type and must never reach TypeSystem.
	var types_value: Variant = sanitized.get("types", {})
	if types_value is Dictionary:
		var types: Dictionary = (types_value as Dictionary).duplicate(true)
		var type_keys: Array[String] = ["primary", "secondary"]
		for type_key: String in type_keys:
			var type_value: Variant = types.get(type_key, "")
			if type_value == null:
				types[type_key] = ""
				continue
			var normalized_type: String = str(type_value).strip_edges().to_lower()
			if normalized_type == "null" or normalized_type == "<null>":
				types[type_key] = ""
		sanitized["types"] = types

	# Non-level evolutions legitimately have no numeric evolution_level. Older
	# family traversal calls int() on this field, so normalize only the missing /
	# non-numeric representation to 0 (= no automatic level evolution) instead of
	# inventing a trigger.
	var evolution_value: Variant = sanitized.get("evolution", {})
	if evolution_value is Dictionary:
		var evolution: Dictionary = (evolution_value as Dictionary).duplicate(true)
		var level_value: Variant = evolution.get("evolution_level", 0)
		if level_value is int or level_value is float:
			evolution["evolution_level"] = int(level_value)
		elif level_value is String:
			var level_text: String = (level_value as String).strip_edges()
			evolution["evolution_level"] = int(level_text) if level_text.is_valid_int() else 0
		else:
			evolution["evolution_level"] = 0
		sanitized["evolution"] = evolution

	return sanitized


func _canonical_species_runtime(source: Dictionary) -> Dictionary:
	var result: Dictionary = super._canonical_species_runtime(source)
	var evolution_value: Variant = source.get("evolution", {})
	if not (evolution_value is Dictionary):
		return result

	var evolution: Dictionary = evolution_value
	var evolves_into_value: Variant = evolution.get("evolves_into", "")
	if evolution.has("choices") or evolves_into_value is Array:
		# Branches must stay structured. Converting the array to String would
		# silently destroy the explicit player-choice information.
		result["evolution"] = evolution.duplicate(true)
	return result


func _database_family_root(species_id: String) -> String:
	if species_id.is_empty():
		return ""

	var family_members_value: Variant = _canonical_pack.get("family_members", {})
	if family_members_value is Dictionary:
		var family_members: Dictionary = family_members_value
		for root_value: Variant in species_ids:
			var root_id: String = str(root_value)
			var members_value: Variant = family_members.get(root_id, [])
			if members_value is Array and (members_value as Array).has(species_id):
				return root_id

	return super._database_family_root(species_id)


func _remaining_rebuild_tm_move_universe() -> void:
	_remaining_tm_move_universe.clear()
	var species_value: Variant = _canonical_pack.get("species", {})
	if not (species_value is Dictionary):
		return

	for entry_value: Variant in (species_value as Dictionary).values():
		if not (entry_value is Dictionary):
			continue
		var learnset_value: Variant = (entry_value as Dictionary).get("learnset", {})
		if not (learnset_value is Dictionary):
			continue
		var tm_value: Variant = (learnset_value as Dictionary).get("tm_hm", [])
		if tm_value is Dictionary:
			for move_value: Variant in (tm_value as Dictionary).values():
				var move_id: String = str(move_value)
				if not move_id.is_empty() and move_id != "tera_blast":
					_remaining_tm_move_universe[move_id] = true
		elif tm_value is Array:
			for move_value: Variant in tm_value:
				var move_id: String = str(move_value)
				if not move_id.is_empty() and move_id != "tera_blast":
					_remaining_tm_move_universe[move_id] = true


func species_can_receive_tm_move(species_id: String, move_id: String) -> bool:
	if species_id.is_empty() or move_id.is_empty() or move_id == "tera_blast":
		return false

	var species_value: Variant = _canonical_pack.get("species", {})
	if not (species_value is Dictionary):
		return false
	var entry_value: Variant = (species_value as Dictionary).get(species_id, {})
	if not (entry_value is Dictionary):
		return false

	var learnset_value: Variant = (entry_value as Dictionary).get("learnset", {})
	if not (learnset_value is Dictionary):
		return false
	var learnset: Dictionary = learnset_value

	if str(learnset.get("tm_rule", "")) == "all_gen9_tm_minus_tera":
		return _remaining_tm_move_universe.has(move_id)

	var tm_value: Variant = learnset.get("tm_hm", [])
	if tm_value is Dictionary:
		return (tm_value as Dictionary).values().has(move_id)
	if tm_value is Array:
		return (tm_value as Array).has(move_id)
	return false


func _lab_available_tm_moves(species_id: String) -> Array:
	var species_value: Variant = data.get("species", {})
	if not (species_value is Dictionary):
		return []

	var entry_value: Variant = (species_value as Dictionary).get(species_id, {})
	if not (entry_value is Dictionary):
		return []
	var learnset_value: Variant = (entry_value as Dictionary).get("source_learnset", {})
	if not (learnset_value is Dictionary):
		return []
	var learnset: Dictionary = learnset_value

	if str(learnset.get("tm_rule", "")) == "all_gen9_tm_minus_tera":
		var all_tm_candidates: Array = []
		for move_id_value: Variant in _remaining_tm_move_universe.keys():
			var move_id: String = str(move_id_value)
			if _runtime_has_move(move_id) and not all_tm_candidates.has(move_id):
				all_tm_candidates.append(move_id)
		return _database_normal_battle_moves(all_tm_candidates)

	var tm_value: Variant = learnset.get("tm_hm", {})
	if tm_value is Dictionary:
		return super._lab_available_tm_moves(species_id)
	if not (tm_value is Array):
		return []

	var candidates: Array = []
	for move_value: Variant in tm_value:
		var move_id: String = str(move_value)
		if move_id.is_empty() or move_id == "tera_blast" or candidates.has(move_id):
			continue
		# Species compatibility may exist before the attack itself does.
		# Only already implemented runtime moves become selectable.
		if _runtime_has_move(move_id):
			candidates.append(move_id)

	return _database_normal_battle_moves(candidates)
