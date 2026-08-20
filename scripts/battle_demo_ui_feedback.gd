extends "res://scripts/battle_demo_hd.gd"

# Player-facing polish for the combat lab:
# - RPG-AP are always displayed as whole numbers.
# - Move tooltips stay compact and decision-focused.
# - Resolved actions remain visible long enough to understand.
# - A persistent battle protocol records the fight between both teams.

const ACTION_FEEDBACK_SECONDS: float = 2.50
const FEEDBACK_RISE_PIXELS: float = 24.0
const PROTOCOL_MAX_ENTRIES: int = 40

var protocol_label: RichTextLabel = null
var protocol_entries: Array[String] = []
var protocol_turn: int = 0


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    _build_protocol_panel()


func _build_protocol_panel() -> void:
    if battle_panel == null:
        return

    var protocol_panel: PanelContainer = PanelContainer.new()
    protocol_panel.name = "BattleProtocol"
    protocol_panel.position = Vector2(202, 10)
    protocol_panel.size = Vector2(232, 204)
    protocol_panel.z_index = 2
    protocol_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    protocol_panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("13201ed9"), Color("5f786d"), 6, 5.0)
    )
    battle_panel.add_child(protocol_panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 3)
    protocol_panel.add_child(content)

    var title: Label = Label.new()
    title.text = "KAMPFPROTOKOLL"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 10)
    title.add_theme_color_override("font_color", Color("d8e5df"))
    content.add_child(title)

    protocol_label = RichTextLabel.new()
    protocol_label.bbcode_enabled = true
    protocol_label.fit_content = false
    protocol_label.scroll_active = true
    protocol_label.scroll_following = true
    protocol_label.selection_enabled = true
    protocol_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    protocol_label.custom_minimum_size = Vector2(0, 174)
    protocol_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    protocol_label.add_theme_font_size_override("normal_font_size", 8)
    protocol_label.add_theme_font_size_override("bold_font_size", 8)
    content.add_child(protocol_label)

    _clear_protocol()


func _start_battle() -> void:
    _clear_protocol()
    super._start_battle()
    _append_protocol_system(
        "Kampf gestartet · Dein Team " + str(player_team.size()) + " vs. Gegner " + str(enemy_team.size())
    )


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
    wait_button.tooltip_text = "Warten · Aggro sinkt · nächster ATB-Zyklus wird kürzer."
    wait_button.pressed.connect(_choose_wait)
    action_grid.add_child(wait_button)

    _refresh_cards()


func _move_tooltip(move: Dictionary) -> String:
    var parts: Array[String] = []
    var ap: int = _ap_value(move)
    var move_type: String = str(move.get("type", "normal"))
    var category: String = str(move.get("category", "physical"))

    parts.append(str(move.get("name", "Attacke")) + " · " + _type_name(move_type) + " · " + _category_name(category))

    var combat_line: Array[String] = []
    if move.get("power", null) != null:
        combat_line.append("Stärke " + str(int(round(float(move.get("power", 0))))))
    if move.get("accuracy", null) != null:
        combat_line.append("Genauigkeit " + str(int(round(float(move.get("accuracy", 100))))) + "%")
    else:
        combat_line.append("trifft ohne Genauigkeitswurf")
    combat_line.append("Ziel: " + _target_name(str(move.get("target", "enemy_highest_aggro"))))
    parts.append(" · ".join(combat_line))

    var effect_summary: String = _compact_effect_summary(move)
    if not effect_summary.is_empty():
        parts.append("Effekt: " + effect_summary)

    var type_context: String = _compact_type_context(move, category, move_type)
    if not type_context.is_empty():
        parts.append(type_context)

    var special_bits: Array[String] = []
    var priority: int = int(round(float(move.get("priority", 0))))
    if priority != 0:
        special_bits.append("Priorität " + ("+" if priority > 0 else "") + str(priority))
    if bool(move.get("opening", false)):
        special_bits.append("in Runde 0 nutzbar")
    if bool(move.get("area", false)):
        special_bits.append("Flächenwirkung")
    if not special_bits.is_empty():
        parts.append("Besonderheit: " + " · ".join(special_bits))

    parts.append(
        "AP " + str(ap) + " → ATB-Zyklus ×" + _decimal(_ap_cycle(ap), 2)
        + " · AP = Zeitkosten, wird nicht verbraucht"
    )

    return "\n".join(parts)


func _compact_type_context(move: Dictionary, category: String, move_type: String) -> String:
    if selected_actor.is_empty():
        return ""

    var bits: Array[String] = []
    var actor_types: Array = _type_array(selected_actor.get("types", []))
    if actor_types.has(move_type):
        if category == "status":
            bits.append(
                "eigener Typbonus ×" + _decimal(
                    TypeSystem.get_same_type_status_multiplier(move_type, actor_types), 2
                )
            )
        else:
            bits.append(
                "eigener Typbonus ×" + _decimal(
                    TypeSystem.get_same_type_damage_multiplier(move_type, actor_types), 2
                )
            )

    if category != "status":
        var current_targets: Array = _targets(
            selected_actor, str(move.get("target", "enemy_highest_aggro"))
        )
        if current_targets.size() == 1 and current_targets[0] is Dictionary:
            var target: Dictionary = current_targets[0]
            var defender_types: Array = _type_array(target.get("types", []))
            var multiplier: float = TypeSystem.get_multiplier(move_type, defender_types)
            bits.append(
                "gegen " + _actor_name(target) + " ×" + _decimal(multiplier, 2)
                + " (" + _effectiveness_name(multiplier) + ")"
            )
        elif current_targets.size() > 1:
            bits.append("Typwirkung wird je Ziel berechnet")

    if bits.is_empty():
        return ""
    return "Matchup: " + " · ".join(bits)


func _compact_effect_summary(move: Dictionary) -> String:
    var effects: Array[String] = []
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return ""

    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        var kind: String = str(mechanic.get("kind", ""))
        var multiplier: float = float(mechanic.get("multiplier_from_special", 0.0))

        match kind:
            "damage":
                effects.append("direkter Schaden")
            "status":
                var chance: int = int(round(float(mechanic.get("chance", 1.0)) * 100.0))
                var status_text: String = _status_name(str(mechanic.get("status", "Status")))
                effects.append(status_text if chance >= 100 else str(chance) + "% " + status_text)
            "outgoing_damage_mod":
                effects.append("verursachter Schaden ↓" if multiplier < 0.0 else "verursachter Schaden ↑")
            "incoming_damage_mod":
                effects.append("eingehender Schaden ↓" if multiplier < 0.0 else "eingehender Schaden ↑")
            "accuracy_mod":
                effects.append("Genauigkeit ↓" if multiplier < 0.0 else "Genauigkeit ↑")
            "atb_cycle_mod":
                effects.append("nächster ATB-Zyklus kürzer" if multiplier < 0.0 else "nächster ATB-Zyklus länger")
            "atb_knockback":
                var chance_knockback: int = int(round(float(mechanic.get("chance", 1.0)) * 100.0))
                var amount: int = int(round(float(mechanic.get("amount", 0.0)) * 100.0))
                effects.append(str(chance_knockback) + "% ATB −" + str(amount) + "%")
            "cleanse_self":
                effects.append("entfernt negative Effekte")
            "seed":
                effects.append("Samen-/Entzugseffekt")
            "binding":
                effects.append("Bindung + Folgeschaden")
            "critical_focus":
                effects.append("Kritisch-Fokus")
            _:
                if not kind.is_empty():
                    effects.append(kind.replace("_", " "))

    return " · ".join(effects)


func _choose_wait() -> void:
    if selected_actor.is_empty():
        return
    var actor: Dictionary = selected_actor
    super._choose_wait()
    _append_protocol_action(actor, "wartet · Aggro gesenkt · nächste Aktion schneller", [])


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    var targets: Array = []
    if not move.is_empty():
        targets = _targets(actor, str(move.get("target", "enemy_highest_aggro")))

    var before_states: Dictionary = {}
    for target_value: Variant in targets:
        if target_value is Dictionary:
            var target: Dictionary = target_value
            var snapshot: Dictionary = _feedback_snapshot(target)
            if str(target.get("id", "")) == str(actor.get("id", "")):
                snapshot["atb"] = 0.0
            before_states[str(target.get("id", ""))] = snapshot

    var actor_hp_before: int = int(actor.get("hp", 0))

    # The ATB clock is deliberately frozen while the action feedback remains
    # on screen. The battle may therefore take a little time, but each action
    # can actually be read and understood.
    paused = true
    _flash_combatant(actor, Color("fff1a3"))
    _spawn_feedback_label(actor, str(move.get("name", move_id)), Color("ffe46c"))

    super._execute_move(actor, move_id)

    var target_ids: Dictionary = {}
    var protocol_results: Array[String] = []
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        target_ids[target_id] = true
        var before_value: Variant = before_states.get(target_id, {})
        var before: Dictionary = before_value if before_value is Dictionary else {}
        var feedback: Dictionary = _show_target_feedback(target, before)
        var feedback_text: String = str(feedback.get("text", "KEIN EFFEKT"))
        if feedback_text != "KEIN EFFEKT":
            protocol_results.append(_actor_name(target) + ": " + feedback_text)

    # Confusion can make the acting Pokémon damage itself even though the
    # originally selected target is an opponent.
    if int(actor.get("hp", 0)) < actor_hp_before and not target_ids.has(str(actor.get("id", ""))):
        var self_damage: int = actor_hp_before - int(actor.get("hp", 0))
        _flash_combatant(actor, Color("ffb2b2"))
        _spawn_feedback_label(actor, "−" + str(self_damage) + " KP", Color("ff8d8d"))
        protocol_results.append(_actor_name(actor) + ": −" + str(self_damage) + " KP durch Verwirrung")

    var action_text: String = str(move.get("name", move_id))
    if log_label != null:
        var parsed_log: String = log_label.get_parsed_text().strip_edges()
        if not parsed_log.is_empty():
            action_text = parsed_log
    _append_protocol_action(actor, action_text, protocol_results)

    get_tree().create_timer(ACTION_FEEDBACK_SECONDS).timeout.connect(_finish_action_feedback)


func _finish_action_feedback() -> void:
    if battle_active:
        paused = false


func _show_target_feedback(target: Dictionary, before: Dictionary) -> Dictionary:
    var feedback: Dictionary = _feedback_result(target, before)
    var kind: String = str(feedback.get("kind", "neutral"))
    var color: Color = Color("ffeaa2")
    if kind == "positive":
        color = Color("8fe39b")
    elif kind == "negative":
        color = Color("ff8d8d")

    _flash_combatant(target, color)
    _spawn_feedback_label(target, str(feedback.get("text", "EFFEKT")), color)
    return feedback


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
    tween.tween_property(card, "modulate", color, 0.18)
    tween.tween_interval(maxf(0.0, ACTION_FEEDBACK_SECONDS - 0.48))
    tween.tween_property(card, "modulate", Color.WHITE, 0.30)


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
    tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(ACTION_FEEDBACK_SECONDS - 0.55)
    tween.chain().tween_callback(label.queue_free)


func _clear_protocol() -> void:
    protocol_entries.clear()
    protocol_turn = 0
    if protocol_label != null:
        protocol_label.text = "[color=#91a69d]Noch keine Aktion.[/color]"


func _append_protocol_system(text: String) -> void:
    protocol_entries.append("[color=#91a69d]" + text + "[/color]")
    _refresh_protocol()


func _append_protocol_action(actor: Dictionary, action_text: String, results: Array[String]) -> void:
    protocol_turn += 1
    var side_text: String = "DEIN TEAM" if str(actor.get("side", "")) == "player" else "GEGNER"
    var side_color: String = "#8fd3ff" if str(actor.get("side", "")) == "player" else "#ffb1a8"

    var entry: String = (
        "[b]" + str(protocol_turn) + ".[/b] "
        + "[color=" + side_color + "]" + side_text + "[/color] · "
        + action_text
    )
    if not results.is_empty():
        entry += "\n[color=#d8e5df]↳ " + " · ".join(results) + "[/color]"

    protocol_entries.append(entry)
    while protocol_entries.size() > PROTOCOL_MAX_ENTRIES:
        protocol_entries.pop_front()
    _refresh_protocol()


func _refresh_protocol() -> void:
    if protocol_label == null:
        return
    protocol_label.text = "\n\n".join(protocol_entries)


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
            return "höchste Aggro"
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
