extends RefCounted
class_name TeamBarrierState


static func break_opposing(actor: Dictionary, combatants: Array) -> int:
    var actor_side: String = str(actor.get("side", ""))
    var broken_count: int = 0
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if str(candidate.get("side", "")) == actor_side:
            continue
        if float(candidate.get("db_light_screen_reduction", 0.0)) > 0.0:
            broken_count += 1
        candidate["db_light_screen_reduction"] = 0.0
        candidate["db_light_screen_source_id"] = ""
        candidate["db_light_screen_expires_source_action"] = -1
    return broken_count
