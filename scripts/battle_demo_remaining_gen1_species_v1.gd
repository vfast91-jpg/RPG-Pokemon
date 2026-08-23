extends "res://scripts/battle_demo_struggle_fallback_v1.gd"

# Final species-only registry layer for the remaining Gen-1 Pokédex.
# Zubat (#041) through Mewtwo (#150) are loaded from the authoritative
# 2026-08-22 Pokémon workbook snapshot. Attack definitions/mechanics are
# intentionally NOT added here; the established runtime filter hides move IDs
# that do not have a runtime definition yet.

const REMAINING_GEN1_MANIFEST_PATH: String = "res://data/gen1_database_manifest_v7.json"
const REMAINING_PACK_MAX_BYTES: int = 2_000_000


func _load_data() -> void:
	super._load_data()
	_remaining_load_expanded_species_registry()


func _remaining_load_expanded_species_registry() -> void:
	var manifest: Dictionary = _remaining_read_json_dictionary(REMAINING_GEN1_MANIFEST_PATH)
	if manifest.is_empty():
		push_error("Erweitertes Gen-1-Datenbank-Manifest fehlt: " + REMAINING_GEN1_MANIFEST_PATH)
		return

	var meta_path: String = str(manifest.get("species_meta_file", ""))
	var meta: Dictionary = _remaining_read_json_dictionary(meta_path)
	if meta.is_empty():
		push_error("Erweiterte Gen-1-Metadaten fehlen: " + meta_path)
		return

	var merged_species: Dictionary = {}
	var species_files_value: Variant = manifest.get("species_files", [])
	if not (species_files_value is Array):
		push_error("Erweitertes Gen-1-Manifest braucht species_files.")
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
				merged_species[species_id] = (entry_value as Dictionary).duplicate(true)

	var runtime_species: Dictionary = {}
	for species_id_value: Variant in merged_species.keys():
		var species_id: String = str(species_id_value)
		var source_value: Variant = merged_species.get(species_id_value, {})
		if source_value is Dictionary:
			runtime_species[species_id] = _canonical_species_runtime(source_value as Dictionary)

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
		else runtime_moves.duplicate(true)
	)

	_canonical_pack = meta.duplicate(true)
	_canonical_pack["species"] = merged_species
	_canonical_pack["moves"] = canonical_moves
	_canonical_pack["manifest"] = manifest.duplicate(true)

	data["species"] = runtime_species
	data["moves"] = runtime_moves

	var roots_value: Variant = meta.get("route_roots", [])
	species_ids = (roots_value as Array).duplicate() if roots_value is Array else []
	data["species_order"] = species_ids.duplicate()
	lab_species_ids = species_ids.duplicate()

	if runtime_species.size() != int(manifest.get("species_count", runtime_species.size())):
		push_error("Erweiterte Gen-1-Datenbank: Pokémon-Anzahl stimmt nicht mit Manifest überein.")
	if runtime_moves.size() != int(manifest.get("move_count", runtime_moves.size())):
		push_error("Erweiterte Gen-1-Datenbank: Attackenzahl wurde unerwartet verändert.")
	if species_ids.size() != int(manifest.get("route_root_count", species_ids.size())):
		push_error("Erweiterte Gen-1-Datenbank: Basislinien-Anzahl stimmt nicht mit Manifest überein.")

	_audit_canonical_database()


func _remaining_read_json_dictionary(path: String) -> Dictionary:
	if path.is_empty():
		return {}

	var text: String = ""
	if path.ends_with(".gz"):
		var compressed: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if compressed.is_empty():
			return {}
		var raw: PackedByteArray = compressed.decompress_dynamic(
			REMAINING_PACK_MAX_BYTES,
			FileAccess.COMPRESSION_GZIP
		)
		if raw.is_empty():
			return {}
		text = raw.get_string_from_utf8()
	else:
		text = FileAccess.get_file_as_string(path)

	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


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

	var tm_value: Variant = (learnset_value as Dictionary).get("tm_hm", {})
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
