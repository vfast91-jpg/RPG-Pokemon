extends "res://scripts/battle_demo_charmander_family_weather.gd"

# Shared Timeflow rules for charge moves that temporarily leave the normal
# battlefield. Fly, Dig and the prepared Dive state all use the same contract:
# entering the hidden phase clears Aggro, normal target selection skips the
# user, and only explicitly supported counter-moves may still reach it.

const SEMI_INVULNERABLE_CHARGE_STATES: Array[String] = [
    "underground",
    "airborne_fly",
    "underwater"
]

var _semi_targeting_move_id: String = ""
var _semi_charge_visual_state: String = ""
var _semi_charge_visual_actor_id: String = ""


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    var runtime_value: Variant = move.get("runtime", {}) if not move.is_empty() else {}
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var charge_state: String = str(runtime.get("timeflow_charge_state", ""))
    var is_semi_charge: bool = (
        bool(runtime.get("charge_then_fire", false))
        and _semi_is_charge_state(charge_state)
    )
    var was_charged_shot: bool = str(actor.get("db_charge_move", "")) == move_id

    # No Aggro may survive the hidden phase. Clear it again immediately before
    # the stored attack fires, so only the actual second-step hit can create new
    # Aggro when the Pokémon returns to the battlefield.
    if is_semi_charge and was_charged_shot and _tf_has_state(actor, charge_state):
        actor["aggro"] = 0.0

    _semi_targeting_move_id = move_id
    if is_semi_charge and not was_charged_shot:
        _semi_charge_visual_state = charge_state
        _semi_charge_visual_actor_id = str(actor.get("id", ""))
    else:
        _semi_charge_visual_state = ""
        _semi_charge_visual_actor_id = ""

    super._execute_move(actor, move_id)

    # The charge sequence only sets db_charge_move after the preparation action
    # really succeeded. Reset Aggro at that point; failed/blocked preparations
    # therefore do not accidentally receive the hidden-state benefit.
    if (
        is_semi_charge
        and not was_charged_shot
        and str(actor.get("db_charge_move", "")) == move_id
        and _tf_has_state(actor, charge_state)
    ):
        actor["aggro"] = 0.0
        _refresh_cards()

    _semi_targeting_move_id = ""
    _semi_charge_visual_state = ""
    _semi_charge_visual_actor_id = ""


func _targets(actor: Dictionary, rule: String) -> Array:
    var move_id: String = _semi_current_move_id()
    if move_id.is_empty():
        return super._targets(actor, rule)

    if rule == "enemy_highest_aggro":
        # A charged attack keeps its originally locked target. If that target
        # has meanwhile entered an unreachable state, the stored attack has no
        # valid target instead of silently jumping to somebody else.
        if bool(actor.get("db_charge_firing", false)):
            return _semi_filter_reachable(actor, super._targets(actor, rule), move_id)

        # Redirect effects remain authoritative when their target is reachable.
        # An unreachable redirect target cannot trap normal attacks in the air.
        var redirected: Dictionary = _database_redirect_target(actor)
        if not redirected.is_empty() and _cf_target_reachable_by_move(redirected, move_id):
            return [redirected]

        var best: Dictionary = _semi_highest_reachable_aggro(actor, move_id)
        return [] if best.is_empty() else [best]

    return _semi_filter_reachable(actor, super._targets(actor, rule), move_id)


func _semi_filter_reachable(actor: Dictionary, targets: Array, move_id: String) -> Array:
    var filtered: Array = []
    var actor_side: String = str(actor.get("side", ""))
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        # Self/allied targets are not part of enemy Aggro selection and must not
        # be removed from support or field-wide ally mechanics.
        if str(target.get("side", "")) == actor_side:
            filtered.append(target)
            continue
        if _cf_target_reachable_by_move(target, move_id):
            filtered.append(target)
    return filtered


func _semi_highest_reachable_aggro(actor: Dictionary, move_id: String) -> Dictionary:
    var best: Dictionary = {}
    for candidate_value: Variant in _living_opponents(actor):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not _cf_target_reachable_by_move(candidate, move_id):
            continue
        if best.is_empty():
            best = candidate
            continue
        var candidate_aggro: float = float(candidate.get("aggro", 0.0))
        var best_aggro: float = float(best.get("aggro", 0.0))
        if candidate_aggro > best_aggro:
            best = candidate
        elif (
            is_equal_approx(candidate_aggro, best_aggro)
            and int(candidate.get("index", 0)) < int(best.get("index", 0))
        ):
            best = candidate
    return best


func _is_highest_aggro(combatant: Dictionary) -> bool:
    if not bool(combatant.get("alive", false)) or _semi_hidden_from_normal_targeting(combatant):
        return false

    var best: Dictionary = {}
    for candidate_value: Variant in _team_for_side(str(combatant.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)) or _semi_hidden_from_normal_targeting(candidate):
            continue
        if best.is_empty():
            best = candidate
            continue
        var candidate_aggro: float = float(candidate.get("aggro", 0.0))
        var best_aggro: float = float(best.get("aggro", 0.0))
        if candidate_aggro > best_aggro:
            best = candidate
        elif (
            is_equal_approx(candidate_aggro, best_aggro)
            and int(candidate.get("index", 0)) < int(best.get("index", 0))
        ):
            best = candidate

    return (
        not best.is_empty()
        and str(best.get("id", "")) == str(combatant.get("id", ""))
    )


func _animate_move_emoji_once(
    actor: Dictionary,
    target: Dictionary,
    move_id: String,
    move: Dictionary
) -> void:
    if (
        not _semi_charge_visual_state.is_empty()
        and str(actor.get("id", "")) == _semi_charge_visual_actor_id
    ):
        # Fly's first step is a take-off, not an attack projectile. Reuse the
        # existing self animation so the wing icon rises above the user. Dig and
        # the future Dive preparation intentionally show no enemy-bound icon.
        if _semi_charge_visual_state == "airborne_fly":
            super._animate_move_emoji_once(actor, actor, move_id, move)
        return
    super._animate_move_emoji_once(actor, target, move_id, move)


func _semi_current_move_id() -> String:
    if not _semi_targeting_move_id.is_empty():
        return _semi_targeting_move_id
    return _cf_current_move_id()


func _semi_hidden_from_normal_targeting(combatant: Dictionary) -> bool:
    for state: String in SEMI_INVULNERABLE_CHARGE_STATES:
        if _tf_has_state(combatant, state):
            return true
    return false


func _semi_is_charge_state(state: String) -> bool:
    return SEMI_INVULNERABLE_CHARGE_STATES.has(state)
