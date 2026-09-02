extends "res://scripts/battle_demo_endgame_atb_v1.gd"

# Final shared guard against runaway temporary Speed control.
#
# Two rules are enforced at the last runtime seam so every battle mode using
# main.tscn gets the same behavior without rewriting the historical modifier
# layers below it:
# 1) Re-applying the same named Speed/ATB-cycle effect refreshes its duration
#    instead of creating another independent stack. Different moves may still
#    combine, preserving intentional tempo-control synergies.
# 2) The combined temporary slowdown can never make the ATB cycle longer than
#    2.5x normal. This keeps strong Speed control useful while preventing a
#    self-reinforcing soft lock where the slowed Pokemon barely receives the
#    own actions that are required for its debuffs to expire.

const TEMPO_SLOWDOWN_CAP: float = 2.5
const TEMPO_EFFECT_ACTIONS: int = 3


func _add_timed_modifier(
    target: Dictionary,
    kind: String,
    multiplier: float,
    source_move: String,
    source_actor: String
) -> void:
    if kind != "atb_cycle_mod" or source_move.is_empty():
        super._add_timed_modifier(target, kind, multiplier, source_move, source_actor)
        return

    var modifiers_value: Variant = target.get("timed_modifiers", [])
    var modifiers: Array = modifiers_value if modifiers_value is Array else []
    var current_action: int = int(target.get("action_serial", 0))

    for index: int in range(modifiers.size()):
        var modifier_value: Variant = modifiers[index]
        if not (modifier_value is Dictionary):
            continue

        var modifier: Dictionary = modifier_value
        if str(modifier.get("kind", "")) != kind:
            continue
        if str(modifier.get("source_move", "")) != source_move:
            continue

        var existing_multiplier: float = maxf(
            0.0001,
            float(modifier.get("multiplier", 1.0))
        )
        var incoming_multiplier: float = maxf(0.0001, multiplier)
        var merged_multiplier: float = incoming_multiplier

        # Same-direction reapplications keep the stronger magnitude while the
        # duration is refreshed. A rare direction change from the same move
        # replaces the old value with the new one instead of mixing both.
        if existing_multiplier > 1.0 and incoming_multiplier > 1.0:
            merged_multiplier = maxf(existing_multiplier, incoming_multiplier)
        elif existing_multiplier < 1.0 and incoming_multiplier < 1.0:
            merged_multiplier = minf(existing_multiplier, incoming_multiplier)

        modifier["multiplier"] = merged_multiplier
        modifier["source_actor"] = source_actor
        modifier["expires_after_action"] = current_action + TEMPO_EFFECT_ACTIONS
        modifiers[index] = modifier
        target["timed_modifiers"] = modifiers
        return

    super._add_timed_modifier(target, kind, multiplier, source_move, source_actor)


func _combined_timed_modifier(combatant: Dictionary, kind: String) -> float:
    var result: float = super._combined_timed_modifier(combatant, kind)
    if kind == "atb_cycle_mod":
        return minf(maxf(0.0001, result), TEMPO_SLOWDOWN_CAP)
    return result
