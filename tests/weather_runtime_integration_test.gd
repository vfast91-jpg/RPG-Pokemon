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

    # Regression: the weather lock is battlefield-global, not tied to the
    # Pokémon that originally activated the weather. A second Pokémon that also
    # knows Sonnentag must see it disabled, and a direct selection attempt must
    # keep the action choice open instead of consuming the turn.
    var second_source: Dictionary = demo._make_combatant(
        "player", 1, {"species_id": "bulbasaur", "level": 10}
    )
    second_source["moves"] = ["sunny_day", "rain_dance"]
    demo.player_team = [source, second_source]
    demo.combatants = [source, second_source, enemy]
    demo._prompt_player(second_source)

    var sunny_day_button: Button = null
    for child: Node in demo.action_grid.get_children():
        if child is Button and (child as Button).text.contains("Sonnentag"):
            sunny_day_button = child as Button
            break

    assert(sunny_day_button != null, "Sonnentag muss in der Aktionsauswahl vorhanden sein.")
    assert(
        sunny_day_button.disabled,
        "Sonnentag muss bei jedem Pokémon gesperrt sein, solange Sonne bereits aktiv ist."
    )

    var remaining_before_blocked_choice: float = demo.battle_weather.remaining_seconds()
    var selected_before_blocked_choice: String = str(demo.selected_actor.get("id", ""))
    demo._choose_move("sunny_day")
    assert(
        str(demo.selected_actor.get("id", "")) == selected_before_blocked_choice,
        "Eine gesperrte Wetterattacke darf die Aktionsauswahl nicht schließen."
    )
    assert(demo.paused, "Nach einer gesperrten Wetterattacke muss die Auswahl pausiert bleiben.")
    assert(
        is_equal_approx(
            demo.battle_weather.remaining_seconds(),
            remaining_before_blocked_choice
        ),
        "Eine gesperrte Wetterattacke darf weder Wetterzeit noch Wetterzustand verändern."
    )

    demo.paused = true
    demo._process(25.0)
    assert(
        is_equal_approx(demo.battle_weather.remaining_seconds(), 50.0),
        "Während Aktionsauswahl/Pause darf die Wetterzeit nicht weiterlaufen."
    )

    print("Weather runtime integration test: OK")
    quit(0)
