extends "res://scripts/battle_demo_v22_critical_support_integrity_v1.gd"

# Final V22 effective-speed integrity layer.
#
# Electro Ball compares the acting Pokemon's currently effective Speed with the
# target's currently effective Speed. The inherited implementation compared ATB
# charge rates (12 + 0.62 * Speed), which shifts the canonical 1x/2x/3x/4x
# boundaries. V22 explicitly counts paralysis and real tempo modifiers, while
# current ATB fill, knockback/pause and the RPG-AP recovery cycle do not count.


func _pika_effective_speed_rate(combatant: Dictionary) -> float:
    var effective_speed: float = maxf(0.0, float(combatant.get("speed", 10.0)))
    if bool(combatant.get("paralyzed", false)):
        effective_speed *= 0.5

    # atb_cycle_mod is the central representation of true temporary tempo
    # effects. AP recovery lives in combatant.cycle and is deliberately ignored.
    var tempo_multiplier: float = maxf(
        0.0001,
        _combined_timed_modifier(combatant, "atb_cycle_mod")
    )
    return maxf(0.0001, effective_speed / tempo_multiplier)
