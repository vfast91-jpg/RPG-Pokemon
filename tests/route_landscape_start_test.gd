extends SceneTree

const RouteScript = preload("res://scripts/demo_route_landscape_start_v1.gd")
const BattleBackgroundScript = preload("res://scripts/battle_demo_stat_profiles.gd")
const LANDSCAPE_DATA_PATH: String = "res://data/landscapes_v1.json"
const EXPECTED_COUNT: int = 18
const EXPECTED_MEADOW_PATH: String = "res://assets/battle_backgrounds/landscapes/01_meadow_grassland.jpg"


func _initialize() -> void:
    var file: FileAccess = FileAccess.open(LANDSCAPE_DATA_PATH, FileAccess.READ)
    assert(file != null, "Landschaftsregister muss vorhanden sein.")
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    assert(parsed is Dictionary, "Landschaftsregister muss gültiges JSON sein.")

    var registry: Dictionary = parsed as Dictionary
    assert(int(registry.get("schema_version", 0)) >= 3, "Landschaftsregister braucht Framing-Schema v3.")
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

        var framing_value: Variant = entry.get("battle_framing", null)
        assert(framing_value is Dictionary, "Landschaft braucht battle_framing: " + landscape_id)
        var framing: Dictionary = framing_value as Dictionary
        var zoom: float = float(framing.get("zoom", 0.0))
        var focus_x: float = float(framing.get("focus_x", -1.0))
        var focus_y: float = float(framing.get("focus_y", -1.0))
        assert(zoom >= 1.0 and zoom <= 1.35, "Battle-Framing darf nicht wieder extrem hineinzoomen: " + landscape_id)
        assert(focus_x >= 0.0 and focus_x <= 1.0, "focus_x ungültig: " + landscape_id)
        assert(focus_y >= 0.0 and focus_y <= 1.0, "focus_y ungültig: " + landscape_id)
        assert(framing.has("offset_x") and framing.has("offset_y"), "Battle-Framing braucht Offsets: " + landscape_id)

        if landscape_id == "meadow":
            meadow_found = true
            assert(background == EXPECTED_MEADOW_PATH, "Wiese muss auf das korrekte Bild zeigen.")

    assert(meadow_found, "Wiese / Ebene muss registriert sein.")

    var route = RouteScript.new()
    assert(route.route_current_landscape_id() == "meadow", "Neue Route muss mit meadow initialisiert sein.")
    route._tf_load_landscape_registry()
    var meadow: Dictionary = route.route_landscape("meadow")
    assert(str(meadow.get("background", "")) == EXPECTED_MEADOW_PATH, "Route muss das Wiesenbild auflösen.")
    assert(meadow.get("battle_framing", null) is Dictionary, "Route muss Battle-Framing mitführen.")
    route.free()

    var battle_background = BattleBackgroundScript.new()
    assert(battle_background.has_method("set_battle_background_framed"), "BattleDemo braucht framed background setter.")
    battle_background.free()

    print("Route landscape start test: OK")
    quit(0)
