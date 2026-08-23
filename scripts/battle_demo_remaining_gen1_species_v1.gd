extends "res://scripts/battle_demo_struggle_fallback_v1.gd"

# Complete Gen-1-family species registry.
# Availability is a global data contract: the game either loads the complete
# 185-Pokemon / 78-family roster or exposes no Pokemon roster at all. Missing
# or deferred attacks never remove a Pokemon; the global Verzweifler fallback
# handles combat until those attacks are implemented.

const REMAINING_GEN1_MANIFEST_PATH: String = "res://data/gen1_database_manifest_v8.json"
const REMAINING_EXPECTED_SPECIES_COUNT: int = 185
const REMAINING_EXPECTED_ROUTE_ROOT_COUNT: int = 78
const REMAINING_SENTINEL_SPECIES: Array[String] = [
	"lapras",
	"snorlax",
	"articuno",
	"zapdos",
	"moltres",
	"dragonite",
	"mewtwo",
	"mew",
	"annihilape",
	"sylveon"
]

var _remaining_tm_move_universe: Dictionary = {}
var _remaining_registry_ready: bool = false


func _load_data() -> void:
	super._load_data()
	_remaining_load_expanded_species_registry()


func pokemon_registry_ready() -> bool:
	return _remaining_registry_ready


func _remaining_load_expanded_species_registry() -> void:
	_remaining_registry_ready = false

	var manifest: Dictionary = _remaining_read_json_dictionary(REMAINING_GEN1_MANIFEST_PATH)
	if manifest.is_empty():
		_remaining_fail_registry(
			"Vollständiges Gen-1-Familien-Manifest fehlt: " + REMAINING_GEN1_MANIFEST_PATH
		)
		return

	if int(manifest.get("species_count", -1)) != REMAINING_EXPECTED_SPECIES_COUNT:
		_remaining_fail_registry(
			"Gen-1-Familien-Manifest muss exakt %d Pokémon deklarieren."
			% REMAINING_EXPECTED_SPECIES_COUNT
		)
		return
	if int(manifest.get("route_root_count", -1)) != REMAINING_EXPECTED_ROUTE_ROOT_COUNT:
		_remaining_fail_registry(
			"Gen-1-Familien-Manifest muss exakt %d Familien deklarieren."
			% REMAINING_EXPECTED_ROUTE_ROOT_COUNT
		)
		return

	var meta_path: String = str(manifest.get("species_meta_file", ""))
	var meta: Dictionary = _remaining_read_json_dictionary(meta_path)
	if meta.is_empty():
		_remaining_fail_registry("Vollständige Gen-1-Familien-Metadaten fehlen: " + meta_path)
		return

	var merged_species: Dictionary = {}
	var species_files_value: Variant = manifest.get("species_files", [])
	if not (species_files_value is Array) or (species_files_value as Array).is_empty():
		_remaining_fail_registry("Gen-1-Familien-Manifest braucht mindestens eine species_files-Quelle.")
		return

	for path_value: Variant in species_files_value:
		var path: String = str(path_value)
		if path.to_lower().ends_with(".gz"):
			_remaining_fail_registry(
				"Komprimierte Pokémon-Datenpakete sind im aktiven Roster nicht mehr erlaubt: " + path
			)
			return
		var pack: Dictionary = _remaining_read_json_dictionary(path)
		var entries_value: Variant = pack.get("species", {})
		if not (entries_value is Dictionary):
			_remaining_fail_registry("Pokémon-Datenpaket ist ungültig: " + path)
			return
		for species_id_value: Variant in (entries_value as Dictionary).keys():
			var species_id: String = str(species_id_value)
			var entry_value: Variant = (entries_value as Dictionary).get(species_id_value, {})
			if not (entry_value is Dictionary):
				_remaining_fail_registry(
					"Pokémon-Datensatz ist ungültig: %s in %s" % [species_id, path]
				)
				return
			merged_species[species_id] = _remaining_sanitize_species_source(
				entry_value as Dictionary
			)

	var runtime_species: Dictionary = {}
	for species_id_value: Variant in merged_species.keys():
		var species_id: String = str(species_id_value)
		var source_value: Variant = merged_species.get(species_id_value, {})
		if source_value is Dictionary:
			runtime_species[species_id] = _canonical_species_runtime(source_value as Dictionary)

	var contract_error: String = _remaining_validate_species_contract(
		manifest,
		meta,
		merged_species,
		runtime_species
	)
	if not contract_error.is_empty():
		_remaining_fail_registry(contract_error)
		return

	# The inherited canonical database still starts from the older v3 manifest.
	# Merge the complete v8 move snapshot here. Runtime-only system moves such as
	# Verzweifler stay preserved but are deliberately excluded from manifest count.
	var manifest_moves: Dictionary = {}
	var move_files_value: Variant = manifest.get("move_files", [])
	if not (move_files_value is Array) or (move_files_value as Array).is_empty():
		_remaining_fail_registry("Gen-1-Familien-Manifest braucht move_files.")
		return

	for path_value: Variant in move_files_value:
		var path: String = str(path_value)
		if path.to_lower().ends_with(".gz"):
			_remaining_fail_registry(
				"Komprimierte Attacken-Datenpakete sind nicht erlaubt: " + path
			)
			return
		var pack: Dictionary = _remaining_read_json_dictionary(path)
		var entries_value: Variant = pack.get("moves", {})
		if not (entries_value is Dictionary):
			_remaining_fail_registry("Attacken-Datenpaket ist ungültig: " + path)
			return
		for move_id_value: Variant in (entries_value as Dictionary).keys():
			var move_id: String = str(move_id_value)
			var entry_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
			if entry_value is Dictionary:
				manifest_moves[move_id] = (entry_value as Dictionary).duplicate(true)

	var expected_move_count: int = int(manifest.get("move_count", -1))
	if expected_move_count < 0 or manifest_moves.size() != expected_move_count:
		_remaining_fail_registry(
			"Gen-1-Familien-Datenbank: Attackenzahl stimmt nicht mit Manifest überein: %d/%d."
			% [manifest_moves.size(), expected_move_count]
		)
		return

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

	# Publish only after every species/family/move contract has succeeded. There
	# is intentionally no fallback to the inherited partial roster.
	_canonical_pack = meta.duplicate(true)
	_canonical_pack["species"] = merged_species
	_canonical_pack["moves"] = canonical_moves
	_canonical_pack["manifest"] = manifest.duplicate(true)

	data["species"] = runtime_species
	data["moves"] = runtime_moves

	var roots_value: Variant = meta.get("route_roots", [])
	species_ids = (roots_value as Array).duplicate()
	data["species_order"] = species_ids.duplicate()
	lab_species_ids = merged_species.keys()
	_remaining_rebuild_tm_move_universe()

	_remaining_registry_ready = true
	print(
		"Pokémon-Datenbank OK: %d Pokémon · %d Familien"
		% [runtime_species.size(), species_ids.size()]
	)
	_audit_canonical_database()


func _remaining_validate_species_contract(
	manifest: Dictionary,
	meta: Dictionary,
	merged_species: Dictionary,
	runtime_species: Dictionary
) -> String:
	if merged_species.size() != REMAINING_EXPECTED_SPECIES_COUNT:
		return (
			"Gen-1-Familien-Datenbank unvollständig: %d/%d Pokémon in den Quelldaten."
			% [merged_species.size(), REMAINING_EXPECTED_SPECIES_COUNT]
		)
	if runtime_species.size() != REMAINING_EXPECTED_SPECIES_COUNT:
		return (
			"Gen-1-Familien-Datenbank unvollständig: %d/%d Pokémon in der Runtime."
			% [runtime_species.size(), REMAINING_EXPECTED_SPECIES_COUNT]
		)

	var roots_value: Variant = meta.get("route_roots", [])
	if not (roots_value is Array):
		return "Gen-1-Familien-Metadaten besitzen keine route_roots-Liste."
	var roots: Array = roots_value
	if roots.size() != REMAINING_EXPECTED_ROUTE_ROOT_COUNT:
		return (
			"Gen-1-Familien-Datenbank unvollständig: %d/%d Familien."
			% [roots.size(), REMAINING_EXPECTED_ROUTE_ROOT_COUNT]
		)

	var seen_roots: Dictionary = {}
	for root_value: Variant in roots:
		var root_id: String = str(root_value)
		if root_id.is_empty() or seen_roots.has(root_id):
			return "Gen-1-Familien-Metadaten enthalten eine leere oder doppelte Familienwurzel."
		seen_roots[root_id] = true
		if not merged_species.has(root_id):
			return "Familienwurzel fehlt in der Pokémon-Datenbank: " + root_id

	var family_members_value: Variant = meta.get("family_members", {})
	if not (family_members_value is Dictionary):
		return "Gen-1-Familien-Metadaten besitzen kein family_members-Dictionary."
	var family_members: Dictionary = family_members_value
	var family_species: Dictionary = {}
	for root_value: Variant in roots:
		var root_id: String = str(root_value)
		var members_value: Variant = family_members.get(root_id, [])
		if not (members_value is Array) or (members_value as Array).is_empty():
			return "Familie besitzt keine Mitglieder: " + root_id
		for member_value: Variant in members_value:
			var member_id: String = str(member_value)
			if member_id.is_empty():
				return "Familie enthält eine leere Pokémon-ID: " + root_id
			family_species[member_id] = true

	if family_species.size() != REMAINING_EXPECTED_SPECIES_COUNT:
		return (
			"Familien-Metadaten decken nur %d/%d Pokémon ab."
			% [family_species.size(), REMAINING_EXPECTED_SPECIES_COUNT]
		)
	for species_id_value: Variant in merged_species.keys():
		var species_id: String = str(species_id_value)
		if not family_species.has(species_id):
			return "Pokémon ist keiner vollständigen Gen-1-Familie zugeordnet: " + species_id

	for sentinel_id: String in REMAINING_SENTINEL_SPECIES:
		if not merged_species.has(sentinel_id) or not runtime_species.has(sentinel_id):
			return "Spätes/legendäres Pflicht-Pokémon fehlt in der Runtime: " + sentinel_id

	for species_id_value: Variant in runtime_species.keys():
		var species_id: String = str(species_id_value)
		var runtime_value: Variant = runtime_species.get(species_id_value, {})
		if not (runtime_value is Dictionary):
			return "Runtime-Pokémon ist ungültig: " + species_id
		var runtime_entry: Dictionary = runtime_value
		if str(runtime_entry.get("id", "")) != species_id:
			return "Runtime-Pokémon-ID stimmt nicht mit Datenbankschlüssel überein: " + species_id
		if str(runtime_entry.get("name", "")).is_empty():
			return "Runtime-Pokémon besitzt keinen Namen: " + species_id
		var types_value: Variant = runtime_entry.get("types", [])
		if not (types_value is Array) or (types_value as Array).is_empty():
			return "Runtime-Pokémon besitzt keinen gültigen Typ: " + species_id
		var stats_value: Variant = runtime_entry.get("base_stats", {})
		if not (stats_value is Dictionary):
			return "Runtime-Pokémon besitzt keine Basiswerte: " + species_id
		var stats: Dictionary = stats_value
		for stat_key: String in ["hp", "attack", "defense", "special", "speed"]:
			if not stats.has(stat_key):
				return "Runtime-Pokémon besitzt unvollständige Basiswerte: " + species_id

	if int(manifest.get("species_count", 0)) != merged_species.size():
		return "Manifest- und Runtime-Pokémonzahl widersprechen sich."
	return ""


func _remaining_fail_registry(message: String) -> void:
	_remaining_registry_ready = false
	_remaining_tm_move_universe.clear()
	data["species"] = {}
	data["species_order"] = []
	species_ids = []
	lab_species_ids = []
	_canonical_pack["species"] = {}
	push_error(message)


func _remaining_read_json_dictionary(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	if path.to_lower().ends_with(".gz"):
		push_error("GZIP-Datenpakete werden nicht mehr unterstützt: " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
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

	# Non-level evolutions legitimately have no numeric evolution_level. Normalize
	# missing/non-numeric values to 0 (= no automatic level evolution).
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
