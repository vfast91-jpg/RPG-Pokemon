extends "res://scripts/battle_demo_status_hp_opening.gd"

# Combat-lab cleanup/fix layer:
# - Removes the battle protocol panel now that action feedback is readable enough.
# - Restores the enemy cards to the left side once the protocol is gone.
# - Implements Energiefokus / critical_focus as a real 3-action buff.
# - Energiefokus grants +25 percentage points critical chance (from bonus_cap=25).
# - Critical hits currently deal x1.5 damage as a provisional combat-lab test value.

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


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind != "critical_focus":
        return super._effect(actor, target, mechanic)

    var bonus_cap_percent: float = float(mechanic.get("bonus_cap", 25.0))
    var bonus: float = clampf(bonus_cap_percent / 100.0, 0.0, 1.0)

    _add_timed_modifier(
        target,
        "critical_focus",
        1.0 + bonus,
        _current_effect_move_name if not _current_effect_move_name.is_empty() else "Energiefokus",
        _actor_name(actor)
    )
    return bonus_cap_percent / 10.0


func _critical_bonus(combatant: Dictionary) -> float:
    var bonus: float = 0.0
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if not (modifier_value is Dictionary):
                continue
            var modifier: Dictionary = modifier_value
            if str(modifier.get("kind", "")) != "critical_focus":
                continue
            bonus += maxf(0.0, float(modifier.get("multiplier", 1.0)) - 1.0)

    # The move data explicitly caps the bonus at 25 percentage points.
    return clampf(bonus, 0.0, 0.25)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0:
        return damage

    # Confusion self-damage does not consume/benefit from Energiefokus.
    if str(actor.get("id", "")) == str(target.get("id", "")):
        return damage

    var crit_chance: float = _critical_bonus(actor)
    if crit_chance <= 0.0 or randf() >= crit_chance:
        return damage

    var critical_damage: int = maxi(1, int(round(float(damage) * CRITICAL_DAMAGE_MULTIPLIER)))
    _spawn_feedback_label(target, "💥 KRITISCH!", Color("ffe46c"))
    return critical_damage


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if _active_modifier_count(combatant, "critical_focus") > 0:
        tokens.append("🔥 KRIT+25%")
    return tokens


func _modifier_detail_text(kind: String, multiplier: float) -> String:
    if kind == "critical_focus":
        var percent: int = int(round(maxf(0.0, multiplier - 1.0) * 100.0))
        return "Krit-Chance +" + str(percent) + " Prozentpunkte"
    return super._modifier_detail_text(kind, multiplier)


func _move_has_three_action_modifier(move: Dictionary) -> bool:
    if super._move_has_three_action_modifier(move):
        return true

    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false
    for mechanic_value: Variant in mechanics_value:
        if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "critical_focus":
            return true
    return false
