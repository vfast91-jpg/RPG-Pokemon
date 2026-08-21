extends "res://scripts/battle_demo_charmander_family_pledge.gd"

func _process(delta: float) -> void:
    var before_state: Dictionary = battle_weather.snapshot()
    super._process(delta)
    _cf_process_sandstorm_pulses(before_state)


func _cf_process_sandstorm_pulses(before_state: Dictionary) -> void:
    if str(before_state.get("weather_id", "")) != "sandstorm":
        if battle_weather.current_id() != "sandstorm":
            _cf_sandstorm_next_pulse = CF_SANDSTORM_PULSE_SECONDS
        return

    var before_remaining: float = float(
        before_state.get("remaining_seconds", CF_SANDSTORM_DURATION_SECONDS)
    )
    var before_elapsed: float = CF_SANDSTORM_DURATION_SECONDS - before_remaining
    var after_remaining: float = (
        battle_weather.remaining_seconds()
        if battle_weather.current_id() == "sandstorm"
        else 0.0
    )
    var after_elapsed: float = CF_SANDSTORM_DURATION_SECONDS - after_remaining
    var source_id: String = str(before_state.get("source_combatant_id", ""))

    while (
        _cf_sandstorm_next_pulse <= after_elapsed + 0.0001
        and _cf_sandstorm_next_pulse > before_elapsed + 0.0001
    ):
        _cf_apply_sandstorm_pulse(source_id)
        _cf_sandstorm_next_pulse += CF_SANDSTORM_PULSE_SECONDS

    if battle_weather.current_id() != "sandstorm":
        _cf_sandstorm_next_pulse = CF_SANDSTORM_PULSE_SECONDS


func _cf_apply_sandstorm_pulse(source_id: String) -> void:
    var any_damage: bool = false
    for target_value: Variant in combatants:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if not bool(target.get("alive", false)) or _cf_sandstorm_immune(target):
            continue
        var actual: int = _cf_deal_field_damage(
            target,
            CF_SANDSTORM_DAMAGE_FRACTION,
            "🌪️ SANDSTURM",
            source_id
        )
        any_damage = any_damage or actual > 0
    if any_damage:
        _refresh_cards()
        _check_end()


func _cf_sandstorm_immune(target: Dictionary) -> bool:
    var types: Array = _type_array(target.get("types", []))
    for type_id: String in CF_SANDSTORM_IMMUNE_TYPES:
        if types.has(type_id):
            return true
    return false


func _weather_effect_lines(weather_id: String) -> Array[String]:
    var lines: Array[String] = super._weather_effect_lines(weather_id)
    if weather_id == "sandstorm":
        lines.append("Alle 10 Sekunden: 1/16 Max-KP Schaden (außer Gestein, Boden, Stahl)")
        lines.append("Gestein-Pokémon: Verteidigung +50 %")
    return lines


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if _tf_has_state(combatant, "underground"):
        tokens.append("🕳️ UNTERIRDISCH")
    if _tf_has_state(combatant, "airborne_fly"):
        tokens.append("🪽 IN DER LUFT")
    if bool(combatant.get("cf_focus_punch_active", false)):
        tokens.append("🥊 FOKUS")
    if int(combatant.get("cf_dragon_cheer_actions", 0)) > 0:
        tokens.append("🐉 JUBEL")
    if int(combatant.get("cf_fire_pledge_ticks", 0)) > 0:
        tokens.append("🔥 FEUERMEER")
    if int(combatant.get("cf_rainbow_actions", 0)) > 0:
        tokens.append("🌈 REGENBOGEN")
    return tokens


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if CF_SUMMARIES.has(move_id):
        return str(CF_SUMMARIES[move_id])
    return super._compact_effect_summary(move)
