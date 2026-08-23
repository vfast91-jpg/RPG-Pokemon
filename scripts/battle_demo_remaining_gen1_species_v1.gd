extends "res://scripts/battle_demo_struggle_fallback_v1.gd"

# Global Pokemon species registry.
#
# The playable roster has exactly one authority: species_master_file in the
# generation-neutral manifest. It contains every Pokemon that exists in the
# game, regardless of origin generation. Detail files may enrich those entries
# with learnsets, TM compatibility and source metadata, but they can never
# add/remove Pokemon and can never make a Pokemon unavailable.
# Missing/deferred attacks likewise never remove a Pokemon; the global
# Verzweifler fallback keeps it combat-capable until regular moves are available.
#
# There is one global species pool and one global runtime move pool. Generation
# is metadata only. Cross-generation evolution families share the same family
# graph. The registry is fail-closed for the roster contract itself: if the
# single master or family metadata are broken, no inherited partial roster may
# leak into PvP, route, capture or combat lab.

const REMAINING_GEN1_MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"
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
			"Globales Pokémon-Datenbank-Manifest fehlt: " + REMAINING_GEN1_MANIFEST_PATH
		)
		return

	var expected_species_count: int = int(manifest.get("species_count", -1))
	var expected_route_root_count: int = int(manifest.get("route_root_count", -1))
	if expected_species_count <= 0:
		_remaining_fail_registry("Globales Pokémon-Manifest braucht eine positive species_count.")
		return
	if expected_route_root_count <= 0:
		_remaining_fail_registry("Globales Pokémon-Manifest braucht eine positive route_root_count.")
		return

	var pool_policy_value: Variant = manifest.get("pool_policy", {})
	if not (pool_policy_value is Dictionary):
		_remaining_fail_registry("Globales Pokémon-Manifest braucht eine eindeutige Pool-Richtlinie.")
		return
	var pool_policy: Dictionary = pool_policy_value
	if str(pool_policy.get("species", "")) != "single_global_pool":
		_remaining_fail_registry("Pokémon müssen aus genau einem globalen Pool stammen.")
		return
	if str(pool_policy.get("moves", "")) != "single_global_pool":
		_remaining_fail_registry("Attacken müssen aus genau einem globalen Pool stammen.")
		return
	if not bool(pool_policy.get("generation_is_metadata_only", false)):
		_remaining_fail_registry("Generationen dürfen die Runtime-Pools nicht trennen.")
		return
	if not bool(pool_policy.get("availability_never_gated_by_generation", false)):
		_remaining_fail_registry("Pokémon-Verfügbarkeit darf niemals von einer Generation gefiltert werden.")
		return
	if not bool(pool_policy.get("cross_generation_families_share_one_family_graph", false)):
		_remaining_fail_registry("Generationsübergreifende Entwicklungen müssen eine gemeinsame Familie bleiben.")
		return

	var meta_path: String = str(manifest.get("species_meta_file", ""))
	var meta: Dictionary = _remaining_read_json_dictionary(meta_path)
	if meta.is_empty():
		_remaining_fail_registry("Globale Pokémon-Familienmetadaten fehlen: " + meta_path)
		return

	# Exactly one master owns roster membership. species_files is kept as a
	# compatibility/audit field, but it must point to that same single file.
	var master_path: String = str(manifest.get("species_master_file", ""))
	if master_path.is_empty() or master_path.to_lower().ends_with(".gz"):
		_remaining_fail_registry("Der Pokémon-Roster braucht genau eine normale JSON-Masterdatei.")
		return

	var species_files_value: Variant = manifest.get("species_files", [])
	if not (species_files_value is Array):
		_remaining_fail_registry("Globales Pokémon-Manifest braucht species_files.")
		return
	var species_files: Array = species_files_value
	if species_files.size() != 1 or str(species_files[0]) != master_path:
		_remaining_fail_registry(
			"species_files muss ausschließlich auf die eine globale Pokémon-Masterdatei verweisen."
		)
		return

	var master_pack: Dictionary = _remaining_read_json_dictionary(master_path)
	var master_entries_value: Variant = master_pack.get("species", {})
	if not (master_entries_value is Dictionary):
		_remaining_fail_registry("Pokémon-Masterdatei ist ungültig: " + master_path)
		return
	if int(master_pack.get("species_count", expected_species_count)) != expected_species_count:
		_remaining_fail_registry(
			"Pokémon-Masterdatei und Manifest deklarieren unterschiedliche Pokémon-Anzahlen."
		)
		return

	var master_species: Dictionary = {}
	for species_id_value: Variant in (master_entries_value as Dictionary).keys():
		var species_id: String = str(species_id_value)
		var entry_value: Variant = (master_entries_value as Dictionary).get(species_id_value, {})
		if species_id.is_empty() or not (entry_value is Dictionary):
			_remaining_fail_registry("Pokémon-Masterdatei enthält einen ungültigen Datensatz.")
			return
		var entry: Dictionary = _remaining_sanitize_species_source(entry_value as Dictionary)
		if str(entry.get("species_id", "")) != species_id:
			_remaining_fail_registry(
				"Pokémon-Masterdatei besitzt eine widersprüchliche ID: " + species_id
			)
			return
		master_species[species_id] = entry

	var master_error: String = _remaining_validate_master_contract(
		meta,
		master_species,
		expected_species_count,
		expected_route_root_count
	)
	if not master_error.is_empty():
		_remaining_fail_registry(master_error)
		return

	# Start every runtime entry from the master so no optional/detail layer can
	# ever remove a Pokemon. Detail packs are enrichment only and fail soft.
	var merged_species: Dictionary = master_species.duplicate(true)
	var detail_files_value: Variant = manifest.get("species_detail_files", [])
	if detail_files_value is Array:
		for path_value: Variant in detail_files_value:
			var detail_path: String = str(path_value)
			if detail_path.is_empty():
				continue
			if detail_path.to_lower().ends_with(".gz"):
				push_warning(
					"Pokémon-Detailpaket wird ignoriert, weil GZIP nicht mehr unterstützt wird: "
					+ detail_path
				)
				continue
			var detail_pack: Dictionary = _remaining_read_json_dictionary(detail_path)
			var detail_entries_value: Variant = detail_pack.get("species", {})
			if not (detail_entries_value is Dictionary):
				push_warning("Pokémon-Detailpaket ist ungültig und wird ignoriert: " + detail_path)
				continue
			for species_id_value: Variant in (detail_entries_value as Dictionary).keys():
				var species_id: String = str(species_id_value)
				if not master_species.has(species_id):
					push_warning(
						"Pokémon-Detailpaket enthält eine nicht im globalen Master registrierte ID und wird dafür ignoriert: "
						+ species_id
					)
					continue
				var detail_value: Variant = (detail_entries_value as Dictionary).get(species_id_value, {})
				if not (detail_value is Dictionary):
					continue
				var base_value: Variant = merged_species.get(species_id, {})
				var base: Dictionary = base_value if base_value is Dictionary else {}
				merged_species[species_id] = _remaining_merge_species_detail(
					base,
					detail_value as Dictionary
				)

	# All move definition files merge into one runtime Dictionary. Physical source
	# files may stay modular for maintenance, but there is never a Gen-1/Gen-2/etc.
	# move pool at runtime and no generation filter is applied here.
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
	var manifest_moves: Dictionary = {}
	var move_files_value: Variant = manifest.get("move_files", [])
	if move_files_value is Array:
		for path_value: Variant in move_files_value:
			var move_path: String = str(path_value)
			if move_path.is_empty():
				continue
			if move_path.to_lower().ends_with(".gz"):
				push_warning("Attacken-Datenpaket wird ignoriert (GZIP): " + move_path)
				continue
			var move_pack: Dictionary = _remaining_read_json_dictionary(move_path)
			var move_entries_value: Variant = move_pack.get("moves", {})
			if not (move_entries_value is Dictionary):
				push_warning("Attacken-Datenpaket ist ungültig und wird ignoriert: " + move_path)
				continue
			for move_id_value: Variant in (move_entries_value as Dictionary).keys():
				var move_id: String = str(move_id_value)
				var move_value: Variant = (move_entries_value as Dictionary).get(move_id_value, {})
				if move_value is Dictionary:
					var move_copy: Dictionary = (move_value as Dictionary).duplicate(true)
					manifest_moves[move_id] = move_copy.duplicate(true)
					runtime_moves[move_id] = move_copy.duplicate(true)
					canonical_moves[move_id] = move_copy

	var expected_move_count: int = int(manifest.get("move_count", -1))
	if expected_move_count >= 0 and manifest_moves.size() != expected_move_count:
		push_warning(
			"Attacken-Manifest derzeit unvollständig: %d/%d. Pokémon bleiben vollständig verfügbar; fehlende Kampfaktionen nutzen Verzweifler."
			% [manifest_moves.size(), expected_move_count]
		)

	# Make all successfully loaded moves visible while converting learnsets.
	var conversion_pack: Dictionary = meta.duplicate(true)
	conversion_pack["moves"] = canonical_moves
	_canonical_pack = conversion_pack

	var runtime_species: Dictionary = {}
	for species_id_value: Variant in merged_species.keys():
		var species_id: String = str(species_id_value)
		var source_value: Variant = merged_species.get(species_id_value, {})
		if source_value is Dictionary:
			runtime_species[species_id] = _canonical_species_runtime(source_value as Dictionary)

	var runtime_error: String = _remaining_validate_runtime_contract(
		master_species,
		runtime_species,
		expected_species_count
	)
	if not runtime_error.is_empty():
		_remaining_fail_registry(runtime_error)
		return

	# Publish only after the one-master roster contract has succeeded. There is
	# intentionally no fallback to an inherited partial roster.
	_canonical_pack = meta.duplicate(true)
	_canonical_pack["species"] = merged_species
	_canonical_pack["moves"] = canonical_moves
	_canonical_pack["manifest"] = manifest.duplicate(true)

	data["species"] = runtime_species
	data["moves"] = runtime_moves

	var roots_value: Variant = meta.get("route_roots", [])
	species_ids = (roots_value as Array).duplicate()
	data["species_order"] = species_ids.duplicate()
	lab_species_ids = runtime_species.keys()
	_remaining_rebuild_tm_move_universe()

	_remaining_registry_ready = true
	print(
		"Pokémon-Datenbank OK: %d Pokémon · %d Familien · ein globaler Attackenpool"
		% [runtime_species.size(), species_ids.size()]
	)
	_audit_canonical_database()


func _remaining_validate_master_contract(
	meta: Dictionary,
	master_species: Dictionary,
	expected_species_count: int,
	expected_route_root_count: int
) -> String:
	if master_species.size() != expected_species_count:
		return (
			"Pokémon-Masterdatei unvollständig: %d/%d Pokémon."
			% [master_species.size(), expected_species_count]
		)

	var roots_value: Variant = meta.get("route_roots", [])
	if not (roots_value is Array):
		return "Pokémon-Familienmetadaten besitzen keine route_roots-Liste."
	var roots: Array = roots_value
	if roots.size() != expected_route_root_count:
		return (
			"Pokémon-Familiendatenbank unvollständig: %d/%d Familien."
			% [roots.size(), expected_route_root_count]
		)

	var seen_roots: Dictionary = {}
	for root_value: Variant in roots:
		var root_id: String = str(root_value)
		if root_id.is_empty() or seen_roots.has(root_id):
			return "Pokémon-Familienmetadaten enthalten eine leere oder doppelte Familienwurzel."
		seen_roots[root_id] = true
		if not master_species.has(root_id):
			return "Familienwurzel fehlt in der Pokémon-Masterdatei: " + root_id

	var family_members_value: Variant = meta.get("family_members", {})
	if not (family_members_value is Dictionary):
		return "Pokémon-Familienmetadaten besitzen kein family_members-Dictionary."
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

	if family_species.size() != expected_species_count:
		return (
			"Familien-Metadaten decken nur %d/%d Pokémon ab."
			% [family_species.size(), expected_species_count]
		)
	for species_id_value: Variant in master_species.keys():
		var species_id: String = str(species_id_value)
		if not family_species.has(species_id):
			return "Pokémon ist keiner globalen Familie zugeordnet: " + species_id
	for member_id_value: Variant in family_species.keys():
		var member_id: String = str(member_id_value)
		if not master_species.has(member_id):
			return "Familien-Metadaten referenzieren ein Pokémon außerhalb des Masters: " + member_id

	for sentinel_id: String in REMAINING_SENTINEL_SPECIES:
		if not master_species.has(sentinel_id):
			return "Bestehendes Pflicht-Pokémon fehlt im Master: " + sentinel_id

	for species_id_value: Variant in master_species.keys():
		var species_id: String = str(species_id_value)
		var entry_value: Variant = master_species.get(species_id_value, {})
		if not (entry_value is Dictionary):
			return "Master-Pokémon ist ungültig: " + species_id
		var entry: Dictionary = entry_value
		if str(entry.get("species_id", "")) != species_id:
			return "Master-Pokémon-ID stimmt nicht mit Datenbankschlüssel überein: " + species_id
		if str(entry.get("display_name", "")).is_empty():
			return "Master-Pokémon besitzt keinen Namen: " + species_id
		var types_value: Variant = entry.get("types", {})
		if not (types_value is Dictionary) or str((types_value as Dictionary).get("primary", "")).is_empty():
			return "Master-Pokémon besitzt keinen Primärtyp: " + species_id
		var stats_error: String = _remaining_validate_base_stats(entry.get("base_stats", {}), species_id)
		if not stats_error.is_empty():
			return stats_error

	return ""


func _remaining_validate_runtime_contract(
	master_species: Dictionary,
	runtime_species: Dictionary,
	expected_species_count: int
) -> String:
	if runtime_species.size() != expected_species_count:
		return (
			"Globale Pokémon-Datenbank unvollständig: %d/%d Pokémon in der Runtime."
			% [runtime_species.size(), expected_species_count]
		)

	for species_id_value: Variant in master_species.keys():
		var species_id: String = str(species_id_value)
		if not runtime_species.has(species_id):
			return "Master-Pokémon fehlt in der Runtime: " + species_id
		var runtime_value: Variant = runtime_species.get(species_id, {})
		if not (runtime_value is Dictionary):
			return "Runtime-Pokémon ist ungültig: " + species_id
		var runtime_entry: Dictionary = runtime_value
		if str(runtime_entry.get("id", "")) != species_id:
			return "Runtime-Pokémon-ID stimmt nicht mit Master überein: " + species_id
		if str(runtime_entry.get("name", "")).is_empty():
			return "Runtime-Pokémon besitzt keinen Namen: " + species_id
		var types_value: Variant = runtime_entry.get("types", [])
		if not (types_value is Array) or (types_value as Array).is_empty():
			return "Runtime-Pokémon besitzt keinen gültigen Typ: " + species_id
		var stats_error: String = _remaining_validate_base_stats(
			runtime_entry.get("base_stats", {}),
			species_id
		)
		if not stats_error.is_empty():
			return stats_error

	for sentinel_id: String in REMAINING_SENTINEL_SPECIES:
		if not runtime_species.has(sentinel_id):
			return "Bestehendes Pflicht-Pokémon fehlt in der Runtime: " + sentinel_id
	return ""


func _remaining_validate_base_stats(stats_value: Variant, species_id: String) -> String:
	if not (stats_value is Dictionary):
		return "Pokémon besitzt keine Basiswerte: " + species_id
	var stats: Dictionary = stats_value
	for stat_key: String in ["hp", "attack", "defense", "special", "speed"]:
		if not stats.has(stat_key):
			return "Pokémon besitzt unvollständige Basiswerte: " + species_id
		if float(stats.get(stat_key, 0.0)) <= 0.0:
			return "Pokémon besitzt einen ungültigen Basiswert (%s): %s" % [stat_key, species_id]
	return ""


func _remaining_merge_species_detail(base: Dictionary, detail: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key_value: Variant in detail.keys():
		var value: Variant = detail.get(key_value)
		if value is Dictionary:
			result[key_value] = (value as Dictionary).duplicate(true)
		elif value is Array:
			result[key_value] = (value as Array).duplicate(true)
		else:
			result[key_value] = value
	# The master owns identity. A detail overlay may enrich/override content but
	# never rename an entry into another species.
	result["species_id"] = str(base.get("species_id", result.get("species_id", "")))
	return _remaining_sanitize_species_source(result)


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
	# string "<null>". It is not a Pokemon type and must never reach TypeSystem.
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