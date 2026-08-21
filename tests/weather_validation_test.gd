extends SceneTree

const WeatherStateScript = preload("res://scripts/battle/weather_state.gd")


func _initialize() -> void:
    var state = WeatherStateScript.new()

    var validation_errors: Array[String] = state.validate_definitions({
        "rain": {
            "display_name": "Regen",
            "emoji": "🌧️",
            "effect_strength_percent": 50.0,
            "duration_seconds": 50.0,
            "duration_mode": "active_battle_time",
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
            "effect_strength_percent": 50.0,
            "duration_seconds": 50.0,
            "duration_mode": "active_battle_time",
            "damage_type_strength_coefficients": {"water": 1.0, "fire": -1.0}
        }
    })

    var source: Dictionary = {
        "battle_instance_id": "player:0:squirtle:1",
        "id": "player_0",
        "side": "player",
        "index": 0,
        "species_id": "squirtle",
        "name": "Schiggy"
    }
    var unknown_result: Dictionary = state.activate("unknown_weather", source)
    assert(
        not bool(unknown_result.get("ok", true)),
        "Eine unbekannte weather_id darf nicht stillschweigend aktiviert oder ignoriert werden."
    )
    assert(state.current_id().is_empty(), "Nach unbekannter weather_id darf kein Wetter aktiv sein.")

    var first_activation: Dictionary = state.activate("rain", source)
    assert(bool(first_activation.get("ok", false)), "Bekannter Regen muss aktivierbar sein.")
    state.advance_time(17.0)
    var remaining_before: float = state.remaining_seconds()
    var duplicate_activation: Dictionary = state.activate("rain", source)
    assert(
        str(duplicate_activation.get("reason", "")) == "already_active",
        "Dasselbe Wetter muss als bereits aktiv erkannt werden."
    )
    assert(
        is_equal_approx(state.remaining_seconds(), remaining_before),
        "Eine identische Wetteraktivierung darf die Restdauer nicht verändern."
    )

    print("Weather validation tests: OK")
    quit(0)
