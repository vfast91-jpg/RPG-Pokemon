extends RefCounted
class_name EndureRules


static func is_active(target: Dictionary) -> bool:
    return int(target.get("action_serial", 0)) < int(target.get("db_endure_expires_after_action", 0))


static func cap_damage(target: Dictionary, damage: int) -> int:
    if not is_active(target):
        return damage

    var allowed: int = maxi(0, int(target.get("hp", 0)) - 1)
    if damage <= allowed:
        return damage

    # Ausdauer gilt höchstens drei eigene Aktionen, rettet aber nur einmal.
    target["db_endure_expires_after_action"] = 0
    return allowed
