extends RefCounted
class_name MoveTagLock

const STATE_KEY: String = "tf_move_tag_locks"


static func ensure_state(combatant: Dictionary) -> void:
    if not (combatant.get(STATE_KEY, {}) is Dictionary):
        combatant[STATE_KEY] = {}


static func apply(combatant: Dictionary, tag: String, duration_actions: int) -> void:
    ensure_state(combatant)
    var clean_tag: String = tag.strip_edges().to_lower()
    var duration: int = maxi(0, duration_actions)
    if clean_tag.is_empty() or duration <= 0:
        return
    var locks: Dictionary = combatant.get(STATE_KEY, {})
    locks[clean_tag] = int(combatant.get("action_serial", 0)) + duration
    combatant[STATE_KEY] = locks


static func remaining_actions(combatant: Dictionary, tag: String) -> int:
    ensure_state(combatant)
    var clean_tag: String = tag.strip_edges().to_lower()
    if clean_tag.is_empty():
        return 0
    var locks: Dictionary = combatant.get(STATE_KEY, {})
    if not locks.has(clean_tag):
        return 0
    return maxi(0, int(locks.get(clean_tag, 0)) - int(combatant.get("action_serial", 0)))


static func blocks(combatant: Dictionary, tag: String) -> bool:
    return remaining_actions(combatant, tag) > 0


static func move_has_tag(move: Dictionary, tag: String) -> bool:
    var clean_tag: String = tag.strip_edges().to_lower()
    if clean_tag.is_empty():
        return false
    var tags_value: Variant = move.get("tags", [])
    if tags_value is Array:
        for tag_value: Variant in tags_value:
            if str(tag_value).strip_edges().to_lower() == clean_tag:
                return true
    return false


static func blocks_move(combatant: Dictionary, move: Dictionary) -> bool:
    var tags_value: Variant = move.get("tags", [])
    if not (tags_value is Array):
        return false
    for tag_value: Variant in tags_value:
        if blocks(combatant, str(tag_value)):
            return true
    return false


static func prune(combatant: Dictionary) -> void:
    ensure_state(combatant)
    var locks: Dictionary = combatant.get(STATE_KEY, {})
    for tag_value: Variant in locks.keys():
        var tag: String = str(tag_value)
        if remaining_actions(combatant, tag) <= 0:
            locks.erase(tag)
    combatant[STATE_KEY] = locks
