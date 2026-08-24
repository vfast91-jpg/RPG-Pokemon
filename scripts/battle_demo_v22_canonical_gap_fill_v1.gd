extends "res://scripts/battle_demo_phase_animation_fix_v1.gd"

# Canonical V22 gap layer.
#
# The V22 catalog contains ten canonical IDs that were absent from the inherited
# runtime packs. Their authoritative definitions live in the final 2026-08-23
# attack database. This layer injects those definitions into BOTH runtime and
# canonical dictionaries and owns only the mechanics that do not already have a
# central Timeflow implementation.
#
# Important design constraints preserved here:
# - no legacy alias replaces a canonical ID;
# - effect Aggro comes from actual effects, not invented flat values;
# - connected-hit follow-ups respect miss, immunity, protection and Delegator;
# - the existing central Status softcap/status modifier/healing-block systems are
#   reused wherever they already express the V22 rule.

const V22_GAP_MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v22_canonical_gap_10.json"
const V22_GAP_CONNECTED_CONFUSION_MOVES: Array[String] = ["axe_kick", "rock_climb"]
const V22_GAP_QUICK_GUARD_MOVE_ID: String = "quick_guard"
const V22_GAP_LAST_RESORT_MOVE_ID: String = "last_resort"

var _v22_gap_active_move_id: String = ""
var _v22_gap_target_snapshots: Dictionary = {}
var _v22_gap_quick_guard_by_side: Dictionary = {}
var _v22_gap_quick_guard_feedback_targets: Dictionary = {}
var _v22_gap_healing_wish_succeeded: bool = false


func _load_data() -> void:
    super._load_data()
    _v22_gap_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _v22_gap_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(V22_GAP_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("V22-Kanonik-Lückenpaket konnte nicht gelesen werden: " + V22_GAP_MOVE_PACK_PATH)
        return

    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("V22-Kanonik-Lückenpaket besitzt kein moves-Dictionary.")
        return

    var runtime_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var canonical_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_value if canonical_value is Dictionary else {}
    var resolved_ids: Array[String] = []

    for move_id_value: Variant in (entries_value as Dictionary).keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
        if not (move_value is Dictionary):
            continue
        runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
        canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)
        resolved_ids.append(move_id)

    data["moves"] = runtime_moves
    _canonical_pack["moves"] = canonical_moves
    _v22_gap_remove_resolved_data_gaps(resolved_ids)


func _v22_gap_remove_resolved_data_gaps(resolved_ids: Array[String]) -> void:
    var gaps_value: Variant = _canonical_pack.get("data_gaps", {})
    if not (gaps_value is Dictionary):
        return
    var gaps: Dictionary = gaps_value
    for key: String in ["missing_move_definitions", "runtime_uncalibrated_moves"]:
        var values_value: Variant = gaps.get(key, [])
        if not (values_value is Array):
            continue
        var values: Array = values_value
        for move_id: String in resolved_ids:
            values.erase(move_id)
        gaps[key] = values
    _canonical_pack["data_gaps"] = gaps


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["v22_gap_distinct_moves_used"] = []
    return combatant


func _start_battle() -> void:
    _v22_gap_quick_guard_by_side.clear()
    _v22_gap_quick_guard_feedback_targets.clear()
    super._start_battle()


func open_config() -> void:
    _v22_gap_quick_guard_by_side.clear()
    _v22_gap_quick_guard_feedback_targets.clear()
    super.open_config()


func _finish_opening_phase() -> void:
    super._finish_opening_phase()
    _v22_gap_quick_guard_by_side.clear()
    _v22_gap_quick_guard_feedback_targets.clear()


func _resolve_opening_phase() -> void:
    # General Timeflow Runde 0 is speed-ordered. V22 Rapidschutz is the explicit
    # exception: protection resolves in its own stage before ordinary offensive
    # priority/opening actions. Within the same stage the original speed order
    # remains unchanged.
    _clear_actions()
    _opening_choices.sort_custom(
        func(a: Variant, b: Variant) -> bool:
            if not (a is Dictionary) or not (b is Dictionary):
                return false
            var move_a: String = str((a as Dictionary).get("move_id", ""))
            var move_b: String = str((b as Dictionary).get("move_id", ""))
            var guard_a: bool = move_a == V22_GAP_QUICK_GUARD_MOVE_ID
            var guard_b: bool = move_b == V22_GAP_QUICK_GUARD_MOVE_ID
            if guard_a != guard_b:
                return guard_a

            var actor_a_value: Variant = (a as Dictionary).get("actor", {})
            var actor_b_value: Variant = (b as Dictionary).get("actor", {})
            if not (actor_a_value is Dictionary) or not (actor_b_value is Dictionary):
                return false
            var actor_a: Dictionary = actor_a_value
            var actor_b: Dictionary = actor_b_value
            var speed_a: float = float(actor_a.get("speed", 0.0))
            var speed_b: float = float(actor_b.get("speed", 0.0))
            if not is_equal_approx(speed_a, speed_b):
                return speed_a > speed_b
            var index_a: int = int(actor_a.get("index", 0))
            var index_b: int = int(actor_b.get("index", 0))
            if index_a != index_b:
                return index_a < index_b
            return str(actor_a.get("side", "")) == "player"
    )
    _resolve_opening_actions_async()


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        super._execute_move(actor, move_id)
        return

    if move_id == V22_GAP_LAST_RESORT_MOVE_ID and not _v22_gap_last_resort_ready(actor):
        _spawn_feedback_label(actor, "✖ ZUFLUCHT NICHT BEREIT", Color("d9a5a5"))
        _ad_execute_empty_action(actor, move_id, move)
        _refresh_cards()
        _check_end()
        return

    var previous_move_id: String = _v22_gap_active_move_id
    var previous_snapshots: Dictionary = _v22_gap_target_snapshots
    var previous_healing_wish: bool = _v22_gap_healing_wish_succeeded

    _v22_gap_active_move_id = move_id
    _v22_gap_quick_guard_feedback_targets.clear()
    _v22_gap_healing_wish_succeeded = false
    if V22_GAP_CONNECTED_CONFUSION_MOVES.has(move_id):
        _v22_gap_target_snapshots = _pika_target_snapshots(actor, move)
    else:
        _v22_gap_target_snapshots = {}

    var serial_before: int = int(actor.get("action_serial", 0))
    super._execute_move(actor, move_id)
    var action_completed: bool = int(actor.get("action_serial", 0)) > serial_before

    if action_completed and move_id != V22_GAP_LAST_RESORT_MOVE_ID:
        _v22_gap_record_distinct_move(actor, move_id)

    var post_resolution_changed: bool = false
    if (
        move_id == "axe_kick"
        and action_completed
        and not _v22_gap_any_connected_target()
        and bool(actor.get("alive", false))
    ):
        _ad_apply_fixed_self_cost(actor, 0.50, "💥 FEHLSCHLAG")
        post_resolution_changed = true

    if (
        move_id == "healing_wish"
        and action_completed
        and _v22_gap_healing_wish_succeeded
        and bool(actor.get("alive", false))
    ):
        _ad_self_ko(actor)
        post_resolution_changed = true

    _v22_gap_active_move_id = previous_move_id
    _v22_gap_target_snapshots = previous_snapshots
    _v22_gap_healing_wish_succeeded = previous_healing_wish

    if post_resolution_changed:
        _refresh_cards()
        _check_end()


func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == "single_ally":
        var selected_id: String = str(_zf_selected_target_id)
        if not selected_id.is_empty():
            for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
                if not (candidate_value is Dictionary):
                    continue
                var candidate: Dictionary = candidate_value
                if (
                    str(candidate.get("id", "")) == selected_id
                    and str(candidate.get("id", "")) != str(actor.get("id", ""))
                    and bool(candidate.get("alive", false))
                ):
                    return [candidate]
        for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
            if not (candidate_value is Dictionary):
                continue
            var candidate: Dictionary = candidate_value
            if (
                str(candidate.get("id", "")) != str(actor.get("id", ""))
                and bool(candidate.get("alive", false))
            ):
                return [candidate]
        return []
    return super._targets(actor, rule)


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    var move: Dictionary = _move_data(_v22_gap_active_move_id)
    if _v22_gap_quick_guard_blocks(actor, target, move):
        var predicted: int = super._damage(
            actor.duplicate(true),
            target.duplicate(true),
            power,
            move_type,
            category
        )
        _v22_gap_credit_quick_guard_prevention(target, predicted)
        _v22_gap_quick_guard_feedback(target)
        return 0
    return super._damage(actor, target, power, move_type, category)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var move: Dictionary = _move_data(_v22_gap_active_move_id)
    if _v22_gap_quick_guard_blocks(actor, target, move):
        _v22_gap_quick_guard_feedback(target)
        return 0.0

    var kind: String = str(mechanic.get("kind", ""))
    match kind:
        "v22_gap_quick_guard":
            return _v22_gap_activate_quick_guard(actor)
        "v22_gap_confusion_on_connected_hit":
            return _v22_gap_confusion_on_connected_hit(actor, target, mechanic)
        "v22_gap_soft_boiled":
            return _v22_gap_soft_boiled(actor)
        "v22_gap_healing_wish":
            return _v22_gap_healing_wish(actor, target)
        "v22_gap_tickle":
            return _v22_gap_tickle(actor, target)
        "v22_gap_heal_block":
            return _v22_gap_heal_block(actor, target, mechanic)
        _:
            return super._effect(actor, target, mechanic)


func _v22_gap_connected_entry(target: Dictionary) -> Dictionary:
    var target_id: String = str(target.get("id", ""))
    if target_id.is_empty():
        return {}
    var entry_value: Variant = _v22_gap_target_snapshots.get(target_id, {})
    return entry_value if entry_value is Dictionary else {}


func _v22_gap_target_connected(target: Dictionary) -> bool:
    var entry: Dictionary = _v22_gap_connected_entry(target)
    return not entry.is_empty() and _pika_snapshot_target_hit(entry)


func _v22_gap_any_connected_target() -> bool:
    for entry_value: Variant in _v22_gap_target_snapshots.values():
        if entry_value is Dictionary and _pika_snapshot_target_hit(entry_value):
            return true
    return false


func _v22_gap_confusion_on_connected_hit(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    var entry: Dictionary = _v22_gap_connected_entry(target)
    if entry.is_empty() or not _pika_snapshot_target_hit(entry):
        return 0.0

    # A hit absorbed by Delegator is a connected hit for Fersenkick's crash
    # condition, but the secondary confusion may not leak through even when the
    # same hit destroys that Delegator.
    if int(entry.get("substitute_hp", 0)) > 0:
        return 0.0
    if _bulba_substitute_blocks_effect(actor, target, {"kind": "status", "status": "confusion"}):
        return 0.0
    if not bool(target.get("alive", false)):
        return 0.0
    if randf() > clampf(float(mechanic.get("chance", 1.0)), 0.0, 1.0):
        return 0.0
    return super._effect(actor, target, {"kind": "status", "status": "confusion", "chance": 1.0})


func _v22_gap_activate_quick_guard(actor: Dictionary) -> float:
    if not opening_phase_active:
        _spawn_feedback_label(actor, "✖ NUR RUNDE 0", Color("d9a5a5"))
        return 0.0
    var side: String = str(actor.get("side", ""))
    if side.is_empty():
        return 0.0
    if _v22_gap_quick_guard_by_side.has(side):
        return 0.0
    _v22_gap_quick_guard_by_side[side] = {"source_id": str(actor.get("id", ""))}
    _spawn_feedback_label(actor, "🛡️ RAPIDSCHUTZ", Color("b8d9ff"))
    # Activation itself has no Aggro by V22; prevention is credited later.
    return 0.0


func _v22_gap_quick_guard_blocks(
    actor: Dictionary,
    target: Dictionary,
    move: Dictionary
) -> bool:
    if not opening_phase_active or move.is_empty():
        return false
    if str(actor.get("side", "")) == str(target.get("side", "")):
        return false

    var target_side: String = str(target.get("side", ""))
    if target_side.is_empty() or not _v22_gap_quick_guard_by_side.has(target_side):
        return false

    if _v22_gap_move_breaks_guard(move):
        _v22_gap_break_quick_guard(target_side, target)
        return false

    if int(move.get("priority", 0)) <= 0:
        return false

    var guard_value: Variant = _v22_gap_quick_guard_by_side.get(target_side, {})
    if guard_value is Dictionary:
        var source: Dictionary = _zf_find_combatant(str((guard_value as Dictionary).get("source_id", "")))
        if source.is_empty() or not bool(source.get("alive", false)):
            _v22_gap_quick_guard_by_side.erase(target_side)
            return false
    return true


func _v22_gap_move_breaks_guard(move: Dictionary) -> bool:
    if str(move.get("id", "")) == "feint":
        return true
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false
    for mechanic_value: Variant in mechanics_value:
        if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "db_break_protect":
            return true
    return false


func _v22_gap_break_quick_guard(side: String, target: Dictionary) -> void:
    if not _v22_gap_quick_guard_by_side.has(side):
        return
    _v22_gap_quick_guard_by_side.erase(side)
    _spawn_feedback_label(target, "🛡️ RAPIDSCHUTZ GEBROCHEN", Color("c8b7ef"))


func _v22_gap_quick_guard_feedback(target: Dictionary) -> void:
    var target_id: String = str(target.get("id", ""))
    if not target_id.is_empty() and _v22_gap_quick_guard_feedback_targets.has(target_id):
        return
    if not target_id.is_empty():
        _v22_gap_quick_guard_feedback_targets[target_id] = true
    _spawn_feedback_label(target, "🛡️ RAPIDSCHUTZ", Color("b8d9ff"))


func _v22_gap_credit_quick_guard_prevention(target: Dictionary, predicted_damage: int) -> void:
    var side: String = str(target.get("side", ""))
    var guard_value: Variant = _v22_gap_quick_guard_by_side.get(side, {})
    if not (guard_value is Dictionary):
        return
    var source: Dictionary = _zf_find_combatant(str((guard_value as Dictionary).get("source_id", "")))
    if source.is_empty() or not bool(source.get("alive", false)):
        return
    var prevented: int = mini(maxi(0, predicted_damage), maxi(0, int(target.get("hp", 0))))
    if prevented <= 0:
        return
    source["aggro"] = float(source.get("aggro", 0.0)) + float(prevented)


func _v22_gap_soft_boiled(actor: Dictionary) -> float:
    if _f40_heal_block_active(actor):
        _f40_heal_block_feedback(actor)
        return 0.0
    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var missing: int = maxi(0, max_hp - int(actor.get("hp", 0)))
    if missing <= 0:
        return 0.0
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var requested: int = maxi(0, int(round(float(max_hp) * ratio)))
    var healed: int = mini(missing, requested)
    if healed <= 0:
        return 0.0
    actor["hp"] = int(actor.get("hp", 0)) + healed
    _spawn_feedback_label(actor, "🥚 +" + str(healed) + " KP", Color("8fe39b"))
    return float(healed)


func _v22_gap_healing_wish(actor: Dictionary, target: Dictionary) -> float:
    if (
        target.is_empty()
        or not bool(target.get("alive", false))
        or str(target.get("side", "")) != str(actor.get("side", ""))
        or str(target.get("id", "")) == str(actor.get("id", ""))
    ):
        return 0.0

    var actual_heal: int = 0
    if not _f40_heal_block_active(target):
        var max_hp: int = maxi(1, int(target.get("max_hp", 1)))
        var missing: int = maxi(0, max_hp - int(target.get("hp", 0)))
        var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
        var fraction: float = minf(1.0, 2.0 * ratio)
        var requested: int = maxi(0, int(round(float(max_hp) * fraction)))
        actual_heal = mini(missing, requested)
        if actual_heal > 0:
            target["hp"] = int(target.get("hp", 0)) + actual_heal
            _spawn_feedback_label(target, "✨ +" + str(actual_heal) + " KP", Color("8fe39b"))
    elif int(target.get("hp", 0)) < int(target.get("max_hp", 1)):
        _f40_heal_block_feedback(target)

    var removed_major_status: bool = not str(target.get("major_status", "")).is_empty()
    if removed_major_status:
        target["major_status"] = ""
        target["paralyzed"] = false
        target["db_sleep_actions"] = 0
        _spawn_feedback_label(target, "✨ STATUS GEHEILT", Color("b9e2a8"))

    if actual_heal <= 0 and not removed_major_status:
        return 0.0

    _v22_gap_healing_wish_succeeded = true
    var support_aggro: float = 0.0
    if removed_major_status:
        support_aggro = float(target.get("max_hp", 1)) * F30_STATUS_CONTROL_HP_FRACTION
    return float(actual_heal) + support_aggro


func _v22_gap_tickle(actor: Dictionary, target: Dictionary) -> float:
    if _v22_gap_hostile_status_blocked(actor, target, "tickle"):
        return 0.0
    var source_name: String = "Spaßkanone"
    var total: float = 0.0
    total += _f30_apply_exact_modifier(
        actor, target, "outgoing_damage_mod", -1.0, source_name
    )
    total += _f30_apply_exact_modifier(
        actor, target, "incoming_damage_mod", -1.0, source_name
    )
    if total > 0.0:
        _spawn_feedback_label(target, "😄 ANGRIFF · VERTEIDIGUNG ↓ · 3 AKTIONEN", Color("d9b0a4"))
    return total


func _v22_gap_heal_block(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _v22_gap_hostile_status_blocked(actor, target, "healing_block"):
        return 0.0
    if _database_status_is_blocked(target, "healing_block"):
        return 0.0
    if _f40_heal_block_active(target):
        return 0.0

    var duration: int = maxi(1, int(mechanic.get("duration_actions", 3)))
    target["f40_heal_block_expires_before_serial"] = int(target.get("action_serial", 0)) + duration
    _spawn_feedback_label(target, "🚫 HEILUNG GESPERRT · " + str(duration) + " AKTIONEN", Color("d7b6df"))
    return float(target.get("max_hp", 1)) * F30_STATUS_CONTROL_HP_FRACTION


func _v22_gap_hostile_status_blocked(
    actor: Dictionary,
    target: Dictionary,
    status_id: String
) -> bool:
    if target.is_empty() or not bool(target.get("alive", false)):
        return true
    if str(actor.get("side", "")) == str(target.get("side", "")):
        return false
    if bool(target.get("protective_guard", false)):
        target["protective_guard"] = false
        _spawn_feedback_label(target, "🛡️ GESCHÜTZT", Color("b8d9ff"))
        return true
    if _bulba_substitute_blocks_effect(actor, target, {"kind": "status", "status": status_id}):
        return true
    return false


func _v22_gap_last_resort_ready(actor: Dictionary) -> bool:
    var available: Array[String] = _v22_gap_available_other_moves(actor)
    if available.is_empty():
        return false
    var required: int = mini(3, available.size())
    var used_value: Variant = actor.get("v22_gap_distinct_moves_used", [])
    if not (used_value is Array):
        return false
    var used: Array = used_value
    var used_available: int = 0
    for move_id: String in available:
        if used.has(move_id):
            used_available += 1
    return used_available >= required


func _v22_gap_available_other_moves(actor: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        return result
    for move_value: Variant in moves_value:
        var move_id: String = str(move_value)
        if (
            move_id.is_empty()
            or move_id == V22_GAP_LAST_RESORT_MOVE_ID
            or result.has(move_id)
            or not _runtime_has_move(move_id)
        ):
            continue
        result.append(move_id)
    return result


func _v22_gap_record_distinct_move(actor: Dictionary, move_id: String) -> void:
    if move_id.is_empty() or move_id == V22_GAP_LAST_RESORT_MOVE_ID:
        return
    var used_value: Variant = actor.get("v22_gap_distinct_moves_used", [])
    var used: Array = used_value if used_value is Array else []
    if not used.has(move_id):
        used.append(move_id)
    actor["v22_gap_distinct_moves_used"] = used
