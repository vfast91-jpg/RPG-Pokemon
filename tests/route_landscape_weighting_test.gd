extends SceneTree

const RouteScript = preload("res://scripts/demo_route_landscape_weighting_v1.gd")
const LANDSCAPE_DATA_PATH: String = "res://data/landscapes_v1.json"
const CANONICAL_TYPES: Array[String] = [
    "normal", "fire", "water", "electric", "grass", "ice", "fighting",
    "poison", "ground", "flying", "psychic", "bug", "rock", "ghost",
    "dragon", "dark", "steel", "fairy"
]

const EXPECTED: Dictionary = {
    "meadow": [["normal", "grass", "flying"], ["ghost", "dark"]],
    "forest": [["grass", "bug", "fairy"], ["rock", "dragon"]],
    "jungle": [["grass", "poison", "bug"], ["psychic", "steel"]],
    "desert": [["fire", "ground", "rock"], ["ice", "fighting"]],
    "canyon": [["fighting", "ground", "rock"], ["water", "grass"]],
    "lakeshore": [["water", "flying", "bug"], ["ground", "rock"]],
    "coast": [["water", "electric", "flying"], ["fighting", "ground"]],
    "swamp": [["poison", "ghost", "dark"], ["electric", "steel"]],
    "mountains": [["ice", "fighting", "dragon"], ["water", "ghost"]],
    "tundra": [["ice", "steel", "fairy"], ["fire", "bug"]],
    "volcano": [["fire", "ground", "rock"], ["ice", "bug"]],
    "cave": [["poison", "ghost", "dark"], ["flying", "fairy"]],
    "city": [["normal", "electric", "steel"], ["psychic", "dragon"]],
    "industry": [["fire", "electric", "steel"], ["grass", "fairy"]],
    "ruins": [["psychic", "ghost", "dark"], ["normal", "electric"]],
    "mystic": [["psychic", "dragon", "fairy"], ["normal", "poison"]],
    "glacier": [["water", "ice", "dragon"], ["fire", "flying"]],
    "temple": [["normal", "fighting", "psychic"], ["poison", "dark"]]
}


func _initialize() -> void:
    var file: FileAccess = FileAccess.open(LANDSCAPE_DATA_PATH, FileAccess.READ)
    assert(file != null, "Landschaftsregister muss vorhanden sein.")
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    assert(parsed is Dictionary, "Landschaftsregister muss gültiges JSON sein.")
    var registry: Dictionary = parsed as Dictionary
    assert(int(registry.get("schema_version", 0)) >= 2, "Typgewichtungen brauchen Schema-Version 2 oder höher.")

    var entries_value: Variant = registry.get("landscapes", [])
    assert(entries_value is Array, "Landschaftsregister braucht eine Liste.")
    var entries: Array = entries_value as Array
    assert(entries.size() == 18, "Es müssen exakt 18 gewichtete Landschaften existieren.")

    var by_id: Dictionary = {}
    for entry_value: Variant in entries:
        assert(entry_value is Dictionary, "Jede Landschaft muss ein Dictionary sein.")
        var entry: Dictionary = entry_value as Dictionary
        var landscape_id: String = str(entry.get("id", ""))
        var preferred_value: Variant = entry.get("preferred_types", [])
        var excluded_value: Variant = entry.get("excluded_types", [])
        assert(preferred_value is Array, "preferred_types muss eine Liste sein: " + landscape_id)
        assert(excluded_value is Array, "excluded_types muss eine Liste sein: " + landscape_id)
        var preferred: Array = preferred_value as Array
        var excluded: Array = excluded_value as Array
        assert(preferred.size() == 3, "Jede Landschaft braucht exakt drei x3-Typen: " + landscape_id)
        assert(excluded.size() == 2, "Jede Landschaft braucht exakt zwei x0-Typen: " + landscape_id)
        for type_value: Variant in preferred:
            var type_id: String = str(type_value)
            assert(CANONICAL_TYPES.has(type_id), "Ungültiger bevorzugter Typ: " + type_id)
            assert(not excluded.has(type_id), "Typ darf nicht gleichzeitig x3 und x0 sein: " + type_id)
        for type_value: Variant in excluded:
            var type_id: String = str(type_value)
            assert(CANONICAL_TYPES.has(type_id), "Ungültiger ausgeschlossener Typ: " + type_id)
        by_id[landscape_id] = entry

    assert(by_id.size() == EXPECTED.size(), "Alle 18 erwarteten Landschafts-IDs müssen vorhanden sein.")
    for landscape_id_value: Variant in EXPECTED.keys():
        var landscape_id: String = str(landscape_id_value)
        assert(by_id.has(landscape_id), "Landschaft fehlt: " + landscape_id)
        var expected_pair: Array = EXPECTED[landscape_id]
        var entry: Dictionary = by_id[landscape_id]
        assert(entry.get("preferred_types", []) == expected_pair[0], "x3-Matrix falsch: " + landscape_id)
        assert(entry.get("excluded_types", []) == expected_pair[1], "x0-Matrix falsch: " + landscape_id)

    var route = RouteScript.new()
    route._tf_load_landscape_registry()

    assert(is_equal_approx(route.route_landscape_type_multiplier(["grass"], "meadow"), 3.0), "Wiese: Pflanze muss x3 sein.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["water"], "meadow"), 1.0), "Wiese: Wasser muss x1 sein.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["ghost"], "meadow"), 0.0), "Wiese: Geist muss x0 sein.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["normal", "flying"], "meadow"), 3.0), "Zwei bevorzugte Typen dürfen nicht zu x9 stapeln.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["grass", "ghost"], "meadow"), 0.0), "x0 muss bei Doppeltypen Vorrang vor x3 haben.")
    assert(is_equal_approx(route.route_landscape_type_multiplier(["fire", "rock"], "desert"), 3.0), "Wüste: zwei bevorzugte Typen bleiben x3.")

    assert(is_equal_approx(route.route_landscape_combined_weight(7.5, ["water"], "meadow"), 7.5), "x1 muss die bestehende Seltenheitsgewichtung unverändert lassen.")
    assert(is_equal_approx(route.route_landscape_combined_weight(7.5, ["grass"], "meadow"), 22.5), "x3 muss die bestehende Seltenheitsgewichtung multiplizieren.")
    assert(is_equal_approx(route.route_landscape_combined_weight(7.5, ["ghost"], "meadow"), 0.0), "x0 muss einen Kandidaten strikt ausschließen.")

    route.free()
    print("Route landscape weighting test: OK")
    quit(0)
