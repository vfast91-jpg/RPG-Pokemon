extends SceneTree

const WeatherStateScript = preload("res://scripts/battle/weather_state.gd")
const BattleDemoScript = preload("res://scripts/battle_demo_weather.gd")


func _initialize() -> void:
    _test_regentanz_data_contract()
    _test_regentanz_activation_and_strength()
    _test_regentanz_strength_cap()
    _test_weather_damage_modifiers()
    _test_weather_applies_to_both_teams()
    _test_weather_applies_to_switched_in_combatant()
    _test_duration_only_counts_source_actions()
    _test_duration_ends_after_exactly_three_source_actions()
    _test_strength_is_snapshotted()
    _test_weather_replacement_is_generic()
    _test_no_multiplier_after_weather_end()
    _test_ui_and_log_are_clear_without_weather()
    print("Weather system behavior tests: OK")
    quit(0)


func _fresh_demo() -> Node:
    var demo: Node = BattleDemoScript.new()
    demo._load_data()

    var log: RichTextLabel = RichTextLabel.new()
    log.bbcode_enabled = true
    demo.log_label = log
    demo.weather_label = Label.new()
    demo.battle_active = true
    demo.paused = false
    return demo


func _combatants_for_demo(demo: Node) -> Dictionary:
    var source: Dictionary = demo._make_combatant(
        "player", 0, {"species_id": "squirtle", "level": 10}
    )
    var target: Dictionary = demo._make_combatant(
        "enemy", 0, {"species_id": "rattata", "level": 10}
    )
    source["hp"] = source["max_hp"]
    target["hp"] = 9999
    target["max_hp"] = 9999
    target["alive"] = true

    demo.player_team = [source]
    demo.enemy_team = [target]
    demo.combatants = [source, target]
    return {"source": source, "target": target}


func _activate_rain(demo: Node, source: Dictionary, special_value: int) -> void:
    source["special"] = special_value
    demo.log_label.text = ""
    demo._execute_move(source, "rain_dance")
    assert(demo.current_weather_id() == "rain", "Regentanz muss global rain aktivieren.")


func _test_regentanz_data_contract() -> void:
    var demo: Node = _fresh_demo()
    var move: Dictionary = demo._move_data("rain_dance")
    assert(not move.is_empty(), "Regentanz muss in den Laufzeit-Attackendaten existieren.")
    assert(str(move.get("name", "")) == "Regentanz", "Regentanz: Name falsch.")
    assert(str(move.get("type", "")) == "water", "Regentanz: Typ muss Wasser sein.")
    assert(str(move.get("category", "")) == "status", "Regentanz: Kategorie muss Status sein.")
    assert(move.get("power", 1) == null, "Regentanz darf keine Schadensstärke besitzen.")
    assert(int(move.get("ap", 0)) == 8, "Regentanz muss RPG-AP 8 besitzen.")
    assert(str(move.get("target", "")) == "global_battlefield", "Regentanz muss das globale Kampffeld zielen.")
    assert(str(move.get("emoji", "")) == "🌧️", "Regentanz muss das Emoji 🌧️ besitzen.")

    var weather_value: Variant = move.get("weather", {})
    assert(weather_value is Dictionary, "Regentanz braucht einen data-driven weather-Block.")
    var weather: Dictionary = weather_value
    assert(str(weather.get("weather_id", "")) == "rain", "Regentanz muss weather_id rain setzen.")
    assert(str(weather.get("strength_stat", "")) == "special", "Regentanz muss den aktuellen Statuswert verwenden.")
    assert(is_equal_approx(float(weather.get("strength_cap", 0.0)), 50.0), "Regentanz-Stärke muss bei 50% gedeckelt sein.")
    assert(int(weather.get("duration_actions", 0)) == 3, "Regentanz muss drei Folgeaktionen dauern.")
    assert(str(weather.get("duration_unit", "")) == "source_actions", "Regentanz muss nur Anwender-Aktionen zählen.")


func _test_regentanz_activation_and_strength() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]

    _activate_rain(demo, source, 22)
    var state: Dictionary = demo.current_weather_state()
    assert(str(state.get("weather_id", "")) == "rain", "1: Regentanz aktiviert rain.")
    _assert_close(float(state.get("strength_percent", 0.0)), 22.0, "2: Regenstärke muss aktuellem Statuswert entsprechen.")
    assert(int(state.get("remaining_actions", 0)) == 3, "Regentanz selbst darf die 3 Folgeaktionen nicht herunterzählen.")
    assert(demo.log_label.get_parsed_text().contains("Es beginnt zu regnen!"), "Battle-Log muss den Regenstart melden.")


func _test_regentanz_strength_cap() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]

    _activate_rain(demo, source, 80)
    _assert_close(
        float(demo.current_weather_state().get("strength_percent", 0.0)),
        50.0,
        "3: Regenstärke muss bei 50% gedeckelt sein."
    )


func _test_weather_damage_modifiers() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]
    var target: Dictionary = setup["target"]

    demo.battle_weather.reset()
    seed(1001)
    var water_base: int = demo._damage(source, target, 40, "water", "special")
    seed(1002)
    var fire_base: int = demo._damage(source, target, 40, "fire", "special")
    seed(1003)
    var normal_base: int = demo._damage(source, target, 40, "normal", "special")

    var activation: Dictionary = demo.battle_weather.activate("rain", source, 30.0, 3)
    assert(bool(activation.get("ok", false)), "Testregen muss aktivierbar sein.")

    seed(1001)
    var water_rain: int = demo._damage(source, target, 40, "water", "special")
    seed(1002)
    var fire_rain: int = demo._damage(source, target, 40, "fire", "special")
    seed(1003)
    var normal_rain: int = demo._damage(source, target, 40, "normal", "special")

    assert(water_rain == int(round(float(water_base) * 1.30)), "4: Regen muss Wasserschaden um die gespeicherte Stärke erhöhen.")
    assert(fire_rain == maxi(1, int(round(float(fire_base) * 0.70))), "5: Regen muss Feuerschaden um die gespeicherte Stärke senken.")
    assert(normal_rain == normal_base, "6: Andere Schadenstypen müssen unverändert bleiben.")


func _test_weather_applies_to_both_teams() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]
    var player_target: Dictionary = setup["target"]
    var enemy_attacker: Dictionary = demo._make_combatant(
        "enemy", 1, {"species_id": "squirtle", "level": 10}
    )
    var enemy_target: Dictionary = demo._make_combatant(
        "player", 1, {"species_id": "rattata", "level": 10}
    )
    enemy_target["hp"] = 9999
    enemy_target["max_hp"] = 9999

    demo.battle_weather.reset()
    seed(2001)
    var player_base: int = demo._damage(source, player_target, 40, "water", "special")
    seed(2002)
    var enemy_base: int = demo._damage(enemy_attacker, enemy_target, 40, "water", "special")

    demo.battle_weather.activate("rain", source, 25.0, 3)
    seed(2001)
    var player_rain: int = demo._damage(source, player_target, 40, "water", "special")
    seed(2002)
    var enemy_rain: int = demo._damage(enemy_attacker, enemy_target, 40, "water", "special")

    assert(player_rain == int(round(float(player_base) * 1.25)), "7: Regen muss für das Spielerteam gelten.")
    assert(enemy_rain == int(round(float(enemy_base) * 1.25)), "7: Regen muss ebenso für das Gegnerteam gelten.")


func _test_weather_applies_to_switched_in_combatant() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]
    demo.battle_weather.activate("rain", source, 40.0, 3)

    var switched_in: Dictionary = demo._make_combatant(
        "enemy", 2, {"species_id": "squirtle", "level": 10}
    )
    var target: Dictionary = demo._make_combatant(
        "player", 2, {"species_id": "rattata", "level": 10}
    )
    target["hp"] = 9999
    target["max_hp"] = 9999

    demo.battle_weather.reset()
    seed(3001)
    var base_damage: int = demo._damage(switched_in, target, 40, "water", "special")
    demo.battle_weather.activate("rain", source, 40.0, 3)
    seed(3001)
    var rain_damage: int = demo._damage(switched_in, target, 40, "water", "special")

    assert(rain_damage == int(round(float(base_damage) * 1.40)), "8: Nachträglich eingewechselte Pokémon müssen das globale Wetter automatisch nutzen.")


func _test_duration_only_counts_source_actions() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]
    var other: Dictionary = setup["target"]

    _activate_rain(demo, source, 30)
    assert(int(demo.current_weather_state().get("remaining_actions", 0)) == 3, "Regen startet bei 3 Folgeaktionen.")

    demo._execute_move(other, "focus_energy")
    assert(int(demo.current_weather_state().get("remaining_actions", 0)) == 3, "9: Fremde Aktionen dürfen den Wetterzähler nicht senken.")

    demo._execute_move(source, "focus_energy")
    assert(int(demo.current_weather_state().get("remaining_actions", 0)) == 2, "9: Eine eigene Folgeaktion muss den Wetterzähler um genau 1 senken.")


func _test_duration_ends_after_exactly_three_source_actions() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]

    _activate_rain(demo, source, 30)
    demo._execute_move(source, "focus_energy")
    assert(int(demo.current_weather_state().get("remaining_actions", 0)) == 2, "Nach Folgeaktion 1 müssen 2 verbleiben.")
    demo._execute_move(source, "focus_energy")
    assert(int(demo.current_weather_state().get("remaining_actions", 0)) == 1, "Nach Folgeaktion 2 muss 1 verbleiben.")
    demo._execute_move(source, "focus_energy")
    assert(demo.current_weather_id().is_empty(), "10: Nach exakt 3 eigenen Folgeaktionen muss Regen enden.")
    assert(demo.log_label.get_parsed_text().contains("Der Regen hört auf."), "Battle-Log muss das Wetterende melden.")


func _test_strength_is_snapshotted() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]

    _activate_rain(demo, source, 22)
    source["special"] = 80
    _assert_close(
        float(demo.current_weather_state().get("strength_percent", 0.0)),
        22.0,
        "11: Bereits laufender Regen darf sich nach späterer Statuswertänderung nicht rückwirkend ändern."
    )


func _test_weather_replacement_is_generic() -> void:
    var weather_state = WeatherStateScript.new()
    weather_state.configure({
        "rain": {
            "display_name": "Regen",
            "emoji": "🌧️",
            "damage_type_strength_coefficients": {"water": 1.0}
        },
        "sun": {
            "display_name": "Sonne",
            "emoji": "☀️",
            "damage_type_strength_coefficients": {"fire": 1.0}
        }
    })
    var source: Dictionary = {
        "battle_instance_id": "player:0:test:1",
        "id": "player_0",
        "side": "player",
        "index": 0,
        "species_id": "test",
        "name": "Testmon",
        "action_serial": 1
    }

    weather_state.activate("rain", source, 30.0, 3)
    var replacement: Dictionary = weather_state.activate("sun", source, 20.0, 3)
    assert(bool(replacement.get("replaced", false)), "12: Ein anderes Wetter muss das laufende Wetter ersetzen.")
    assert(weather_state.current_id() == "sun", "12: Nach Ersetzung darf nur das neue Wetter aktiv sein.")
    _assert_close(float(weather_state.snapshot().get("strength_percent", 0.0)), 20.0, "12: Das neue Wetter muss seine eigene gespeicherte Stärke besitzen.")


func _test_no_multiplier_after_weather_end() -> void:
    var demo: Node = _fresh_demo()
    var setup: Dictionary = _combatants_for_demo(demo)
    var source: Dictionary = setup["source"]
    var target: Dictionary = setup["target"]

    demo.battle_weather.reset()
    seed(4001)
    var baseline: int = demo._damage(source, target, 40, "water", "special")

    _activate_rain(demo, source, 35)
    demo._execute_move(source, "focus_energy")
    demo._execute_move(source, "focus_energy")
    demo._execute_move(source, "focus_energy")
    assert(demo.current_weather_id().is_empty(), "Regen muss vor dem End-Multiplikator-Test beendet sein.")
    _assert_close(demo.weather_damage_multiplier("water"), 1.0, "13: Nach Wetterende muss der Schadensmultiplikator neutral sein.")

    seed(4001)
    var after_end: int = demo._damage(source, target, 40, "water", "special")
    assert(after_end == baseline, "13: Nach Wetterende muss wieder exakt normaler Schaden gelten.")


func _test_ui_and_log_are_clear_without_weather() -> void:
    var demo: Node = _fresh_demo()
    demo.battle_weather.reset()
    demo.log_label.text = "Der Kampf läuft ohne Wetter."
    demo._update_weather_ui()

    assert(demo._weather_status_text().is_empty(), "14: Ohne Wetter darf die Wetteranzeige keinen Text liefern.")
    assert(not demo.weather_label.visible, "14: Ohne Wetter muss die Wetteranzeige verborgen sein.")
    assert(not demo.log_label.get_parsed_text().contains("Regen"), "14: Ohne aktiven Regen darf das Battle-Log keinen Regen anzeigen.")


func _assert_close(actual: float, expected: float, message: String) -> void:
    assert(absf(actual - expected) < 0.0001, message + " Erwartet: " + str(expected) + ", tatsächlich: " + str(actual))
