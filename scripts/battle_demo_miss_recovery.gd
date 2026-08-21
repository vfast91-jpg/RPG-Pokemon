extends "res://scripts/battle_demo_bulbasaur_tm_runtime_audit.gd"

# Timeflow miss compensation.
# A missed move keeps its normal AP/ATB recovery calculation, then receives a
# 25% recovery bonus. The inherited base currently applies a 15% miss bonus;
# this final layer converts that existing result from x0.85 to the desired x0.75
# without discarding any other recovery multipliers that were already applied.

const MISS_ATB_RECOVERY_MULTIPLIER: float = 0.75
const INHERITED_MISS_ATB_RECOVERY_MULTIPLIER: float = 0.85

var _miss_detection_stack: Array[bool] = []


func _execute_move(actor: Dictionary, move_id: String) -> void:
    _miss_detection_stack.append(false)
    super._execute_move(actor, move_id)

    var missed: bool = false
    if not _miss_detection_stack.is_empty():
        missed = bool(_miss_detection_stack.pop_back())

    if not missed:
        return

    actor["cycle"] = (
        float(actor.get("cycle", 1.0))
        * MISS_ATB_RECOVERY_MULTIPLIER
        / INHERITED_MISS_ATB_RECOVERY_MULTIPLIER
    )
    _refresh_cards()


func _set_log(text: String) -> void:
    if (
        not _miss_detection_stack.is_empty()
        and text.contains(" verfehlt mit ")
    ):
        _miss_detection_stack[_miss_detection_stack.size() - 1] = true

    super._set_log(text)
