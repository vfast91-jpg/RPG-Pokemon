extends "res://scripts/battle_demo_v22_sequence_hit_integrity_v1.gd"

# Player-facing target marker cleanup.
#
# The target icon remains as a quick tactical cue, while the incoming-target
# count is intentionally hidden. The count is only presentation metadata; it
# does not multiply damage, Aggro, or any move effect.


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    for index: int in range(tokens.size()):
        if tokens[index].contains("ZIEL"):
            tokens[index] = "🎯 ZIEL"
    return tokens


func _roster_status_text(combatant: Dictionary, active: bool) -> String:
    var text: String = super._roster_status_text(combatant, active)
    var target_count: int = _incoming_target_count(combatant)
    if target_count > 0:
        text = text.replace("🎯×%d" % target_count, "🎯")
    return text
