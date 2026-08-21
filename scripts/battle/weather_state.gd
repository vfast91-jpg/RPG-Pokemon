extends RefCounted
class_name BattleWeatherState

# Exactly one global weather can be active. Sources only activate a weather ID;
# strength, duration and combat effects live in data/rules/weather_rules.json.
# Normal Timeflow weather uses one continuous timer measured in active battle
# seconds. Player decision pauses therefore pause weather automatically because
# the battle layer does not advance this state while combat is paused.

const SUPPORTED_DEFINITION_KEYS: Dictionary = {
    "display_name": true,
    "emoji": true,
    "start_message": true,
    "end_message": true,
    "effect_strength_percent": true,
    "duration_seconds": true,
    "duration_mode": true,
    "damage_type_strength_coefficients": true
}
const ACTIVE_BATTLE_TIME_MODE: String = "active_battle_time"

var _definitions: Dictionary = {}
var _state: Dictionary = {}


func configure(definitions: Dictionary) -> void:
    _definitions = definitions.duplicate(true)
    reset()
    for validation_error: String in validate_definitions(_definitions):
        push_error(validation_error)


func validate_definitions(definitions: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for weather_id_value: Variant in definitions.keys():
        var weather_id: String = str(weather_id_value)
        var definition_value: Variant = definitions.get(weather_id, {})
        if not (definition_value is Dictionary):
            errors.append("Wetterdefinition '%s' ist kein Dictionary." % weather_id)
            continue

        var weather_definition: Dictionary = definition_value
        for key_value: Variant in weather_definition.keys():
            var key: String = str(key_value)
            if not SUPPORTED_DEFINITION_KEYS.has(key):
                errors.append(
                    "Wetterdefinition '%s' enthält die nicht unterstützte Eigenschaft '%s'."
                    % [weather_id, key]
                )

        if str(weather_definition.get("display_name", "")).is_empty():
            errors.append("Wetterdefinition '%s' besitzt keinen display_name." % weather_id)
        if float(weather_definition.get("effect_strength_percent", -1.0)) < 0.0:
            errors.append("Wetterdefinition '%s' braucht effect_strength_percent >= 0." % weather_id)
        if float(weather_definition.get("duration_seconds", 0.0)) <= 0.0:
            errors.append("Wetterdefinition '%s' braucht duration_seconds > 0." % weather_id)
        if str(weather_definition.get("duration_mode", "")) != ACTIVE_BATTLE_TIME_MODE:
            errors.append(
                "Wetterdefinition '%s' muss duration_mode '%s' verwenden."
                % [weather_id, ACTIVE_BATTLE_TIME_MODE]
            )

        var damage_rules_value: Variant = weather_definition.get(
            "damage_type_strength_coefficients", {}
        )
        if not (damage_rules_value is Dictionary):
            errors.append(
                "Wetterdefinition '%s' besitzt keine gültigen Schadenskoeffizienten."
                % weather_id
            )
            continue
        for move_type_value: Variant in (damage_rules_value as Dictionary).keys():
            var coefficient_value: Variant = (
                damage_rules_value as Dictionary
            ).get(move_type_value)
            if not (coefficient_value is int or coefficient_value is float):
                errors.append(
                    "Wetterdefinition '%s' besitzt für Typ '%s' keinen numerischen Koeffizienten."
                    % [weather_id, str(move_type_value)]
                )
    return errors


func reset() -> void:
    _state = {}


func has_weather(weather_id: String) -> bool:
    return _definitions.has(weather_id)


func current_id() -> String:
    return str(_state.get("weather_id", ""))


func is_active() -> bool:
    return not current_id().is_empty()


func snapshot() -> Dictionary:
    return _state.duplicate(true)


func definition(weather_id: String) -> Dictionary:
    var value: Variant = _definitions.get(weather_id, {})
    return value if value is Dictionary else {}


func duration_seconds(weather_id: String = "") -> float:
    var resolved_id: String = weather_id if not weather_id.is_empty() else current_id()
    if resolved_id.is_empty():
        return 0.0
    return maxf(0.0, float(definition(resolved_id).get("duration_seconds", 0.0)))


func remaining_seconds() -> float:
    return maxf(0.0, float(_state.get("remaining_seconds", 0.0)))


func remaining_fraction() -> float:
    var total: float = maxf(0.0001, float(_state.get("duration_seconds", 0.0)))
    return clampf(remaining_seconds() / total, 0.0, 1.0) if is_active() else 0.0


func activate(
    weather_id: String,
    source: Dictionary,
    _legacy_strength_percent: float = -1.0,
    _legacy_duration_actions: int = -1
) -> Dictionary:
    # Optional legacy arguments stay accepted so older callers cannot crash.
    # Timeflow weather strength and duration are always read centrally.
    if not has_weather(weather_id):
        push_error("Unbekannte weather_id '%s' kann nicht aktiviert werden." % weather_id)
        return {"ok": false, "reason": "unknown_weather_id", "weather_id": weather_id}

    var previous_weather_id: String = current_id()
    if previous_weather_id == weather_id:
        # Core Timeflow rule: identical weather never refreshes or restarts its timer.
        return {
            "ok": false,
            "reason": "already_active",
            "weather_id": weather_id,
            "previous_weather_id": previous_weather_id,
            "unchanged": true
        }

    var source_instance_id: String = str(
        source.get("battle_instance_id", source.get("id", ""))
    )
    if source_instance_id.is_empty():
        push_error("Wetterquelle besitzt keine stabile Kampf-Identität.")
        return {"ok": false, "reason": "missing_source_identity", "weather_id": weather_id}

    var weather_definition: Dictionary = definition(weather_id)
    var strength_percent: float = maxf(
        0.0,
        float(weather_definition.get("effect_strength_percent", 0.0))
    )
    var total_seconds: float = maxf(
        0.001,
        float(weather_definition.get("duration_seconds", 0.0))
    )

    _state = {
        "weather_id": weather_id,
        "source_instance_id": source_instance_id,
        "source_combatant_id": str(source.get("id", "")),
        "source_side": str(source.get("side", "")),
        "source_index": int(source.get("index", -1)),
        "source_species_id": str(source.get("species_id", "")),
        "source_name": str(source.get("name", "Quelle")),
        "strength_percent": strength_percent,
        "remaining_seconds": total_seconds,
        "duration_seconds": total_seconds,
        "duration_mode": ACTIVE_BATTLE_TIME_MODE
    }

    return {
        "ok": true,
        "weather_id": weather_id,
        "previous_weather_id": previous_weather_id,
        "replaced": not previous_weather_id.is_empty() and previous_weather_id != weather_id,
        "refreshed": false
    }


func advance_time(delta_seconds: float) -> Dictionary:
    if not is_active() or delta_seconds <= 0.0:
        return {"advanced": false, "ended": false}

    var remaining: float = maxf(0.0, remaining_seconds() - delta_seconds)
    _state["remaining_seconds"] = remaining
    if remaining > 0.0:
        return {
            "advanced": true,
            "ended": false,
            "weather_id": current_id(),
            "remaining_seconds": remaining
        }

    var ended_weather_id: String = current_id()
    var ended_definition: Dictionary = definition(ended_weather_id).duplicate(true)
    reset()
    return {
        "advanced": true,
        "ended": true,
        "weather_id": ended_weather_id,
        "remaining_seconds": 0.0,
        "definition": ended_definition
    }


func complete_action(_actor: Dictionary) -> Dictionary:
    # Compatibility hook for older battle layers. Weather no longer counts any
    # Pokémon's actions; only advance_time() can consume its duration.
    return {"counted": false, "ended": false}


func damage_multiplier(move_type: String) -> float:
    if not is_active():
        return 1.0
    var active_definition: Dictionary = definition(current_id())
    if active_definition.is_empty():
        return 1.0
    var rules_value: Variant = active_definition.get(
        "damage_type_strength_coefficients", {}
    )
    if not (rules_value is Dictionary) or not (rules_value as Dictionary).has(move_type):
        return 1.0
    var coefficient_value: Variant = (rules_value as Dictionary).get(move_type, 0.0)
    if not (coefficient_value is int or coefficient_value is float):
        return 1.0
    var coefficient: float = float(coefficient_value)
    var strength: float = float(_state.get("strength_percent", 0.0)) / 100.0
    return maxf(0.0, 1.0 + strength * coefficient)


func display_text() -> String:
    if not is_active():
        return ""
    return weather_name(current_id())


func start_message(weather_id: String) -> String:
    return str(definition(weather_id).get("start_message", ""))


func end_message(weather_id: String, supplied_definition: Dictionary = {}) -> String:
    var weather_definition: Dictionary = (
        supplied_definition if not supplied_definition.is_empty() else definition(weather_id)
    )
    return str(weather_definition.get("end_message", ""))


func weather_name(weather_id: String) -> String:
    var weather_definition: Dictionary = definition(weather_id)
    var emoji: String = str(weather_definition.get("emoji", ""))
    var display_name: String = str(weather_definition.get("display_name", weather_id))
    return (emoji + " " if not emoji.is_empty() else "") + display_name
