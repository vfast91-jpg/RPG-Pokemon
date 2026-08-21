extends "res://scripts/battle_demo_move_order.gd"

# Final player-language layer.
# Technical multiplier/ATB vocabulary may remain inside the combat engine, but
# the visible UI explains real attributes and timing changes in plain percent.
#
# Player-facing convention:
# - outgoing_damage_mod -> Angriff
# - incoming_damage_mod -> Verteidigung
# - accuracy_mod -> Genauigkeit
# - timed atb_cycle_mod -> Geschwindigkeit
# - one-shot cycle/AP effects -> Zeit bis zur nächsten Aktion
# - direct ATB fill changes -> Aktionsleiste


func _prompt_player(actor: Dictionary) -> void:
    super._prompt_player(actor)

    # Parent layers create the wait button themselves. Sanitize every visible
    # tooltip afterwards so no inherited technical wording slips through.
    if action_grid == null:
        return
    for child_value: Variant in action_grid.get_children():
        if child_value is Button:
            var button: Button = child_value
            button.tooltip_text = _player_text_cleanup(button.tooltip_text)


func _move_tooltip(move: Dictionary) -> String:
    var text: String = super._move_tooltip(move)
    var ap: int = _ap_value(move)
    var cycle: float = _ap_cycle(ap)

    # AP is a time cost, not a stat change. Keep it separate from Speed effects.
    text = text.replace(
        "AP %d → Aktionszyklus ×%s" % [ap, _decimal(cycle, 2)],
        "AP %d → Zeitkosten %s" % [ap, _signed_percent_delta(cycle)]
    )
    return _player_text_cleanup(text)


func _compact_effect_summary(move: Dictionary) -> String:
    var text: String = super._compact_effect_summary(move)
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return _player_text_cleanup(text)

    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        var kind: String = str(mechanic.get("kind", ""))
        var signed_weight: float = float(mechanic.get("multiplier_from_special", 0.0))

        match kind:
            "outgoing_damage_mod":
                var old_outgoing: String = (
                    "verursachter Schaden ↓" if signed_weight < 0.0
                    else "verursachter Schaden ↑"
                )
                text = text.replace(
                    old_outgoing,
                    _attribute_modifier_summary(mechanic, kind)
                )

            "incoming_damage_mod":
                var old_incoming: String = (
                    "eingehender Schaden ↓" if signed_weight < 0.0
                    else "eingehender Schaden ↑"
                )
                text = text.replace(
                    old_incoming,
                    _attribute_modifier_summary(mechanic, kind)
                )

            "accuracy_mod":
                var old_accuracy: String = (
                    "Genauigkeit ↓" if signed_weight < 0.0
                    else "Genauigkeit ↑"
                )
                text = text.replace(
                    old_accuracy,
                    _attribute_modifier_summary(mechanic, kind)
                )

            "atb_cycle_mod":
                var speed_summary: String = _attribute_modifier_summary(mechanic, kind)
                text = text.replace("Aktionsleiste schneller", speed_summary)
                text = text.replace("Aktionsleiste langsamer", speed_summary)
                text = text.replace("schneller wieder bereit", speed_summary)
                text = text.replace("später wieder bereit", speed_summary)

            "db_team_modifier":
                var team_kind: String = str(mechanic.get("modifier_kind", ""))
                if _is_player_attribute_modifier(team_kind):
                    text = text.replace(
                        "db team modifier",
                        _attribute_modifier_summary(mechanic, team_kind, false, false)
                    )

            "db_on_ko_modifier":
                var ko_kind: String = str(mechanic.get("modifier_kind", ""))
                if _is_player_attribute_modifier(ko_kind):
                    text = text.replace(
                        "db on ko modifier",
                        "bei K.O.: " + _attribute_modifier_summary(
                            mechanic,
                            ko_kind,
                            false,
                            false
                        )
                    )

            "db_chance_mechanic":
                var nested_value: Variant = mechanic.get("mechanic", {})
                if nested_value is Dictionary:
                    var nested: Dictionary = nested_value
                    var nested_kind: String = str(nested.get("kind", ""))
                    if _is_player_attribute_modifier(nested_kind):
                        var chance: int = int(round(
                            float(mechanic.get("chance", 1.0)) * 100.0
                        ))
                        text = text.replace(
                            "db chance mechanic",
                            "%d%% Chance: %s" % [
                                chance,
                                _attribute_modifier_summary(nested, nested_kind)
                            ]
                        )

            "db_incoming_accuracy":
                var direction: String = str(mechanic.get("direction", "reduction"))
                var adjusted: Dictionary = mechanic.duplicate(true)
                var incoming_weight: float = absf(
                    float(mechanic.get("multiplier_from_special", 1.0))
                )
                if direction != "bonus":
                    incoming_weight *= -1.0
                adjusted["multiplier_from_special"] = incoming_weight
                if selected_actor.is_empty():
                    text = text.replace(
                        "db incoming accuracy",
                        "Treffchance gegen Ziel " + ("↑" if direction == "bonus" else "↓")
                    )
                else:
                    var hit_multiplier: float = _status_modifier_multiplier(
                        selected_actor,
                        adjusted,
                        "accuracy_mod",
                        false,
                        false
                    )
                    text = text.replace(
                        "db incoming accuracy",
                        "Treffchance gegen Ziel " + _signed_percent_delta(hit_multiplier)
                    )

            "db_next_cycle_mod":
                var next_cycle_mechanic: Dictionary = {
                    "multiplier_from_special": float(
                        mechanic.get("multiplier_from_special", -1.0)
                    )
                }
                if selected_actor.is_empty():
                    text = text.replace(
                        "db next cycle mod",
                        "Zeit bis zur nächsten Aktion wird verkürzt"
                    )
                else:
                    var next_cycle_multiplier: float = _status_modifier_multiplier(
                        selected_actor,
                        next_cycle_mechanic,
                        "atb_cycle_mod",
                        false,
                        false
                    )
                    text = text.replace(
                        "db next cycle mod",
                        _action_time_sentence(next_cycle_multiplier)
                    )

    return _player_text_cleanup(text)


func _compact_type_context(move: Dictionary, category: String, move_type: String) -> String:
    if selected_actor.is_empty():
        return ""

    var bits: Array[String] = []
    var actor_types: Array = _type_array(selected_actor.get("types", []))
    if actor_types.has(move_type):
        if category == "status":
            var status_bonus: float = TypeSystem.get_same_type_status_multiplier(
                move_type,
                actor_types
            )
            bits.append("eigener Typbonus: Statuswirkung " + _signed_percent_delta(status_bonus))
        else:
            var damage_bonus: float = TypeSystem.get_same_type_damage_multiplier(
                move_type,
                actor_types
            )
            bits.append("eigener Typbonus: Schaden " + _signed_percent_delta(damage_bonus))

    if category != "status":
        var current_targets: Array = _targets(
            selected_actor,
            str(move.get("target", "enemy_highest_aggro"))
        )
        if current_targets.size() == 1 and current_targets[0] is Dictionary:
            var target: Dictionary = current_targets[0]
            var defender_types: Array = _type_array(target.get("types", []))
            var multiplier: float = TypeSystem.get_multiplier(move_type, defender_types)
            if is_equal_approx(multiplier, 1.0):
                bits.append("gegen " + _actor_name(target) + ": normal")
            else:
                bits.append(
                    "gegen " + _actor_name(target) + ": Schaden "
                    + _signed_percent_delta(multiplier)
                    + " (" + _effectiveness_name(multiplier) + ")"
                )
        elif current_targets.size() > 1:
            bits.append("Typwirkung wird je Ziel berechnet")

    if bits.is_empty():
        return ""
    return "Matchup: " + " · ".join(bits)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var inherited: Array[String] = super._status_tokens(combatant)
    var result: Array[String] = []

    # Small battle cards use compact labels, but still show exact percentages.
    # Full attribute names remain available in the detail panel and tooltips.
    for token: String in inherited:
        if (
            token.begins_with("ANG")
            or token.begins_with("DEF")
            or token.begins_with("GEN")
            or token.begins_with("ZEIT")
        ):
            continue
        result.append(_player_text_cleanup(token))

    if _active_modifier_count(combatant, "outgoing_damage_mod") > 0:
        result.append(
            "ANG " + _signed_percent_delta(
                _combined_timed_modifier(combatant, "outgoing_damage_mod")
            )
        )

    if _active_modifier_count(combatant, "incoming_damage_mod") > 0:
        result.append(
            "VER " + _signed_percent_delta(
                _combined_timed_modifier(combatant, "incoming_damage_mod")
            )
        )

    if _active_modifier_count(combatant, "accuracy_mod") > 0:
        result.append(
            "GEN " + _signed_percent_delta(
                _combined_timed_modifier(combatant, "accuracy_mod")
            )
        )

    if _active_modifier_count(combatant, "atb_cycle_mod") > 0:
        var cycle: float = _combined_timed_modifier(combatant, "atb_cycle_mod")
        result.append(
            "GES " + _signed_percent_delta(_speed_multiplier_from_cycle(cycle))
        )

    # next_cycle is a one-shot recovery/time effect, not a Speed-stat effect.
    var next_cycle: float = float(combatant.get("next_cycle", 1.0))
    if not is_equal_approx(next_cycle, 1.0):
        result.append("ZEIT " + _signed_percent_delta(next_cycle))

    return result


func _modifier_detail_text(kind: String, multiplier: float) -> String:
    match kind:
        "outgoing_damage_mod":
            return "Angriff " + _signed_percent_delta(multiplier)
        "incoming_damage_mod":
            return "Verteidigung " + _signed_percent_delta(multiplier)
        "accuracy_mod":
            return "Genauigkeit " + _signed_percent_delta(multiplier)
        "atb_cycle_mod":
            return (
                "Geschwindigkeit "
                + _signed_percent_delta(_speed_multiplier_from_cycle(multiplier))
            )
        _:
            return _player_text_cleanup(super._modifier_detail_text(kind, multiplier))


func _detail_info(combatant: Dictionary) -> String:
    var text: String = super._detail_info(combatant)

    # Legacy one-shot fields: name the actual affected attribute rather than
    # explaining it indirectly through damage.
    var attack_mult: float = float(combatant.get("attack_mult", 1.0))
    if not is_equal_approx(attack_mult, 1.0):
        text = text.replace(
            "Nächster Schaden: " + _signed_percent_delta(attack_mult),
            "Angriff für nächste Schadensattacke: " + _signed_percent_delta(attack_mult)
        )

    var defense_mult: float = float(combatant.get("defense_mult", 1.0))
    if not is_equal_approx(defense_mult, 1.0):
        var old_incoming_mult: float = 1.0 / maxf(0.25, defense_mult)
        text = text.replace(
            "Eingehender Schaden: ca. " + _signed_percent_delta(old_incoming_mult),
            "Verteidigung: " + _signed_percent_delta(defense_mult)
        )

    # Stacked temporary effects: totals are totals of the actual attributes.
    if _active_modifier_count(combatant, "outgoing_damage_mod") > 1:
        var attack_total: float = _combined_timed_modifier(
            combatant,
            "outgoing_damage_mod"
        )
        text = text.replace(
            "Gesamt verursachter Schaden: " + _signed_percent_delta(attack_total),
            "Gesamt Angriff: " + _signed_percent_delta(attack_total)
        )

    if _active_modifier_count(combatant, "incoming_damage_mod") > 1:
        var defense_total: float = _combined_timed_modifier(
            combatant,
            "incoming_damage_mod"
        )
        var old_incoming_total: float = 1.0 / maxf(0.25, defense_total)
        text = text.replace(
            "Gesamt eingehender Schaden: " + _signed_percent_delta(old_incoming_total),
            "Gesamt Verteidigung: " + _signed_percent_delta(defense_total)
        )

    if _active_modifier_count(combatant, "atb_cycle_mod") > 1:
        var cycle_total: float = _combined_timed_modifier(combatant, "atb_cycle_mod")
        text = text.replace(
            "Gesamt " + _action_time_sentence(cycle_total),
            "Gesamt Geschwindigkeit: "
            + _signed_percent_delta(_speed_multiplier_from_cycle(cycle_total))
        )

    return _player_text_cleanup(text)


func _feedback_result(target: Dictionary, before: Dictionary) -> Dictionary:
    var result: Dictionary = super._feedback_result(target, before)
    var text: String = str(result.get("text", ""))

    var attack_after: float = _combined_timed_modifier(target, "outgoing_damage_mod")
    var attack_change: int = _compare_float(
        float(before.get("attack_mult", 1.0)),
        attack_after
    )
    if attack_change != 0:
        text = text.replace(
            "ANGRIFF " + ("↑" if attack_change > 0 else "↓") + " · 3 AKTIONEN",
            "ANGRIFF " + _signed_percent_delta(attack_after) + " · 3 AKTIONEN"
        )

    var defense_after: float = _combined_timed_modifier(target, "incoming_damage_mod")
    var defense_change: int = _compare_float(
        float(before.get("defense_mult", 1.0)),
        defense_after
    )
    if defense_change != 0:
        text = text.replace(
            "SCHUTZ " + ("↑" if defense_change > 0 else "↓") + " · 3 AKTIONEN",
            "VERTEIDIGUNG " + _signed_percent_delta(defense_after) + " · 3 AKTIONEN"
        )

    var accuracy_after: float = _combined_timed_modifier(target, "accuracy_mod")
    var accuracy_change: int = _compare_float(
        float(before.get("accuracy_mult", 1.0)),
        accuracy_after
    )
    if accuracy_change != 0:
        text = text.replace(
            "GENAUIGKEIT " + ("↑" if accuracy_change > 0 else "↓") + " · 3 AKTIONEN",
            "GENAUIGKEIT " + _signed_percent_delta(accuracy_after) + " · 3 AKTIONEN"
        )

    var cycle_after: float = _combined_timed_modifier(target, "atb_cycle_mod")
    var cycle_change: int = _compare_float(
        float(before.get("next_cycle", 1.0)),
        cycle_after
    )
    if cycle_change != 0:
        var speed_text: String = (
            "GESCHWINDIGKEIT "
            + _signed_percent_delta(_speed_multiplier_from_cycle(cycle_after))
            + " · 3 AKTIONEN"
        )
        text = text.replace("AKTIONSLEISTE LANGSAMER · 3 AKTIONEN", speed_text)
        text = text.replace("AKTIONSLEISTE SCHNELLER · 3 AKTIONEN", speed_text)
        text = text.replace("ATB LANGSAMER · 3 AKTIONEN", speed_text)
        text = text.replace("ATB SCHNELLER · 3 AKTIONEN", speed_text)

    # Direct bar knockback is not a Speed change; show the exact lost fill.
    var atb_before: float = float(before.get("atb", 0.0))
    var atb_after: float = float(target.get("atb", 0.0))
    if atb_after < atb_before - 0.5:
        var lost_fill: int = int(round(atb_before - atb_after))
        text = text.replace("AKTIONSLEISTE ↓", "AKTIONSLEISTE −%d%%" % lost_fill)
        text = text.replace("ATB ↓", "AKTIONSLEISTE −%d%%" % lost_fill)

    result["text"] = _player_text_cleanup(text)
    return result


func _attribute_modifier_summary(
    mechanic: Dictionary,
    kind: String,
    apply_type_bonus: bool = true,
    apply_sun_bonus: bool = true
) -> String:
    if selected_actor.is_empty():
        return _attribute_direction_summary(mechanic, kind)

    var multiplier: float = _status_modifier_multiplier(
        selected_actor,
        mechanic,
        kind,
        apply_type_bonus,
        apply_sun_bonus
    )

    match kind:
        "outgoing_damage_mod":
            return "Angriff " + _signed_percent_delta(multiplier)
        "incoming_damage_mod":
            return "Verteidigung " + _signed_percent_delta(multiplier)
        "accuracy_mod":
            return "Genauigkeit " + _signed_percent_delta(multiplier)
        "atb_cycle_mod":
            return (
                "Geschwindigkeit "
                + _signed_percent_delta(_speed_multiplier_from_cycle(multiplier))
            )
        _:
            return kind.replace("_", " ")


func _attribute_direction_summary(mechanic: Dictionary, kind: String) -> String:
    var signed_weight: float = float(mechanic.get("multiplier_from_special", 0.0))
    match kind:
        "outgoing_damage_mod":
            return "Angriff " + ("↑" if signed_weight >= 0.0 else "↓")
        "incoming_damage_mod":
            # Positive internal weight means vulnerability = lower Defense.
            return "Verteidigung " + ("↓" if signed_weight >= 0.0 else "↑")
        "accuracy_mod":
            return "Genauigkeit " + ("↑" if signed_weight >= 0.0 else "↓")
        "atb_cycle_mod":
            # Positive cycle weight = longer cycle = lower Speed.
            return "Geschwindigkeit " + ("↓" if signed_weight >= 0.0 else "↑")
        _:
            return kind.replace("_", " ")


func _is_player_attribute_modifier(kind: String) -> bool:
    return (
        kind == "outgoing_damage_mod"
        or kind == "incoming_damage_mod"
        or kind == "accuracy_mod"
        or kind == "atb_cycle_mod"
    )


func _speed_multiplier_from_cycle(cycle_multiplier: float) -> float:
    # Charging gain is divided by the cycle multiplier, so effective Speed/tempo
    # changes inversely. Example: cycle 0.80 -> effective speed +25%.
    return 1.0 / maxf(0.0001, cycle_multiplier)


func _player_text_cleanup(source: String) -> String:
    # Natural-language move descriptions should name the attribute itself.
    # This function only touches player-visible strings; mechanic IDs remain
    # unchanged inside the database and combat engine.
    var text: String = source

    text = text.replace(
        "nächster ATB-Zyklus wird kürzer",
        "danach schneller wieder bereit"
    )
    text = text.replace(
        "beschleunigt seinen nächsten ATB-Zyklus",
        "verkürzt die Zeit bis zur nächsten eigenen Aktion"
    )

    text = super._player_text_cleanup(text)

    # Core attribute language -------------------------------------------------
    text = text.replace("ausgehenden Schaden", "Angriff")
    text = text.replace("verursachten Schaden", "Angriff")
    text = text.replace("verursachter Schaden", "Angriff")

    text = text.replace(
        "macht alle Gegner für deren nächste drei eigene Aktionen verwundbarer",
        "senkt die Verteidigung aller Gegner für deren nächste drei eigene Aktionen"
    )
    text = text.replace(
        "macht sie für deren nächste drei eigene Aktionen verwundbarer",
        "senkt ihre Verteidigung für deren nächste drei eigene Aktionen"
    )
    text = text.replace(
        "macht das Ziel verwundbarer",
        "senkt die Verteidigung des Ziels"
    )
    text = text.replace(
        "macht sie verwundbarer",
        "senkt ihre Verteidigung"
    )
    text = text.replace(
        "reduziert eingehenden Schaden",
        "erhöht seine Verteidigung"
    )

    text = text.replace(
        "verlangsamt alle Gegner",
        "senkt die Geschwindigkeit aller Gegner"
    )
    text = text.replace(
        "verlangsamt das Ziel",
        "senkt die Geschwindigkeit des Ziels"
    )
    text = text.replace(
        "beschleunigt das gesamte eigene Viererteam",
        "erhöht die Geschwindigkeit des gesamten eigenen Viererteams"
    )
    text = text.replace(
        "Beschleunigt den eigenen Aktionszyklus stark.",
        "Erhöht die eigene Geschwindigkeit stark."
    )
    text = text.replace(
        "Der Anwender wird deutlich schneller wieder bereit.",
        "Erhöht die eigene Geschwindigkeit stark."
    )

    text = text.replace(
        "Ein Tanz verstärkt Schaden, Defensive und Tempo.",
        "Ein Tanz erhöht Angriff, Verteidigung und Geschwindigkeit."
    )
    text = text.replace("Defensive", "Verteidigung")

    # Older summary wording from presentation layers.
    text = text.replace("nächster Aktionszyklus kürzer", "Zeit bis zur nächsten Aktion kürzer")
    text = text.replace("nächster Aktionszyklus länger", "Zeit bis zur nächsten Aktion länger")
    return text
