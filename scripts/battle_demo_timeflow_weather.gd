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
const WEATHER_ATB_BLUE: Color = Color("42aef5")
const WEATHER_BAR_BACKGROUND: Color = Color("b5b5aa")
const WEATHER_BAR_BORDER: Color = Color("34443d")

var weather_bar: ProgressBar = null
var weather_bar_frame: PanelContainer = null
var weather_interaction: Button = null
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


func _weather_frame_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = WEATHER_BAR_BACKGROUND
    style.border_color = WEATHER_BAR_BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(3)
    style.content_margin_left = 1.0
    style.content_margin_right = 1.0
    style.content_margin_top = 1.0
    style.content_margin_bottom = 1.0
    return style


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
        weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

    weather_bar_frame = PanelContainer.new()
    weather_bar_frame.name = "WeatherTimeflowFrame"
    weather_bar_frame.anchor_left = 0.5
    weather_bar_frame.anchor_right = 0.5
    weather_bar_frame.offset_left = -49.0
    weather_bar_frame.offset_top = 47.0
    weather_bar_frame.offset_right = 49.0
    weather_bar_frame.offset_bottom = 55.0
    weather_bar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weather_bar_frame.z_index = 150
    weather_bar_frame.add_theme_stylebox_override("panel", _weather_frame_style())
    battle_panel.add_child(weather_bar_frame)

    weather_bar = ProgressBar.new()
    weather_bar.name = "WeatherTimeflowBar"
    weather_bar.min_value = 0.0
    weather_bar.max_value = 1.0
    weather_bar.value = 0.0
    weather_bar.show_percentage = false
    weather_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weather_bar.add_theme_stylebox_override(
        "background", _bar(WEATHER_BAR_BACKGROUND, 2)
    )
    weather_bar.add_theme_stylebox_override(
        "fill", _bar(WEATHER_ATB_BLUE, 2)
    )
    weather_bar_frame.add_child(weather_bar)

    # Desktop: hovering this invisible hit area shows a normal tooltip.
    # Mobile/Touch: one tap opens the existing pause-safe details overlay.
    weather_interaction = Button.new()
    weather_interaction.name = "WeatherInteraction"
    weather_interaction.anchor_left = 0.5
    weather_interaction.anchor_right = 0.5
    weather_interaction.offset_left = -54.0
    weather_interaction.offset_top = 31.0
    weather_interaction.offset_right = 54.0
    weather_interaction.offset_bottom = 58.0
    weather_interaction.text = ""
    weather_interaction.flat = true
    weather_interaction.focus_mode = Control.FOCUS_NONE
    weather_interaction.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    weather_interaction.z_index = 151
    var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
    for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
        weather_interaction.add_theme_stylebox_override(state, empty_style)
    weather_interaction.pressed.connect(_show_weather_info)
    battle_panel.add_child(weather_interaction)

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


func _weather_effect_lines(weather_id: String) -> Array[String]:
    var lines: Array[String] = []
    var definition: Dictionary = battle_weather.definition(weather_id)
    var rules_value: Variant = definition.get("damage_type_strength_coefficients", {})
    if not (rules_value is Dictionary):
        return lines

    var strength_percent: float = float(definition.get("effect_strength_percent", 0.0))
    var state: Dictionary = battle_weather.snapshot()
    if weather_id == battle_weather.current_id():
        strength_percent = float(state.get("strength_percent", strength_percent))

    for type_value: Variant in (rules_value as Dictionary).keys():
        var coefficient_value: Variant = (rules_value as Dictionary).get(type_value, 0.0)
        if not (coefficient_value is int or coefficient_value is float):
            continue
        var delta_percent: float = strength_percent * float(coefficient_value)
        if is_zero_approx(delta_percent):
            continue
        var sign: String = "+" if delta_percent > 0.0 else ""
        lines.append(
            _type_name(str(type_value)) + "-Attacken: "
            + sign + str(int(round(delta_percent))) + "% Schaden"
        )
    return lines


func _weather_tooltip_text() -> String:
    if not battle_weather.is_active():
        return ""

    var weather_id: String = battle_weather.current_id()
    var lines: Array[String] = [battle_weather.weather_name(weather_id)]
    for effect_line: String in _weather_effect_lines(weather_id):
        lines.append(effect_line)
    lines.append(
        "Restdauer: %.1f von %.0f Sekunden aktiver Kampfzeit"
        % [battle_weather.remaining_seconds(), battle_weather.duration_seconds(weather_id)]
    )
    lines.append("Bei der Aktionsauswahl pausiert auch die Wetterzeit.")
    lines.append("Klicken/Tippen für Details.")
    return "\n".join(lines)


func _weather_detail_text() -> String:
    if not battle_weather.is_active():
        return ""

    var weather_id: String = battle_weather.current_id()
    var state: Dictionary = battle_weather.snapshot()
    var lines: Array[String] = []
    lines.append("[b]KAMPFEFFEKT[/b]")
    var effect_lines: Array[String] = _weather_effect_lines(weather_id)
    if effect_lines.is_empty():
        lines.append("• Keine Schadensmodifikatoren")
    else:
        for effect_line: String in effect_lines:
            lines.append("• " + effect_line)

    lines.append("")
    lines.append("[b]TIMEFLOW[/b]")
    lines.append(
        "Restdauer: %.1f von %.0f Sekunden"
        % [battle_weather.remaining_seconds(), battle_weather.duration_seconds(weather_id)]
    )
    lines.append("• Die Wetterzeit läuft nur während aktiver Kampfzeit.")
    lines.append("• Während deiner Aktionsauswahl steht die Wetterzeit still.")
    lines.append("• Dasselbe aktive Wetter kann seine Dauer nicht erneuern.")
    lines.append("• Ein anderes Wetter ersetzt das aktuell aktive Wetter sofort.")

    var source_name: String = str(state.get("source_name", ""))
    if not source_name.is_empty():
        lines.append("")
        lines.append("Ausgelöst von: " + source_name)
    return "\n".join(lines)


func _show_weather_info() -> void:
    if not battle_weather.is_active() or info_panel == null:
        return

    info_was_paused = paused
    paused = true
    info_title.text = battle_weather.weather_name(battle_weather.current_id())
    info_body.text = _weather_detail_text()
    info_shade.visible = true
    info_panel.visible = true


func _update_weather_ui() -> void:
    var active: bool = battle_weather.is_active()

    if weather_label != null:
        weather_label.text = battle_weather.display_text() if active else ""
        weather_label.visible = active

    if weather_bar_frame != null:
        weather_bar_frame.visible = active

    if weather_bar != null:
        weather_bar.value = battle_weather.remaining_fraction() if active else 0.0
        weather_bar.visible = active

    if weather_interaction != null:
        weather_interaction.visible = active
        weather_interaction.tooltip_text = _weather_tooltip_text() if active else ""
