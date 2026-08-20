extends "res://scripts/battle_demo_ui_feedback.gd"

# Combat-lab balancing layer:
# - Temporary positive and negative stat/control modifiers last for the next
#   three actions of the affected Pokemon.
# - Every application is stored as its own effect instance, so stacked effects
#   expire independently.
# - ATB modifiers affect charging immediately while they are active.
# - The stronger AP test curve reflects the latest combat-lab playtest.

const TEMP_EFFECT_ACTIONS: int = 3
const TEMP_EFFECT_KINDS: Array[String] = [
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod"
]

const AP_TEST_CURVE: Dictionary = {
    1: 1.00,
    2: 1.20,
    3: 1.45,
    4: 1.75,
    5: 2.10,
    6: 2.50,
    7: 3.00,
    8: 3.60
}

var _current_effect_move_name: String = ""


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["action_serial"] = 0
    combatant["timed_modifiers"] = []
    # Compatibility fields from the older one-shot implementation remain
    # neutral. The active values are calculated from timed_modifiers instead.
    combatant["attack_mult"] = 1.0
    combatant["defense_mult"] = 1.0
    combatant["accuracy_mult"] = 1.0
    combatant["next_cycle"] = 1.0
    return combatant


func _ap_cycle(ap: int) -> float:
    return float(AP_TEST_CURVE.get(clampi(ap, 1, 8), 1.0))


func _process(delta: float) -> void:
    if not battle_active or paused:
        return

    var ready_actor: Dictionary = {}
    var best_speed: float = -1.0

    for combatant_value: Variant in combatants:
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)):
            continue

        var effective_speed: float = float(combatant.get("speed", 10))
        if bool(combatant.get("paralyzed", false)):
            effective_speed *= 0.5

        var ap_cycle: float = maxf(0.01, float(combatant.get("cycle", 1.0)))
        var status_cycle: float = _combined_timed_modifier(combatant, "atb_cycle_mod")
        var effective_cycle: float = maxf(0.01, ap_cycle * status_cycle)
        var gain: float = delta * (12.0 + effective_speed * 0.62) / effective_cycle
        combatant["atb"] = minf(100.0, float(combatant.get("atb", 0.0)) + gain)

        if float(combatant.get("atb", 0.0)) >= 100.0 and effective_speed > best_speed:
            ready_actor = combatant
            best_speed = effective_speed

    _refresh_cards()
    if ready_actor.is_empty():
        return

    if str(ready_actor.get("side", "")) == "player":
        _prompt_player(ready_actor)
    else:
        _enemy_act(ready_actor)


func _choose_wait() -> void:
    if selected_actor.is_empty():
        return
    var actor: Dictionary = selected_actor
    _begin_counted_action(actor)
    super._choose_wait()
    _expire_finished_modifiers(actor)
    _refresh_cards()


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    _begin_counted_action(actor)
    actor["accuracy_mult"] = _combined_timed_modifier(actor, "accuracy_mod")
    actor["next_cycle"] = 1.0

    var move: Dictionary = _move_data(move_id)
    _current_effect_move_name = str(move.get("name", move_id))
    super._execute_move(actor, move_id)
    _current_effect_move_name = ""

    actor["accuracy_mult"] = 1.0
    actor["next_cycle"] = 1.0
    _expire_finished_modifiers(actor)
    _refresh_cards()


func _begin_counted_action(actor: Dictionary) -> void:
    actor["action_serial"] = int(actor.get("action_serial", 0)) + 1


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if not TEMP_EFFECT_KINDS.has(kind):
        return super._effect(actor, target, mechanic)

    var attacker_types: Array = _type_array(actor.get("types", []))
    var status_bonus: float = TypeSystem.get_same_type_status_multiplier(_active_move_type, attacker_types)
    var special_percent: float = float(actor.get("special", 0)) / 100.0
    var multiplier_from_special: float = float(mechanic.get("multiplier_from_special", 1.0))
    var scaled_delta: float = special_percent * multiplier_from_special * status_bonus
    var single_multiplier: float = 1.0
    var aggro_value: float = absf(scaled_delta) * 8.0

    match kind:
        "outgoing_damage_mod":
            single_multiplier = clampf(1.0 + scaled_delta, 0.25, 2.5)
            aggro_value = absf(scaled_delta) * 10.0
        "incoming_damage_mod":
            single_multiplier = clampf(1.0 - scaled_delta, 0.25, 2.5)
            aggro_value = absf(scaled_delta) * 10.0
        "accuracy_mod":
            single_multiplier = clampf(1.0 + scaled_delta, 0.2, 2.5)
        "atb_cycle_mod":
            single_multiplier = clampf(1.0 + scaled_delta, 0.45, 2.5)

    _add_timed_modifier(
        target,
        kind,
        single_multiplier,
        _current_effect_move_name,
        _actor_name(actor)
    )
    return aggro_value


func _add_timed_modifier(
    target: Dictionary,
    kind: String,
    multiplier: float,
    source_move: String,
    source_actor: String
) -> void:
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    var modifiers: Array = modifiers_value if modifiers_value is Array else []
    var current_action: int = int(target.get("action_serial", 0))
    modifiers.append({
        "kind": kind,
        "multiplier": multiplier,
        "source_move": source_move,
        "source_actor": source_actor,
        "expires_after_action": current_action + TEMP_EFFECT_ACTIONS
    })
    target["timed_modifiers"] = modifiers


func _expire_finished_modifiers(combatant: Dictionary) -> void:
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        combatant["timed_modifiers"] = []
        return

    var current_action: int = int(combatant.get("action_serial", 0))
    var remaining: Array = []
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if current_action < int(modifier.get("expires_after_action", current_action)):
            remaining.append(modifier)
    combatant["timed_modifiers"] = remaining


func _combined_timed_modifier(combatant: Dictionary, kind: String) -> float:
    var result: float = 1.0
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if not (modifier_value is Dictionary):
                continue
            var modifier: Dictionary = modifier_value
            if str(modifier.get("kind", "")) == kind:
                result *= float(modifier.get("multiplier", 1.0))

    match kind:
        "accuracy_mod":
            return clampf(result, 0.2, 2.5)
        "atb_cycle_mod":
            return clampf(result, 0.25, 4.0)
        _:
            return clampf(result, 0.25, 4.0)


func _active_modifier_count(combatant: Dictionary, kind: String) -> int:
    var count: int = 0
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if modifier_value is Dictionary and str(modifier_value.get("kind", "")) == kind:
                count += 1
    return count


func _remaining_modifier_actions(combatant: Dictionary, modifier: Dictionary) -> int:
    return maxi(
        0,
        int(modifier.get("expires_after_action", 0)) - int(combatant.get("action_serial", 0))
    )


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    if power <= 0:
        return 0

    var offensive_stat: float = float(actor.get("attack", 10))
    if category == "special":
        offensive_stat = float(actor.get("special", 10))

    var attack_multiplier: float = _combined_timed_modifier(actor, "outgoing_damage_mod")
    var defense_multiplier: float = _combined_timed_modifier(target, "incoming_damage_mod")

    var raw: float = (
        ((2.0 * float(actor.get("level", 1)) / 5.0 + 2.0)
        * float(power) * offensive_stat * attack_multiplier
        / maxf(1.0, float(target.get("defense", 10)))) / 50.0
    ) + 2.0

    raw /= maxf(0.25, defense_multiplier)

    var attacker_types: Array = _type_array(actor.get("types", []))
    var defender_types: Array = _type_array(target.get("types", []))
    var effectiveness: float = TypeSystem.get_multiplier(move_type, defender_types)
    if is_zero_approx(effectiveness):
        return 0

    var stab: float = TypeSystem.get_same_type_damage_multiplier(move_type, attacker_types)
    return maxi(1, int(round(raw * randf_range(0.88, 1.0) * effectiveness * stab)))


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = []
    if _is_highest_aggro(combatant):
        tokens.append("ZIEL")
    if bool(combatant.get("paralyzed", false)):
        tokens.append("PAR")
    var confused_turns: int = int(combatant.get("confused_turns", 0))
    if confused_turns > 0:
        tokens.append("VERW" + str(confused_turns))

    _append_modifier_token(tokens, combatant, "outgoing_damage_mod", "ANG", false)
    _append_modifier_token(tokens, combatant, "incoming_damage_mod", "DEF", true)
    _append_modifier_token(tokens, combatant, "accuracy_mod", "GEN", false)
    _append_modifier_token(tokens, combatant, "atb_cycle_mod", "ATB", true)
    return tokens


func _append_modifier_token(
    tokens: Array[String],
    combatant: Dictionary,
    kind: String,
    label: String,
    inverse_direction: bool
) -> void:
    var count: int = _active_modifier_count(combatant, kind)
    if count <= 0:
        return
    var value: float = _combined_timed_modifier(combatant, kind)
    var positive: bool = value > 1.001
    if inverse_direction:
        positive = value < 0.999
    var sign_text: String = "+" if positive else "-"
    tokens.append(label + sign_text + ("×" + str(count) if count > 1 else ""))


func _detail_info(combatant: Dictionary) -> String:
    var lines: Array[String] = []
    var type_names: Array[String] = []
    var types_value: Variant = combatant.get("types", [])
    if types_value is Array:
        for type_value: Variant in types_value:
            type_names.append(_type_name(str(type_value)))

    lines.append("[b]KAMPFSTATUS[/b]")
    lines.append("KP: " + str(combatant.get("hp", 0)) + "/" + str(combatant.get("max_hp", 0)))
    lines.append("ATB: %.0f%%" % float(combatant.get("atb", 0.0)))
    lines.append("Aggro: %.1f" % float(combatant.get("aggro", 0.0)))
    lines.append("Typ: " + (" / ".join(type_names) if not type_names.is_empty() else "–"))
    lines.append("")
    lines.append("[b]WERTE[/b]")
    lines.append("Angriff " + str(combatant.get("attack", 0)) + " · Verteidigung " + str(combatant.get("defense", 0)))
    lines.append("Spezial " + str(combatant.get("special", 0)) + " · Initiative " + str(combatant.get("speed", 0)))
    lines.append("")
    lines.append("[b]AKTIVE EFFEKTE[/b]")

    var has_effect: bool = false
    if not bool(combatant.get("alive", false)):
        lines.append("• Kampfunfähig")
        has_effect = true
    if bool(combatant.get("paralyzed", false)):
        lines.append("• Paralyse: Initiative halbiert; 25% Handlungsausfall")
        has_effect = true
    var confused_turns: int = int(combatant.get("confused_turns", 0))
    if confused_turns > 0:
        lines.append("• Verwirrung: noch " + str(confused_turns) + " eigene Aktion(en); 33% Selbsttrefferchance")
        has_effect = true

    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if not (modifier_value is Dictionary):
                continue
            var modifier: Dictionary = modifier_value
            var remaining: int = _remaining_modifier_actions(combatant, modifier)
            if remaining <= 0:
                continue
            var source_move: String = str(modifier.get("source_move", "Statuseffekt"))
            var effect_text: String = _modifier_detail_text(
                str(modifier.get("kind", "")),
                float(modifier.get("multiplier", 1.0))
            )
            lines.append("• " + source_move + ": " + effect_text + " · noch " + str(remaining) + " Aktion(en)")
            has_effect = true

    if not has_effect:
        lines.append("• Keine aktiven Veränderungen")

    if _active_modifier_count(combatant, "outgoing_damage_mod") > 1:
        lines.append("  Gesamt verursachter Schaden: ×" + _decimal(_combined_timed_modifier(combatant, "outgoing_damage_mod"), 2))
    if _active_modifier_count(combatant, "incoming_damage_mod") > 1:
        lines.append("  Gesamt eingehender Schaden: ×" + _decimal(1.0 / maxf(0.25, _combined_timed_modifier(combatant, "incoming_damage_mod")), 2))
    if _active_modifier_count(combatant, "accuracy_mod") > 1:
        lines.append("  Gesamt Genauigkeit: ×" + _decimal(_combined_timed_modifier(combatant, "accuracy_mod"), 2))
    if _active_modifier_count(combatant, "atb_cycle_mod") > 1:
        lines.append("  Gesamt ATB-Zyklus: ×" + _decimal(_combined_timed_modifier(combatant, "atb_cycle_mod"), 2))

    lines.append("")
    lines.append("[b]VERFÜGBARE ATTACKEN[/b]")
    for move_name: String in _move_names(combatant.get("moves", [])):
        lines.append("• " + move_name)
    return "\n".join(lines)


func _modifier_detail_text(kind: String, multiplier: float) -> String:
    match kind:
        "outgoing_damage_mod":
            return "verursachter Schaden ×" + _decimal(multiplier, 2)
        "incoming_damage_mod":
            return "eingehender Schaden ×" + _decimal(1.0 / maxf(0.25, multiplier), 2)
        "accuracy_mod":
            return "Genauigkeit ×" + _decimal(multiplier, 2)
        "atb_cycle_mod":
            return "ATB-Zyklus ×" + _decimal(multiplier, 2)
        _:
            return kind.replace("_", " ") + " ×" + _decimal(multiplier, 2)


func _feedback_snapshot(target: Dictionary) -> Dictionary:
    return {
        "hp": int(target.get("hp", 0)),
        "alive": bool(target.get("alive", true)),
        "paralyzed": bool(target.get("paralyzed", false)),
        "confused_turns": int(target.get("confused_turns", 0)),
        "attack_mult": _combined_timed_modifier(target, "outgoing_damage_mod"),
        "defense_mult": _combined_timed_modifier(target, "incoming_damage_mod"),
        "accuracy_mult": _combined_timed_modifier(target, "accuracy_mod"),
        "next_cycle": _combined_timed_modifier(target, "atb_cycle_mod"),
        "atb": float(target.get("atb", 0.0))
    }


func _feedback_result(target: Dictionary, before: Dictionary) -> Dictionary:
    var lines: Array[String] = []
    var negative: bool = false
    var positive: bool = false

    var hp_before: int = int(before.get("hp", int(target.get("hp", 0))))
    var hp_after: int = int(target.get("hp", 0))
    if hp_after < hp_before:
        lines.append("−" + str(hp_before - hp_after) + " KP")
        negative = true
    elif hp_after > hp_before:
        lines.append("+" + str(hp_after - hp_before) + " KP")
        positive = true

    if bool(before.get("alive", true)) and not bool(target.get("alive", true)):
        lines.append("K.O.")
        negative = true
    if not bool(before.get("paralyzed", false)) and bool(target.get("paralyzed", false)):
        lines.append("PARALYSE")
        negative = true
    if int(before.get("confused_turns", 0)) <= 0 and int(target.get("confused_turns", 0)) > 0:
        lines.append("VERWIRRT")
        negative = true

    var attack_after: float = _combined_timed_modifier(target, "outgoing_damage_mod")
    var attack_change: int = _compare_float(float(before.get("attack_mult", 1.0)), attack_after)
    if attack_change < 0:
        lines.append("ANGRIFF ↓ · 3 AKTIONEN")
        negative = true
    elif attack_change > 0:
        lines.append("ANGRIFF ↑ · 3 AKTIONEN")
        positive = true

    var defense_after: float = _combined_timed_modifier(target, "incoming_damage_mod")
    var defense_change: int = _compare_float(float(before.get("defense_mult", 1.0)), defense_after)
    if defense_change < 0:
        lines.append("SCHUTZ ↓ · 3 AKTIONEN")
        negative = true
    elif defense_change > 0:
        lines.append("SCHUTZ ↑ · 3 AKTIONEN")
        positive = true

    var accuracy_after: float = _combined_timed_modifier(target, "accuracy_mod")
    var accuracy_change: int = _compare_float(float(before.get("accuracy_mult", 1.0)), accuracy_after)
    if accuracy_change < 0:
        lines.append("GENAUIGKEIT ↓ · 3 AKTIONEN")
        negative = true
    elif accuracy_change > 0:
        lines.append("GENAUIGKEIT ↑ · 3 AKTIONEN")
        positive = true

    var cycle_after: float = _combined_timed_modifier(target, "atb_cycle_mod")
    var cycle_change: int = _compare_float(float(before.get("next_cycle", 1.0)), cycle_after)
    if cycle_change > 0:
        lines.append("ATB LANGSAMER · 3 AKTIONEN")
        negative = true
    elif cycle_change < 0:
        lines.append("ATB SCHNELLER · 3 AKTIONEN")
        positive = true

    var atb_before: float = float(before.get("atb", 0.0))
    var atb_after: float = float(target.get("atb", 0.0))
    if atb_after < atb_before - 0.5:
        lines.append("ATB ↓")
        negative = true

    if lines.is_empty():
        lines.append("KEIN EFFEKT")

    var result_kind: String = "neutral"
    if negative:
        result_kind = "negative"
    elif positive:
        result_kind = "positive"
    return {"kind": result_kind, "text": " · ".join(lines)}


func _compact_effect_summary(move: Dictionary) -> String:
    var summary: String = super._compact_effect_summary(move)
    var has_temporary_modifier: bool = false
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if mechanic_value is Dictionary and TEMP_EFFECT_KINDS.has(str(mechanic_value.get("kind", ""))):
                has_temporary_modifier = true
                break

    summary = summary.replace("nächster ATB-Zyklus kürzer", "ATB schneller")
    summary = summary.replace("nächster ATB-Zyklus länger", "ATB langsamer")
    if has_temporary_modifier:
        summary += " · wirkt auf die nächsten 3 eigenen Aktionen des betroffenen Pokémon"
    return summary
