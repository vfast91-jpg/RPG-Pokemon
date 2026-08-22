extends RefCounted
class_name MoveCategoryLock

# Generic Timeflow state for effects that temporarily forbid one move category.
# The state is action-serial based so Warten, normal attacks and every other
# counted own action shorten the duration through the same central clock used by
# other three-action effects.
const STATE_KEY: String = "tf_move_category_locks"


static func ensure_state(combatant: Dictionary) -> void:
    if not (combatant.get(STATE_KEY, null) is Dictionary):
        combatant[STATE_KEY] = {}


static func apply(combatant: Dictionary, category: String, duration_actions: int) -> void:
    if category.is_empty() or duration_actions <= 0:
        return
    ensure_state(combatant)
    var locks: Dictionary = combatant.get(STATE_KEY, {})
    locks[category] = int(combatant.get("action_serial", 0)) + duration_actions
    combatant[STATE_KEY] = locks


static func blocks(combatant: Dictionary, category: String) -> bool:
    return remaining_actions(combatant, category) > 0


static func remaining_actions(combatant: Dictionary, category: String) -> int:
    if category.is_empty():
        return 0
    ensure_state(combatant)
    var locks: Dictionary = combatant.get(STATE_KEY, {})
    var expires_after_action: int = int(locks.get(category, 0))
    return maxi(0, expires_after_action - int(combatant.get("action_serial", 0)))


static func prune(combatant: Dictionary) -> void:
    ensure_state(combatant)
    var locks: Dictionary = combatant.get(STATE_KEY, {})
    var current_action: int = int(combatant.get("action_serial", 0))
    var active: Dictionary = {}
    for category_value: Variant in locks.keys():
        var category: String = str(category_value)
        var expires_after_action: int = int(locks.get(category, 0))
        if current_action < expires_after_action:
            active[category] = expires_after_action
    combatant[STATE_KEY] = active
