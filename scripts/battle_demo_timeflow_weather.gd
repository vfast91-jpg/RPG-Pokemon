extends "res://scripts/battle_demo_lab_tm_toggle.gd"

# Final Timeflow weather layer.
#
# Normal weather is a global battlefield state with one continuous timer. The
# timer advances only while battle time itself advances, so player decision
# pauses freeze it automatically. Weather moves only activate a weather ID;
# the central weather definition owns strength and the 50-second duration.

const TIMEFLOW_WEATHER_MOVE_KEYS: Dictionary = {
    "weather_id": true
}

var weather_bar: ProgressBar = null
var _same_weather_rejected_id: String = ""


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
        _audit_weather_mechanic_entries(move_id, move)
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
        if not _audit_weather_spec_keys(move_id, weather):
            continue

        var weather_id: String = str(weather.get("weather_id", ""))
        if weather_id.is_empty():
            push_error("Wetter-Audit: %s besitzt keine weather_id." % move_id)
        elif not battle_weather.has_weather(weather_id):
            push_error(
                "Wetter-Audit: %s verwendet unbekannte weather_id '%s'."
                % [move_id, weather_id]
            )


func _audit_weather_spec_keys(move_id: String, weather: Dictionary) -> bool:
    var valid: bool = true
    for key_value: Variant in weather.keys():
        var key: String = str(key_value)
        if not TIMEFLOW_WEATHER_MOVE_KEYS.has(key):
            var message: String = (
                "Wetter-Audit: %s enthält das nicht unterstützte Wetterfeld '%s'. "
                + "Wetterattacken dürfen nur eine weather_id aktivieren."
            ) % [move_id, key]
            push_error(message)
            valid = false
    return valid


func _build_battle(root: Control) -> void:
    super._build_battle(root)

    # The TYPEN button occupies y=7..32 in the final HUD. Weather gets its own
    # compact center lane directly underneath instead of competing for that spot.
    if weather_label != null:
        weather_label.anchor_left = 0.5
        weather_label.anchor_right = 0.5
        weather_label.offset_left = -48.0
        weather_label.offset_top = 33.0
        weather_label.offset_right = 48.0
        weather_label.offset_bottom = 46.0
        weather_label.add_theme_font_size_override("font_size", 10)
        weather_label.tooltip_text = (
            "Globales Wetter · läuft nur während aktiver Kampfzeit"
        )

    weather_bar = ProgressBar.new()
    weather_bar.name = "WeatherTimeflowBar"
    weather_bar.anchor_left = 0.5
    weather_bar.anchor_right = 0.5
    weather_bar.offset_left = -48.0
    weather_bar.offset_top = 47.0
    weather_bar.offset_right = 48.0
    weather_bar.offset_bottom = 53.0
    weather_bar.min_value = 0.0
    weather_bar.max_value = 1.0
    weather_bar.value = 0.0
    weather_bar.show_percentage = false
    weather_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weather_bar.z_index = 150
    weather_bar.tooltip_text = (
        "Wetterdauer: 50 Sekunden aktive Kampfzeit · pausiert bei Aktionsauswahl"
    )
    weather_bar.add_theme_stylebox_override(
        "background", _bar(Color("17211fcc"), 2)
    )
    weather_bar.add_theme_stylebox_override(
        "fill", _bar(Color("f5df78"), 2)
    )
    battle_panel.add_child(weather_bar)
    _update_weather_ui()


func _process(delta: float) -> void:
    var weather_messages: Array[String] = []

    # Advance before combatants so a weather that reaches zero on this frame is
    # already gone when a newly-ready action resolves.
    if battle_active and not paused and battle_weather.is_active():
        var completion: Dictionary = battle_weather.advance_time(delta)
        if bool(completion.get("ended", false)):
            var weather_id: String = str(completion.get("weather_id", ""))
            var definition_value: Variant = completion.get("definition", {})
            var ended_definition: Dictionary = (
                definition_value if definition_value is Dictionary else {}
            )
            var end_message: String = battle_weather.end_message(
                weather_id, ended_definition
            )
            if not end_message.is_empty():
                weather_messages.append(end_message)
        _update_weather_ui()

    super._process(delta)
    _append_weather_log(weather_messages)


func _move_tooltip(move: Dictionary) -> String:
    var inherited: String = super._move_tooltip(move)
    var weather_id: String = _weather_id_for_move(move)
    if weather_id.is_empty():
        return inherited

    # Remove the legacy source-action/status line from the older weather layer.
    var kept := PackedStringArray()
    for line: String in inherited.split("\n"):
        if not line.begins_with("Wetter: "):
            kept.append(line)

    var seconds: int = int(round(battle_weather.duration_seconds(weather_id)))
    var extra: String = (
        "Wetter: " + battle_weather.weather_name(weather_id)
        + " · Dauer: " + str(seconds) + " Sekunden aktive Kampfzeit"
        + " · gleiches aktives Wetter kann nicht erneuert werden"
    )
    kept.append(extra)
    return "\n".join(kept)


func _activate_weather_from_move(actor: Dictionary, weather: Dictionary) -> Dictionary:
    var weather_id: String = str(weather.get("weather_id", ""))
    if not battle_weather.has_weather(weather_id):
        push_error("Attacke versucht unbekannte weather_id '%s' zu aktivieren." % weather_id)
        return {"ok": false, "reason": "unknown_weather_id"}

    var activation: Dictionary = battle_weather.activate(weather_id, actor)
    if str(activation.get("reason", "")) == "already_active":
        _same_weather_rejected_id = weather_id
    return activation


func _execute_move(actor: Dictionary, move_id: String) -> void:
    _same_weather_rejected_id = ""
    super._execute_move(actor, move_id)

    if not _same_weather_rejected_id.is_empty():
        var messages: Array[String] = [
            battle_weather.weather_name(_same_weather_rejected_id)
            + " ist bereits aktiv. Die Wetterdauer wird nicht erneuert."
        ]
        _append_weather_log(messages)
        _same_weather_rejected_id = ""


func _prompt_player(actor: Dictionary) -> void:
    super._prompt_player(actor)
    if action_grid == null or not battle_weather.is_active():
        return

    var actor_moves_value: Variant = actor.get("moves", [])
    if not (actor_moves_value is Array):
        return

    var move_buttons: Array[Button] = []
    for child: Node in action_grid.get_children():
        if child is Button:
            move_buttons.append(child as Button)

    var actor_moves: Array = actor_moves_value
    for move_index: int in range(mini(actor_moves.size(), move_buttons.size())):
        var move_id: String = str(actor_moves[move_index])
        var move: Dictionary = _move_data(move_id)
        var weather_id: String = _weather_id_for_move(move)
        if weather_id.is_empty() or weather_id != battle_weather.current_id():
            continue

        var button: Button = move_buttons[move_index]
        button.disabled = true
        var note: String = "Dieses Wetter ist bereits aktiv und kann nicht erneuert werden."
        button.tooltip_text = (
            note if button.tooltip_text.is_empty() else button.tooltip_text + "\n" + note
        )


func _weather_id_for_move(move: Dictionary) -> String:
    var weather_value: Variant = move.get("weather", null)
    if not (weather_value is Dictionary):
        return ""
    return str((weather_value as Dictionary).get("weather_id", ""))


func _update_weather_ui() -> void:
    var active: bool = battle_weather.is_active()

    if weather_label != null:
        weather_label.text = battle_weather.display_text() if active else ""
        weather_label.visible = active

    if weather_bar != null:
        weather_bar.value = battle_weather.remaining_fraction() if active else 0.0
        weather_bar.visible = active
        if active:
            weather_bar.tooltip_text = (
                "Wetterdauer: %.1f von %.0f Sekunden aktive Kampfzeit"
                % [battle_weather.remaining_seconds(), battle_weather.duration_seconds()]
            )
