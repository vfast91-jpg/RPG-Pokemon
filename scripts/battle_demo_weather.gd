extends "res://scripts/battle_demo_forced_evolution.gd"

const WeatherStateScript = preload("res://scripts/battle/weather_state.gd")
const WEATHER_RULE_PATH: String = "res://data/rules/weather_rules.json"
const WEATHER_MOVE_PACK_PATH: String = "res://data/WEATHER_MOVES.json"
const GLOBAL_BATTLEFIELD_TARGET: String = "global_battlefield"
const WEATHER_MECHANIC_KIND: String = "weather"

var battle_weather = WeatherStateScript.new()
var weather_label: Label = null
var _battle_instance_counter: int = 0
var _active_weather_move: Dictionary = {}
var _weather_activation_result: Dictionary = {}


func _load_data() -> void:
    super._load_data()
    _load_weather_rules()
    _merge_weather_moves()
    _audit_weather_moves()


func _load_weather_rules() -> void:
    var file: FileAccess = FileAccess.open(WEATHER_RULE_PATH, FileAccess.READ)
    if file == null:
        push_error("Wetterregeln fehlen: " + WEATHER_RULE_PATH)
        battle_weather.configure({})
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Wetterregeln sind kein gültiges JSON-Dictionary.")
        battle_weather.configure({})
        return

    var weather_value: Variant = (parsed as Dictionary).get("weathers", {})
    if not (weather_value is Dictionary):
        push_error("weather_rules.json besitzt kein gültiges weathers-Dictionary.")
        battle_weather.configure({})
        return

    battle_weather.configure(weather_value as Dictionary)


func _merge_weather_moves() -> void:
    var file: FileAccess = FileAccess.open(WEATHER_MOVE_PACK_PATH, FileAccess.READ)
    if file == null:
        push_error("Wetter-Attackenpaket fehlt: " + WEATHER_MOVE_PACK_PATH)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Wetter-Attackenpaket ist kein gültiges JSON-Dictionary.")
        return

    var pack_moves_value: Variant = (parsed as Dictionary).get("moves", {})
    if not (pack_moves_value is Dictionary):
        push_error("Wetter-Attackenpaket besitzt kein gültiges moves-Dictionary.")
        return

    var runtime_moves_value: Variant = data.get("moves", {})
    if not (runtime_moves_value is Dictionary):
        push_error("Kampfdaten besitzen kein gültiges moves-Dictionary.")
        return

    var runtime_moves: Dictionary = runtime_moves_value
    var pack_moves: Dictionary = pack_moves_value
    for move_id_value: Variant in pack_moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = pack_moves.get(move_id, {})
        if not (move_value is Dictionary):
            push_error("Wetter-Attacke '%s' ist kein Dictionary." % move_id)
            continue
        if runtime_moves.has(move_id):
            push_error(
                "Wetter-Attacke '%s' existiert bereits in den Basiskampfdaten; doppelte Definition wird nicht still überschrieben."
                % move_id
            )
            continue
        runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)

    data["moves"] = runtime_moves


func _audit_weather_moves() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        push_error("Wetter-Audit: moves-Dictionary fehlt.")
        return

    for move_id_value: Variant in (moves_value as Dictionary).keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        var weather_value: Variant = move.get("weather", null)
        var has_weather_mechanic: bool = _move_contains_weather_mechanic(move)

        if weather_value == null:
            if has_weather_mechanic:
                push_error(
                    "Wetter-Audit: %s besitzt eine weather-Mechanik ohne weather-Datenblock."
                    % move_id
                )
            continue

        if not (weather_value is Dictionary):
            push_error("Wetter-Audit: %s besitzt keinen gültigen weather-Block." % move_id)
            continue
        if not has_weather_mechanic:
            push_error(
                "Wetter-Audit: %s besitzt weather-Daten, aber keine weather-Mechanik in mechanics."
                % move_id
            )

        var weather: Dictionary = weather_value
        var weather_id: String = str(weather.get("weather_id", ""))
        if weather_id.is_empty():
            push_error("Wetter-Audit: %s besitzt keine weather_id." % move_id)
            continue
        if not battle_weather.has_weather(weather_id):
            push_error(
                "Wetter-Audit: %s verwendet unbekannte weather_id '%s'."
                % [move_id, weather_id]
            )

        var duration_unit: String = str(weather.get("duration_unit", "source_actions"))
        if duration_unit != "source_actions":
            push_error(
                "Wetter-Audit: %s verwendet nicht unterstützte Wetterdauer '%s'."
                % [move_id, duration_unit]
            )
        if int(weather.get("duration_actions", 0)) <= 0:
            push_error("Wetter-Audit: %s braucht duration_actions > 0." % move_id)

        var strength_stat: String = str(weather.get("strength_stat", ""))
        if strength_stat.is_empty():
            push_error("Wetter-Audit: %s braucht strength_stat." % move_id)


func _move_contains_weather_mechanic(move: Dictionary) -> bool:
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false
    for mechanic_value: Variant in mechanics_value:
        if (
            mechanic_value is Dictionary
            and str((mechanic_value as Dictionary).get("kind", "")) == WEATHER_MECHANIC_KIND
        ):
            return true
    return false


func _build_battle(root: Control) -> void:
    super._build_battle(root)

    weather_label = Label.new()
    weather_label.name = "WeatherStatus"
    weather_label.anchor_left = 0.5
    weather_label.anchor_right = 0.5
    weather_label.offset_left = -100.0
    weather_label.offset_top = 7.0
    weather_label.offset_right = 100.0
    weather_label.offset_bottom = 31.0
    weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weather_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weather_label.z_index = 150
    weather_label.add_theme_font_size_override("font_size", 12)
    weather_label.add_theme_color_override("font_color", Color("eef7ff"))
    weather_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.08, 0.88))
    weather_label.add_theme_constant_override("outline_size", 4)
    battle_panel.add_child(weather_label)
    _update_weather_ui()


func _start_battle() -> void:
    battle_weather.reset()
    _battle_instance_counter = 0
    super._start_battle()
    _update_weather_ui()


func open_config() -> void:
    battle_weather.reset()
    _update_weather_ui()
    super.open_config()


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    _battle_instance_counter += 1
    combatant["battle_instance_id"] = (
        side + ":" + str(index) + ":" + str(combatant.get("species_id", ""))
        + ":" + str(_battle_instance_counter)
    )
    return combatant


func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == GLOBAL_BATTLEFIELD_TARGET:
        # The effect is global. A single synthetic self target lets the inherited
        # resolver execute the move exactly once without inventing an opponent.
        return [actor]
    return super._targets(actor, rule)


func _target_name(rule: String) -> String:
    if rule == GLOBAL_BATTLEFIELD_TARGET:
        return "globales Kampffeld"
    return super._target_name(rule)


func _move_emoji(move_id: String, move: Dictionary) -> String:
    var explicit_emoji: String = str(move.get("emoji", ""))
    if not explicit_emoji.is_empty():
        return explicit_emoji
    return super._move_emoji(move_id, move)


func _compact_effect_summary(move: Dictionary) -> String:
    var summary: String = super._compact_effect_summary(move)
    var weather_value: Variant = move.get("weather", null)
    if not (weather_value is Dictionary):
        return summary

    var weather_id: String = str((weather_value as Dictionary).get("weather_id", ""))
    var weather_text: String = "globales Wetter " + battle_weather.weather_name(weather_id)
    if summary.is_empty():
        return weather_text
    return summary.replace(WEATHER_MECHANIC_KIND, weather_text)


func _move_tooltip(move: Dictionary) -> String:
    var tooltip: String = super._move_tooltip(move)
    var weather_value: Variant = move.get("weather", null)
    if not (weather_value is Dictionary):
        return tooltip

    var weather: Dictionary = weather_value
    var weather_id: String = str(weather.get("weather_id", ""))
    var weather_name: String = battle_weather.weather_name(weather_id)
    var cap: int = int(round(float(weather.get("strength_cap", 100.0))))
    var actions: int = int(weather.get("duration_actions", 0))
    var extra: String = (
        "Wetter: " + weather_name
        + " · Stärke min(aktueller Status, " + str(cap) + ") %"
        + " · Dauer: nächste " + str(actions) + " eigene Aktionen des Anwenders"
    )
    return extra if tooltip.is_empty() else tooltip + "\n" + extra


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    _active_weather_move = move
    _weather_activation_result = {}

    super._execute_move(actor, move_id)

    _active_weather_move = {}
    var weather_messages: Array[String] = []
    if bool(_weather_activation_result.get("ok", false)):
        _append_weather_activation_messages(weather_messages, _weather_activation_result)
    _weather_activation_result = {}

    _complete_weather_action(actor, weather_messages)
    _update_weather_ui()
    _append_weather_log(weather_messages)


func _choose_wait() -> void:
    if selected_actor.is_empty():
        return
    var actor: Dictionary = selected_actor
    super._choose_wait()

    var weather_messages: Array[String] = []
    _complete_weather_action(actor, weather_messages)
    _update_weather_ui()
    _append_weather_log(weather_messages)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind != WEATHER_MECHANIC_KIND:
        return super._effect(actor, target, mechanic)

    if not _weather_activation_result.is_empty():
        push_error("Wettermechanik wurde innerhalb derselben Attacke mehrfach aufgelöst.")
        return 0.0

    var weather_value: Variant = _active_weather_move.get("weather", null)
    if not (weather_value is Dictionary):
        push_error("Wettermechanik wurde ohne gültigen weather-Datenblock ausgeführt.")
        _weather_activation_result = {"ok": false, "reason": "missing_weather_block"}
        return 0.0

    _weather_activation_result = _activate_weather_from_move(actor, weather_value as Dictionary)
    return 0.0


func _activate_weather_from_move(actor: Dictionary, weather: Dictionary) -> Dictionary:
    var weather_id: String = str(weather.get("weather_id", ""))
    if not battle_weather.has_weather(weather_id):
        push_error("Attacke versucht unbekannte weather_id '%s' zu aktivieren." % weather_id)
        return {"ok": false, "reason": "unknown_weather_id"}

    var duration_unit: String = str(weather.get("duration_unit", "source_actions"))
    if duration_unit != "source_actions":
        push_error("Nicht unterstützte Wetterdauer '%s'." % duration_unit)
        return {"ok": false, "reason": "unsupported_duration_unit"}

    var strength_stat: String = str(weather.get("strength_stat", ""))
    if strength_stat.is_empty() or not actor.has(strength_stat):
        push_error(
            "Wetterstärke kann nicht aus Statuswert '%s' gelesen werden."
            % strength_stat
        )
        return {"ok": false, "reason": "missing_strength_stat"}

    var strength_cap: float = maxf(0.0, float(weather.get("strength_cap", 100.0)))
    var current_stat: float = float(actor.get(strength_stat, 0.0))
    var strength_percent: float = minf(current_stat, strength_cap)
    var duration_actions: int = maxi(1, int(weather.get("duration_actions", 1)))

    return battle_weather.activate(
        weather_id,
        actor,
        strength_percent,
        duration_actions
    )


func _feedback_snapshot(target: Dictionary) -> Dictionary:
    var snapshot: Dictionary = super._feedback_snapshot(target)
    var weather_state: Dictionary = battle_weather.snapshot()
    snapshot["global_weather_id"] = str(weather_state.get("weather_id", ""))
    snapshot["global_weather_strength"] = float(weather_state.get("strength_percent", 0.0))
    snapshot["global_weather_remaining"] = int(weather_state.get("remaining_actions", 0))
    return snapshot


func _feedback_result(target: Dictionary, before: Dictionary) -> Dictionary:
    var result: Dictionary = super._feedback_result(target, before)
    var weather_state: Dictionary = battle_weather.snapshot()
    var before_id: String = str(before.get("global_weather_id", ""))
    var after_id: String = str(weather_state.get("weather_id", ""))
    var before_strength: float = float(before.get("global_weather_strength", 0.0))
    var after_strength: float = float(weather_state.get("strength_percent", 0.0))
    var before_remaining: int = int(before.get("global_weather_remaining", 0))
    var after_remaining: int = int(weather_state.get("remaining_actions", 0))

    var weather_changed: bool = (
        before_id != after_id
        or not is_equal_approx(before_strength, after_strength)
        or before_remaining != after_remaining
    )
    if not weather_changed or after_id.is_empty():
        return result

    var weather_feedback: String = battle_weather.display_text()
    var text: String = str(result.get("text", "KEIN EFFEKT"))
    if text == "KEIN EFFEKT":
        text = weather_feedback
    elif not weather_feedback.is_empty():
        text += " · " + weather_feedback
    return {"kind": "positive", "text": text}


func _complete_weather_action(actor: Dictionary, messages: Array[String]) -> void:
    var completion: Dictionary = battle_weather.complete_action(actor)
    if not bool(completion.get("ended", false)):
        return

    var weather_id: String = str(completion.get("weather_id", ""))
    var definition_value: Variant = completion.get("definition", {})
    var ended_definition: Dictionary = (
        definition_value if definition_value is Dictionary else {}
    )
    var end_message: String = battle_weather.end_message(weather_id, ended_definition)
    if not end_message.is_empty():
        messages.append(end_message)


func _append_weather_activation_messages(messages: Array[String], activation: Dictionary) -> void:
    var weather_id: String = str(activation.get("weather_id", ""))
    var previous_weather_id: String = str(activation.get("previous_weather_id", ""))

    if bool(activation.get("replaced", false)):
        messages.append(
            "🌦️ Wetterwechsel: " + battle_weather.weather_name(previous_weather_id)
            + " → " + battle_weather.weather_name(weather_id) + "."
        )
    elif bool(activation.get("refreshed", false)):
        messages.append(battle_weather.weather_name(weather_id) + " wird erneuert.")

    var start_message: String = battle_weather.start_message(weather_id)
    if not start_message.is_empty() and not bool(activation.get("refreshed", false)):
        messages.append(start_message)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0:
        return damage

    var weather_multiplier: float = battle_weather.damage_multiplier(move_type)
    if is_equal_approx(weather_multiplier, 1.0):
        return damage

    return maxi(1, int(round(float(damage) * weather_multiplier)))


func current_weather_id() -> String:
    return battle_weather.current_id()


func current_weather_state() -> Dictionary:
    return battle_weather.snapshot()


func weather_damage_multiplier(move_type: String) -> float:
    return battle_weather.damage_multiplier(move_type)


func _weather_status_text() -> String:
    return battle_weather.display_text()


func _update_weather_ui() -> void:
    if weather_label == null:
        return
    var text: String = _weather_status_text()
    weather_label.text = text
    weather_label.visible = not text.is_empty()


func _append_weather_log(messages: Array[String]) -> void:
    if messages.is_empty() or log_label == null:
        return
    var block: String = "\n".join(messages)
    var current_text: String = log_label.text.strip_edges()
    log_label.text = block if current_text.is_empty() else current_text + "\n" + block
