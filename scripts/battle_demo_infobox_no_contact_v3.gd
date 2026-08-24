extends "res://scripts/battle_demo_v22_effective_speed_integrity_v1.gd"

# Player-facing infobox refinement: contact is a combat-internal property and
# should not consume an extra presentation line. Other genuine special features
# (priority, Runde 0, area effects, etc.) remain visible.


func _standard_feature_bits(move: Dictionary) -> Array[String]:
    var bits: Array[String] = super._standard_feature_bits(move)
    bits.erase("Kontakt")
    return bits
