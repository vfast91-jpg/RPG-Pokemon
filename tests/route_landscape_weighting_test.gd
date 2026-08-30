extends SceneTree

const RouteScript = preload("res://scripts/demo_route_landscape_weighting_v1.gd")
const BattleScript = preload("res://scripts/battle_demo_pvp.gd")
const LANDSCAPE_DATA_PATH: String = "res://data/landscapes_v1.json"
const CANONICAL_TYPES: Array[String] = [
    "normal", "fire", "water", "electric", "grass", "ice", "fighting",
    "poison", "ground", "flying", "psychic", "bug", "rock", "ghost",
    "dragon", "dark", "steel", "fairy"
]

const EXPECTED: Dictionary = {
    "meadow": [["normal", "grass", "flying"], ["fire", "electric", "rock", "dragon", "steel"], ["ghost", "dark"]],
    "forest": [["grass", "bug", "fairy"], ["fire", "fighting", "ground", "dark", "steel"], ["rock", "dragon"]],
    "jungle": [["grass", "poison", "bug"], ["fire", "ice", "flying", "rock", "ghost"], ["psychic", "steel"]],
    "desert": [["fire", "ground", "rock"], ["water", "grass", "dark", "steel", "fairy"], ["ice", "fighting"]],
    "canyon": [["fighting", "ground", "rock"], ["normal", "poison", "flying", "psychic", "fairy"], ["water", "grass"]],
    "lakeshore": [["water", "flying", "bug"], ["normal", "fighting", "ghost", "dark", "steel"], ["ground", "rock"]],
    "coast": [["water", "electric", "flying"], ["fire", "psychic", "bug", "ghost", "dragon"], ["fighting", "ground"]],
    "swamp": [["poison", "ghost", "dark"], ["fire", "fighting", "rock", "dragon", "fairy"], ["electric", "steel"]],
    "mountains": [["ice", "fighting", "dragon"], ["grass", "poison", "psychic", "bug", "fairy"], ["water", "ghost"]],
    "tundra": [["ice", "steel", "fairy"], ["electric", "grass", "poison", "flying", "ghost"], ["fire", "bug"]],
    "volcano": [["fire", "ground", "rock"], ["normal", "water", "grass", "psychic", "fairy"], ["ice", "bug"]],
    "cave": [["poison", "ghost", "dark"], ["normal", "electric", "ice", "bug", "dragon"], ["flying", "fairy"]],
    "city": [["normal", "electric", "steel"], ["water", "ice", "ground", "rock", "dark"], ["psychic", "dragon"]],
    "industry": [["fire", "electric", "steel"], ["ice", "poison", "psychic", "bug", "dragon"], ["grass", "fairy"]],
    "ruins": [["psychic", "ghost", "dark"], ["water", "grass", "fighting", "flying", "bug"], ["normal", "electric"]],
    "mystic": [["psychic", "dragon", "fairy"], ["fighting", "ground", "rock", "ghost", "steel"], ["normal", "poison"]],
    "glacier": [["water", "ice", "dragon"], ["normal", "electric", "poison", "ground", "dark"], ["fire", "flying"]],
    "temple": [["normal", "fighting", "psychic"], ["water", "electric", "ice", "ground", "flying"], ["poison", "dark"]]
}


func _initialize() -> void:
    var file: FileAccess = FileAccess.open(LANDSCAPE_DATA_PATH, FileAccess.READ)
    assert(file != null, "Landschaftsregister muss vorhanden sein.")
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    assert(parsed is Dictionary, "Landschaftsregister muss gültiges JSON sein.")
    var registry: Dictionary = parsed as Dictionary
    assert(int(registry.get("schema_version", 0)) >= 4, "Vierstufige Typgewichtungen brauchen Schema-Version 4 oder höher.")

    var entries_value: Variant = registry.get("landscapes", [])
    assert(entries_value is Array, "Landschaftsregister braucht eine Liste.")
    var entries: Array = entries_value as Array
    assert(entries.size() == 18, "Es müssen exakt 18 gewichtete Landschaften existieren.")

    var preferred_counts: Dictionary = {}
    var normal_counts: Dictionary = {}
    var rare_counts: Dictionary = {}
    var excluded_counts: Dictionary = {}
    for type_id: String in CANONICAL_TYPES:
        preferred_counts[type_id] = 0
        normal_counts[type_id] = 0
        rare_counts[type_id] = 0
        excluded_counts[type_id] = 0

    var by_id: Dictionary = {}
    for entry_value: Variant in entries:
        assert(entry_value is Dictionary, "Jede Landschaft muss ein Dictionary sein.")
        var entry: Dictionary = entry_value as Dictionary
        var landscape_id: String = str(entry.get("id", ""))
        var preferred_value: Variant = entry.get("preferred_types", [])
        var rare_value: Variant = entry.get("rare_types", [])
        var excluded_value: Variant = entry.get("excluded_types", [])
        assert(preferred_value is Array, "preferred_types muss eine Liste sein: " + landscape_id)
        assert(rare_value is Array, "rare_types muss eine Liste sein: " + landscape_id)
        assert(excluded_value is Array, "excluded_types muss eine Liste sein: " + landscape_id)
        var preferred: Array = preferred_value as Array
        var rare: Array = rare_value as Array
        var excluded: Array = excluded_value as Array

        assert(preferred.size() == 3, "Jede Landschaft braucht exakt drei x8-Typen: " + landscape_id)
        assert(rare.size() == 5, "Jede Landschaft braucht exakt fünf x0.2-Typen: " + landscape_id)
        assert(excluded.size() == 2, "Jede Landschaft braucht exakt zwei x0-Typen: " + landscape_id)

        for type_id: String in CANONICAL_TYPES:
            var category_count: int = int(preferred.has(type_id)) + int(rare.has(type_id)) + int(excluded.has(type_id))
            assert(category_count <= 1, "Typ darf in einer Landschaft nur einer Sonderkategorie angehören: %s / %s" % [landscape_id, type_id])
            if preferred.has(type_id):
                preferred_counts[type_id] = int(preferred_counts[type_id]) + 1
            elif rare.has(type_id):
                rare_counts[type_id] = int(rare_counts[type_id]) + 1
            elif excluded.has(type_id):
                excluded_counts[type_id] = int(excluded_counts[type_id]) + 1
            else:
                normal_counts[type_id] = int(normal_counts[type_id]) + 1

        for type_value: Variant in preferred:
            assert(CANONICAL_TYPES.has(str(type_value)), "Ungültiger x8-Typ: " + str(type_value))
        for type_value: Variant in rare:
            assert(CANONICAL_TYPES.has(str(type_value)), "Ungültiger x0.2-Typ: " + str(type_value))
        for type_value: Variant in excluded:
            assert(CANONICAL_TYPES.has(str(type_value)), "Ungültiger x0-Typ: " + str(type_value))

        by_id[landscape_id] = entry

    assert(by_id.size() == EXPECTED.size(), "Alle 18 erwarteten Landschafts-IDs müssen vorhanden sein.")
    for landscape_id_value: Variant in EXPECTED.keys():
        var landscape_id: String = str(landscape_id_value)
        assert(by_id.has(landscape_id), "Landschaft fehlt: " + landscape_id)
        var expected_groups: Array = EXPECTED[landscape_id]
        var entry: Dictionary = by_id[landscape_id]
        assert(entry.get("preferred_types", []) == expected_groups[0], "x8-Matrix falsch: " + landscape_id)
        assert(entry.get("rare_types", []) == expected_groups[1], "x0.2-Matrix falsch: " + landscape_id)
        assert(entry.get("excluded_types", []) == expected_groups[2], "x0-Matrix falsch: " + landscape_id)

    # Vollständige Symmetrie: Jeder Typ ist über 18 Landschaften exakt
    # 3x stark bevorzugt, 8x normal, 5x selten und 2x ausgeschlossen.
    for type_id: String in CANONICAL_TYPES:
        assert(int(preferred_counts[type_id]) == 3, "%s muss exakt 3x x8 sein." % type_id)
        assert(int(normal_counts[type_id]) == 8, "%s muss exakt 8x x1 sein." % type_id)
        assert(int(rare_counts[type_id]) == 5, "%s muss exakt 5x x0.2 sein." % type_id)
        assert(int(excluded_counts[type_id]) == 2, "%s muss exakt 2x x0 sein." % type_id)

    var route = RouteScript.new()
    route._tf_load_landscape_registry()

    assert(is_equal_approx(route.route_landscape_type_multiplier(["grass"], "meadow"), 8.0), "Wiese: Pflanze muss x8 sein.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["water"], "meadow"), 1.0), "Wiese: Wasser muss x1 sein.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["fire"], "meadow"), 0.2), "Wiese: Feuer muss x0.2 sein.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["ghost"], "meadow"), 0.0), "Wiese: Geist muss x0 sein.")

    # Bei Doppeltypen zählt ausschließlich Typ 1.
    assert(is_equal_approx(route.route_landscape_type_multiplier(["grass", "ghost"], "meadow"), 8.0), "Typ 2 darf einen x8-Primärtyp nicht verändern.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["ghost", "grass"], "meadow"), 0.0), "Ein x0-Primärtyp bleibt trotz bevorzugtem Typ 2 ausgeschlossen.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["fire", "normal"], "meadow"), 0.2), "Ein x0.2-Primärtyp bleibt trotz normalem Typ 2 selten.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["electric", "steel"], "tundra"), 0.2), "Magnetilo-Prinzip: Elektro/Stahl muss in der Tundra nach Elektro x0.2 sein.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["steel", "electric"], "tundra"), 8.0), "Umgekehrte Typreihenfolge muss nach Stahl x8 sein.")

    assert(is_equal_approx(route.route_landscape_combined_weight(7.5, ["water"], "meadow"), 7.5), "x1 muss die bestehende Seltenheitsgewichtung unverändert lassen.")
    assert(is_equal_approx(route.route_landscape_combined_weight(7.5, ["grass"], "meadow"), 60.0), "x8 muss die bestehende Seltenheitsgewichtung multiplizieren.")
    assert(is_equal_approx(route.route_landscape_combined_weight(7.5, ["fire"], "meadow"), 1.5), "x0.2 muss die bestehende Seltenheitsgewichtung multiplizieren.")
    assert(is_equal_approx(route.route_landscape_combined_weight(7.5, ["ghost"], "meadow"), 0.0), "x0 muss einen Kandidaten strikt ausschließen.")

    # Die Landschaftsschicht darf das feste Gesamtgewicht des Legendären-Pools
    # nicht wieder mit x8/x0.2 multiplizieren. Auch hier bleibt er bei allen drei
    # Suchen exakt 0.05 relativ zu einer Fangrate-45-Familie.
    route.stage = 95
    for search_number: int in [1, 2, 3]:
        var reference_45: float = route._capture_family_weight("bulbasaur", search_number)
        var legendary_pool: float = route._capture_legendary_pool_weight(search_number)
        assert(
            is_equal_approx(legendary_pool / reference_45, 0.05),
            "Landschaftsschicht muss Legendären-Pool bei Suche %d auf exakt 0.05 halten." % search_number
        )

    var battle = BattleScript.new()
    root.add_child(battle)
    route.battle_demo = battle
    route.team = [{"species_id": "bulbasaur", "level": 30, "hp": 80, "max_hp": 80}]

    var generated_eevee: String = route._tf_generated_capture_species("eevee", 30)
    assert(not generated_eevee.is_empty(), "Fangwiese muss einen konkreten Evoli-Systemzweig erzeugen können.")
    assert(
        battle.route_generated_species_options_for_level("eevee", 30).has(generated_eevee),
        "Der Fangwiesen-Zweig muss eine gültige Evoli-Entwicklung sein."
    )
    assert(
        route._resolve_capture_species_for_root("eevee", 30) == generated_eevee,
        "Landschaftsgewichtung und anschließendes Fangangebot müssen exakt denselben Entwicklungszweig verwenden."
    )

    # Legendäre behalten den Landschafts-Sonderstatus: x0 schließt eine Familie
    # weiterhin strikt aus. Sobald ihr Primärtyp erlaubt ist, kann dieselbe Familie
    # innerhalb des gemeinsamen Legendären-Pools ausgewählt werden.
    assert(battle.route_species_is_available("mew"), "Mew muss für den Landschafts-Legendären-Test verfügbar sein.")
    route.current_landscape_id = "city"
    route._tf_capture_generated_species_by_root.clear()
    var excluded_mew: String = route._tf_weighted_capture_root_from_candidates(["mew"], 1)
    assert(excluded_mew.is_empty(), "Stadt x0 für Psycho muss Mew auch im Legendären-Pool strikt ausschließen.")

    route.current_landscape_id = "ruins"
    route._tf_capture_generated_species_by_root.clear()
    var allowed_mew: String = route._tf_weighted_capture_root_from_candidates(["mew"], 1)
    assert(allowed_mew == "mew", "Ruinen x8 für Psycho muss Mew innerhalb des Legendären-Pools erlauben.")

    battle.queue_free()
    route.free()
    print("Route landscape weighting test: OK")
    quit(0)
