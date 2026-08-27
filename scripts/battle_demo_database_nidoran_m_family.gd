extends "res://scripts/battle_demo_database_nidoran_f_family.gd"

const NIDORAN_M_SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_nidoran_m_family_v1.json"
const NIDORAN_M_MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_21_nidoran_m_family.json"
const NIDORAN_M_MANIFEST_PATH: String = "res://data/gen1_database_manifest_v4.json"
const NIDORAN_M_META_PATH: String = "res://data/gen1_database_meta_v4.json"

# The parent Nidoran♀ layer validates the same global V4 manifest while it is
# still only responsible for the first 32 species / 271 moves / 12 route roots.
# During that parent phase, expose its phase-local counts. The final male layer
# then validates the actual complete V4 manifest (35 / 273 / 13).
var _nidoran_m_parent_load_phase: bool = false


func _database_read_json_dictionary(path: String) -> Dictionary:
    var parsed: Dictionary = super._database_read_json_dictionary(path)
    if _nidoran_m_parent_load_phase and path == NIDORAN_M_MANIFEST_PATH:
        parsed = parsed.duplicate(true)
        parsed["species_count"] = 32
        parsed["move_count"] = 271
        parsed["route_root_count"] = 12
    return parsed


func _load_canonical_database() -> void:
    _nidoran_m_parent_load_phase = true
    super._load_canonical_database()
    _nidoran_m_parent_load_phase = false

    var species_pack: Dictionary = _database_read_json_dictionary(NIDORAN_M_SPECIES_PACK_PATH)
    var move_pack: Dictionary = _database_read_json_dictionary(NIDORAN_M_MOVE_PACK_PATH)
    var manifest: Dictionary = _database_read_json_dictionary(NIDORAN_M_MANIFEST_PATH)
    var meta: Dictionary = _database_read_json_dictionary(NIDORAN_M_META_PATH)

    var move_entries_value: Variant = move_pack.get("moves", {})
    var move_entries: Dictionary = move_entries_value if move_entries_value is Dictionary else {}
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_moves_value if canonical_moves_value is Dictionary else {}
    var runtime_moves_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_moves_value if runtime_moves_value is Dictionary else {}
    for move_id_value: Variant in move_entries.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = move_entries.get(move_id, {})
        if not (move_value is Dictionary):
            continue
        canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)
        runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
    _canonical_pack["moves"] = canonical_moves
    data["moves"] = runtime_moves

    var species_entries_value: Variant = species_pack.get("species", {})
    var species_entries: Dictionary = species_entries_value if species_entries_value is Dictionary else {}
    var canonical_species_value: Variant = _canonical_pack.get("species", {})
    var canonical_species: Dictionary = canonical_species_value if canonical_species_value is Dictionary else {}
    var runtime_species_value: Variant = data.get("species", {})
    var runtime_species: Dictionary = runtime_species_value if runtime_species_value is Dictionary else {}
    for species_id_value: Variant in species_entries.keys():
        var species_id: String = str(species_id_value)
        var species_value: Variant = species_entries.get(species_id, {})
        if not (species_value is Dictionary):
            continue
        var source_species: Dictionary = (species_value as Dictionary).duplicate(true)
        canonical_species[species_id] = source_species
        runtime_species[species_id] = _canonical_species_runtime(source_species)
    _canonical_pack["species"] = canonical_species
    data["species"] = runtime_species

    if not species_ids.has("nidoran_m"):
        species_ids.append("nidoran_m")
    data["species_order"] = species_ids.duplicate()

    if not meta.is_empty():
        for meta_key_value: Variant in meta.keys():
            var meta_key: String = str(meta_key_value)
            _canonical_pack[meta_key] = meta.get(meta_key_value)

    if not manifest.is_empty():
        _canonical_pack["manifest"] = manifest.duplicate(true)
        if runtime_species.size() != int(manifest.get("species_count", runtime_species.size())):
            push_error("Nidoran♂-Familie: Pokémon-Anzahl stimmt nicht mit V4-Manifest überein.")
        if runtime_moves.size() != int(manifest.get("move_count", runtime_moves.size())):
            push_error("Nidoran♂-Familie: Attacken-Anzahl stimmt nicht mit V4-Manifest überein.")
        if species_ids.size() != int(manifest.get("route_root_count", species_ids.size())):
            push_error("Nidoran♂-Familie: Basislinien-Anzahl stimmt nicht mit V4-Manifest überein.")


# Encore/Zugabe uses the shared forced-move state, but unlike rampage-style
# moves the repeated move itself does not carry a forced_sequence runtime tag.
# Track only Encore-created locks so their configured action duration can expire.
func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var result: float = super._effect(actor, target, mechanic)
    if str(mechanic.get("kind", "")) == "db_encore" and result > 0.0:
        target["db_encore_forced_active"] = true
    return result


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var encore_forced_action: bool = (
        bool(actor.get("db_encore_forced_active", false))
        and str(actor.get("db_forced_move_id", "")) == move_id
        and int(actor.get("db_forced_actions_left", 0)) > 0
    )
    var move: Dictionary = _move_data(move_id)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var parent_counts_forced_action: bool = runtime.has("forced_sequence")

    super._execute_move(actor, move_id)

    if not encore_forced_action:
        return
    if str(actor.get("db_forced_move_id", "")) != move_id:
        actor["db_encore_forced_active"] = false
        return
    if parent_counts_forced_action:
        if int(actor.get("db_forced_actions_left", 0)) <= 0:
            actor["db_encore_forced_active"] = false
        return
    if not _database_move_was_attempted(move_id):
        _database_interrupt_forced_sequence(actor)
        return

    actor["db_forced_actions_left"] = maxi(
        0,
        int(actor.get("db_forced_actions_left", 0)) - 1
    )
    if int(actor.get("db_forced_actions_left", 0)) <= 0:
        _database_interrupt_forced_sequence(actor)


func _database_interrupt_forced_sequence(actor: Dictionary) -> void:
    super._database_interrupt_forced_sequence(actor)
    actor["db_encore_forced_active"] = false
