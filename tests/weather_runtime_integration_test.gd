extends SceneTree

const RuntimeBattleScript = preload("res://scripts/battle_demo_forced_evolution.gd")


func _initialize() -> void:
    var demo = RuntimeBattleScript.new()
    demo.process_mode = Node.PROCESS_MODE_DISABLED
    get_root().add_child(demo)

    assert(not demo.data.is_empty(), "Die echte Battle-Demo muss Laufzeitdaten geladen haben.")
    assert(demo._move_data("rain_dance").get("name", "") == "Regentanz", "Regentanz muss im echten Runtime-Leaf verfügbar sein.")

    var source: Dictionary = demo._make_combatant(
        "player", 0, {"species_id": "squirtle", "level": 10}
    )
    var enemy: Dictionary = demo._make_combatant(
        "enemy", 0, {"species_id": "rattata", "level": 10}
    )
    source["special"] = 30
    source["hp"] = source["max_hp"]
    enemy["hp"] = 9999
    enemy["max_hp"] = 9999
    enemy["alive"] = true

    demo.player_team = [source]
    demo.enemy_team = [enemy]
    demo.combatants = [source, enemy]
    demo.battle_active = true
    demo.paused = false
    demo.log_label.text = ""

    demo._execute_move(source, "rain_dance")
    assert(demo.current_weather_id() == "rain", "Regentanz muss auch im vollständigen Battle-Layer rain aktivieren.")
    assert(int(demo.current_weather_state().get("remaining_actions", 0)) == 3, "Regentanz darf seine eigene Aktivierungsaktion nicht mitzählen.")
    assert(is_equal_approx(float(demo.current_weather_state().get("strength_percent", 0.0)), 30.0), "Der vollständige Runtime-Leaf muss die gespeicherte Regenstärke übernehmen.")

    demo.battle_weather.reset()
    seed(731)
    var base_damage: int = demo._damage(source, enemy, 40, "water", "special")
    demo.battle_weather.activate("rain", source, 30.0, 3)
    seed(731)
    var rain_damage: int = demo._damage(source, enemy, 40, "water", "special")
    assert(rain_damage == int(round(float(base_damage) * 1.30)), "Die echte Schadenskette muss den Regenmultiplikator anwenden.")

    demo._execute_move(source, "focus_energy")
    demo._execute_move(source, "focus_energy")
    demo._execute_move(source, "focus_energy")
    assert(demo.current_weather_id().is_empty(), "Der Regen muss auch im vollständigen Runtime-Leaf nach exakt drei Folgeaktionen enden.")

    print("Weather runtime integration test: OK")
    quit(0)
