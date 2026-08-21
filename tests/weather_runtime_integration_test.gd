extends SceneTree

const RuntimeBattleScript = preload("res://scripts/battle_demo_timeflow_weather.gd")


func _initialize() -> void:
    var demo = RuntimeBattleScript.new()
    demo.process_mode = Node.PROCESS_MODE_DISABLED
    get_root().add_child(demo)

    assert(not demo.data.is_empty(), "Die echte Battle-Demo muss Laufzeitdaten geladen haben.")
    assert(
        demo._move_data("rain_dance").get("name", "") == "Regentanz",
        "Regentanz muss im echten Runtime-Leaf verfügbar sein."
    )
    assert(demo.weather_bar != null, "Der echte Runtime-Leaf muss die Wetterleiste besitzen.")

    var source: Dictionary = demo._make_combatant(
        "player", 0, {"species_id": "squirtle", "level": 10}
    )
    var enemy: Dictionary = demo._make_combatant(
        "enemy", 0, {"species_id": "rattata", "level": 10}
    )
    source["hp"] = source["max_hp"]
    enemy["hp"] = 9999
    enemy["max_hp"] = 9999
    enemy["alive"] = true

    demo.player_team = [source]
    demo.enemy_team = [enemy]
    demo.combatants = []
    demo.battle_active = true
    demo.paused = false
    demo.log_label.text = ""

    demo._execute_move(source, "rain_dance")
    assert(
        demo.current_weather_id() == "rain",
        "Regentanz muss auch im vollständigen Battle-Layer rain aktivieren."
    )
    assert(
        is_equal_approx(demo.battle_weather.remaining_seconds(), 50.0),
        "Der echte Runtime-Leaf muss mit 50 Sekunden Wetterzeit starten."
    )
    assert(
        is_equal_approx(
            float(demo.current_weather_state().get("strength_percent", 0.0)),
            50.0
        ),
        "Die Wetterstärke muss aus der zentralen Wetterdefinition kommen."
    )

    demo._process(10.0)
    assert(
        is_equal_approx(demo.battle_weather.remaining_seconds(), 40.0),
        "Zehn Sekunden aktive Kampfzeit müssen zehn Sekunden Wetterzeit verbrauchen."
    )

    demo._execute_move(source, "rain_dance")
    assert(
        is_equal_approx(demo.battle_weather.remaining_seconds(), 40.0),
        "Dasselbe Wetter darf im echten Runtime-Leaf nicht erneuert werden."
    )

    demo._execute_move(source, "sunny_day")
    assert(demo.current_weather_id() == "sun", "Sonnentag muss Regen ersetzen können.")
    assert(
        is_equal_approx(demo.battle_weather.remaining_seconds(), 50.0),
        "Das ersetzende Wetter muss mit einer vollen 50-Sekunden-Leiste starten."
    )

    demo.paused = true
    demo._process(25.0)
    assert(
        is_equal_approx(demo.battle_weather.remaining_seconds(), 50.0),
        "Während Aktionsauswahl/Pause darf die Wetterzeit nicht weiterlaufen."
    )

    print("Weather runtime integration test: OK")
    quit(0)
