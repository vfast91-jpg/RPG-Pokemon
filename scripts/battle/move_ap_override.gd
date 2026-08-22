extends RefCounted
class_name MoveApOverride

const STATE_KEY: String = "tf_move_ap_override"


static func ensure_state(combatant: Dictionary) -> void:
    if not (combatant.get(STATE_KEY, {}) is Dictionary):
        combatant[STATE_KEY] = {}


static func apply(combatant: Dictionary, fixed_ap: int, duration_actions: int) -> void:
    ensure_state(combatant)
    var duration: int = maxi(0, duration_actions)
    if duration <= 0:
        combatant[STATE_KEY] = {}
        return
    combatant[STATE_KEY] = {
        "ap": clampi(fixed_ap, 1, 8),
        "expires_after_action": int(combatant.get("action_serial", 0)) + duration
    }


static func remaining_actions(combatant: Dictionary) -> int:
    ensure_state(combatant)
    var state: Dictionary = combatant.get(STATE_KEY, {})
    if state.is_empty():
        return 0
    return maxi(
        0,
        int(state.get("expires_after_action", 0)) - int(combatant.get("action_serial", 0))
    )


static func effective_ap(combatant: Dictionary, normal_ap: int) -> int:
    ensure_state(combatant)
    if remaining_actions(combatant) <= 0:
        return normal_ap
    var state: Dictionary = combatant.get(STATE_KEY, {})
    return clampi(int(state.get("ap", normal_ap)), 1, 8)


static func prune(combatant: Dictionary) -> void:
    ensure_state(combatant)
    if remaining_actions(combatant) <= 0:
        combatant[STATE_KEY] = {}
