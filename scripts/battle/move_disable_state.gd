extends RefCounted
class_name MoveDisableState

const STATE_KEY: String = "tf_disable_state"
const DEFAULT_DURATION_ACTIONS: int = 3


static func apply(combatant: Dictionary, move_id: String, duration_actions: int = DEFAULT_DURATION_ACTIONS) -> void:
    var clean_move_id: String = move_id.strip_edges()
    var duration: int = maxi(0, duration_actions)
    if clean_move_id.is_empty() or duration <= 0:
        clear(combatant)
        return

    combatant[STATE_KEY] = {
        "move_id": clean_move_id,
        "expires_at_action_serial": int(combatant.get("action_serial", 0)) + duration
    }


static func clear(combatant: Dictionary) -> void:
    combatant.erase(STATE_KEY)


static func active_state(combatant: Dictionary) -> Dictionary:
    var state_value: Variant = combatant.get(STATE_KEY, {})
    if not (state_value is Dictionary):
        clear(combatant)
        return {}

    var state: Dictionary = state_value
    var move_id: String = str(state.get("move_id", "")).strip_edges()
    var expires_at: int = int(state.get("expires_at_action_serial", -1))
    var current_action: int = int(combatant.get("action_serial", 0))
    if move_id.is_empty() or expires_at < 0 or current_action >= expires_at:
        clear(combatant)
        return {}

    return state.duplicate(true)


static func disabled_move_id(combatant: Dictionary) -> String:
    return str(active_state(combatant).get("move_id", ""))


static func remaining_actions(combatant: Dictionary) -> int:
    var state: Dictionary = active_state(combatant)
    if state.is_empty():
        return 0
    return maxi(
        0,
        int(state.get("expires_at_action_serial", 0)) - int(combatant.get("action_serial", 0))
    )


static func blocks_move_id(combatant: Dictionary, move_id: String) -> bool:
    var clean_move_id: String = move_id.strip_edges()
    return not clean_move_id.is_empty() and disabled_move_id(combatant) == clean_move_id


static func prune(combatant: Dictionary) -> void:
    active_state(combatant)
