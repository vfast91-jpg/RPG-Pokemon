extends "res://scripts/battle_demo_status_hp_opening.gd"

# Combat-lab cleanup/critical-hit layer:
# - Removes the battle protocol panel now that action feedback is readable enough.
# - Restores the enemy cards to the left side once the protocol is gone.
# - Uses the central V2 critical-hit rules: 5% base chance, x1.5 damage.
# - Energiefokus adds min(Spezial, 25) percentage points until switch/battle end.
# - Energiefokus is persistent and non-stackable; it is NOT a 3-action modifier.

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
