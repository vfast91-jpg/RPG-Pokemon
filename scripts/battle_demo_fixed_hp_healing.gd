extends "res://scripts/battle_demo_status_softcaps.gd"

# Central fixed-Max-HP healing bridge.
# KP healing is deliberately independent of the Status soft-cap curve whenever
# the move contract supplies fraction_max_hp. This keeps healing meaningful at
# every level because Max-KP itself already scales with level.

func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if (
        str(mechanic.get("kind", "")) == "db_heal_self"
        and mechanic.has("fraction_max_hp")
    ):
        var missing: int = maxi(
            0,
            int(actor.get("max_hp", 1)) - int(actor.get("hp", 0))
        )
        if missing <= 0:
            return 0.0
        var fraction: float = clampf(float(mechanic.get("fraction_max_hp", 0.0)), 0.0, 1.0)
        if fraction <= 0.0:
            return 0.0
        var requested: int = maxi(
            1,
            int(round(float(actor.get("max_hp", 1)) * fraction))
        )
        var healed: int = mini(missing, requested)
        actor["hp"] = int(actor.get("hp", 0)) + healed
        _spawn_feedback_label(actor, "💚 +" + str(healed) + " KP", Color("8fe39b"))
        return float(healed)
    return super._effect(actor, target, mechanic)
