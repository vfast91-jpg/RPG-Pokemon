extends SceneTree

const RouteScript = preload("res://scripts/demo_route_landscape_start_v1.gd")
const LANDSCAPE_DATA_PATH: String = "res://data/landscapes_v1.json"
const EXPECTED_COUNT: int = 18
const EXPECTED_MEADOW_PATH: String = "res://assets/battle_backgrounds/landscapes/01_meadow_grassland.jpg"


func _initialize() -> void:
    var file: FileAccess = FileAccess.open(LANDSCAPE_DATA_PATH, FileAccess.READ)
    assert(file != null, "Landschaftsregister muss vorhanden sein.")
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    assert(parsed is Dictionary, "Landschaftsregister muss gültiges JSON sein.")

    var registry: Dictionary = parsed as Dictionary
    assert(str(registry.get("default_landscape", "")) == "meadow", "Startlandschaft muss meadow sein.")
    var entries_value: Variant = registry.get("landscapes", [])
    assert(entries_value is Array, "Landschaftsregister braucht eine Liste.")
    var entries: Array = entries_value as Array
    assert(entries.size() == EXPECTED_COUNT, "Es müssen exakt 18 Landschaften registriert sein.")

    var ids: Dictionary = {}
    var meadow_found: bool = false
    for entry_value: Variant in entries:
        assert(entry_value is Dictionary, "Jeder Landschaftseintrag muss ein Dictionary sein.")
        var entry: Dictionary = entry_value as Dictionary
        var landscape_id: String = str(entry.get("id", ""))
        var background: String = str(entry.get("background", ""))
        assert(not landscape_id.is_empty(), "Jede Landschaft braucht eine ID.")
        assert(not ids.has(landscape_id), "Landschafts-IDs müssen eindeutig sein: " + landscape_id)
        ids[landscape_id] = true
        assert(background.ends_with(".jpg"), "Landschaft muss auf JPG zeigen: " + landscape_id)
        assert(FileAccess.file_exists(background), "Landschaftsbild fehlt: " + background)
        if landscape_id == "meadow":
            meadow_found = true
            assert(background == EXPECTED_MEADOW_PATH, "Wiese muss auf das korrekte Bild zeigen.")

    assert(meadow_found, "Wiese / Ebene muss registriert sein.")

    var route = RouteScript.new()
    assert(route.route_current_landscape_id() == "meadow", "Neue Route muss mit meadow initialisiert sein.")
    route._tf_load_landscape_registry()
    var meadow: Dictionary = route.route_landscape("meadow")
    assert(str(meadow.get("background", "")) == EXPECTED_MEADOW_PATH, "Route muss das Wiesenbild auflösen.")
    route.free()

    print("Route landscape start test: OK")
    quit(0)
