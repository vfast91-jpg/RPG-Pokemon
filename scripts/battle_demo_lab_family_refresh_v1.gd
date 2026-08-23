extends "res://scripts/battle_demo_endgame_v2.gd"

# Final combat-lab family registry refresh.
# Lower family layers append their route roots during _load_data(). The family
# lab itself sits below those layers in the inheritance chain, so its earlier
# snapshot can be stale by the time the UI is built. Refresh once at the very
# top after every family loader has finished.
#
# This is also the final target-Aggro guardrail. The historical base resolver
# halves Aggro after damage only, which misses pure status moves and also halves
# every damaged target of spread moves. At this top layer all family-specific
# move wrappers have finished, so we can normalize the final result against the
# actual resolved target selection without hard-coding individual moves.

const SingleTargetAggroRules = preload("res://scripts/battle/single_target_aggro_rules.gd")

var _single_target_aggro_context_stack: Array[Dictionary] = []


func _load_data() -> void:
    super._load_data()
    lab_species_ids = species_ids.duplicate()


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var context: Dictionary = {
        "actor_id": str(actor.get("id", "")),
        "move_id": move_id,
        "action_serial_before": int(actor.get("action_serial", 0)),
        "aggro_before": _single_target_aggro_snapshot(),
        "target_state_before": _single_target_aggro_state_hash_snapshot(),
        "fallback_target_ids": [],
        "fallback_rule": "",
        "fallback_move": {},
        "resolved_target_ids": [],
        "resolved_rule": "",
        "resolved_move": {},
        "explicit_miss": false
    }
    _single_target_aggro_context_stack.append(context)

    super._execute_move(actor, move_id)

    var resolved_context: Dictionary = _single_target_aggro_context_stack.pop_back()
    _single_target_aggro_finalize(actor, move_id, resolved_context)


func _targets(actor: Dictionary, rule: String) -> Array:
    var targets: Array = super._targets(actor, rule)
    if _single_target_aggro_context_stack.is_empty():
        return targets

    var context: Dictionary = _single_target_aggro_context_stack.back()
    if str(context.get("actor_id", "")) != str(actor.get("id", "")):
        return targets

    var target_ids: Array[String] = []
    for target_value: Variant in targets:
        if target_value is Dictionary:
            target_ids.append(str((target_value as Dictionary).get("id", "")))

    var tracked_move_id: String = str(context.get("move_id", ""))
    var move: Dictionary = _move_data(tracked_move_id).duplicate(true)

    # Keep the latest call as a fallback. During the real database resolution,
    # prefer the call made while the database move context is active. This is
    # what preserves manual targets (e.g. Angeberei) and runtime target changes
    # (e.g. a move becoming all_enemies only under a field condition).
    context["fallback_target_ids"] = target_ids
    context["fallback_rule"] = rule
    context["fallback_move"] = move

    var database_move_id: String = str(_database_move_id)
    var database_active_id: String = ""
    if _database_active_move is Dictionary:
        database_active_id = str((_database_active_move as Dictionary).get("id", ""))

    if database_move_id == tracked_move_id or database_active_id == tracked_move_id:
        context["resolved_target_ids"] = target_ids
        context["resolved_rule"] = rule
        context["resolved_move"] = move

    return targets


func _set_log(text: String) -> void:
    if (
        not _single_target_aggro_context_stack.is_empty()
        and text.to_lower().contains("verfehlt")
    ):
        var context: Dictionary = _single_target_aggro_context_stack.back()
        context["explicit_miss"] = true
    super._set_log(text)


func _single_target_aggro_snapshot() -> Dictionary:
    var result: Dictionary = {}
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        result[str(combatant.get("id", ""))] = float(combatant.get("aggro", 0.0))
    return result


func _single_target_aggro_state_hash_snapshot() -> Dictionary:
    var result: Dictionary = {}
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        result[str(combatant.get("id", ""))] = _single_target_aggro_state_hash(combatant)
    return result


func _single_target_aggro_state_hash(combatant: Dictionary) -> int:
    var state: Dictionary = combatant.duplicate(true)
    # Aggro itself is the value we are deciding whether to reduce. Excluding it
    # lets us detect whether a status/control move actually changed its target
    # instead of mistaking the legacy Aggro half for a successful effect.
    state.erase("aggro")
    return hash(state)


func _single_target_aggro_target_state_changed(
    target: Dictionary,
    context: Dictionary
) -> bool:
    var before_value: Variant = context.get("target_state_before", {})
    if not (before_value is Dictionary):
        return false
    var before: Dictionary = before_value
    var target_id: String = str(target.get("id", ""))
    if not before.has(target_id):
        return false
    return int(before.get(target_id, 0)) != _single_target_aggro_state_hash(target)


func _single_target_aggro_finalize(
    actor: Dictionary,
    move_id: String,
    context: Dictionary
) -> void:
    var target_ids_value: Variant = context.get("resolved_target_ids", [])
    var target_ids: Array = target_ids_value if target_ids_value is Array else []
    var resolved_rule: String = str(context.get("resolved_rule", ""))
    var move_value: Variant = context.get("resolved_move", {})
    var move: Dictionary = move_value if move_value is Dictionary else {}

    if target_ids.is_empty():
        target_ids_value = context.get("fallback_target_ids", [])
        target_ids = target_ids_value if target_ids_value is Array else []
        resolved_rule = str(context.get("fallback_rule", ""))
        move_value = context.get("fallback_move", {})
        move = move_value if move_value is Dictionary else {}

    if move.is_empty():
        move = _move_data(move_id).duplicate(true)
    if target_ids.is_empty():
        return

    var before_value: Variant = context.get("aggro_before", {})
    var aggro_before: Dictionary = before_value if before_value is Dictionary else {}
    var direct_damage: bool = SingleTargetAggroRules.is_direct_damage_move(move)
    var damage_resolution: bool = SingleTargetAggroRules.is_damage_resolution_move(move)
    var spread: bool = SingleTargetAggroRules.is_spread_move(move, resolved_rule)

    # Legacy base behavior already halves Aggro for every damaged target. Undo
    # exactly that legacy half for spread damage, including the important case
    # where only one valid target remains. Structurally it is still a spread move.
    # This applies to every spread target, including allies hit by all-others
    # moves such as Surf or Earthquake: area damage never receives target relief.
    if spread:
        if damage_resolution:
            for target_id_value: Variant in target_ids:
                var spread_target: Dictionary = _single_target_aggro_find(str(target_id_value))
                if spread_target.is_empty():
                    continue
                var spread_id: String = str(spread_target.get("id", ""))
                if not aggro_before.has(spread_id):
                    continue
                var old_aggro: float = float(aggro_before.get(spread_id, 0.0))
                var current_aggro: float = float(spread_target.get("aggro", 0.0))
                if is_equal_approx(
                    current_aggro,
                    old_aggro * SingleTargetAggroRules.TARGET_AGGRO_MULTIPLIER
                ):
                    spread_target["aggro"] = old_aggro
                    _refresh_cards()
        return

    # A true single-target action must resolve to exactly one concrete target.
    if target_ids.size() != 1:
        return
    var target: Dictionary = _single_target_aggro_find(str(target_ids[0]))
    if target.is_empty() or not SingleTargetAggroRules.is_hostile(actor, target):
        return

    var attempted: bool = _database_move_was_attempted(move_id)
    if not attempted:
        attempted = (
            int(actor.get("action_serial", 0))
            > int(context.get("action_serial_before", 0))
        )
    var outcome: String = str(actor.get("tf_last_move_outcome", ""))
    var explicit_miss: bool = bool(context.get("explicit_miss", false))
    var success: bool = SingleTargetAggroRules.should_reduce(
        move,
        actor,
        target,
        attempted,
        outcome,
        explicit_miss,
        resolved_rule
    )

    # For pure status/control moves and custom damage contracts without a normal
    # damage mechanic, a successful accuracy roll is not enough: the target must
    # actually have changed. This excludes e.g. failed Disable, Mimic/Psych Up
    # (which only change the user) and the cast step of Future Sight, while a
    # real Bitter Kiss/confusion/debuff or custom Night Shade hit still qualifies.
    if success and not direct_damage:
        success = _single_target_aggro_target_state_changed(target, context)

    var target_id: String = str(target.get("id", ""))
    var old_target_aggro: float = float(
        aggro_before.get(target_id, float(target.get("aggro", 0.0)))
    )
    var current_target_aggro: float = float(target.get("aggro", 0.0))
    var legacy_half: float = (
        old_target_aggro * SingleTargetAggroRules.TARGET_AGGRO_MULTIPLIER
    )

    if not success:
        # Damage immunity/protection or a custom no-effect path can still pass
        # through historical code that applied a half. A failed hit must never
        # keep that legacy Aggro relief.
        if damage_resolution and is_equal_approx(current_target_aggro, legacy_half):
            target["aggro"] = old_target_aggro
            _refresh_cards()
        return

    # Some older custom damage paths (notably Night Shade) already applied the
    # historical half themselves. Treat that as the one allowed reduction and
    # never halve a second time.
    if is_equal_approx(current_target_aggro, legacy_half):
        return

    if damage_resolution:
        if is_equal_approx(current_target_aggro, old_target_aggro):
            SingleTargetAggroRules.reduce(target)
            _refresh_cards()
        return

    # Pure status/debuff/control single-target moves were the original missing
    # case. Apply the global relief after the complete move resolution so the
    # target-changing effect has already finished before current Aggro is halved.
    SingleTargetAggroRules.reduce(target)
    _refresh_cards()


func _single_target_aggro_find(combatant_id: String) -> Dictionary:
    if combatant_id.is_empty():
        return {}
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if str(combatant.get("id", "")) == combatant_id:
            return combatant
    return {}


# Gegenstoß and Seher intentionally resolve damage outside the normal move
# resolver. Let the legacy implementation perform its special damage/state work,
# then normalize only its target-Aggro result through the same central rule.
func _bfam_resolve_payback_retaliation(defender: Dictionary, attacker: Dictionary) -> int:
    var aggro_before: float = float(attacker.get("aggro", 0.0))
    var damage: int = super._bfam_resolve_payback_retaliation(defender, attacker)
    if damage <= 0:
        return damage

    attacker["aggro"] = aggro_before
    if SingleTargetAggroRules.is_hostile(defender, attacker):
        SingleTargetAggroRules.reduce(attacker)
    _refresh_cards()
    return damage


func _cleffa_resolve_future_sight(event: Dictionary) -> void:
    var target: Dictionary = {}
    var target_team: Array = _team_for_side(str(event.get("target_side", "")))
    var slot: int = int(event.get("slot", -1))
    if slot >= 0 and slot < target_team.size() and target_team[slot] is Dictionary:
        target = target_team[slot]

    var hp_before: int = int(target.get("hp", 0)) if not target.is_empty() else 0
    var aggro_before: float = float(target.get("aggro", 0.0)) if not target.is_empty() else 0.0

    super._cleffa_resolve_future_sight(event)

    if target.is_empty():
        return
    var actual_damage: int = maxi(0, hp_before - int(target.get("hp", 0)))
    if actual_damage <= 0:
        return

    # The inherited special path already applied its historical half. Restore
    # the pre-impact value and let the canonical rule own the final reduction.
    target["aggro"] = aggro_before
    var snapshot_value: Variant = event.get("snapshot_actor", {})
    if not (snapshot_value is Dictionary):
        _refresh_cards()
        return
    var snapshot_actor: Dictionary = snapshot_value
    var move: Dictionary = _move_data("future_sight")
    if SingleTargetAggroRules.should_reduce(
        move,
        snapshot_actor,
        target,
        true,
        "success",
        false,
        "enemy_highest_aggro"
    ):
        SingleTargetAggroRules.reduce(target)
    _refresh_cards()


# Doppelteam's generated mechanics text was technically derived but very hard
# to understand in the infobox. The database contract is simple: enemy attacks
# against the user become less accurate for three of the user's own actions,
# with the strength scaling from the user's Statuswert. Present exactly that to
# the player instead of exposing AP/recovery math or the vague "Treffbarkeit".
func _move_tooltip(move: Dictionary) -> String:
    if str(move.get("id", "")) == "double_team":
        return (
            "👥 Doppelteam · Normal · Status · AP %s\n"
            + "Ziel: Anwender · Dauer: 3 eigene Aktionen\n"
            + "Gegnerische Attacken gegen den Anwender werden ungenauer. "
            + "Stärke abhängig vom Statuswert."
        ) % str(move.get("ap", 6))
    return super._move_tooltip(move)


func _compact_effect_summary(move: Dictionary) -> String:
    if str(move.get("id", "")) == "double_team":
        return "Gegnerische Genauigkeit gegen Anwender ↓ · 3 eigene Aktionen"
    return super._compact_effect_summary(move)
