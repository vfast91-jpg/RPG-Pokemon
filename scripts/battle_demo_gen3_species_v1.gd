extends "res://scripts/battle_demo_ursaluna_family_v1.gd"

# Generation 3 roster integration.
#
# Pokémon data only: this layer appends the approved Gen-3 species/forms,
# family graph, evolutions and learnset/TM identifiers to the one global
# generation-neutral Pokémon pool. It deliberately does not add or alter move
# definitions or move mechanics.

const GEN3_EXTENSION_MANIFEST_PATH: String = "res://data/pokemon_database_extension_gen3_v1.json"


func _load_data() -> void:
    super._load_data()
    _gen3_load_roster_extension()


func _gen3_load_roster_extension() -> void:
    if not pokemon_registry_ready():
        return

    var extension: Dictionary = _remaining_read_json_dictionary(GEN3_EXTENSION_MANIFEST_PATH)
    if extension.is_empty():
        _gen3_fail("Gen3-Erweiterungsmanifest fehlt.")
        return

    var runtime_species_value: Variant = data.get("species", {})
    var canonical_species_value: Variant = _canonical_pack.get("species", {})
    var roots_value: Variant = _canonical_pack.get("route_roots", [])
    var family_members_value: Variant = _canonical_pack.get("family_members", {})
    if not (runtime_species_value is Dictionary and canonical_species_value is Dictionary):
        _gen3_fail("Basis-Pokemonpool ist vor der Gen3-Erweiterung ungueltig.")
        return
    if not (roots_value is Array and family_members_value is Dictionary):
        _gen3_fail("Basis-Familiengraph ist vor der Gen3-Erweiterung ungueltig.")
        return

    var runtime_species: Dictionary = (runtime_species_value as Dictionary).duplicate(true)
    var canonical_species: Dictionary = (canonical_species_value as Dictionary).duplicate(true)
    var roots: Array = (roots_value as Array).duplicate()
    var family_members: Dictionary = (family_members_value as Dictionary).duplicate(true)

    var expected_base_species: int = int(extension.get("expected_base_species_count", -1))
    var expected_base_roots: int = int(extension.get("expected_base_route_root_count", -1))
    if runtime_species.size() != expected_base_species or roots.size() != expected_base_roots:
        _gen3_fail("Gen3-Erweiterung passt nicht zum aktiven Basis-Roster.")
        return

    var core_pack: Dictionary = _remaining_read_json_dictionary(
        str(extension.get("species_master_extension_file", ""))
    )
    var core_value: Variant = core_pack.get("species", {})
    var family_pack: Dictionary = _remaining_read_json_dictionary(
        str(extension.get("family_meta_extension_file", ""))
    )
    var new_roots_value: Variant = family_pack.get("route_roots", [])
    var new_families_value: Variant = family_pack.get("family_members", {})
    if not (core_value is Dictionary and new_roots_value is Array and new_families_value is Dictionary):
        _gen3_fail("Gen3-Erweiterungsdaten sind ungueltig.")
        return

    var details_by_species: Dictionary = {}
    var detail_files_value: Variant = extension.get("species_detail_files", [])
    if detail_files_value is Array:
        for path_value: Variant in detail_files_value:
            var pack: Dictionary = _remaining_read_json_dictionary(str(path_value))
            var entries_value: Variant = pack.get("species", {})
            if not (entries_value is Dictionary):
                _gen3_fail("Gen3-Detailpaket ist ungueltig: " + str(path_value))
                return
            for species_id_value: Variant in (entries_value as Dictionary).keys():
                var species_id: String = str(species_id_value)
                if details_by_species.has(species_id):
                    _gen3_fail("Doppelte Pokemon-ID in Gen3-Detailpaketen: " + species_id)
                    return
                var detail_value: Variant = (entries_value as Dictionary).get(species_id_value, {})
                if detail_value is Dictionary:
                    details_by_species[species_id] = (detail_value as Dictionary).duplicate(true)

    var core_species: Dictionary = core_value as Dictionary
    if core_species.size() != int(extension.get("extension_species_count", -1)):
        _gen3_fail("Gen3-Core enthaelt eine falsche Pokemon-Anzahl.")
        return
    if details_by_species.size() != core_species.size():
        _gen3_fail("Gen3-Detailpakete decken den Core nicht vollstaendig ab.")
        return
    if (new_roots_value as Array).size() != int(extension.get("extension_route_root_count", -1)):
        _gen3_fail("Gen3-Familiendaten enthalten eine falsche Familienanzahl.")
        return

    for species_id_value: Variant in core_species.keys():
        var species_id: String = str(species_id_value)
        if canonical_species.has(species_id):
            _gen3_fail("Gen3-Erweiterung kollidiert mit bestehender Pokemon-ID: " + species_id)
            return
        var core_entry_value: Variant = core_species.get(species_id_value, {})
        if not (core_entry_value is Dictionary):
            _gen3_fail("Ungueltiger Gen3-Core-Datensatz: " + species_id)
            return
        var core_entry: Dictionary = _remaining_sanitize_species_source(core_entry_value as Dictionary)
        if str(core_entry.get("species_id", "")) != species_id:
            _gen3_fail("Widerspruechliche Gen3-Core-ID: " + species_id)
            return
        var merged: Dictionary = _remaining_merge_species_detail(
            core_entry,
            details_by_species.get(species_id, {})
        )
        canonical_species[species_id] = merged
        runtime_species[species_id] = _canonical_species_runtime(merged)

    for root_value: Variant in (new_roots_value as Array):
        var root_id: String = str(root_value)
        if roots.has(root_id) or family_members.has(root_id):
            _gen3_fail("Doppelte Gen3-Familienwurzel: " + root_id)
            return
        var members_value: Variant = (new_families_value as Dictionary).get(root_id, [])
        if not (members_value is Array) or (members_value as Array).is_empty():
            _gen3_fail("Leere Gen3-Familie: " + root_id)
            return
        if not (members_value as Array).has(root_id):
            _gen3_fail("Gen3-Familienwurzel fehlt in eigener Familie: " + root_id)
            return
        for member_value: Variant in (members_value as Array):
            if not runtime_species.has(str(member_value)):
                _gen3_fail(
                    "Gen3-Familienmitglied fehlt im Runtime-Pool: " + str(member_value)
                )
                return
        roots.append(root_id)
        family_members[root_id] = (members_value as Array).duplicate()

    if runtime_species.size() != int(extension.get("runtime_species_count", -1)):
        _gen3_fail("Gen3-Runtime-Pokemonanzahl ist unvollstaendig.")
        return
    if roots.size() != int(extension.get("runtime_route_root_count", -1)):
        _gen3_fail("Gen3-Runtime-Familienanzahl ist unvollstaendig.")
        return

    _canonical_pack["species"] = canonical_species
    _canonical_pack["route_roots"] = roots
    _canonical_pack["family_members"] = family_members
    data["species"] = runtime_species
    species_ids = roots.duplicate()
    data["species_order"] = species_ids.duplicate()
    lab_species_ids = runtime_species.keys()
    _remaining_rebuild_tm_move_universe()

    print(
        "Gen3 roster extension OK: %d Pokemon, %d families total"
        % [runtime_species.size(), species_ids.size()]
    )


func _gen3_fail(message: String) -> void:
    _remaining_registry_ready = false
    push_error(message)
