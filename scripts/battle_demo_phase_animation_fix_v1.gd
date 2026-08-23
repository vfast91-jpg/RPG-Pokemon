extends "res://scripts/battle_demo_pvp_active_v1.gd"

# Final presentation guard for preparation and delayed-effect moves.
# A setup phase must never look like an immediate hit on the selected enemy.
# It also suppresses the generic "KEIN EFFEKT" feedback when the move is
# intentionally preparing a later effect.

var _phase_feedback_context: Dictionary = {}


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    var previous_context: Dictionary = _phase_feedback_context
    var context: Dictionary = _phase_build_context(actor, move_id, move)
    _phase_feedback_context = context

    super._execute_move(actor, move_id)

    _phase_finish_context(actor, move_id, move, context)
    _phase_feedback_context = previous_context


func _phase_build_context(
    actor: Dictionary,
    move_id: String,
    move: Dictionary
) -> Dictionary:
    var context: Dictionary = {
        "kind": "",
        "move_id": move_id,
        "target": {},
        "future_match_count_before": 0
    }
    if move.is_empty():
        return context

    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if bool(runtime.get("timeflow_future_sight", false)):
        context["kind"] = "future_sight"
        var targets: Array = _targets(
            actor, str(move.get("target", "enemy_highest_aggro"))
        )
        if not targets.is_empty() and targets[0] is Dictionary:
            var target: Dictionary = targets[0]
            context["target"] = target
            context["future_match_count_before"] = _phase_future_sight_match_count(
                actor, target
            )
        return context

    if (
        bool(runtime.get("timeflow_meteor_beam", false))
        and not bool(actor.get("cleffa_meteor_beam_firing", false))
    ):
        context["kind"] = "charge"
        return context

    if (
        bool(runtime.get("charge_then_fire", false))
        and str(actor.get("db_charge_move", "")) != move_id
        and not _database_sun_is_active(runtime)
    ):
        context["kind"] = "charge"
        return context

    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            var mechanic_kind: String = str(
                (mechanic_value as Dictionary).get("kind", "")
            )
            if mechanic_kind == "f64_wish":
                context["kind"] = "wish"
                return context
            if mechanic_kind == "ad_yawn":
                context["kind"] = "delayed_status"
                return context
            if mechanic_kind == "ad_mirror_coat":
                context["kind"] = "preparation_stance"
                return context

    return context


func _phase_finish_context(
    actor: Dictionary,
    move_id: String,
    move: Dictionary,
    context: Dictionary
) -> void:
    var kind: String = str(context.get("kind", ""))
    if kind.is_empty():
        return

    var move_name: String = str(move.get("name", move_id))
    match kind:
        "future_sight":
            var target_value: Variant = context.get("target", {})
            if not (target_value is Dictionary):
                return
            var target: Dictionary = target_value
            var before_count: int = int(
                context.get("future_match_count_before", 0)
            )
            var after_count: int = _phase_future_sight_match_count(actor, target)
            if after_count > before_count:
                _spawn_feedback_label(target, "👁️ MARKIERT", Color("d2c7ff"))
                _set_log(
                    _actor_name(actor) + " nutzt [b]" + move_name
                    + "[/b]. Die gegnerische Position wurde markiert; "
                    + "der Angriff schlägt später dort ein."
                )
            else:
                _set_log(
                    _actor_name(actor) + " nutzt [b]" + move_name
                    + "[/b], aber diese Position ist bereits markiert."
                )
        "charge":
            var charging: bool = (
                str(actor.get("db_charge_move", "")) == move_id
                or (
                    move_id == "meteor_beam"
                    and bool(actor.get("cleffa_meteor_beam_charging", false))
                )
            )
            if charging:
                _set_log(
                    _actor_name(actor) + " lädt [b]" + move_name
                    + "[/b] auf. Noch findet kein Treffer statt."
                )
        "wish":
            if bool(actor.get("f64_wish_pending", false)):
                _set_log(
                    _actor_name(actor) + " bereitet [b]" + move_name
                    + "[/b] vor. Die Heilung erfolgt verzögert."
                )
        "delayed_status":
            _set_log(
                _actor_name(actor) + " nutzt [b]" + move_name
                + "[/b]. Die Wirkung tritt erst später ein."
            )
        "preparation_stance":
            _set_log(
                _actor_name(actor) + " geht mit [b]" + move_name
                + "[/b] in Bereitschaft."
            )


func _show_target_feedback(target: Dictionary, before: Dictionary) -> Dictionary:
    var kind: String = str(_phase_feedback_context.get("kind", ""))
    if not kind.is_empty():
        var feedback: Dictionary = _feedback_result(target, before)
        if str(feedback.get("text", "KEIN EFFEKT")) == "KEIN EFFEKT":
            # Intentional preparation is not a failed hit. Do not flash the
            # nominal target and do not display the misleading neutral label.
            return feedback
    return super._show_target_feedback(target, before)


func _is_charge_preparation(move: Dictionary) -> bool:
    if super._is_charge_preparation(move):
        return true
    if move.is_empty():
        return false

    var runtime_value: Variant = move.get("runtime", {})
    if not (runtime_value is Dictionary):
        return false
    var runtime: Dictionary = runtime_value
    if not bool(runtime.get("timeflow_meteor_beam", false)):
        return false

    var mechanics_value: Variant = move.get("mechanics", [])
    var mechanics_empty: bool = (
        not (mechanics_value is Array)
        or (mechanics_value as Array).is_empty()
    )
    return (
        move.get("power", null) == null
        and move.get("accuracy", null) == null
        and mechanics_empty
    )


func _animate_move_emoji_once(
    actor: Dictionary,
    target: Dictionary,
    move_id: String,
    move: Dictionary
) -> void:
    # Seher's cast only marks a position. Its normal projectile/hit animation
    # belongs to the delayed impact, not to the cast itself.
    if (
        move_id == "future_sight"
        and str(_phase_feedback_context.get("kind", "")) == "future_sight"
    ):
        return
    super._animate_move_emoji_once(actor, target, move_id, move)


func _cleffa_resolve_future_sight(event: Dictionary) -> void:
    var target_team: Array = _team_for_side(str(event.get("target_side", "")))
    var slot: int = int(event.get("slot", -1))
    if slot >= 0 and slot < target_team.size():
        var target_value: Variant = target_team[slot]
        if target_value is Dictionary:
            var target: Dictionary = target_value
            if bool(target.get("alive", false)):
                var snapshot_value: Variant = event.get("snapshot_actor", {})
                var visual_actor: Dictionary = (
                    snapshot_value as Dictionary
                    if snapshot_value is Dictionary
                    else target
                )
                var move: Dictionary = _move_data("future_sight")
                _visual_animated_targets.erase(str(target.get("id", "")))
                _animate_move_emoji_once(
                    visual_actor, target, "future_sight", move
                )
                _flash_combatant(target, Color("d2c7ff"))

    super._cleffa_resolve_future_sight(event)


func _f64_resolve_wish(actor: Dictionary) -> void:
    var hp_before: int = int(actor.get("hp", 0))
    var was_pending: bool = bool(actor.get("f64_wish_pending", false))
    super._f64_resolve_wish(actor)
    if was_pending and int(actor.get("hp", 0)) > hp_before:
        var move: Dictionary = _move_data("wish")
        _visual_animated_targets.erase(str(actor.get("id", "")))
        _animate_move_emoji_once(actor, actor, "wish", move)


func _phase_future_sight_match_count(
    actor: Dictionary,
    target: Dictionary
) -> int:
    if actor.is_empty() or target.is_empty():
        return 0
    var target_side: String = str(target.get("side", ""))
    var target_team: Array = _team_for_side(target_side)
    var slot: int = target_team.find(target)
    if slot < 0:
        return 0

    var count: int = 0
    for event_value: Variant in _cleffa_future_sight_events:
        if not (event_value is Dictionary):
            continue
        var event: Dictionary = event_value
        if (
            str(event.get("source_side", "")) == str(actor.get("side", ""))
            and str(event.get("target_side", "")) == target_side
            and int(event.get("slot", -1)) == slot
        ):
            count += 1
    return count
