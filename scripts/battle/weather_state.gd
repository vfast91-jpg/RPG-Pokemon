extends RefCounted
class_name BattleWeatherState

# Central runtime state for exactly one global battle weather.
# Weather definitions are supplied by data/rules/weather_rules.json so new
# weather IDs and type-damage coefficients do not require per-move code.

var _definitions: Dictionary = {}
var _state: Dictionary = {}


func configure(definitions: Dictionary) -> void:
    _definitions = definitions.duplicate(true)
    reset()

    for weather_id_value: Variant in _definitions.keys():
        var weather_id: String = str(weather_id_value)
        var definition_value: Variant = _definitions.get(weather_id, {})
        if not (definition_value is Dictionary):
            push_error("Wetterdefinition '%s' ist kein Dictionary." % weather_id)
            continue
        var definition: Dictionary = definition_value
        if str(definition.get("display_name", "")).is_empty():
            push_error("Wetterdefinition '%s' besitzt keinen display_name." % weather_id)
        var damage_rules_value: Variant = definition.get("damage_type_strength_coefficients", {})
        if not (damage_rules_value is Dictionary):
            push_error(
                "Wetterdefinition '%s' besitzt keine gültigen damage_type_strength_coefficients."
                % weather_id
            )


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


func activate(
    weather_id: String,
    source: Dictionary,
    strength_percent: float,
    duration_actions: int
) -> Dictionary:
    if not has_weather(weather_id):
        push_error("Unbekannte weather_id '%s' kann nicht aktiviert werden." % weather_id)
        return {"ok": false, "reason": "unknown_weather_id", "weather_id": weather_id}

    var source_instance_id: String = str(
        source.get("battle_instance_id", source.get("id", ""))
    )
    if source_instance_id.is_empty():
        push_error("Wetterquelle besitzt keine stabile Kampf-Identität.")
        return {"ok": false, "reason": "missing_source_identity", "weather_id": weather_id}

    var previous_weather_id: String = current_id()
    var action_serial: int = int(source.get("action_serial", 0))
    var normalized_duration: int = maxi(1, duration_actions)

    _state = {
        "weather_id": weather_id,
        "source_instance_id": source_instance_id,
        "source_combatant_id": str(source.get("id", "")),
        "source_side": str(source.get("side", "")),
        "source_index": int(source.get("index", -1)),
        "source_species_id": str(source.get("species_id", "")),
        "source_name": str(source.get("name", "Pokémon")),
        "strength_percent": clampf(strength_percent, 0.0, 100.0),
        "remaining_actions": normalized_duration,
        "duration_actions": normalized_duration,
        "duration_mode": "source_actions",
        "activation_action_serial": action_serial,
        "last_counted_action_serial": action_serial
    }

    return {
        "ok": true,
        "weather_id": weather_id,
        "previous_weather_id": previous_weather_id,
        "replaced": not previous_weather_id.is_empty() and previous_weather_id != weather_id,
        "refreshed": previous_weather_id == weather_id
    }


func complete_action(actor: Dictionary) -> Dictionary:
    if not is_active():
        return {"counted": false, "ended": false}

    var actor_instance_id: String = str(
        actor.get("battle_instance_id", actor.get("id", ""))
    )
    if actor_instance_id != str(_state.get("source_instance_id", "")):
        return {"counted": false, "ended": false}

    var action_serial: int = int(actor.get("action_serial", 0))
    var last_counted: int = int(_state.get("last_counted_action_serial", 0))
    if action_serial <= last_counted:
        # This also protects the activation action itself: Regentanz stores the
        # already-incremented action_serial and therefore starts at a full 3.
        return {"counted": false, "ended": false}

    _state["last_counted_action_serial"] = action_serial
    var remaining: int = maxi(0, int(_state.get("remaining_actions", 0)) - 1)
    _state["remaining_actions"] = remaining

    if remaining > 0:
        return {
            "counted": true,
            "ended": false,
            "weather_id": current_id(),
            "remaining_actions": remaining
        }

    var ended_weather_id: String = current_id()
    var ended_definition: Dictionary = definition(ended_weather_id).duplicate(true)
    reset()
    return {
        "counted": true,
        "ended": true,
        "weather_id": ended_weather_id,
        "remaining_actions": 0,
        "definition": ended_definition
    }


func damage_multiplier(move_type: String) -> float:
    if not is_active():
        return 1.0

    var weather_id: String = current_id()
    var active_definition: Dictionary = definition(weather_id)
    if active_definition.is_empty():
        push_error("Aktives Wetter '%s' besitzt keine Definition." % weather_id)
        return 1.0

    var rules_value: Variant = active_definition.get("damage_type_strength_coefficients", {})
    if not (rules_value is Dictionary):
        push_error("Wetter '%s' besitzt ungültige Schadensregeln." % weather_id)
        return 1.0

    var rules: Dictionary = rules_value
    if not rules.has(move_type):
        return 1.0

    var coefficient: float = float(rules.get(move_type, 0.0))
    var strength: float = float(_state.get("strength_percent", 0.0)) / 100.0
    return maxf(0.0, 1.0 + strength * coefficient)


func display_text() -> String:
    if not is_active():
        return ""
    var active_definition: Dictionary = definition(current_id())
    if active_definition.is_empty():
        return ""
    var emoji: String = str(active_definition.get("emoji", ""))
    var display_name: String = str(active_definition.get("display_name", current_id()))
    var strength: int = int(round(float(_state.get("strength_percent", 0.0))))
    return (emoji + " " if not emoji.is_empty() else "") + display_name + " · " + str(strength) + " %"


func start_message(weather_id: String) -> String:
    var weather_definition: Dictionary = definition(weather_id)
    return str(weather_definition.get("start_message", ""))


func end_message(weather_id: String, supplied_definition: Dictionary = {}) -> String:
    var weather_definition: Dictionary = supplied_definition
    if weather_definition.is_empty():
        weather_definition = definition(weather_id)
    return str(weather_definition.get("end_message", ""))


func weather_name(weather_id: String) -> String:
    var weather_definition: Dictionary = definition(weather_id)
    var emoji: String = str(weather_definition.get("emoji", ""))
    var display_name: String = str(weather_definition.get("display_name", weather_id))
    return (emoji + " " if not emoji.is_empty() else "") + display_name
