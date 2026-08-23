extends "res://scripts/battle_demo_binding_feedback_fix_v1.gd"

# V22 charge / delayed-action integrity.
#
# The historical generic charge engine stored a concrete Pokémon id. V22's
# charge contracts lock the battlefield position for the moves below. A later
# occupant of that position is therefore the phase-2 target; the move must not
# silently retarget to current highest Aggro or keep following an old entity id.
# This layer also prevents phase-1 charge actions from playing an enemy-bound
# attack projectile before the actual damaging phase exists.

const V22_SLOT_LOCKED_CHARGE_MOVE_IDS: Array[String] = [
    "solar_beam",
    "dig",
    "focus_punch",
    "fly",
    "sky_attack",
    "solar_blade",
    "bounce",
    "dive",
    "phantom_force",
    "skull_bash"
]

const V22_SHORT_PREP_SLOT_LOCK_MOVE_IDS: Array[String] = [
    "vital_throw"
]

var _v22_executing_move_id: String = ""


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    var runtime_value: Variant = move.get("runtime", {}) if not move.is_empty() else {}
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var was_charged_shot: bool = str(actor.get("db_charge_move", "")) == move_id

    var pending_slot: Dictionary = {}
    if (
        not was_charged_shot
        and V22_SLOT_LOCKED_CHARGE_MOVE_IDS.has(move_id)
        and bool(runtime.get("charge_then_fire", false))
        and str(move.get("target", "")) == "enemy_highest_aggro"
    ):
        pending_slot = _v22_current_target_slot(actor, move)

    var previous_executing_move: String = _v22_executing_move_id
    _v22_executing_move_id = move_id
    super._execute_move(actor, move_id)
    _v22_executing_move_id = previous_executing_move

    if (
        not was_charged_shot
        and str(actor.get("db_charge_move", "")) == move_id
        and not pending_slot.is_empty()
    ):
        actor["v22_charge_target_side"] = str(pending_slot.get("side", ""))
        actor["v22_charge_target_index"] = int(pending_slot.get("index", -1))
        actor["v22_charge_target_original_id"] = str(pending_slot.get("id", ""))

    if was_charged_shot and str(actor.get("db_charge_move", "")) != move_id:
        _v22_clear_charge_slot(actor)

    if (
        bool(actor.get("ad_short_charge_resolving", false))
        and V22_SHORT_PREP_SLOT_LOCK_MOVE_IDS.has(move_id)
    ):
        _v22_clear_short_prep_slot(actor)


func _ad_begin_short_charge(
    actor: Dictionary,
    move_id: String,
    runtime: Dictionary
) -> void:
    if V22_SHORT_PREP_SLOT_LOCK_MOVE_IDS.has(move_id):
        var move: Dictionary = _move_data(move_id)
        var slot: Dictionary = _v22_current_target_slot(actor, move)
        if slot.is_empty():
            _v22_clear_short_prep_slot(actor)
        else:
            actor["v22_short_prep_move_id"] = move_id
            actor["v22_short_prep_target_side"] = str(slot.get("side", ""))
            actor["v22_short_prep_target_index"] = int(slot.get("index", -1))
            actor["v22_short_prep_target_original_id"] = str(slot.get("id", ""))
    super._ad_begin_short_charge(actor, move_id, runtime)


func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == "enemy_highest_aggro":
        var charged_move: String = str(actor.get("db_charge_move", ""))
        var resolving_charge: bool = (
            not charged_move.is_empty()
            and charged_move == _v22_executing_move_id
            and V22_SLOT_LOCKED_CHARGE_MOVE_IDS.has(charged_move)
        )
        if resolving_charge:
            return _v22_locked_slot_targets(
                actor,
                charged_move,
                str(actor.get("v22_charge_target_side", "")),
                int(actor.get("v22_charge_target_index", -1))
            )

        var short_move: String = str(actor.get("v22_short_prep_move_id", ""))
        if (
            bool(actor.get("ad_short_charge_resolving", false))
            and V22_SHORT_PREP_SLOT_LOCK_MOVE_IDS.has(short_move)
        ):
            return _v22_locked_slot_targets(
                actor,
                short_move,
                str(actor.get("v22_short_prep_target_side", "")),
                int(actor.get("v22_short_prep_target_index", -1))
            )

    return super._targets(actor, rule)


func _v22_current_target_slot(actor: Dictionary, move: Dictionary) -> Dictionary:
    var rule: String = str(move.get("target", "enemy_highest_aggro"))
    var targets: Array = super._targets(actor, rule)
    if targets.is_empty() or not (targets[0] is Dictionary):
        return {}
    var target: Dictionary = targets[0]
    return {
        "side": str(target.get("side", "")),
        "index": int(target.get("index", -1)),
        "id": str(target.get("id", ""))
    }


func _v22_locked_slot_targets(
    actor: Dictionary,
    move_id: String,
    target_side: String,
    target_index: int
) -> Array:
    if target_side.is_empty() or target_index < 0:
        return []
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue
        if str(candidate.get("side", "")) != target_side:
            continue
        if int(candidate.get("index", -1)) != target_index:
            continue
        if not _cf_target_reachable_by_move(candidate, move_id):
            return []
        return [candidate]
    return []


func _animate_move_emoji_once(
    actor: Dictionary,
    target: Dictionary,
    move_id: String,
    move: Dictionary
) -> void:
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var mechanics_value: Variant = move.get("mechanics", [])
    var empty_mechanics: bool = mechanics_value is Array and (mechanics_value as Array).is_empty()

    # Generic charge phase 1 is an action, not an attack launch. The sequence
    # engine temporarily strips power/mechanics for exactly this phase. Fly is
    # the one intentional visual exception: the inherited semi-invulnerable
    # layer converts its icon into a self/take-off animation.
    if (
        bool(runtime.get("charge_then_fire", false))
        and move.get("power", null) == null
        and empty_mechanics
        and str(actor.get("db_charge_move", "")) != move_id
    ):
        if str(runtime.get("timeflow_charge_state", "")) == "airborne_fly":
            super._animate_move_emoji_once(actor, target, move_id, move)
        return

    super._animate_move_emoji_once(actor, target, move_id, move)


func _v22_clear_charge_slot(actor: Dictionary) -> void:
    actor.erase("v22_charge_target_side")
    actor.erase("v22_charge_target_index")
    actor.erase("v22_charge_target_original_id")


func _v22_clear_short_prep_slot(actor: Dictionary) -> void:
    actor.erase("v22_short_prep_move_id")
    actor.erase("v22_short_prep_target_side")
    actor.erase("v22_short_prep_target_index")
    actor.erase("v22_short_prep_target_original_id")
