extends "res://scripts/battle_demo_atb_pause_power_v1.gd"

# Canonical V22 low-HP variable-power rule shared by Gegenschlag and
# Dreschflegel. The spreadsheet contract uses exact percentage boundaries:
# 0-4% = 200, >4-10% = 150, >10-20% = 100, >20-35% = 80,
# >35-70% = 40, >70% = 20.
#
# Integer cross-multiplication deliberately avoids floating-point drift at the
# exact 4/10/20/35/70 percent boundaries.

func _v22_low_hp_power(actor: Dictionary) -> int:
    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var hp: int = clampi(int(actor.get("hp", 0)), 0, max_hp)
    var scaled_hp: int = hp * 100

    if scaled_hp <= max_hp * 4:
        return 200
    if scaled_hp <= max_hp * 10:
        return 150
    if scaled_hp <= max_hp * 20:
        return 100
    if scaled_hp <= max_hp * 35:
        return 80
    if scaled_hp <= max_hp * 70:
        return 40
    return 20


func _pika_reversal_power(actor: Dictionary) -> int:
    return _v22_low_hp_power(actor)


func _f30_flail_power(actor: Dictionary) -> int:
    return _v22_low_hp_power(actor)
