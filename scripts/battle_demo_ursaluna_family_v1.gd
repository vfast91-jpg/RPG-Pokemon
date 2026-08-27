extends "res://scripts/battle_demo_gen2_species_51_v1.gd"

# Activates normal Ursaluna as the third member of the existing
# Teddiursa -> Ursaring family. This layer is intentionally append-only: the
# validated 266-species base master and the existing Gen-2 extensions remain
# untouched, while runtime/canonical registries gain exactly one species and no
# new route root. Headlong Rush is deliberately not part of this change.

const URSALUNA_EXTENSION_PATH: String = "res://data/pokemon_database_extension_ursaluna_v1.json"


func _load_data() -> void:
	super._load_data()
	_ursaluna_load_family_extension()


func _ursaluna_load_family_extension() -> void:
	if not pokemon_registry_ready():
		return

	var extension: Dictionary = _remaining_read_json_dictionary(URSALUNA_EXTENSION_PATH)
	if extension.is_empty():
		_ursaluna_fail("Ursaluna-Erweiterungsdaten fehlen.")
		return

	var runtime_value: Variant = data.get("species", {})
	var canonical_value: Variant = _canonical_pack.get("species", {})
	var roots_value: Variant = _canonical_pack.get("route_roots", [])
	var families_value: Variant = _canonical_pack.get("family_members", {})
	if not (runtime_value is Dictionary and canonical_value is Dictionary):
		_ursaluna_fail("Pokemonpool ist vor der Ursaluna-Erweiterung ungueltig.")
		return
	if not (roots_value is Array and families_value is Dictionary):
		_ursaluna_fail("Familiengraph ist vor der Ursaluna-Erweiterung ungueltig.")
		return

	var runtime_species: Dictionary = (runtime_value as Dictionary).duplicate(true)
	var canonical_species: Dictionary = (canonical_value as Dictionary).duplicate(true)
	var roots: Array = (roots_value as Array).duplicate()
	var family_members: Dictionary = (families_value as Dictionary).duplicate(true)

	if runtime_species.size() != int(extension.get("expected_base_species_count", -1)):
		_ursaluna_fail("Ursaluna-Erweiterung passt nicht zum aktiven Pokemonpool.")
		return
	if roots.size() != int(extension.get("expected_base_route_root_count", -1)):
		_ursaluna_fail("Ursaluna-Erweiterung passt nicht zum aktiven Familiengraphen.")
		return
	if runtime_species.has("ursaluna") or canonical_species.has("ursaluna"):
		_ursaluna_fail("Ursaluna ist bereits registriert; doppelte Aktivierung verhindert.")
		return

	var family_root: String = str(extension.get("family_root", ""))
	if family_root != "teddiursa" or not roots.has(family_root):
		_ursaluna_fail("Die bestehende Teddiursa-Familie fehlt.")
		return
	var old_members_value: Variant = family_members.get(family_root, [])
	if not (old_members_value is Array):
		_ursaluna_fail("Die Teddiursa-Familie besitzt keine gueltige Mitgliederliste.")
		return
	var old_members: Array = old_members_value as Array
	if not old_members.has("teddiursa") or not old_members.has("ursaring"):
		_ursaluna_fail("Teddiursa/Ursaring fehlen in ihrer bestehenden Familie.")
		return

	var core_value: Variant = extension.get("species_core", {})
	var detail_value: Variant = extension.get("species_detail", {})
	if not (core_value is Dictionary and detail_value is Dictionary):
		_ursaluna_fail("Ursaluna-Core/Details sind ungueltig.")
		return
	var core_entry_value: Variant = (core_value as Dictionary).get("ursaluna", {})
	var detail_entry_value: Variant = (detail_value as Dictionary).get("ursaluna", {})
	if not (core_entry_value is Dictionary and detail_entry_value is Dictionary):
		_ursaluna_fail("Ursaluna-Datensatz ist unvollstaendig.")
		return

	var core_entry: Dictionary = _remaining_sanitize_species_source(core_entry_value as Dictionary)
	var merged_ursaluna: Dictionary = _remaining_merge_species_detail(core_entry, detail_entry_value as Dictionary)
	canonical_species["ursaluna"] = merged_ursaluna
	runtime_species["ursaluna"] = _canonical_species_runtime(merged_ursaluna)

	# Activate the already approved Timeflow translation of Peat Block/full moon:
	# mandatory Ursaring -> Ursaluna at level 50.
	var ursaring_value: Variant = canonical_species.get("ursaring", {})
	if not (ursaring_value is Dictionary):
		_ursaluna_fail("Ursaring fehlt im kanonischen Pokemonpool.")
		return
	var ursaring: Dictionary = (ursaring_value as Dictionary).duplicate(true)
	var ursaring_evolution_value: Variant = extension.get("ursaring_evolution", {})
	if not (ursaring_evolution_value is Dictionary):
		_ursaluna_fail("Ursaring-Entwicklungsregel fehlt.")
		return
	ursaring["evolution"] = (ursaring_evolution_value as Dictionary).duplicate(true)

	# Family catch rate changes only because the family now genuinely has three
	# members; no other encounter data is touched.
	var family_catch_rate: float = float(extension.get("family_catch_rate", 0.0))
	for member_id: String in ["teddiursa", "ursaring"]:
		var member_value: Variant = canonical_species.get(member_id, {})
		if member_value is Dictionary:
			var member: Dictionary = (member_value as Dictionary).duplicate(true)
			member["family_catch_rate"] = family_catch_rate
			canonical_species[member_id] = member
			runtime_species[member_id] = _canonical_species_runtime(member)
	ursaring["family_catch_rate"] = family_catch_rate
	canonical_species["ursaring"] = ursaring
	runtime_species["ursaring"] = _canonical_species_runtime(ursaring)

	var new_members_value: Variant = extension.get("family_members", [])
	if not (new_members_value is Array) or (new_members_value as Array) != ["teddiursa", "ursaring", "ursaluna"]:
		_ursaluna_fail("Ursaluna-Familienliste ist ungueltig.")
		return
	family_members[family_root] = (new_members_value as Array).duplicate()

	if runtime_species.size() != int(extension.get("runtime_species_count", -1)):
		_ursaluna_fail("Ursaluna wurde nicht exakt einmal zum Runtime-Pool hinzugefuegt.")
		return
	if roots.size() != int(extension.get("runtime_route_root_count", -1)):
		_ursaluna_fail("Ursaluna darf keine neue Familienwurzel erzeugen.")
		return

	_canonical_pack["species"] = canonical_species
	_canonical_pack["family_members"] = family_members
	_canonical_pack["route_roots"] = roots
	var gaps_value: Variant = _canonical_pack.get("data_gaps", {})
	if gaps_value is Dictionary:
		var gaps: Dictionary = (gaps_value as Dictionary).duplicate(true)
		gaps.erase("ursaluna_deferred")
		gaps.erase("ursaluna_deferred_reason")
		_canonical_pack["data_gaps"] = gaps

	data["species"] = runtime_species
	species_ids = roots.duplicate()
	data["species_order"] = species_ids.duplicate()
	lab_species_ids = runtime_species.keys()
	_remaining_rebuild_tm_move_universe()
	print("Ursaluna family extension OK: Teddiursa -> Ursaring -> Ursaluna")


func _ursaluna_fail(message: String) -> void:
	_remaining_registry_ready = false
	push_error(message)
