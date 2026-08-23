extends RefCounted

# Central Timeflow rule for the Aggro relief of a successfully hit hostile
# single target. The actual battle layer owns resolution tracking; this helper
# owns only the invariant classification and multiplier.

const TARGET_AGGRO_MULTIPLIER: float = 0.5
const NON_SUCCESS_OUTCOMES: Array[String] = [
    "miss", "immune", "blocked", "failed", "skipped"
]


static func is_spread_move(move: Dictionary, resolved_target_rule: String = "") -> bool:
    var rule: String = resolved_target_rule
    if rule.is_empty():
        rule = str(move.get("target", "enemy_highest_aggro"))

    if bool(move.get("area", false)):
        return true
    if rule.begins_with("all_"):
        return true
    return rule in ["field", "battlefield", "all_active", "all_others"]


static func is_hostile(actor: Dictionary, target: Dictionary) -> bool:
    var actor_side: String = str(actor.get("side", ""))
    var target_side: String = str(target.get("side", ""))
    return (
        not actor_side.is_empty()
        and not target_side.is_empty()
        and actor_side != target_side
        and str(actor.get("id", "")) != str(target.get("id", ""))
    )


static func is_direct_damage_move(move: Dictionary) -> bool:
    for list_key: String in ["mechanics", "effects"]:
        var entries_value: Variant = move.get(list_key, [])
        if not (entries_value is Array):
            continue
        for entry_value: Variant in entries_value:
            if (
                entry_value is Dictionary
                and str((entry_value as Dictionary).get("kind", "")) == "damage"
            ):
                return true

    var power_value: Variant = move.get("power", null)
    if str(move.get("category", "")) == "status" or power_value == null:
        return false
    if power_value is int or power_value is float:
        return float(power_value) > 0.0
    if power_value is String and (power_value as String).is_valid_float():
        return float(power_value) > 0.0
    return false


static func resolved_successfully(
    attempted: bool,
    outcome: String,
    explicit_miss: bool
) -> bool:
    if not attempted or explicit_miss:
        return false
    return not NON_SUCCESS_OUTCOMES.has(outcome)


static func should_reduce(
    move: Dictionary,
    actor: Dictionary,
    target: Dictionary,
    attempted: bool,
    outcome: String,
    explicit_miss: bool,
    resolved_target_rule: String = ""
) -> bool:
    return (
        not is_spread_move(move, resolved_target_rule)
        and is_hostile(actor, target)
        and resolved_successfully(attempted, outcome, explicit_miss)
    )


static func reduce(target: Dictionary) -> void:
    target["aggro"] = float(target.get("aggro", 0.0)) * TARGET_AGGRO_MULTIPLIER
