extends "res://scripts/battle_demo_stage50_mirror_v1.gd"

# Gen-2 / V24 missing-move integration · block 01/05.
#
# Additive leaf layer for Eruption, Feenbrise, Schutztausch, Plage and Magieraum.
# Existing damage, targeting, binding, timed-modifier, Aggro and route systems
# remain authoritative. Only Timeflow-specific runtime state is owned here.

const V24_MOVE_PACK_PATH: String = "res://data/gen2_missing_moves_runtime_v24_05.json"
const V24_MAGIC_ROOM_DURATION_SECONDS: float = 50.0
const V24_DEFENSE_MODIFIER_KIND: String = "incoming_damage_mod"
const V24_MAGIC_ROOM_TIMED_KINDS: Array[String] = [
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod",
    # Forward-compatible names for the Statuswert attribute if/when a generic
    # timed Statuswert modifier is added to the central runtime.
    "status_value_mod",
    "status_mod",
    "special_mod"
]

var _v24_magic_room_remaining_seconds: float = 0.0
var _v24_active_move_id: String = ""
var _v24_followup_snapshots: Dictionary = {}


func _load_data() -> void:
    super._load_data()
    _v24_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _v24_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(V24_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("V24-Attackenpaket konnte nicht gelesen werden: " + V24_MOVE_PACK_PATH)
        return

    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("V24-Attackenpaket besitzt kein moves-Dictionary.")
        return

    var runtime_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var canonical_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_value if canonical_value is Dictionary else {}

    for move_id_value: Variant in (entries_value as Dictionary).keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
        if not (move_value is Dictionary):
            continue
        runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
        canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)

    data["moves"] = runtime_moves
    _canonical_pack["moves"] = canonical_moves


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var previous_move_id: String = _v24_active_move_id
    var previous_snapshots: Dictionary = _v24_followup_snapshots
    _v24_active_move_id = move_id
    _v24_followup_snapshots = {}

    var move: Dictionary = _move_data(move_id)
    if move_id == "infestation" and not move.is_empty():
        _v24_followup_snapshots = _pika_target_snapshots(actor, move)

    if move_id == "eruption" and not move.is_empty():
        var original: Dictionary = move.duplicate(true)
        var patched: Dictionary = move.duplicate(true)
        var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
        var current_hp: int = clampi(int(actor.get("hp", 0)), 0, max_hp)
        patched["power"] = maxi(
            1,
            int(floor(150.0 * float(current_hp) / float(max_hp)))
        )

        _v24_set_runtime_move(move_id, patched)
        super._execute_move(actor, move_id)
        _v24_set_runtime_move(move_id, original)
    else:
        super._execute_move(actor, move_id)

    _v24_active_move_id = previous_move_id
    _v24_followup_snapshots = previous_snapshots


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    # Plage may only start its binding after a genuinely connected hit. This is
    # the same hit-integrity contract already used by Sandgrab: actual Pokémon-
    # or Delegator-HP loss counts; miss, immunity and full protection do not.
    if (
        _v24_active_move_id == "infestation"
        and kind == "binding"
        and not _v24_infestation_connected(target)
    ):
        return 0.0

    match kind:
        "v24_guard_swap":
            return _v24_guard_swap(actor, target)
        "v24_magic_room":
            return _v24_toggle_magic_room(actor)
        _:
            return super._effect(actor, target, mechanic)


func _v24_infestation_connected(target: Dictionary) -> bool:
    var target_id: String = str(target.get("id", ""))
    if target_id.is_empty():
        return false
    var snapshot_value: Variant = _v24_followup_snapshots.get(target_id, {})
    if not (snapshot_value is Dictionary):
        return false
    return _pika_snapshot_target_hit(snapshot_value as Dictionary)


func _v24_guard_swap(actor: Dictionary, target: Dictionary) -> float:
    if actor.is_empty() or target.is_empty():
        return 0.0
    if not bool(actor.get("alive", false)) or not bool(target.get("alive", false)):
        return 0.0

    var actor_defense: Array = _v24_active_defense_modifiers(actor)
    var target_defense: Array = _v24_active_defense_modifiers(target)

    if actor_defense.is_empty() and target_defense.is_empty():
        _spawn_feedback_label(target, "🔄 KEINE DEF-ÄNDERUNGEN", Color("c8bfdc"))
        return 0.0

    var actor_before: float = _combined_timed_modifier(actor, V24_DEFENSE_MODIFIER_KIND)
    var target_before: float = _combined_timed_modifier(target, V24_DEFENSE_MODIFIER_KIND)

    _v24_replace_defense_modifiers(actor, target_defense)
    _v24_replace_defense_modifiers(target, actor_defense)

    var actor_after: float = _combined_timed_modifier(actor, V24_DEFENSE_MODIFIER_KIND)
    var target_after: float = _combined_timed_modifier(target, V24_DEFENSE_MODIFIER_KIND)

    _spawn_feedback_label(actor, "🔄 DEF GETAUSCHT", Color("d6c2ff"))
    _spawn_feedback_label(target, "🔄 DEF GETAUSCHT", Color("d6c2ff"))

    # Use the same 10-point effect scale as the central defense modifier path.
    # If Magieraum currently suppresses both states, the immediate effect is 0.
    return (
        absf(actor_after - actor_before)
        + absf(target_after - target_before)
    ) * 10.0


func _v24_active_defense_modifiers(combatant: Dictionary) -> Array:
    var result: Array = []
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return result

    var current_action: int = int(combatant.get("action_serial", 0))
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if str(modifier.get("kind", "")) != V24_DEFENSE_MODIFIER_KIND:
            continue

        var remaining: int = (
            int(modifier.get("expires_after_action", current_action))
            - current_action
        )
        if remaining <= 0:
            continue

        var transferred: Dictionary = modifier.duplicate(true)
        transferred["_v24_remaining_actions"] = remaining
        result.append(transferred)
    return result


func _v24_replace_defense_modifiers(combatant: Dictionary, replacements: Array) -> void:
    var kept: Array = []
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if not (modifier_value is Dictionary):
                continue
            var modifier: Dictionary = modifier_value
            if str(modifier.get("kind", "")) != V24_DEFENSE_MODIFIER_KIND:
                kept.append(modifier)

    var current_action: int = int(combatant.get("action_serial", 0))
    for replacement_value: Variant in replacements:
        if not (replacement_value is Dictionary):
            continue
        var replacement: Dictionary = (replacement_value as Dictionary).duplicate(true)
        var remaining: int = maxi(0, int(replacement.get("_v24_remaining_actions", 0)))
        replacement.erase("_v24_remaining_actions")
        if remaining <= 0:
            continue
        replacement["expires_after_action"] = current_action + remaining
        kept.append(replacement)

    combatant["timed_modifiers"] = kept


func _v24_magic_room_active() -> bool:
    return battle_active and _v24_magic_room_remaining_seconds > 0.0


func _v24_toggle_magic_room(actor: Dictionary) -> float:
    if _v24_magic_room_active():
        _v24_magic_room_remaining_seconds = 0.0
        _spawn_feedback_label(actor, "🔮 MAGIERAUM ENDET", Color("d7c4ff"))
        _set_log(
            "[b]MAGIERAUM[/b] · Temporäre Attributsänderungen wirken wieder; "
            + "ihre angehaltene Restdauer läuft weiter."
        )
        return 0.0

    _v24_magic_room_remaining_seconds = V24_MAGIC_ROOM_DURATION_SECONDS
    _spawn_feedback_label(actor, "🔮 MAGIERAUM · 50 s", Color("d7c4ff"))
    _set_log(
        "[b]MAGIERAUM[/b] · Temporäre Attributsänderungen beider Teams sind "
        + "für 50 aktive Kampfsekunden außer Kraft; ihre Restdauer ist angehalten."
    )
    return 0.0


func _combined_timed_modifier(combatant: Dictionary, kind: String) -> float:
    if _v24_magic_room_active() and V24_MAGIC_ROOM_TIMED_KINDS.has(kind):
        return 1.0
    return super._combined_timed_modifier(combatant, kind)


func _begin_counted_action(actor: Dictionary) -> void:
    if _v24_magic_room_active():
        _v24_freeze_attribute_durations_for_action(actor)
    super._begin_counted_action(actor)


func _v24_freeze_attribute_durations_for_action(combatant: Dictionary) -> void:
    var current_action: int = int(combatant.get("action_serial", 0))
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if not (modifier_value is Dictionary):
                continue
            var modifier: Dictionary = modifier_value
            if not V24_MAGIC_ROOM_TIMED_KINDS.has(str(modifier.get("kind", ""))):
                continue
            var expires: int = int(modifier.get("expires_after_action", current_action))
            if current_action < expires:
                modifier["expires_after_action"] = expires + 1

    # Some central accuracy effects are represented outside timed_modifiers.
    # Freeze their target-action duration as well and suppress them below.
    var accuracy_expires: int = int(combatant.get("db_incoming_accuracy_expires", 0))
    if current_action < accuracy_expires:
        combatant["db_incoming_accuracy_expires"] = accuracy_expires + 1


func _database_apply_incoming_accuracy_to_move(
    actor: Dictionary,
    temp_move: Dictionary
) -> void:
    if _v24_magic_room_active():
        return
    super._database_apply_incoming_accuracy_to_move(actor, temp_move)


func _process(delta: float) -> void:
    var room_clock_was_running: bool = (
        battle_active
        and not paused
        and _v24_magic_room_remaining_seconds > 0.0
    )

    super._process(delta)

    if not battle_active:
        _v24_magic_room_remaining_seconds = 0.0
        return
    if not room_clock_was_running or _v24_magic_room_remaining_seconds <= 0.0:
        return

    var previous: float = _v24_magic_room_remaining_seconds
    _v24_magic_room_remaining_seconds = maxf(
        0.0,
        _v24_magic_room_remaining_seconds - delta
    )
    if previous > 0.0 and _v24_magic_room_remaining_seconds <= 0.0:
        var anchor: Dictionary = _v24_first_living_combatant()
        if not anchor.is_empty():
            _spawn_feedback_label(anchor, "🔮 MAGIERAUM ENDET", Color("d7c4ff"))
        _set_log(
            "[b]MAGIERAUM[/b] · Temporäre Attributsänderungen wirken wieder; "
            + "ihre angehaltene Restdauer läuft weiter."
        )


func magic_room_remaining_seconds() -> float:
    return maxf(0.0, _v24_magic_room_remaining_seconds)


func _v24_first_living_combatant() -> Dictionary:
    for combatant_value: Variant in combatants:
        if combatant_value is Dictionary:
            var combatant: Dictionary = combatant_value
            if bool(combatant.get("alive", false)):
                return combatant
    return {}


func _v24_set_runtime_move(move_id: String, move: Dictionary) -> void:
    var moves_value: Variant = data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}
    moves[move_id] = move.duplicate(true)
    data["moves"] = moves
