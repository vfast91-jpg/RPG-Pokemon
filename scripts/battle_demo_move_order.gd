extends "res://scripts/battle_demo_status_curve_final.gd"

# Route-only presentation bridge: the move order chosen in the between-battle
# team view is applied after the normal combatant setup (including TM moves).
# No combat rules or move availability are changed.
#
# This final layer also owns player-facing timing language. Internally the
# battle engine keeps the established ATB field/mechanic names, but players
# only see Aktionsleiste/Aktionszeit and percentage changes. Raw multipliers
# such as x0.90 or x1.15 must never be required to understand an effect.


func _load_data() -> void:
    super._load_data()
    _sanitize_player_move_descriptions()


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not route_mode or not battle_active:
        return

    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        if team_index < 0 or team_index >= _route_team_state.size():
            continue

        var combatant_value: Variant = player_team[local_index]
        var member_value: Variant = _route_team_state[team_index]
        if combatant_value is Dictionary and member_value is Dictionary:
            _apply_route_move_order(combatant_value as Dictionary, member_value as Dictionary)

    _refresh_cards()


func _apply_route_move_order(combatant: Dictionary, member_state: Dictionary) -> void:
    var current_value: Variant = combatant.get("moves", [])
    if not (current_value is Array):
        return

    var current: Array[String] = []
    for move_value: Variant in current_value:
        var move_id: String = str(move_value)
        if not move_id.is_empty() and not current.has(move_id):
            current.append(move_id)

    var ordered: Array[String] = []
    var stored_value: Variant = member_state.get("move_order", [])
    if stored_value is Array:
        for move_value: Variant in stored_value:
            var move_id: String = str(move_value)
            if current.has(move_id) and not ordered.has(move_id):
                ordered.append(move_id)

    # Newly learned or newly acquired TM moves that are not in the saved order
    # are appended, so the player never loses access to an attack.
    for move_id: String in current:
        if not ordered.has(move_id):
            ordered.append(move_id)

    combatant["moves"] = ordered


func _refresh_cards() -> void:
    super._refresh_cards()

    # "BEREIT" explains the bar through play: at 100% this Pokemon can act.
    # Internal node/dictionary keys intentionally stay named ATB for stability.
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var ready_label: Label = ui.get("atb_text") as Label
        if ready_label != null:
            ready_label.text = "BEREIT %.0f%%" % float(combatant.get("atb", 0.0))


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var inherited: Array[String] = super._status_tokens(combatant)
    var result: Array[String] = []

    # Remove every old technical ATB shorthand, including stacked forms such as
    # ATB+×2. A single exact percentage below replaces all of them.
    for token: String in inherited:
        if token.begins_with("ATB"):
            continue
        result.append(_player_text_cleanup(token))

    var next_cycle: float = float(combatant.get("next_cycle", 1.0))
    var timed_cycle: float = _combined_timed_modifier(combatant, "atb_cycle_mod")
    var timing_multiplier: float = next_cycle * timed_cycle
    if not is_equal_approx(timing_multiplier, 1.0):
        result.append("ZEIT " + _signed_percent_delta(timing_multiplier))

    return result


func _detail_info(combatant: Dictionary) -> String:
    var text: String = super._detail_info(combatant)

    var fill: float = float(combatant.get("atb", 0.0))
    text = text.replace(
        "ATB: %.0f%%" % fill,
        "Aktionsleiste: %.0f%%" % fill
    )

    # Old one-shot fields can still appear in inherited/debug paths. Translate
    # them as percentages instead of exposing raw multipliers.
    var attack_mult: float = float(combatant.get("attack_mult", 1.0))
    if not is_equal_approx(attack_mult, 1.0):
        text = text.replace(
            "Nächster Schaden: x%.2f" % attack_mult,
            "Nächster Schaden: " + _signed_percent_delta(attack_mult)
        )

    var defense_mult: float = float(combatant.get("defense_mult", 1.0))
    if not is_equal_approx(defense_mult, 1.0):
        var incoming_mult: float = 1.0 / maxf(0.25, defense_mult)
        text = text.replace(
            "Eingehender Schaden: ca. x%.2f" % incoming_mult,
            "Eingehender Schaden: ca. " + _signed_percent_delta(incoming_mult)
        )

    var accuracy_mult: float = float(combatant.get("accuracy_mult", 1.0))
    if not is_equal_approx(accuracy_mult, 1.0):
        text = text.replace(
            "Nächste Genauigkeit: x%.2f" % accuracy_mult,
            "Nächste Genauigkeit: " + _signed_percent_delta(accuracy_mult)
        )

    var next_cycle: float = float(combatant.get("next_cycle", 1.0))
    if not is_equal_approx(next_cycle, 1.0):
        text = text.replace(
            "Nächster ATB-Zyklus: x%.2f" % next_cycle,
            _action_time_sentence(next_cycle)
        )

    # Three-action effects also show combined values when several effects stack.
    # Convert those aggregate multipliers to the same percentage language.
    if _active_modifier_count(combatant, "outgoing_damage_mod") > 1:
        var outgoing_total: float = _combined_timed_modifier(combatant, "outgoing_damage_mod")
        text = text.replace(
            "Gesamt verursachter Schaden: ×" + _decimal(outgoing_total, 2),
            "Gesamt verursachter Schaden: " + _signed_percent_delta(outgoing_total)
        )

    if _active_modifier_count(combatant, "incoming_damage_mod") > 1:
        var incoming_total: float = 1.0 / maxf(
            0.25,
            _combined_timed_modifier(combatant, "incoming_damage_mod")
        )
        text = text.replace(
            "Gesamt eingehender Schaden: ×" + _decimal(incoming_total, 2),
            "Gesamt eingehender Schaden: " + _signed_percent_delta(incoming_total)
        )

    if _active_modifier_count(combatant, "accuracy_mod") > 1:
        var accuracy_total: float = _combined_timed_modifier(combatant, "accuracy_mod")
        text = text.replace(
            "Gesamt Genauigkeit: ×" + _decimal(accuracy_total, 2),
            "Gesamt Genauigkeit: " + _signed_percent_delta(accuracy_total)
        )

    if _active_modifier_count(combatant, "atb_cycle_mod") > 1:
        var timing_total: float = _combined_timed_modifier(combatant, "atb_cycle_mod")
        text = text.replace(
            "Gesamt ATB-Zyklus: ×" + _decimal(timing_total, 2),
            "Gesamt " + _action_time_sentence(timing_total)
        )

    text = text.replace("Initiative halbiert", "Geschwindigkeit −50%")
    text = text.replace("Initiative", "Geschwindigkeit")
    return _player_text_cleanup(text)


func _modifier_detail_text(kind: String, multiplier: float) -> String:
    match kind:
        "outgoing_damage_mod":
            return "verursachter Schaden " + _signed_percent_delta(multiplier)
        "incoming_damage_mod":
            var incoming_multiplier: float = 1.0 / maxf(0.25, multiplier)
            return "eingehender Schaden " + _signed_percent_delta(incoming_multiplier)
        "accuracy_mod":
            return "Genauigkeit " + _signed_percent_delta(multiplier)
        "atb_cycle_mod":
            return _action_time_sentence(multiplier)
        _:
            return _player_text_cleanup(super._modifier_detail_text(kind, multiplier))


func _move_tooltip(move: Dictionary) -> String:
    return _player_text_cleanup(super._move_tooltip(move))


func _compact_effect_summary(move: Dictionary) -> String:
    return _player_text_cleanup(super._compact_effect_summary(move))


func _feedback_result(target: Dictionary, before: Dictionary) -> Dictionary:
    var result: Dictionary = super._feedback_result(target, before)
    result["text"] = _player_text_cleanup(str(result.get("text", "")))
    return result


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    # Keep the exact established pause mechanic, but replace its one remaining
    # technical floating label. All calculations and stored fields stay intact.
    if str(mechanic.get("kind", "")) == "db_atb_pause":
        var pause_fraction: float = _status_ratio(float(actor.get("special", 0.0)))
        var pause_seconds: float = (
            _target_full_atb_cycle_seconds(target)
            * pause_fraction
            * ATB_PAUSE_CYCLE_SCALE
        )
        if pause_seconds <= 0.0:
            return 0.0
        target["db_atb_pause_remaining_seconds"] = maxf(
            float(target.get("db_atb_pause_remaining_seconds", 0.0)),
            pause_seconds
        )
        _spawn_feedback_label(
            target,
            "⏸ AKTIONSLEISTE PAUSIERT · %.1fs" % pause_seconds,
            Color("b9d7ff")
        )
        return pause_seconds * 4.0

    return super._effect(actor, target, mechanic)


func _sanitize_player_move_descriptions() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return

    var moves: Dictionary = moves_value
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        if move.has("description"):
            move["description"] = _player_text_cleanup(str(move.get("description", "")))
        moves[move_id] = move
    data["moves"] = moves


func _signed_percent_delta(multiplier: float) -> String:
    var percent: int = int(round((multiplier - 1.0) * 100.0))
    if percent > 0:
        return "+%d%%" % percent
    if percent < 0:
        return "−%d%%" % absi(percent)
    return "0%"


func _action_time_sentence(multiplier: float) -> String:
    var delta_text: String = _signed_percent_delta(multiplier)
    if multiplier < 1.0:
        return "Zeit bis zur nächsten Aktion: %s (schneller bereit)" % delta_text
    if multiplier > 1.0:
        return "Zeit bis zur nächsten Aktion: %s (später bereit)" % delta_text
    return "Zeit bis zur nächsten Aktion: unverändert"


func _player_text_cleanup(source: String) -> String:
    # Long/specific phrases first, then a final acronym catch-all. This only
    # touches strings shown to the player; technical mechanic IDs stay intact.
    var text: String = source
    text = text.replace("ATB-Geschwindigkeit", "Aktionsgeschwindigkeit")
    text = text.replace("ATB-Knockback", "Zurückwurf der Aktionsleiste")
    text = text.replace("ATB-Pause", "Pause der Aktionsleiste")
    text = text.replace("ATB-Leiste", "Aktionsleiste")
    text = text.replace("ATB-Zyklus", "Aktionszyklus")
    text = text.replace("ATB", "Aktionsleiste")
    text = text.replace("stoppt die Aktionsleiste", "pausiert die Aktionsleiste")
    return text
