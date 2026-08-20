extends "res://scripts/battle_demo_opening_recovery.gd"

# Player-facing action feedback fixes:
# - Accuracy misses say DANEBEN instead of KEIN EFFEKT.
# - Type immunities say WIRKUNGSLOS.
# - Persistent/special mechanics are included in the feedback snapshot so
#   successful effects such as Energiefokus, Egelsamen and Bindung are visible.
# - Waiting grants a much stronger next-cycle speed advantage (0.45x cycle).

const WAIT_CYCLE_MULTIPLIER: float = 0.45

var _feedback_active_move_id: String = ""


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
    super._execute_move(actor, move_id)
    _feedback_active_move_id = ""


func _feedback_snapshot(target: Dictionary) -> Dictionary:
    var snapshot: Dictionary = super._feedback_snapshot(target)
    snapshot["major_status"] = str(target.get("major_status", ""))
    snapshot["critical_focus_bonus"] = float(target.get("critical_focus_bonus", 0.0))
    snapshot["seed_active"] = _effect_dictionary_active(target.get("seed_effect", {}))
    snapshot["binding_active"] = _effect_dictionary_active(target.get("binding_effect", {}))
    return snapshot


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
            "paralysis":
                # The inherited feedback already reports PARALYSE via its
                # dedicated boolean field, so do not duplicate it here.
                pass
            _:
                extras.append(status_after.to_upper())
                extra_negative = true

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
