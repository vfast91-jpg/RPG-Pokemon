extends "res://scripts/battle_demo_infobox_final_v2.gd"

# Player-facing infobox refinement: contact is a combat-internal property and
# should not consume an extra presentation line. Other genuine special features
# (priority, Runde 0, area effects, etc.) remain visible.


func _standard_feature_bits(move: Dictionary) -> Array[String]:
    var bits: Array[String] = super._standard_feature_bits(move)
    bits.erase("Kontakt")
    return bits
