extends "res://scripts/battle_demo_hd.gd"

# Player-facing polish for the combat lab:
# - RPG-AP are always displayed as whole numbers.
# - Move tooltips explain tactical consequences in detail.
# - Every resolved action produces readable, human-scale visual feedback.

const ACTION_FEEDBACK_SECONDS: float = 1.10
const FEEDBACK_RISE_PIXELS: float = 18.0


func _prompt_player(actor: Dictionary) -> void:
    paused = true
    selected_actor = actor
    _clear_actions()
    _set_log("[b]" + _actor_name(actor) + "[/b] ist bereit. Wähle eine Aktion.")

    var moves_all: Variant = data.get("moves", {})
    var actor_moves: Variant = actor.get("moves", [])
    if actor_moves is Array and moves_all is Dictionary:
        for move_value: Variant in actor_moves:
            var move_id: String = str(move_value)
            var move_value_data: Variant = moves_all.get(move_id, {})
            var move: Dictionary = move_value_data if move_value_data is Dictionary else {}
            var button: Button = Button.new()
            button.text = str(move.get("name", move_id)) + " · AP " + str(_ap_value(move))
            button.custom_minimum_size = Vector2(145, 31)
            button.tooltip_text = _move_tooltip(move)
            button.pressed.connect(_choose_move.bind(move_id))
            action_grid.add_child(button)

    var wait_button: Button = Button.new()
    wait_button.text = "Warten"
    wait_button.custom_minimum_size = Vector2(145, 31)
    wait_button.tooltip_text = "Aggro senken und schneller wieder bereit werden."
    wait_button.pressed.connect(_choose_wait)
    action_grid.add_child(wait_button)

    _refresh_cards()


func _move_tooltip(move: Dictionary) -> String:
    var parts: Array[String] = []
    var ap: int = _ap_value(move)
    var move_type: String = str(move.get("type", "normal"))
    var category: String = str(move.get("category", "physical"))

    parts.append(str(move.get("name", "Attacke")))
    parts.append("Typ: " + _type_name(move_type) + " · Kategorie: " + _category_name(category))

    if move.get("power", null) != null:
        parts.append("Stärke: " + str(int(round(float(move.get("power", 0))))))
    else:
        parts.append("Stärke: — (Status-/Supportattacke)")

    if move.get("accuracy", null) != null:
        parts.append("Genauigkeit: " + str(int(round(float(move.get("accuracy", 100))))) + "%")
    else:
        parts.append("Genauigkeit: kein Genauigkeitswurf")

    parts.append("Ziel: " + _target_name(str(move.get("target", "enemy_highest_aggro"))))
    if bool(move.get("area", false)):
        parts.append("Flächenattacke: ja")

    var priority: int = int(round(float(move.get("priority", 0))))
    if priority != 0:
        parts.append("Priorität: " + ("+" if priority > 0 else "") + str(priority))
    if bool(move.get("opening", false)):
        parts.append("Runde 0: einsetzbar")

    _append_type_context(parts, move, category, move_type)

    parts.append("")
    parts.append("Wirkung:")
    var effect_lines: Array[String] = _move_effect_lines(move)
    if effect_lines.is_empty():
        parts.append("• Keine zusätzliche Wirkung hinterlegt.")
    else:
        for line: String in effect_lines:
            parts.append(line)

    parts.append("")
    parts.append("AP: " + str(ap) + " · nächster ATB-Zyklus ×" + _decimal(_ap_cycle(ap), 2))
    parts.append("AP werden NICHT verbraucht. Sie sind die Zeitkosten der Attacke.")
    parts.append("AP 1 = keine zusätzliche ATB-Verlangsamung; höhere AP = längere Erholung bis zur nächsten Aktion.")

    return "\n".join(parts)


func _append_type_context(parts: Array[String], move: Dictionary, category: String, move_type: String) -> void:
    if selected_actor.is_empty():
        return

    var actor_types: Array = _type_array(selected_actor.get("types", []))
    if actor_types.has(move_type):
        if category == "status":
            var status_bonus: float = TypeSystem.get_same_type_status_multiplier(move_type, actor_types)
            parts.append("Eigener Typbonus: Statuswirkung ×" + _decimal(status_bonus, 2))
        else:
            var damage_bonus: float = TypeSystem.get_same_type_damage_multiplier(move_type, actor_types)
            parts.append("Eigener Typbonus: Schaden ×" + _decimal(damage_bonus, 2))

    if category == "status":
        return

    var current_targets: Array = _targets(selected_actor, str(move.get("target", "enemy_highest_aggro")))
    for target_value: Variant in current_targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var defender_types: Array = _type_array(target.get("types", []))
        var multiplier: float = TypeSystem.get_multiplier(move_type, defender_types)
        parts.append("Gegen " + _actor_name(target) + ": Typwirkung ×" + _decimal(multiplier, 2) + " (" + _effectiveness_name(multiplier) + ")")


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    var targets: Array = []
    if not move.is_empty():
        targets = _targets(actor, str(move.get("target", "enemy_highest_aggro")))

    var before_states: Dictionary = {}
    for target_value: Variant in targets:
        if target_value is Dictionary:
            var target: Dictionary = target_value
            before_states[str(target.get("id", ""))] = _feedback_snapshot(target)

    var actor_hp_before: int = int(actor.get("hp", 0))

    # Freeze the ATB clock while the action feedback is visible. The actual
    # action still resolves immediately; only the next ATB progress waits.
    paused = true
    _flash_combatant(actor, Color("fff1a3"))
    _spawn_feedback_label(actor, str(move.get("name", move_id)), Color("ffe46c"))

    super._execute_move(actor, move_id)

    var target_ids: Dictionary = {}
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        target_ids[target_id] = true
        var before_value: Variant = before_states.get(target_id, {})
        var before: Dictionary = before_value if before_value is Dictionary else {}
        _show_target_feedback(target, before)

    # Confusion can make the acting Pokémon damage itself even though the
    # originally selected target is an opponent.
    if int(actor.get("hp", 0)) < actor_hp_before and not target_ids.has(str(actor.get("id", ""))):
        _flash_combatant(actor, Color("ffb2b2"))
        _spawn_feedback_label(actor, "−" + str(actor_hp_before - int(actor.get("hp", 0))) + " KP", Color("ff8d8d"))

    get_tree().create_timer(ACTION_FEEDBACK_SECONDS).timeout.connect(_finish_action_feedback)


func _finish_action_feedback() -> void:
    if battle_active:
        paused = false


func _show_target_feedback(target: Dictionary, before: Dictionary) -> void:
    var feedback: Dictionary = _feedback_result(target, before)
    var kind: String = str(feedback.get("kind", "neutral"))
    var color: Color = Color("ffeaa2")
    if kind == "positive":
        color = Color("8fe39b")
    elif kind == "negative":
        color = Color("ff8d8d")

    _flash_combatant(target, color)
    _spawn_feedback_label(target, str(feedback.get("text", "EFFEKT")), color)


func _flash_combatant(combatant: Dictionary, color: Color) -> void:
    var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
    if not (ui_value is Dictionary):
        return
    var ui: Dictionary = ui_value
    var card: Control = ui.get("card") as Control
    if card == null:
        return

    card.modulate = Color.WHITE
    var tween: Tween = create_tween()
    tween.tween_property(card, "modulate", color, 0.12)
    tween.tween_interval(0.72)
    tween.tween_property(card, "modulate", Color.WHITE, 0.20)


func _spawn_feedback_label(combatant: Dictionary, text: String, color: Color) -> void:
    if battle_panel == null:
        return

    var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
    if not (ui_value is Dictionary):
        return
    var ui: Dictionary = ui_value
    var card: Control = ui.get("card") as Control
    if card == null:
        return

    var label: Label = Label.new()
    label.text = text
    label.position = card.global_position + Vector2(8.0, -19.0)
    label.z_index = 60
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color("18211f"))
    label.add_theme_constant_override("outline_size", 4)
    battle_panel.add_child(label)

    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "position:y", label.position.y - FEEDBACK_RISE_PIXELS, ACTION_FEEDBACK_SECONDS)
    tween.tween_property(label, "modulate:a", 0.0, 0.30).set_delay(ACTION_FEEDBACK_SECONDS - 0.30)
    tween.chain().tween_callback(label.queue_free)


func _feedback_snapshot(target: Dictionary) -> Dictionary:
    return {
        "hp": int(target.get("hp", 0)),
        "alive": bool(target.get("alive", true)),
        "paralyzed": bool(target.get("paralyzed", false)),
        "confused_turns": int(target.get("confused_turns", 0)),
        "attack_mult": float(target.get("attack_mult", 1.0)),
        "defense_mult": float(target.get("defense_mult", 1.0)),
        "accuracy_mult": float(target.get("accuracy_mult", 1.0)),
        "next_cycle": float(target.get("next_cycle", 1.0)),
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

    var attack_change: int = _compare_float(float(before.get("attack_mult", 1.0)), float(target.get("attack_mult", 1.0)))
    if attack_change < 0:
        lines.append("ANGRIFF ↓")
        negative = true
    elif attack_change > 0:
        lines.append("ANGRIFF ↑")
        positive = true

    var defense_change: int = _compare_float(float(before.get("defense_mult", 1.0)), float(target.get("defense_mult", 1.0)))
    if defense_change < 0:
        lines.append("SCHUTZ ↓")
        negative = true
    elif defense_change > 0:
        lines.append("SCHUTZ ↑")
        positive = true

    var accuracy_change: int = _compare_float(float(before.get("accuracy_mult", 1.0)), float(target.get("accuracy_mult", 1.0)))
    if accuracy_change < 0:
        lines.append("GENAUIGKEIT ↓")
        negative = true
    elif accuracy_change > 0:
        lines.append("GENAUIGKEIT ↑")
        positive = true

    var cycle_before: float = float(before.get("next_cycle", 1.0))
    var cycle_after: float = float(target.get("next_cycle", 1.0))
    var cycle_change: int = _compare_float(cycle_before, cycle_after)
    if cycle_change > 0:
        lines.append("NÄCHSTE AKTION SPÄTER")
        negative = true
    elif cycle_change < 0:
        lines.append("NÄCHSTE AKTION FRÜHER")
        positive = true

    var atb_before: float = float(before.get("atb", 0.0))
    var atb_after: float = float(target.get("atb", 0.0))
    if atb_after < atb_before - 0.5:
        lines.append("ATB ↓")
        negative = true

    if lines.is_empty():
        lines.append("KEIN EFFEKT")

    var kind: String = "neutral"
    if negative:
        kind = "negative"
    elif positive:
        kind = "positive"

    return {"kind": kind, "text": " · ".join(lines)}


func _compare_float(before: float, after: float) -> int:
    if after > before + 0.001:
        return 1
    if after < before - 0.001:
        return -1
    return 0


func _move_data(move_id: String) -> Dictionary:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return {}
    var move_value: Variant = moves_value.get(move_id, {})
    return move_value if move_value is Dictionary else {}


func _ap_value(move: Dictionary) -> int:
    return maxi(1, int(round(float(move.get("ap", 1)))))


func _decimal(value: float, decimals: int = 2) -> String:
    var pattern: String = "%." + str(decimals) + "f"
    return (pattern % value).replace(".", ",")


func _category_name(category: String) -> String:
    match category:
        "physical":
            return "Physisch"
        "special":
            return "Spezial"
        "status":
            return "Status"
        _:
            return category.capitalize()


func _target_name(rule: String) -> String:
    match rule:
        "self":
            return "Anwender"
        "all_enemies":
            return "alle Gegner"
        "all_allies":
            return "alle Verbündeten"
        "ally":
            return "ein Verbündeter"
        "field":
            return "gesamtes Kampffeld"
        "enemy_highest_aggro":
            return "Gegner mit höchster Aggro"
        _:
            return rule.replace("_", " ")


func _status_name(status_id: String) -> String:
    match status_id:
        "paralysis":
            return "Paralyse"
        "confusion":
            return "Verwirrung"
        "burn":
            return "Verbrennung"
        "poison":
            return "Vergiftung"
        _:
            return status_id.replace("_", " ").capitalize()


func _effectiveness_name(multiplier: float) -> String:
    if is_zero_approx(multiplier):
        return "wirkungslos"
    if multiplier >= 2.0:
        return "sehr effektiv"
    if multiplier > 1.0:
        return "effektiv"
    if multiplier < 1.0:
        return "wenig effektiv"
    return "normal"


func _move_effect_lines(move: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return result

    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        var kind: String = str(mechanic.get("kind", ""))
        var multiplier: float = float(mechanic.get("multiplier_from_special", 0.0))

        match kind:
            "damage":
                result.append("• Verursacht direkten Schaden.")
                if bool(mechanic.get("conditional_double_if_damaged_since_last_action", false)):
                    result.append("• Spezialregel: kann unter der hinterlegten Bedingung doppelten Schaden verursachen.")
            "status":
                var chance: int = int(round(float(mechanic.get("chance", 1.0)) * 100.0))
                var status_text: String = _status_name(str(mechanic.get("status", "Status")))
                if chance >= 100:
                    result.append("• Verursacht " + status_text + ".")
                else:
                    result.append("• " + str(chance) + "% Chance auf " + status_text + ".")
            "outgoing_damage_mod":
                if multiplier < 0.0:
                    result.append("• Senkt den verursachten Schaden des Ziels für dessen nächsten Schaden.")
                else:
                    result.append("• Erhöht den verursachten Schaden des Ziels für dessen nächsten Schaden.")
            "incoming_damage_mod":
                if multiplier < 0.0:
                    result.append("• Verringert den nächsten eingehenden Schaden des Ziels.")
                else:
                    result.append("• Erhöht den nächsten eingehenden Schaden des Ziels.")
            "accuracy_mod":
                if multiplier < 0.0:
                    result.append("• Senkt die Genauigkeit des Ziels für den nächsten Genauigkeitswurf.")
                else:
                    result.append("• Erhöht die Genauigkeit des Ziels.")
            "atb_cycle_mod":
                if multiplier < 0.0:
                    result.append("• Verkürzt den nächsten ATB-Zyklus des Ziels.")
                else:
                    result.append("• Verlängert den nächsten ATB-Zyklus des Ziels.")
            "atb_knockback":
                var chance_knockback: int = int(round(float(mechanic.get("chance", 1.0)) * 100.0))
                var amount: int = int(round(float(mechanic.get("amount", 0.0)) * 100.0))
                result.append("• " + str(chance_knockback) + "% Chance, die ATB-Leiste des Ziels um ca. " + str(amount) + "% zurückzuwerfen.")
            "cleanse_self":
                result.append("• Entfernt hinterlegte negative Effekte vom Anwender.")
            "seed":
                result.append("• Setzt einen fortlaufenden Samen-/Entzugseffekt auf das Ziel.")
            "binding":
                result.append("• Bindet das Ziel und verursacht über mehrere Ticks Folgewirkung.")
            "critical_focus":
                result.append("• Bereitet einen Kritisch-Fokus für kommende Angriffe vor.")
            _:
                result.append("• Zusatzeffekt: " + kind.replace("_", " ") + ".")

    return result
