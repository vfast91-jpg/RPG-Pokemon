extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_pvp_active_v1.gd")

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v8.json"
const EXPECTED_MASTER_PATH: String = "res://data/gen1_species_roster_master_v8.json"
const EXPECTED_SPECIES_COUNT: int = 185
const EXPECTED_FAMILY_COUNT: int = 78
const SENTINEL_SPECIES: Array[String] = [
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
const PVP_LEVEL_50_SENTINELS: Array[String] = [
    "lapras",
    "snorlax",
    "articuno",
    "zapdos",
    "moltres",
    "mewtwo",
    "mew"
]

var failures: int = 0


func _initialize() -> void:
    _check_single_master_storage_contract()

    var battle = BattleScript.new()
    root.add_child(battle)

    _check(
        battle.pokemon_registry_ready(),
        "Der aktive BattleDemo muss den vollständigen Pokémon-Roster als bereit markieren."
    )

    var species_value: Variant = battle.data.get("species", {})
    _check(species_value is Dictionary, "Die aktive Runtime braucht ein species-Dictionary.")
    if not (species_value is Dictionary):
        _finish(battle)
        return

    var species: Dictionary = species_value
    _check(
        species.size() == EXPECTED_SPECIES_COUNT,
        "Die aktive Runtime muss exakt %d Pokémon enthalten, geladen wurden %d."
        % [EXPECTED_SPECIES_COUNT, species.size()]
    )
    _check(
        battle.species_ids.size() == EXPECTED_FAMILY_COUNT,
        "Die aktive Runtime muss exakt %d Familienwurzeln enthalten, geladen wurden %d."
        % [EXPECTED_FAMILY_COUNT, battle.species_ids.size()]
    )
    _check(
        battle.lab_species_ids.size() == EXPECTED_SPECIES_COUNT,
        "Das aktive Kampflabor muss alle %d registrierten Pokémon direkt auswählbar machen, nicht nur die 78 Routenwurzeln."
        % EXPECTED_SPECIES_COUNT
    )
    _check(
        battle.route_species_ids_valid_through_level(100).size() == EXPECTED_FAMILY_COUNT,
        "Alle 78 Familien müssen für die globale Systemgenerierung grundsätzlich erreichbar bleiben."
    )

    for sentinel_id: String in SENTINEL_SPECIES:
        _check(
            species.has(sentinel_id),
            "Spätes/legendäres Pflicht-Pokémon fehlt in der aktiven Runtime: %s" % sentinel_id
        )
        _check(
            battle.lab_species_ids.has(sentinel_id),
            "Spätes/legendäres Pflicht-Pokémon fehlt im Kampflabor: %s" % sentinel_id
        )

    # Every registered Pokemon must be structurally usable and capable of
    # entering combat. Attack completeness is deliberately not an availability
    # condition: the global Verzweifler fallback must keep the combatant usable.
    for species_id_value: Variant in species.keys():
        var species_id: String = str(species_id_value)
        var entry_value: Variant = species.get(species_id_value, {})
        _check(entry_value is Dictionary, "Ungültiger Runtime-Datensatz: %s" % species_id)
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        _check(str(entry.get("id", "")) == species_id, "Runtime-ID stimmt nicht: %s" % species_id)
        _check(not str(entry.get("name", "")).is_empty(), "Runtime-Name fehlt: %s" % species_id)
        var types_value: Variant = entry.get("types", [])
        _check(types_value is Array and not (types_value as Array).is_empty(), "Runtime-Typ fehlt: %s" % species_id)
        var stats_value: Variant = entry.get("base_stats", {})
        _check(stats_value is Dictionary, "Runtime-Basiswerte fehlen: %s" % species_id)
        if stats_value is Dictionary:
            var stats: Dictionary = stats_value
            for stat_key: String in ["hp", "attack", "defense", "special", "speed"]:
                _check(stats.has(stat_key), "Runtime-Basiswert %s fehlt bei %s" % [stat_key, species_id])
                _check(float(stats.get(stat_key, 0.0)) > 0.0, "Runtime-Basiswert %s ist ungültig bei %s" % [stat_key, species_id])

        var combatant: Dictionary = battle._make_combatant(
            "player",
            0,
            {"species_id": species_id, "level": 1}
        )
        _check(not combatant.is_empty(), "Pokémon kann nicht als Combatant erzeugt werden: %s" % species_id)
        _check(not str(combatant.get("name", "")).is_empty(), "Combatant besitzt keinen Namen: %s" % species_id)
        _check(int(combatant.get("max_hp", 0)) > 0, "Combatant besitzt keine gültigen KP: %s" % species_id)
        var normal_moves: Array = battle._database_normal_battle_moves(combatant.get("moves", []))
        var effective_moves: Array = battle._tf_effective_combat_moves(combatant, normal_moves)
        _check(
            not effective_moves.is_empty(),
            "Pokémon besitzt weder nutzbare Attacke noch Verzweifler: %s" % species_id
        )
        if normal_moves.is_empty():
            _check(
                effective_moves == ["struggle"],
                "Pokémon ohne reguläre Attacke muss exakt Verzweifler erhalten: %s" % species_id
            )

    # Global reachability is tested from the same 78 family roots used by route,
    # captures, enemies and system-generated PvP forms. Across levels 1-100 the
    # union must be exactly the complete 185-Pokemon runtime roster.
    var generated_reachable: Dictionary = {}
    for generated_level: int in range(1, 101):
        for root_value: Variant in battle.species_ids:
            var options: Array = battle.route_generated_species_options_for_level(
                str(root_value),
                generated_level
            )
            for option_value: Variant in options:
                generated_reachable[str(option_value)] = true

    _check(
        generated_reachable.size() == EXPECTED_SPECIES_COUNT,
        "Globale Systemgenerierung erreicht nur %d/%d Pokémon."
        % [generated_reachable.size(), EXPECTED_SPECIES_COUNT]
    )
    for species_id_value: Variant in species.keys():
        var species_id: String = str(species_id_value)
        _check(
            generated_reachable.has(species_id),
            "Registriertes Pokémon ist global nicht systemgenerierbar: %s" % species_id
        )

    # PvP is deterministic at catalog level. Random shuffling is only presentation:
    # late and legendary Pokemon must already be present in the flat source pool.
    var catalog_50: Array = battle.pvp_catalog(50)
    var catalog_50_ids: Dictionary = _catalog_ids(catalog_50)
    for sentinel_id: String in PVP_LEVEL_50_SENTINELS:
        _check(
            catalog_50_ids.has(sentinel_id),
            "Spätes/legendäres Pokémon fehlt im PvP-Katalog auf Level 50: %s" % sentinel_id
        )

    var catalog_60_ids: Dictionary = _catalog_ids(battle.pvp_catalog(60))
    _check(
        catalog_60_ids.has("dragonite"),
        "Dragoran muss nach seiner Pflichtentwicklung im PvP-Katalog auf Level 60 vorkommen."
    )

    for entry_value: Variant in catalog_50:
        if not (entry_value is Dictionary):
            continue
        var moves_value: Variant = (entry_value as Dictionary).get("moves", [])
        _check(
            moves_value is Array and not (moves_value as Array).is_empty(),
            "Kein PvP-Kandidat darf wegen unvollständiger Attacken ohne Kampfaktion bleiben."
        )

    _finish(battle)


func _check_single_master_storage_contract() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    _check(not manifest.is_empty(), "Das v8-Roster-Manifest muss lesbar sein.")
    if manifest.is_empty():
        return

    var master_path: String = str(manifest.get("species_master_file", ""))
    _check(master_path == EXPECTED_MASTER_PATH, "Der Roster muss genau die festgelegte Masterdatei benutzen.")

    var species_files_value: Variant = manifest.get("species_files", [])
    _check(species_files_value is Array, "species_files muss eine Liste sein.")
    if species_files_value is Array:
        var species_files: Array = species_files_value
        _check(
            species_files.size() == 1 and str(species_files[0]) == EXPECTED_MASTER_PATH,
            "Für Roster-Mitgliedschaft darf es exakt eine Pokémon-Masterdatei geben."
        )

    var master: Dictionary = _read_json(master_path)
    var master_species_value: Variant = master.get("species", {})
    _check(master_species_value is Dictionary, "Die Pokémon-Masterdatei braucht ein species-Dictionary.")
    if master_species_value is Dictionary:
        var master_species: Dictionary = master_species_value
        _check(
            master_species.size() == EXPECTED_SPECIES_COUNT,
            "Die eine Masterdatei muss exakt %d Pokémon enthalten, gefunden wurden %d."
            % [EXPECTED_SPECIES_COUNT, master_species.size()]
        )
        for sentinel_id: String in SENTINEL_SPECIES:
            _check(master_species.has(sentinel_id), "Pflicht-Pokémon fehlt in der Masterdatei: %s" % sentinel_id)

    for list_key: String in ["species_files", "species_detail_files", "move_files"]:
        var paths_value: Variant = manifest.get(list_key, [])
        if not (paths_value is Array):
            continue
        for path_value: Variant in paths_value:
            _check(
                not str(path_value).to_lower().ends_with(".gz"),
                "Im aktiven v8-Datenpfad darf keine GZIP-Datei mehr vorkommen: %s" % str(path_value)
            )


func _catalog_ids(catalog: Array) -> Dictionary:
    var result: Dictionary = {}
    for entry_value: Variant in catalog:
        if entry_value is Dictionary:
            var species_id: String = str((entry_value as Dictionary).get("id", ""))
            if not species_id.is_empty():
                result[species_id] = true
    return result


func _read_json(path: String) -> Dictionary:
    if path.is_empty():
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}


func _finish(battle: Node) -> void:
    battle.queue_free()
    if failures == 0:
        print("Gen1 runtime roster integrity test: PASS")
        quit(0)
    push_error("Gen1 runtime roster integrity test: %d Fehler" % failures)
    quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
