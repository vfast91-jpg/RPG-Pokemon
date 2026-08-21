extends "res://scripts/battle_demo_uncapped_light_screen.gd"

# Final central Status-scaling layer.
#
# All move effects that derive their strength from the RPG Status attribute use
# one shared diminishing-returns curve instead of linear percentages plus hard
# caps:
#
#     R = Status / (75 + Status)
#
# R is always below 1.0 at every finite Status value, so every additional point
# remains useful. Move-specific 1x/2x/3x weights are applied after the curve.
# Directional effects use multiplicative formulas that can never become
# negative: increases/slowdowns use (1 + kR), reductions/speedups use
# 1 / (1 + kR). Natural ceilings such as 100% healing/critical chance are only
# approached, never reached by the move contribution at a finite Status value.
#
# Weather is deliberately excluded: weather moves only activate a weather ID;
# the weather system owns weather strength/effects independently of Status.

const STATUS_CURVE: float = 75.0
const ATB_PAUSE_CYCLE_SCALE: float = 1.0
const TEMP_STATUS_KINDS: Array[String] = [
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod"
]


func _load_data() -> void:
    super._load_data()
    # Validate the final canonical move set after all database override files
    # have been merged.
    _audit_weather_moves()


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["db_focus_energy_bonus_pp"] = 0.0
    combatant["db_atb_pause_remaining_seconds"] = 0.0
    return combatant


func _process(delta: float) -> void:
    # ATB-pause control uses real combat time, but does not tick down while the
    # whole battle is paused for player input/feedback or during Runde 0.
    var frozen_cycles: Array = []
    var tick_pause: bool = battle_active and not paused and not opening_phase_active
    if tick_pause:
        for combatant_value: Variant in combatants:
            if not (combatant_value is Dictionary):
                continue
            var combatant: Dictionary = combatant_value
            var remaining: float = maxf(0.0, float(combatant.get("db_atb_pause_remaining_seconds", 0.0)))
            if remaining <= 0.0 or not bool(combatant.get("alive", false)):
                continue
            frozen_cycles.append({"combatant": combatant, "cycle": float(combatant.get("cycle", 1.0))})
            # The inherited ATB loop divides gain by cycle. A huge temporary
            # cycle therefore produces an actual pause without duplicating the
            # complete ATB implementation in this leaf layer.
            combatant["cycle"] = maxf(1.0, float(combatant.get("cycle", 1.0))) * 1000000.0
            combatant["db_atb_pause_remaining_seconds"] = maxf(0.0, remaining - delta)

    super._process(delta)

    for frozen_value: Variant in frozen_cycles:
        if not (frozen_value is Dictionary):
            continue
        var frozen: Dictionary = frozen_value
        var combatant_value: Variant = frozen.get("combatant", {})
        if combatant_value is Dictionary:
            (combatant_value as Dictionary)["cycle"] = float(frozen.get("cycle", 1.0))


func _status_ratio(status_value: float) -> float:
    var status: float = maxf(0.0, status_value)
    if status <= 0.0:
        return 0.0
    return status / (STATUS_CURVE + status)


func _status_percent(status_value: float) -> float:
    return 100.0 * _status_ratio(status_value)


func _status_strength_weight(actor: Dictionary, mechanic: Dictionary) -> float:
    var weight: float = absf(float(mechanic.get("multiplier_from_special", 1.0)))

    # Preserve the existing same-type Status bonus and Wachstum's sun
    # amplification, but apply both as move weights after the curve.
    var actor_types: Array = _type_array(actor.get("types", []))
    weight *= TypeSystem.get_same_type_status_multiplier(_active_move_type, actor_types)

    var runtime_value: Variant = _database_active_move.get("runtime", {})
    if runtime_value is Dictionary:
        var runtime: Dictionary = runtime_value
        if (
            float(runtime.get("sun_special_multiplier", 1.0)) > 1.0
            and str(battle_weather.snapshot().get("weather_id", "")) == "sun"
        ):
            weight *= float(runtime.get("sun_special_multiplier", 1.0))
    return maxf(0.0, weight)


func _status_modifier_multiplier(
    actor: Dictionary,
    mechanic: Dictionary,
    kind: String
) -> float:
    var signed_weight: float = float(mechanic.get("multiplier_from_special", 1.0))
    var weight: float = _status_strength_weight(actor, mechanic)
    var scaled: float = weight * _status_ratio(float(actor.get("special", 0.0)))

    match kind:
        "outgoing_damage_mod":
            return 1.0 + scaled if signed_weight >= 0.0 else 1.0 / (1.0 + scaled)
        "incoming_damage_mod":
            # Positive means vulnerability in this combat model. Damage
            # resolution divides by this stored defense multiplier.
            return 1.0 / (1.0 + scaled) if signed_weight >= 0.0 else 1.0 + scaled
        "accuracy_mod":
            return 1.0 + scaled if signed_weight >= 0.0 else 1.0 / (1.0 + scaled)
        "atb_cycle_mod":
            # Positive = slower (longer cycle); negative = faster.
            return 1.0 + scaled if signed_weight >= 0.0 else 1.0 / (1.0 + scaled)
        _:
            return 1.0


func _status_effect_aggro(kind: String, multiplier: float) -> float:
    var actual_multiplier: float = multiplier
    if kind == "incoming_damage_mod":
        actual_multiplier = 1.0 / maxf(0.0001, multiplier)
    var delta: float = absf(actual_multiplier - 1.0)
    var aggro_scale: float = 10.0 if kind == "outgoing_damage_mod" or kind == "incoming_damage_mod" else 8.0
    return delta * aggro_scale


func _target_full_atb_cycle_seconds(target: Dictionary) -> float:
    var speed: float = maxf(0.0, float(target.get("speed", 10.0)))
    if bool(target.get("paralyzed", false)):
        speed *= 0.5
    var cycle: float = maxf(
        0.01,
        float(target.get("cycle", 1.0)) * _combined_timed_modifier(target, "atb_cycle_mod")
    )
    var gain_per_second: float = maxf(0.01, (12.0 + speed * 0.62) / cycle)
    return 100.0 / gain_per_second


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    if TEMP_STATUS_KINDS.has(kind) and mechanic.has("multiplier_from_special"):
        if _database_positive_modifier_is_blocked(target, mechanic):
            _spawn_feedback_label(target, "⛔ BUFF BLOCKIERT", Color("e6b3b3"))
            return 0.0

        var multiplier: float = _status_modifier_multiplier(actor, mechanic, kind)
        _add_timed_modifier(
            target,
            kind,
            multiplier,
            _current_effect_move_name,
            _actor_name(actor)
        )
        return _status_effect_aggro(kind, multiplier)

    match kind:
        "critical_focus":
            var bonus_pp: float = _status_percent(float(actor.get("special", 0.0)))
            actor["db_focus_energy_bonus_pp"] = bonus_pp
            actor["critical_focus_bonus"] = bonus_pp / 100.0
            _spawn_feedback_label(actor, "🎯 KRIT +%.0f%%" % bonus_pp, Color("f3dc85"))
            return bonus_pp / 10.0

        "db_heal_self":
            var heal_percent: float = _status_percent(float(actor.get("special", 0.0)))
            var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
            if missing <= 0 or heal_percent <= 0.0:
                return 0.0
            var amount: int = mini(
                missing,
                maxi(1, int(round(float(actor.get("max_hp", 1)) * heal_percent / 100.0)))
            )
            actor["hp"] = int(actor.get("hp", 0)) + amount
            if amount > 0:
                _spawn_feedback_label(actor, "💚 +" + str(amount) + " KP", Color("8fe39b"))
            return float(amount)

        "db_light_screen":
            var reduction: float = _status_ratio(float(actor.get("special", 0.0)))
            target["db_light_screen_reduction"] = reduction
            target["db_light_screen_source_id"] = str(actor.get("id", ""))
            target["db_light_screen_expires_source_action"] = (
                int(actor.get("action_serial", 0))
                + maxi(1, int(mechanic.get("duration_actions", 3)))
            )
            return reduction * 10.0

        "db_next_cycle_mod":
            var next_cycle_multiplier: float = _status_modifier_multiplier(
                actor,
                {"multiplier_from_special": float(mechanic.get("multiplier_from_special", -1.0))},
                "atb_cycle_mod"
            )
            actor["cycle"] = float(actor.get("cycle", 1.0)) * next_cycle_multiplier
            return absf(next_cycle_multiplier - 1.0) * 8.0

        "db_incoming_accuracy":
            var direction: String = str(mechanic.get("direction", "reduction"))
            var signed_weight: float = absf(float(mechanic.get("multiplier_from_special", 1.0)))
            if direction != "bonus":
                signed_weight *= -1.0
            var adjusted: Dictionary = mechanic.duplicate(true)
            adjusted["multiplier_from_special"] = signed_weight
            target["db_incoming_accuracy_mult"] = _status_modifier_multiplier(actor, adjusted, "accuracy_mod")
            target["db_incoming_accuracy_expires"] = int(target.get("action_serial", 0)) + 3
            return absf(float(target.get("db_incoming_accuracy_mult", 1.0)) - 1.0) * 8.0

        "db_team_modifier":
            var modifier_kind: String = str(mechanic.get("modifier_kind", "atb_cycle_mod"))
            var team_multiplier: float = _status_modifier_multiplier(actor, mechanic, modifier_kind)
            _add_timed_modifier(
                target,
                modifier_kind,
                team_multiplier,
                str(_database_active_move.get("name", "Team-Effekt")),
                _actor_name(actor)
            )
            return _status_effect_aggro(modifier_kind, team_multiplier)

        "db_on_ko_modifier":
            if bool(target.get("alive", false)):
                return 0.0
            var ko_kind: String = str(mechanic.get("modifier_kind", "outgoing_damage_mod"))
            var ko_multiplier: float = _status_modifier_multiplier(actor, mechanic, ko_kind)
            _add_timed_modifier(
                actor,
                ko_kind,
                ko_multiplier,
                str(_database_active_move.get("name", "KO-Bonus")),
                _actor_name(actor)
            )
            return _status_effect_aggro(ko_kind, ko_multiplier)

        "db_stockpile":
            var max_stacks: int = maxi(1, int(mechanic.get("max", 3)))
            actor["db_stockpile"] = mini(max_stacks, int(actor.get("db_stockpile", 0)) + 1)
            var stacks: int = int(actor.get("db_stockpile", 0))
            var stockpile_mechanic: Dictionary = {"multiplier_from_special": -2.0 * float(stacks)}
            var stockpile_multiplier: float = _status_modifier_multiplier(actor, stockpile_mechanic, "incoming_damage_mod")
            _add_timed_modifier(actor, "incoming_damage_mod", stockpile_multiplier, "Horter", _actor_name(actor))
            return float(stacks)

        "db_atb_pause":
            var pause_weight: float = _status_strength_weight(actor, {"multiplier_from_special": 1.0})
            var pause_fraction: float = pause_weight * _status_ratio(float(actor.get("special", 0.0)))
            var pause_seconds: float = _target_full_atb_cycle_seconds(target) * pause_fraction * ATB_PAUSE_CYCLE_SCALE
            if pause_seconds <= 0.0:
                return 0.0
            target["db_atb_pause_remaining_seconds"] = maxf(
                float(target.get("db_atb_pause_remaining_seconds", 0.0)),
                pause_seconds
            )
            _spawn_feedback_label(target, "⏸ ATB %.1fs" % pause_seconds, Color("b9d7ff"))
            return pause_seconds * 4.0

    return super._effect(actor, target, mechanic)


func _combined_timed_modifier(combatant: Dictionary, kind: String) -> float:
    # Individual Status effects are already bounded by the curve, so the old
    # hard result clamps would only create a second artificial plateau.
    var result: float = 1.0
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if not (modifier_value is Dictionary):
                continue
            var modifier: Dictionary = modifier_value
            if str(modifier.get("kind", "")) == kind:
                result *= maxf(0.0001, float(modifier.get("multiplier", 1.0)))
    return maxf(0.0001, result)


func _critical_chance(combatant: Dictionary) -> float:
    if bool(combatant.get("db_guaranteed_crit", false)):
        return 1.0
    return clampf(super._critical_chance(combatant), 0.0, 1.0)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var pause_seconds: float = float(combatant.get("db_atb_pause_remaining_seconds", 0.0))
    if pause_seconds > 0.01:
        tokens.append("⏸ %.1fs" % pause_seconds)
    return tokens


# Weather move contract -----------------------------------------------------
# The move supplies only weather_id. Strength, duration and actual combat
# effects live in BattleWeatherState/weather_rules.json so abilities/items/
# areas can later activate the exact same weather without pretending to use a
# move.

func _audit_weather_spec_keys(move_id: String, weather: Dictionary) -> bool:
    var valid: bool = true
    for key_value: Variant in weather.keys():
        var key: String = str(key_value)
        if key != "weather_id":
            push_error(
                "Wetter-Audit: %s enthält das veraltete attackenspezifische Wetterfeld '%s'."
                % [move_id, key]
            )
            valid = false
    return valid


func _audit_weather_moves() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
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
                push_error("Wetter-Audit: %s hat eine weather-Mechanik ohne weather_id." % move_id)
            continue
        if not (weather_value is Dictionary):
            push_error("Wetter-Audit: %s besitzt keinen gültigen weather-Block." % move_id)
            continue
        if not has_weather_mechanic:
            push_error("Wetter-Audit: %s hat weather-Daten ohne weather-Mechanik." % move_id)
            continue
        var weather: Dictionary = weather_value
        if not _audit_weather_spec_keys(move_id, weather):
            continue
        var weather_id: String = str(weather.get("weather_id", ""))
        if weather_id.is_empty() or not battle_weather.has_weather(weather_id):
            push_error("Wetter-Audit: %s verwendet unbekannte weather_id '%s'." % [move_id, weather_id])


func _activate_weather_from_move(actor: Dictionary, weather: Dictionary) -> Dictionary:
    var weather_id: String = str(weather.get("weather_id", ""))
    if weather_id.is_empty() or not battle_weather.has_weather(weather_id):
        push_error("Attacke versucht unbekannte weather_id '%s' zu aktivieren." % weather_id)
        return {"ok": false, "reason": "unknown_weather_id"}
    return battle_weather.activate(weather_id, actor)


func _move_tooltip(move: Dictionary) -> String:
    var tooltip: String = super._move_tooltip(move)
    var weather_value: Variant = move.get("weather", null)
    if not (weather_value is Dictionary):
        return tooltip
    var weather_id: String = str((weather_value as Dictionary).get("weather_id", ""))
    var extra: String = (
        "Aktiviert " + battle_weather.weather_name(weather_id)
        + ". Stärke, Dauer und Wirkung gehören vollständig zum zentralen Wettersystem."
    )
    return extra if tooltip.is_empty() else tooltip + "\n" + extra


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    var status_value: float = 0.0 if selected_actor.is_empty() else maxf(0.0, float(selected_actor.get("special", 0.0)))

    if move_id == "rain_dance" or move_id == "sunny_day":
        var weather_value: Variant = move.get("weather", {})
        var weather_id: String = str((weather_value as Dictionary).get("weather_id", "")) if weather_value is Dictionary else ""
        return "aktiviert global " + battle_weather.weather_name(weather_id) + " · ersetzt anderes aktives Wetter"

    if move_id == "focus_energy":
        if not selected_actor.is_empty():
            return "Volltrefferchance +%d Prozentpunkte (Status %d) · bis Wechsel/Kampfende · nicht stapelbar" % [int(round(_status_percent(status_value))), int(round(status_value))]
        return "Volltrefferbonus = 100 × Status / (75 + Status) Prozentpunkte · nicht stapelbar"

    if move_id == "synthesis" or move_id == "roost":
        var suffix: String = ""
        if move_id == "roost":
            suffix = " · Flug-Typ bis zur nächsten eigenen Aktion entfernt"
        if not selected_actor.is_empty():
            return "heilt %d%% der Max-KP (Status %d) · jeder weitere Statuspunkt wirkt weiter%s" % [int(round(_status_percent(status_value))), int(round(status_value)), suffix]
        return "Heilung = 100 × Status / (75 + Status) %% der Max-KP" + suffix

    if move_id == "light_screen":
        var duration: int = 3
        var mechanics_value: Variant = move.get("mechanics", [])
        if mechanics_value is Array:
            for mechanic_value: Variant in mechanics_value:
                if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "db_light_screen":
                    duration = maxi(1, int((mechanic_value as Dictionary).get("duration_actions", 3)))
                    break
        if not selected_actor.is_empty():
            return "Spezial-Attacken gegen alle Verbündeten: −%d%% Schaden (Status %d) · physisch unverändert · %d eigene Aktionen" % [int(round(_status_percent(status_value))), int(round(status_value)), duration]
        return "Spezial-Schadensreduktion = 100 × Status / (75 + Status) %% · physisch unverändert"

    if move_id == "whirlwind" or move_id == "roar":
        if not selected_actor.is_empty():
            var targets: Array = _targets(selected_actor, str(move.get("target", "enemy_highest_aggro")))
            if not targets.is_empty() and targets[0] is Dictionary:
                var target: Dictionary = targets[0]
                var pause_weight: float = _status_strength_weight(selected_actor, {"multiplier_from_special": 1.0})
                var pause_seconds: float = _target_full_atb_cycle_seconds(target) * pause_weight * _status_ratio(status_value)
                return "pausiert die ATB von %s für ca. %.1f s (Status %d)" % [_actor_name(target), pause_seconds, int(round(status_value))]
        return "ATB-Pausendauer = voller Ziel-ATB-Zyklus × Status / (75 + Status)"

    var mechanics_value: Variant = move.get("mechanics", [])
    if not selected_actor.is_empty() and mechanics_value is Array:
        var details: Array[String] = []
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            var mechanic: Dictionary = mechanic_value
            var kind: String = str(mechanic.get("kind", ""))
            if TEMP_STATUS_KINDS.has(kind) and mechanic.has("multiplier_from_special"):
                var multiplier: float = _status_modifier_multiplier(selected_actor, mechanic, kind)
                match kind:
                    "outgoing_damage_mod": details.append("verursachter Schaden ×" + _decimal(multiplier, 2))
                    "incoming_damage_mod": details.append("eingehender Schaden ×" + _decimal(1.0 / maxf(0.0001, multiplier), 2))
                    "accuracy_mod": details.append("Genauigkeit ×" + _decimal(multiplier, 2))
                    "atb_cycle_mod": details.append("ATB-Zyklus ×" + _decimal(multiplier, 2))
        if not details.is_empty():
            return " · ".join(details) + " · 3 eigene Aktionen des betroffenen Pokémon"

    return super._compact_effect_summary(move)
