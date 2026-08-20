extends SceneTree

const WeatherStateScript = preload("res://scripts/battle/weather_state.gd")


func _initialize() -> void:
    var state = WeatherStateScript.new()

    var validation_errors: Array[String] = state.validate_definitions({
        "rain": {
            "display_name": "Regen",
            "emoji": "🌧️",
            "damage_type_strength_coefficients": {"water": 1.0},
            "unsupported_future_magic": true
        }
    })
    assert(
        not validation_errors.is_empty(),
        "Nicht unterstützte Wettermechaniken/-eigenschaften müssen im Development/Test auffallen."
    )

    state.configure({
        "rain": {
            "display_name": "Regen",
            "emoji": "🌧️",
            "damage_type_strength_coefficients": {"water": 1.0, "fire": -1.0}
        }
    })

    var source: Dictionary = {
        "battle_instance_id": "player:0:squirtle:1",
        "id": "player_0",
        "side": "player",
        "index": 0,
        "species_id": "squirtle",
        "name": "Schiggy",
        "action_serial": 1
    }
    var unknown_result: Dictionary = state.activate("unknown_weather", source, 20.0, 3)
    assert(
        not bool(unknown_result.get("ok", true)),
        "Eine unbekannte weather_id darf nicht stillschweigend aktiviert oder ignoriert werden."
    )
    assert(state.current_id().is_empty(), "Nach unbekannter weather_id darf kein Wetter aktiv sein.")

    print("Weather validation tests: OK")
    quit(0)
