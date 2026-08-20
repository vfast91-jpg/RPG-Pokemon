extends "res://scripts/battle_demo_status_hp_opening.gd"

# Combat-lab cleanup/critical-hit layer:
# - Removes the battle protocol panel now that action feedback is readable enough.
# - Restores the enemy cards to the left side once the protocol is gone.
# - Uses the central V2 critical-hit rules: 5% base chance, x1.5 damage.
# - Energiefokus adds min(Spezial, 25) percentage points until switch/battle end.
# - Energiefokus is persistent and non-stackable; it is NOT a 3-action modifier.
# - Resolved damaging moves report type effectiveness in the visible battle log.

const BASE_CRITICAL_CHANCE: float = 0.05
const CRITICAL_DAMAGE_MULTIPLIER: float = 1.5


func _build_battle(root: Control) -> void:
    super._build_battle(root)

    var protocol_panel: PanelContainer = battle_panel.get_node_or_null("BattleProtocol") as PanelContainer
    if protocol_panel != null:
        protocol_label = null
        battle_panel.remove_child(protocol_panel)
        protocol_panel.queue_free()


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    var positions: Array = _positions_for_count(team.size())
    for index: int in range(team.size()):
        var combatant: Dictionary = team[index]
        var card: Control = _make_card(combatant, enemy)
        card.position = Vector2(16.0 if enemy else PLAYER_COLUMN_X, float(positions[index]))
        area.add_child(card)


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["critical_focus_bonus"] = 0.0
    return combatant


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind != "critical_focus":
        return super._effect(actor, target, mechanic)

    var bonus_cap_percent: float = float(mechanic.get("bonus_cap", 25.0))
    var bonus_percent: float = minf(float(actor.get("special", 0)), bonus_cap_percent)
    var bonus: float = clampf(bonus_percent / 100.0, 0.0, 1.0)

    # Non-stackable: using Energiefokus again replaces/refreshes the same state.
    target["critical_focus_bonus"] = bonus
    return bonus_percent / 10.0


func _critical_chance(combatant: Dictionary) -> float:
    return clampf(
        BASE_CRITICAL_CHANCE + float(combatant.get("critical_focus_bonus", 0.0)),
        0.0,
        1.0
    )


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    var type_feedback_contexts: Array = []

    if not move.is_empty():
        var category: String = str(move.get("category", "status"))
        var power_value: Variant = move.get("power", null)
        if category != "status" and power_value != null and float(power_value) > 0.0:
            var move_type: String = str(move.get("type", "normal"))
            var targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
            for target_value: Variant in targets:
                if not (target_value is Dictionary):
                    continue
                var target: Dictionary = target_value
                var defender_types: Array = _type_array(target.get("types", []))
                type_feedback_contexts.append({
                    "target": target,
                    "hp_before": int(target.get("hp", 0)),
                    "multiplier": TypeSystem.get_multiplier(move_type, defender_types)
                })

    super._execute_move(actor, move_id)

    if type_feedback_contexts.is_empty() or log_label == null:
        return

    # Only an actually resolved move may report effectiveness. This prevents
    # paralysis, confusion self-hits and accuracy misses from producing a
    # misleading type-effectiveness message. Immunities still report correctly.
    var resolved_log: String = log_label.get_parsed_text().strip_edges()
    var move_name: String = str(move.get("name", move_id))
    var move_was_resolved: bool = resolved_log.contains("nutzt") and resolved_log.contains(move_name)
    if not move_was_resolved:
        return

    var feedback_lines: Array[String] = []
    var multiple_targets: bool = type_feedback_contexts.size() > 1

    for context_value: Variant in type_feedback_contexts:
        if not (context_value is Dictionary):
            continue
        var context: Dictionary = context_value
        var target_value: Variant = context.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var multiplier: float = float(context.get("multiplier", 1.0))
        var hp_before: int = int(context.get("hp_before", int(target.get("hp", 0))))
        var hp_after: int = int(target.get("hp", 0))

        var effectiveness_text: String = _resolved_effectiveness_feedback(multiplier, hp_after < hp_before)
        if effectiveness_text.is_empty():
            continue

        if multiple_targets:
            feedback_lines.append(_actor_name(target) + ": " + effectiveness_text)
        else:
            feedback_lines.append(effectiveness_text)

    if feedback_lines.is_empty():
        return

    var current_text: String = log_label.text.strip_edges()
    var effectiveness_block: String = "[b]" + "\n".join(feedback_lines) + "[/b]"
    log_label.text = effectiveness_block if current_text.is_empty() else current_text + "\n" + effectiveness_block


func _resolved_effectiveness_feedback(multiplier: float, dealt_damage: bool) -> String:
    if is_zero_approx(multiplier):
        return "⛔ WIRKUNGSLOS!"
    if not dealt_damage:
        return ""
    if multiplier >= 2.0:
        return "🔥 SEHR EFFEKTIV!"
    if multiplier < 1.0:
        return "🛡️ NICHT SEHR EFFEKTIV!"
    return ""


func _resolve_opening_actions_async() -> void:
    if _opening_choices.is_empty():
        _finish_opening_phase()
        return

    for choice_value: Variant in _opening_choices:
        if not battle_active:
            return
        if not (choice_value is Dictionary):
            continue
        var choice: Dictionary = choice_value
        var actor_value: Variant = choice.get("actor", {})
        if not (actor_value is Dictionary):
            continue
        var actor: Dictionary = actor_value
        if not bool(actor.get("alive", false)):
            continue

        var move_id: String = str(choice.get("move_id", ""))
        if move_id.is_empty():
            continue

        paused = true
        _set_log(
            "[b]RUNDE 0[/b] · " + _actor_name(actor)
            + " setzt " + str(_move_data(move_id).get("name", move_id)) + " ein."
        )
        # Use this leaf layer instead of bypassing it with super so opening
        # attacks receive the same type-effectiveness feedback as normal moves.
        _execute_move(actor, move_id)
        await get_tree().create_timer(SHORT_ACTION_FEEDBACK_SECONDS).timeout
        if not battle_active:
            return
        paused = true

    _finish_opening_phase()


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0:
        return damage

    # Confusion self-damage cannot critically hit.
    if str(actor.get("id", "")) == str(target.get("id", "")):
        return damage

    if randf() >= _critical_chance(actor):
        return damage

    var critical_damage: int = maxi(1, int(round(float(damage) * CRITICAL_DAMAGE_MULTIPLIER)))
    _spawn_feedback_label(target, "💥 KRITISCH!", Color("ffe46c"))
    return critical_damage


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var bonus: float = float(combatant.get("critical_focus_bonus", 0.0))
    if bonus > 0.0001:
        tokens.append("🔥 KRIT+" + str(int(round(bonus * 100.0))) + "%")
    return tokens


func _move_has_three_action_modifier(move: Dictionary) -> bool:
    # Energiefokus is intentionally excluded: it persists until switch/battle end.
    return super._move_has_three_action_modifier(move)
