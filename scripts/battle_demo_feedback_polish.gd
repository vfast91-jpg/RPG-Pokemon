extends "res://scripts/battle_demo_opening_recovery.gd"

# Player-facing action feedback fixes:
# - Accuracy misses say DANEBEN instead of KEIN EFFEKT.
# - Type immunities say WIRKUNGSLOS.
# - Persistent/special mechanics are included in the feedback snapshot so
#   successful effects such as Energiefokus, Egelsamen and Bindung are visible.
# - Newer database/TM state (timed modifiers, guards, substitute, etc.) is also
#   compared instead of falling through to the legacy KEIN-EFFEKT fallback.
# - A provisional KEIN EFFEKT is deferred until all outer runtime layers have
#   finished. This is important for effects applied after the legacy resolver,
#   such as Solarstrahl charging and the Bisasam-family TM post-effects.
# - Existing mechanic-specific feedback labels win over the generic fallback.
# - Waiting grants a much stronger next-cycle speed advantage (0.45x cycle).

const WAIT_CYCLE_MULTIPLIER: float = 0.45

var _feedback_active_move_id: String = ""
var _feedback_active_actor_id: String = ""
var _feedback_custom_labels: Dictionary = {}
var _feedback_rendering_generic: bool = false


func _choose_wait() -> void:
    if selected_actor.is_empty():
        return

    var actor: Dictionary = selected_actor
    super._choose_wait()

    # The inherited wait action uses 0.70x. Make waiting a much stronger tempo
    # choice: the next personal charging cycle takes only 45% of normal time.
    actor["cycle"] = WAIT_CYCLE_MULTIPLIER
    _set_log(
        _actor_name(actor)
        + " wartet, senkt seine Aggro und bekommt einen starken Zeitvorteil: "
        + "Der nächste Ladezyklus ist 55% kürzer."
    )
    _refresh_cards()


func _execute_move(actor: Dictionary, move_id: String) -> void:
    _feedback_active_move_id = move_id
    _feedback_active_actor_id = str(actor.get("id", ""))
    _feedback_custom_labels.clear()
    super._execute_move(actor, move_id)

    # Do not clear the context synchronously. Several newer runtime layers apply
    # their visible effect immediately after their super._execute_move() returns.
    # Deferred KEIN-EFFEKT validation must still be able to see those labels.
    call_deferred(
        "_feedback_clear_active_context",
        move_id,
        _feedback_active_actor_id
    )


func _feedback_clear_active_context(move_id: String, actor_id: String) -> void:
    if _feedback_active_move_id != move_id or _feedback_active_actor_id != actor_id:
        return
    _feedback_active_move_id = ""
    _feedback_active_actor_id = ""
    _feedback_custom_labels.clear()


func _spawn_feedback_label(combatant: Dictionary, text: String, color: Color) -> void:
    if _feedback_should_capture_custom_label(text):
        var target_id: String = str(combatant.get("id", ""))
        if not target_id.is_empty():
            var labels_value: Variant = _feedback_custom_labels.get(target_id, [])
            var labels: Array = labels_value if labels_value is Array else []
            if not labels.has(text):
                labels.append(text)
            _feedback_custom_labels[target_id] = labels
    super._spawn_feedback_label(combatant, text, color)


func _feedback_should_capture_custom_label(text: String) -> bool:
    if _feedback_rendering_generic or _feedback_active_move_id.is_empty():
        return false
    var clean: String = text.strip_edges()
    if clean.is_empty():
        return false

    # The generic action layer first shows the attack name over the user. That
    # is not an effect result and must not suppress a later real KEIN EFFEKT.
    var move: Dictionary = _move_data(_feedback_active_move_id)
    var move_name: String = str(move.get("name", _feedback_active_move_id)).strip_edges()
    return clean != move_name


func _feedback_snapshot(target: Dictionary) -> Dictionary:
    var snapshot: Dictionary = super._feedback_snapshot(target)
    snapshot["max_hp"] = int(target.get("max_hp", 1))
    snapshot["major_status"] = str(target.get("major_status", ""))
    snapshot["critical_focus_bonus"] = float(target.get("critical_focus_bonus", 0.0))
    snapshot["seed_active"] = _effect_dictionary_active(target.get("seed_effect", {}))
    snapshot["binding_active"] = _effect_dictionary_active(target.get("binding_effect", {}))

    # Modern database/TM mechanics mostly live in timed or dedicated runtime
    # state instead of the old attack_mult/defense_mult fields.
    snapshot["timed_modifiers"] = _feedback_array_copy(target.get("timed_modifiers", []))
    snapshot["protective_guard"] = bool(target.get("protective_guard", false))
    snapshot["db_endure_expires_after_action"] = int(target.get("db_endure_expires_after_action", 0))
    snapshot["db_substitute_hp"] = int(target.get("db_substitute_hp", 0))
    snapshot["db_substitute_max_hp"] = int(target.get("db_substitute_max_hp", 0))
    snapshot["db_sleep_actions"] = int(target.get("db_sleep_actions", 0))
    snapshot["db_status_immunities"] = _feedback_array_copy(target.get("db_status_immunities", []))
    snapshot["db_incoming_accuracy_mult"] = float(target.get("db_incoming_accuracy_mult", 1.0))
    snapshot["db_incoming_accuracy_expires"] = int(target.get("db_incoming_accuracy_expires", 0))
    snapshot["db_redirect_expires"] = int(target.get("db_redirect_expires", 0))
    snapshot["db_guaranteed_crit"] = bool(target.get("db_guaranteed_crit", false))
    snapshot["db_block_positive_expires"] = int(target.get("db_block_positive_expires", 0))
    snapshot["db_light_screen_reduction"] = float(target.get("db_light_screen_reduction", 0.0))
    snapshot["db_light_screen_expires_source_action"] = int(target.get("db_light_screen_expires_source_action", 0))
    snapshot["db_stockpile"] = int(target.get("db_stockpile", 0))
    snapshot["db_charge_move"] = str(target.get("db_charge_move", ""))
    snapshot["types"] = _type_array(target.get("types", [])).duplicate()
    return snapshot


func _show_target_feedback(target: Dictionary, before: Dictionary) -> Dictionary:
    var feedback: Dictionary = _feedback_result(target, before)
    if str(feedback.get("text", "KEIN EFFEKT")) != "KEIN EFFEKT":
        _feedback_display_now(target, feedback)
        return feedback

    # Never show KEIN EFFEKT while outer runtime layers still have a chance to
    # apply their state/labels. Re-check once the current call stack is finished.
    call_deferred(
        "_feedback_resolve_deferred_no_effect",
        target,
        before.duplicate(true),
        _feedback_active_move_id,
        _feedback_active_actor_id
    )

    # The inherited protocol suppresses exactly this token. The player-facing
    # label itself is intentionally NOT spawned here.
    return {"kind": "neutral", "text": "KEIN EFFEKT"}


func _feedback_resolve_deferred_no_effect(
    target: Dictionary,
    before: Dictionary,
    move_id: String,
    actor_id: String
) -> void:
    if target.is_empty() or not is_instance_valid(self):
        return

    var previous_move_id: String = _feedback_active_move_id
    var previous_actor_id: String = _feedback_active_actor_id
    _feedback_active_move_id = move_id
    _feedback_active_actor_id = actor_id

    # If the mechanic itself already emitted a precise result label, that is the
    # source of truth. Do not stack a generic KEIN EFFEKT on top of it.
    if not _feedback_existing_custom_result(target, actor_id, move_id).is_empty():
        _feedback_active_move_id = previous_move_id
        _feedback_active_actor_id = previous_actor_id
        return

    var feedback: Dictionary = _feedback_result(target, before)
    if str(feedback.get("text", "KEIN EFFEKT")) == "KEIN EFFEKT":
        var fallback: String = _feedback_move_specific_fallback(target, before, move_id, actor_id)
        if not fallback.is_empty():
            feedback = {"kind": _feedback_kind_for_text(fallback), "text": fallback}

    _feedback_display_now(target, feedback)
    _feedback_active_move_id = previous_move_id
    _feedback_active_actor_id = previous_actor_id


func _feedback_display_now(target: Dictionary, feedback: Dictionary) -> void:
    var text: String = str(feedback.get("text", "KEIN EFFEKT"))
    if text.is_empty():
        return

    var kind: String = str(feedback.get("kind", "neutral"))
    var color: Color = Color("ffeaa2")
    if kind == "positive":
        color = Color("8fe39b")
    elif kind == "negative":
        color = Color("ff8d8d")

    _flash_combatant(target, color)
    _feedback_rendering_generic = true
    _spawn_feedback_label(target, text, color)
    _feedback_rendering_generic = false


func _feedback_result(target: Dictionary, before: Dictionary) -> Dictionary:
    if _current_move_missed():
        return {"kind": "neutral", "text": "💨 DANEBEN!"}

    var result: Dictionary = super._feedback_result(target, before)
    var text: String = str(result.get("text", "KEIN EFFEKT"))
    var kind: String = str(result.get("kind", "neutral"))

    # Keep internal ATB mechanics untouched while removing the acronym from
    # player-facing action feedback.
    text = text.replace("ATB LANGSAMER", "AKTIONSLEISTE LANGSAMER")
    text = text.replace("ATB SCHNELLER", "AKTIONSLEISTE SCHNELLER")
    text = text.replace("ATB ↓", "AKTIONSLEISTE ↓")

    var extras: Array[String] = []
    var extra_positive: bool = false
    var extra_negative: bool = false

    var status_before: String = str(before.get("major_status", ""))
    var status_after: String = str(target.get("major_status", ""))
    if status_after != status_before and not status_after.is_empty():
        match status_after:
            "burn":
                extras.append("🔥 VERBRANNT")
                extra_negative = true
            "poison":
                extras.append("☠️ VERGIFTET")
                extra_negative = true
            "bad_poison":
                extras.append("☠️ SCHWER VERGIFTET")
                extra_negative = true
            "sleep":
                extras.append("💤 SCHLÄFT")
                extra_negative = true
            "freeze":
                extras.append("❄️ GEFROREN")
                extra_negative = true
            "paralysis":
                # The inherited feedback already reports PARALYSE via its
                # dedicated boolean field, so do not duplicate it here.
                pass
            _:
                extras.append(status_after.to_upper())
                extra_negative = true
    elif not status_before.is_empty() and status_after.is_empty():
        extras.append("✨ STATUS ENTFERNT")
        extra_positive = true

    if bool(before.get("paralyzed", false)) and not bool(target.get("paralyzed", false)):
        extras.append("✨ PARALYSE ENTFERNT")
        extra_positive = true

    var focus_before: float = float(before.get("critical_focus_bonus", 0.0))
    var focus_after: float = float(target.get("critical_focus_bonus", 0.0))
    if focus_after > focus_before + 0.0001:
        extras.append("🎯 KRIT-FOKUS +%d%%" % int(round(focus_after * 100.0)))
        extra_positive = true
    elif (
        _feedback_active_move_id == "focus_energy"
        and focus_after > 0.0001
        and text == "KEIN EFFEKT"
    ):
        extras.append("🎯 KRIT-FOKUS AKTIV")
        extra_positive = true

    var seed_before: bool = bool(before.get("seed_active", false))
    var seed_after: bool = _effect_dictionary_active(target.get("seed_effect", {}))
    if not seed_before and seed_after:
        extras.append("🌱 EGELSAMEN")
        extra_negative = true

    var binding_before: bool = bool(before.get("binding_active", false))
    var binding_after: bool = _effect_dictionary_active(target.get("binding_effect", {}))
    if not binding_before and binding_after:
        extras.append("🪢 GEBUNDEN")
        extra_negative = true

    var timed_effect: Dictionary = _feedback_new_timed_modifier(before, target)
    if not timed_effect.is_empty():
        extras.append(str(timed_effect.get("text", "EFFEKT")))
        if str(timed_effect.get("kind", "neutral")) == "negative":
            extra_negative = true
        elif str(timed_effect.get("kind", "neutral")) == "positive":
            extra_positive = true

    if (
        not bool(before.get("protective_guard", false))
        and bool(target.get("protective_guard", false))
    ):
        extras.append("🛡️ SCHUTZSCHILD")
        extra_positive = true

    if (
        int(target.get("db_endure_expires_after_action", 0))
        > int(before.get("db_endure_expires_after_action", 0))
    ):
        extras.append("💪 AUSDAUER · 3 AKTIONEN")
        extra_positive = true

    var substitute_before: int = int(before.get("db_substitute_hp", 0))
    var substitute_after: int = int(target.get("db_substitute_hp", 0))
    if substitute_before <= 0 and substitute_after > 0:
        extras.append("🧸 DELEGATOR " + str(substitute_after) + " KP")
        extra_positive = true
    elif substitute_before > 0 and substitute_after < substitute_before:
        if substitute_after <= 0:
            extras.append("🧸 DELEGATOR ZERSTÖRT")
        else:
            extras.append("🧸 DELEGATOR −" + str(substitute_before - substitute_after) + " KP")
        extra_negative = true

    if _feedback_has_new_array_entry(
        before.get("db_status_immunities", []),
        target.get("db_status_immunities", [])
    ):
        extras.append("🛡️ STATUSSCHUTZ AKTIV")
        extra_positive = true

    var incoming_accuracy_before: float = float(before.get("db_incoming_accuracy_mult", 1.0))
    var incoming_accuracy_after: float = float(target.get("db_incoming_accuracy_mult", 1.0))
    if incoming_accuracy_after > incoming_accuracy_before + 0.001:
        extras.append("🎯 GENAUIGKEIT GEGEN ZIEL ↑")
        extra_negative = true
    elif incoming_accuracy_after < incoming_accuracy_before - 0.001:
        extras.append("🎯 GENAUIGKEIT GEGEN ZIEL ↓")
        extra_positive = true

    if int(target.get("db_redirect_expires", 0)) > int(before.get("db_redirect_expires", 0)):
        extras.append("🧲 UMLEITUNG AKTIV")
        extra_positive = true

    if (
        not bool(before.get("db_guaranteed_crit", false))
        and bool(target.get("db_guaranteed_crit", false))
    ):
        extras.append("🎯 NÄCHSTER TREFFER KRITISCH")
        extra_positive = true

    if (
        int(target.get("db_block_positive_expires", 0))
        > int(before.get("db_block_positive_expires", 0))
    ):
        extras.append("⛔ POSITIVE EFFEKTE BLOCKIERT")
        extra_negative = true

    if (
        float(target.get("db_light_screen_reduction", 0.0))
        > float(before.get("db_light_screen_reduction", 0.0)) + 0.001
    ):
        extras.append("🛡️ LICHTSCHILD AKTIV")
        extra_positive = true

    var stockpile_before: int = int(before.get("db_stockpile", 0))
    var stockpile_after: int = int(target.get("db_stockpile", 0))
    if stockpile_after > stockpile_before:
        extras.append("📦 HORTER ×" + str(stockpile_after))
        extra_positive = true

    var charge_before: String = str(before.get("db_charge_move", ""))
    var charge_after: String = str(target.get("db_charge_move", ""))
    if charge_before.is_empty() and not charge_after.is_empty():
        extras.append("☀️ LÄDT AUF")
        extra_positive = true

    var types_before_value: Variant = before.get("types", [])
    var types_before: Array = types_before_value if types_before_value is Array else []
    var types_after: Array = _type_array(target.get("types", []))
    if types_after.size() < types_before.size():
        extras.append("🔄 TYP TEMPORÄR ENTFERNT")
        extra_negative = true

    if text == "KEIN EFFEKT" and _current_move_is_type_immune(target):
        text = "⛔ WIRKUNGSLOS!"

    if not extras.is_empty():
        if text == "KEIN EFFEKT":
            text = ""
        text = " · ".join(extras) if text.is_empty() else text + " · " + " · ".join(extras)
        if extra_negative:
            kind = "negative"
        elif extra_positive and kind == "neutral":
            kind = "positive"

    return {"kind": kind, "text": text}


func _feedback_new_timed_modifier(before: Dictionary, target: Dictionary) -> Dictionary:
    var before_value: Variant = before.get("timed_modifiers", [])
    var before_modifiers: Array = before_value if before_value is Array else []
    var after_modifiers: Array = _feedback_array_copy(target.get("timed_modifiers", []))

    for modifier_value: Variant in after_modifiers:
        if not (modifier_value is Dictionary):
            continue
        if before_modifiers.has(modifier_value):
            continue
        return _feedback_modifier_text(modifier_value as Dictionary)
    return {}


func _feedback_modifier_text(modifier: Dictionary) -> Dictionary:
    var modifier_kind: String = str(modifier.get("kind", ""))
    var multiplier: float = float(modifier.get("multiplier", 1.0))
    var visible_multiplier: float = multiplier
    var label: String = ""

    match modifier_kind:
        "outgoing_damage_mod":
            label = "ANGRIFF"
        "incoming_damage_mod":
            label = "VERTEIDIGUNG"
        "accuracy_mod":
            label = "GENAUIGKEIT"
        "atb_cycle_mod":
            label = "GESCHWINDIGKEIT"
            visible_multiplier = 1.0 / maxf(0.0001, multiplier)
        _:
            return {"kind": "neutral", "text": "✨ EFFEKT AKTIV"}

    var delta: float = visible_multiplier - 1.0
    var result_kind: String = "positive" if delta > 0.0 else "negative"
    return {
        "kind": result_kind,
        "text": label + " " + _feedback_signed_percent_delta(visible_multiplier)
    }


func _feedback_signed_percent_delta(multiplier: float) -> String:
    var percent: int = int(round((multiplier - 1.0) * 100.0))
    if percent > 0:
        return "+" + str(percent) + "%"
    if percent < 0:
        return "−" + str(abs(percent)) + "%"
    return "±0%"


func _feedback_existing_custom_result(target: Dictionary, actor_id: String, move_id: String) -> String:
    var target_id: String = str(target.get("id", ""))
    var direct: String = _feedback_join_custom_labels(target_id)
    if not direct.is_empty():
        return direct

    # These moves deliberately resolve their first visible state on the user or
    # field while the generic feedback target can be an opponent.
    if move_id in ["solar_beam", "grass_pledge", "sunny_day", "grassy_terrain"]:
        return _feedback_join_custom_labels(actor_id)
    return ""


func _feedback_join_custom_labels(combatant_id: String) -> String:
    if combatant_id.is_empty():
        return ""
    var labels_value: Variant = _feedback_custom_labels.get(combatant_id, [])
    if not (labels_value is Array):
        return ""
    var clean_labels: Array[String] = []
    for label_value: Variant in labels_value:
        var label: String = str(label_value).strip_edges()
        if not label.is_empty() and not clean_labels.has(label):
            clean_labels.append(label)
    return " · ".join(clean_labels)


func _feedback_move_specific_fallback(
    target: Dictionary,
    before: Dictionary,
    move_id: String,
    actor_id: String
) -> String:
    match move_id:
        "protect":
            return "✖ SCHUTZ FEHLGESCHLAGEN"
        "endure":
            return "✖ SCHUTZ FEHLGESCHLAGEN"
        "rest":
            if int(before.get("hp", 0)) >= int(before.get("max_hp", 1)):
                return "✖ KP BEREITS VOLL"
            return "✖ ERHOLUNG FEHLGESCHLAGEN"
        "substitute":
            if int(before.get("db_substitute_hp", 0)) > 0:
                return "🧸 DELEGATOR BEREITS AKTIV"
            var cost: int = maxi(1, int(floor(float(before.get("max_hp", 1)) * 0.25)))
            if int(before.get("hp", 0)) <= cost:
                return "✖ ZU WENIG KP"
            return "✖ DELEGATOR FEHLGESCHLAGEN"
        "sleep_talk":
            return "💤 NUR IM SCHLAF"
        "sunny_day":
            return "☀️ SONNE AKTIV"
        "grassy_terrain":
            return "🌱 GRASFELD AKTIV"
        "helping_hand":
            return "🤝 ANGRIFF ↑ · 3 AKTIONEN"
        "charm":
            return "💗 ANGRIFF ↓ · 3 AKTIONEN"
        "solar_beam":
            var actor: Dictionary = _feedback_find_combatant(actor_id)
            if str(actor.get("db_charge_move", "")) == "solar_beam":
                return "☀️ LÄDT AUF"
        "grass_pledge":
            if _feedback_log_contains("Pflanzensäulen") or _feedback_log_contains("bereitet"):
                return "🌿 SÄULEN BEREIT"
    return ""


func _feedback_kind_for_text(text: String) -> String:
    if (
        text.contains("FEHLGESCHLAGEN")
        or text.contains("ZU WENIG")
        or text.contains("↓")
        or text.contains("WIRKUNGSLOS")
        or text.contains("DANEBEN")
    ):
        return "negative"
    if (
        text.contains("↑")
        or text.contains("AKTIV")
        or text.contains("LÄDT AUF")
        or text.contains("SÄULEN BEREIT")
    ):
        return "positive"
    return "neutral"


func _feedback_find_combatant(combatant_id: String) -> Dictionary:
    for combatant_value: Variant in combatants:
        if combatant_value is Dictionary:
            var combatant: Dictionary = combatant_value
            if str(combatant.get("id", "")) == combatant_id:
                return combatant
    return {}


func _feedback_log_contains(fragment: String) -> bool:
    if log_label == null:
        return false
    return log_label.get_parsed_text().contains(fragment)


func _feedback_array_copy(value: Variant) -> Array:
    return (value as Array).duplicate(true) if value is Array else []


func _feedback_has_new_array_entry(before_value: Variant, after_value: Variant) -> bool:
    var before_array: Array = before_value if before_value is Array else []
    var after_array: Array = after_value if after_value is Array else []
    for entry_value: Variant in after_array:
        if not before_array.has(entry_value):
            return true
    return false


func _current_move_missed() -> bool:
    if _feedback_active_move_id.is_empty() or log_label == null:
        return false
    var move: Dictionary = _move_data(_feedback_active_move_id)
    var move_name: String = str(move.get("name", _feedback_active_move_id))
    var resolved_log: String = log_label.get_parsed_text().strip_edges()
    return resolved_log.contains("verfehlt mit") and resolved_log.contains(move_name)


func _current_move_is_type_immune(target: Dictionary) -> bool:
    if _feedback_active_move_id.is_empty():
        return false
    var move: Dictionary = _move_data(_feedback_active_move_id)
    if move.is_empty() or str(move.get("category", "status")) == "status":
        return false
    var power_value: Variant = move.get("power", null)
    if power_value == null or float(power_value) <= 0.0:
        return false
    var target_types: Array = _type_array(target.get("types", []))
    return is_zero_approx(TypeSystem.get_multiplier(str(move.get("type", "normal")), target_types))


func _effect_dictionary_active(value: Variant) -> bool:
    return value is Dictionary and not (value as Dictionary).is_empty()
