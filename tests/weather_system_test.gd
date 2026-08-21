extends SceneTree

const WeatherStateScript = preload("res://scripts/battle/weather_state.gd")
const BattleDemoScript = preload("res://scripts/battle_demo_timeflow_weather.gd")


func _initialize() -> void:
    _test_weather_data_contract()
    _test_continuous_active_time_duration()
    _test_pause_freezes_weather()
    _test_same_weather_cannot_refresh()
    _test_different_weather_replaces_and_restarts()
    _test_weather_damage_modifiers()
    _test_weather_hud_sits_below_type_button()
    _test_active_weather_move_is_disabled_for_player()
    _test_weather_ends_at_zero()
    print("Weather system behavior tests: OK")
    quit(0)


func _fresh_demo():
    var demo = BattleDemoScript.new()
    demo.process_mode = Node.PROCESS_MODE_DISABLED
    get_root().add_child(demo)
    assert(not demo.data.is_empty(), "BattleDemo muss seine echten Laufzeitdaten geladen haben.")
    assert(demo.log_label != null, "BattleDemo muss die echte Battle-Log-UI aufgebaut haben.")
    assert(demo.weather_label != null, "BattleDemo muss die Wetterbezeichnung aufgebaut haben.")
    assert(demo.weather_bar != null, "BattleDemo muss die Timeflow-Wetterleiste aufgebaut haben.")
    demo.battle_active = true
    demo.paused = false
    demo.log_label.text = ""
    demo.combatants = []
    return demo


func _source_for_demo(demo) -> Dictionary:
    var source: Dictionary = demo._make_combatant(
        "player", 0, {"species_id": "squirtle", "level": 10}
    )
    source["hp"] = source["max_hp"]
    source["alive"] = true
    return source


func _activate_rain(demo, source: Dictionary) -> void:
    demo._execute_move(source, "rain_dance")
    assert(demo.current_weather_id() == "rain", "Regentanz muss global rain aktivieren.")


func _test_weather_data_contract() -> void:
    var demo = _fresh_demo()
    var rain_move: Dictionary = demo._move_data("rain_dance")
    assert(str(rain_move.get("name", "")) == "Regentanz", "Regentanz muss verfügbar sein.")
    var rain_weather: Dictionary = rain_move.get("weather", {})
    assert(rain_weather.keys() == ["weather_id"], "Wetterattacken dürfen nur die weather_id tragen.")
    assert(str(rain_weather.get("weather_id", "")) == "rain", "Regentanz muss rain aktivieren.")

    var definition: Dictionary = demo.battle_weather.definition("rain")
    assert(
        is_equal_approx(float(definition.get("duration_seconds", 0.0)), 50.0),
        "Normales Wetter muss 50 Sekunden aktive Kampfzeit dauern."
    )
    assert(
        str(definition.get("duration_mode", "")) == "active_battle_time",
        "Wetterdauer muss an aktive Kampfzeit gebunden sein."
    )


func _test_continuous_active_time_duration() -> void:
    var demo = _fresh_demo()
    var source: Dictionary = _source_for_demo(demo)
    _activate_rain(demo, source)

    _assert_close(
        float(demo.current_weather_state().get("remaining_seconds", 0.0)),
        50.0,
        "Regen muss mit einer einzigen vollen 50-Sekunden-Leiste starten."
    )
    demo._process(12.5)
    _assert_close(
        float(demo.current_weather_state().get("remaining_seconds", 0.0)),
        37.5,
        "Die Wetterleiste muss kontinuierlich mit aktiver Kampfzeit sinken."
    )
    _assert_close(
        float(demo.weather_bar.value),
        0.75,
        "Nach 12,5 von 50 Sekunden muss die sichtbare Wetterleiste bei 75% stehen."
    )


func _test_pause_freezes_weather() -> void:
    var demo = _fresh_demo()
    var source: Dictionary = _source_for_demo(demo)
    _activate_rain(demo, source)
    demo._process(10.0)
    var before_pause: float = demo.battle_weather.remaining_seconds()

    demo.paused = true
    demo._process(20.0)
    _assert_close(
        demo.battle_weather.remaining_seconds(),
        before_pause,
        "Aktionsauswahl/Pause darf keine Wetterzeit verbrauchen."
    )


func _test_same_weather_cannot_refresh() -> void:
    var demo = _fresh_demo()
    var source: Dictionary = _source_for_demo(demo)
    _activate_rain(demo, source)
    demo._process(18.0)
    var remaining_before: float = demo.battle_weather.remaining_seconds()

    demo._execute_move(source, "rain_dance")
    assert(demo.current_weather_id() == "rain", "Dasselbe Wetter muss aktiv bleiben.")
    _assert_close(
        demo.battle_weather.remaining_seconds(),
        remaining_before,
        "Regentanz darf laufenden Regen nicht auf 50 Sekunden zurücksetzen."
    )
    assert(
        demo.log_label.get_parsed_text().contains("nicht erneuert"),
        "Ein erzwungener Wiederholungsversuch soll verständliches Feedback geben."
    )


func _test_different_weather_replaces_and_restarts() -> void:
    var demo = _fresh_demo()
    var source: Dictionary = _source_for_demo(demo)
    _activate_rain(demo, source)
    demo._process(33.0)

    demo._execute_move(source, "sunny_day")
    assert(demo.current_weather_id() == "sun", "Sonnentag muss Regen sofort ersetzen.")
    _assert_close(
        demo.battle_weather.remaining_seconds(),
        50.0,
        "Ein anderes Wetter muss mit seiner vollständigen 50-Sekunden-Leiste starten."
    )


func _test_weather_damage_modifiers() -> void:
    var state = WeatherStateScript.new()
    state.configure({
        "rain": {
            "display_name": "Regen",
            "emoji": "🌧️",
            "effect_strength_percent": 50.0,
            "duration_seconds": 50.0,
            "duration_mode": "active_battle_time",
            "damage_type_strength_coefficients": {"water": 1.0, "fire": -1.0}
        }
    })
    var source: Dictionary = {"battle_instance_id": "player:0:test:1", "id": "player_0"}
    assert(bool(state.activate("rain", source).get("ok", false)), "Regen muss aktivierbar sein.")
    _assert_close(state.damage_multiplier("water"), 1.5, "Regen muss Wasser um 50% verstärken.")
    _assert_close(state.damage_multiplier("fire"), 0.5, "Regen muss Feuer um 50% schwächen.")
    _assert_close(state.damage_multiplier("normal"), 1.0, "Andere Typen bleiben unverändert.")


func _test_weather_hud_sits_below_type_button() -> void:
    var demo = _fresh_demo()
    assert(demo._type_help_button != null, "Der TYPEN-Button muss existieren.")
    assert(
        demo.weather_label.offset_top >= demo._type_help_button.offset_bottom,
        "Die Wetterbezeichnung darf den TYPEN-Button nicht überlagern."
    )
    assert(
        demo.weather_bar.offset_top >= demo.weather_label.offset_bottom,
        "Die Wetterleiste muss direkt unter der Wetterbezeichnung liegen."
    )


func _test_active_weather_move_is_disabled_for_player() -> void:
    var demo = _fresh_demo()
    var source: Dictionary = _source_for_demo(demo)
    source["moves"] = ["rain_dance", "sunny_day"]
    _activate_rain(demo, source)

    demo._prompt_player(source)
    var buttons: Array[Button] = []
    for child: Node in demo.action_grid.get_children():
        if child is Button:
            buttons.append(child as Button)
    assert(buttons.size() >= 2, "Beide Wetterattacken müssen als Aktionsbuttons vorhanden sein.")
    assert(buttons[0].disabled, "Regentanz muss bei bereits aktivem Regen deaktiviert sein.")
    assert(not buttons[1].disabled, "Sonnentag muss Regen weiterhin ersetzen können.")


func _test_weather_ends_at_zero() -> void:
    var demo = _fresh_demo()
    var source: Dictionary = _source_for_demo(demo)
    _activate_rain(demo, source)
    demo._process(50.1)

    assert(demo.current_weather_id().is_empty(), "Nach 50 Sekunden aktiver Kampfzeit muss Regen enden.")
    assert(not demo.weather_label.visible, "Nach Wetterende muss die Wetterbezeichnung verschwinden.")
    assert(not demo.weather_bar.visible, "Nach Wetterende muss die Wetterleiste verschwinden.")
    assert(
        demo.log_label.get_parsed_text().contains("Der Regen hört auf."),
        "Das Battle-Log muss das Wetterende melden."
    )


func _assert_close(actual: float, expected: float, message: String) -> void:
    assert(absf(actual - expected) < 0.001, message + " Erwartet: %s, erhalten: %s" % [expected, actual])
