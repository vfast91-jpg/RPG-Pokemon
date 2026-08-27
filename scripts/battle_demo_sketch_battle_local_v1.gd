extends "res://scripts/battle_demo_aggro_rules_final_v2.gd"

# Farbeagle / Nachahmer (Sketch): one battle-local move-pool copy.
#
# Nachahmer is a deliberate setup action: once per battle, Farbeagle copies all
# currently known, copyable moves of the enemy selected by the normal
# enemy_highest_aggro targeting rule. The copied moves remain available only for
# this battle. Nachahmer itself is consumed immediately after the attempt and is
# restored for the next battle.
#
# Important persistence rule: between battles a Smeargle is ALWAYS normalized
# back to its real base move pool (Sketch only). We do not rely only on the old
# temporary-copy marker, because route persistence can outlive/lose that marker
# while still retaining copied ids inside the normal `moves` array.
#
# This leaf also cleans legacy V23 route state where individual Sketch copies
# were persisted between encounters.

const SKETCH_MOVE_ID: String = "sketch"
const SKETCH_STATE_KEY: String = "v23_sketch_learned_moves"
const SKETCH_USED_KEY: String = "sketch_battle_used"
const SKETCH_SPECIES_ID: String = "smeargle"


func _load_data() -> void:
    super._load_data()
    _sketch_patch_move_text(data)
    _sketch_patch_move_text(_canonical_pack)


func route_new_member(species_id: String, level: int) -> Dictionary:
    var member: Dictionary = super.route_new_member(species_id, level)
    # Never seed a newly obtained Pokemon with battle-local/legacy Sketch state.
    member.erase(SKETCH_STATE_KEY)
    member.erase(SKETCH_USED_KEY)
    if species_id == SKETCH_SPECIES_ID:
        _sketch_reset_smeargle_between_battles(member)
    return member


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    # Old route saves can contain both the legacy copy list and those same move
    # ids in the normal move array. Let the inherited stack build normally, then
    # strip stale state and start a fresh once-per-battle Sketch charge.
    var legacy_copies: Array[String] = _v23_string_array(
        setup.get(SKETCH_STATE_KEY, [])
    )
    var legacy_used: bool = bool(setup.get(SKETCH_USED_KEY, false))
    var combatant: Dictionary = super._make_combatant(side, index, setup)

    if str(combatant.get("species_id", setup.get("species_id", ""))) == SKETCH_SPECIES_ID:
        # Strong boundary reset: even if the route state lost the temporary-copy
        # marker but retained copied ids in `moves`, none may enter a new battle.
        _sketch_reset_smeargle_between_battles(combatant)
    else:
        _sketch_clear_battle_state(combatant, legacy_copies, legacy_used)
        combatant[SKETCH_STATE_KEY] = []
        combatant[SKETCH_USED_KEY] = false
    return combatant


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not route_mode:
        return

    # The V23 ancestor can reload legacy/persisted move state after combatant
    # construction. Normalize Smeargle again after that reload so every new
    # encounter begins with exactly one available Sketch and zero old copies.
    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        if team_index < 0 or team_index >= _route_team_state.size():
            continue

        var state_value: Variant = _route_team_state[team_index]
        var combatant_value: Variant = player_team[local_index]
        if not (state_value is Dictionary) or not (combatant_value is Dictionary):
            continue

        var state: Dictionary = state_value
        var combatant: Dictionary = combatant_value
        var is_smeargle: bool = (
            str(combatant.get("species_id", "")) == SKETCH_SPECIES_ID
            or str(state.get("species_id", "")) == SKETCH_SPECIES_ID
        )

        if is_smeargle:
            _sketch_reset_smeargle_between_battles(combatant)
            _sketch_reset_smeargle_between_battles(state)
        else:
            var legacy_copies: Array[String] = _v23_string_array(
                state.get(SKETCH_STATE_KEY, [])
            )
            var legacy_used: bool = bool(state.get(SKETCH_USED_KEY, false))
            _sketch_clear_battle_state(combatant, legacy_copies, legacy_used)
            combatant[SKETCH_STATE_KEY] = []
            combatant[SKETCH_USED_KEY] = false
            state.erase(SKETCH_STATE_KEY)
            state.erase(SKETCH_USED_KEY)

        _route_team_state[team_index] = state


func _route_store_current_state() -> void:
    # Snapshot transient copies before the V23 ancestor writes combat state into
    # route state. The post-super Smeargle normalization below is deliberately
    # independent from this marker and is therefore safe even if the marker was
    # already lost by another persistence layer.
    var copies_by_team_index: Dictionary = {}
    var used_by_team_index: Dictionary = {}
    var smeargle_team_indices: Dictionary = {}

    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        if team_index < 0 or team_index >= _route_team_state.size():
            continue
        var combatant_value: Variant = player_team[local_index]
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        copies_by_team_index[team_index] = _v23_string_array(
            combatant.get(SKETCH_STATE_KEY, [])
        )
        used_by_team_index[team_index] = bool(combatant.get(SKETCH_USED_KEY, false))
        if str(combatant.get("species_id", "")) == SKETCH_SPECIES_ID:
            smeargle_team_indices[team_index] = true

    super._route_store_current_state()

    for team_index_value: Variant in used_by_team_index.keys():
        var team_index: int = int(team_index_value)
        if team_index < 0 or team_index >= _route_team_state.size():
            continue
        var state_value: Variant = _route_team_state[team_index]
        if not (state_value is Dictionary):
            continue

        var state: Dictionary = state_value
        var is_smeargle: bool = (
            bool(smeargle_team_indices.get(team_index, false))
            or str(state.get("species_id", "")) == SKETCH_SPECIES_ID
        )

        if is_smeargle:
            # Authoritative battle boundary: route state must never persist any
            # copied move, even when temporary bookkeeping keys are missing.
            _sketch_reset_smeargle_between_battles(state)
        else:
            var battle_copies: Array[String] = _v23_string_array(
                copies_by_team_index.get(team_index, [])
            )
            var battle_used: bool = bool(used_by_team_index.get(team_index, false))
            _sketch_clear_battle_state(state, battle_copies, battle_used)
            state.erase(SKETCH_STATE_KEY)
            state.erase(SKETCH_USED_KEY)

        _route_team_state[team_index] = state


func _v23_sketch(actor: Dictionary, target: Dictionary) -> float:
    if actor.is_empty() or target.is_empty() or not bool(actor.get("alive", false)):
        return 0.0

    # Safety guard. Nachahmer is normally removed from the move list immediately
    # after the first attempt, but this prevents a second use through any other
    # execution path in the same battle.
    if bool(actor.get(SKETCH_USED_KEY, false)):
        _spawn_feedback_label(actor, "🎨 BEREITS VERBRAUCHT", Color("d9a5a5"))
        return 0.0

    actor[SKETCH_USED_KEY] = true

    var actor_moves: Array[String] = _v23_string_array(actor.get("moves", []))
    var target_moves: Array[String] = _v23_string_array(target.get("moves", []))
    var temporary_copies: Array[String] = []

    # The move definition targets enemy_highest_aggro. Copy that target's whole
    # usable move pool instead of only its last action.
    for move_id: String in target_moves:
        if not _sketch_move_copyable_in_battle(move_id):
            continue
        if actor_moves.has(move_id):
            continue
        actor_moves.append(move_id)
        temporary_copies.append(move_id)

    actor_moves.erase(SKETCH_MOVE_ID)
    actor["moves"] = actor_moves
    actor[SKETCH_STATE_KEY] = temporary_copies

    if temporary_copies.is_empty():
        _spawn_feedback_label(actor, "🎨 NICHTS KOPIERBAR", Color("d9a5a5"))
        return 0.0

    _spawn_feedback_label(
        actor,
        "🎨 " + str(temporary_copies.size()) + " ATTACKEN KOPIERT",
        Color("d9c6ff")
    )
    return 4.0


func _sketch_move_copyable_in_battle(move_id: String) -> bool:
    if not _v23_sketch_copyable(move_id):
        return false
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return false
    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary:
        var runtime: Dictionary = runtime_value
        if runtime.has("normal_battle_available") and not bool(runtime.get("normal_battle_available", true)):
            return false
    return true


func _sketch_reset_smeargle_between_battles(holder: Dictionary) -> void:
    # Smeargle currently has no legitimate permanent move pool other than
    # Sketch. Therefore the safest battle boundary is an explicit canonical
    # reset instead of trying to reconstruct which ids were temporary.
    holder["moves"] = [SKETCH_MOVE_ID]
    holder[SKETCH_STATE_KEY] = []
    holder[SKETCH_USED_KEY] = false


func _sketch_clear_battle_state(
    holder: Dictionary,
    copied_ids: Array[String],
    was_used: bool = false
) -> void:
    var moves: Array[String] = _v23_string_array(holder.get("moves", []))
    for move_id: String in copied_ids:
        moves.erase(move_id)

    # A used Sketch is removed during battle. Restore it between battles even if
    # the chosen enemy happened to have zero copyable moves. The species check
    # also repairs old exhausted Farbeagle saves that lost Sketch permanently.
    var should_restore: bool = (
        was_used
        or not copied_ids.is_empty()
        or str(holder.get("species_id", "")) == SKETCH_SPECIES_ID
    )
    if should_restore and not moves.has(SKETCH_MOVE_ID):
        moves.insert(0, SKETCH_MOVE_ID)
    holder["moves"] = moves


func _sketch_patch_move_text(container: Dictionary) -> void:
    var moves_value: Variant = container.get("moves", {})
    if not (moves_value is Dictionary):
        return
    var moves: Dictionary = moves_value
    var sketch_value: Variant = moves.get(SKETCH_MOVE_ID, {})
    if not (sketch_value is Dictionary):
        return

    var sketch: Dictionary = (sketch_value as Dictionary).duplicate(true)
    sketch["description"] = (
        "Kopiert einmal pro Kampf alle kopierbaren Attacken des gegnerischen Pokémon mit der höchsten Aggro bis zum Kampfende."
    )
    sketch["ap"] = 7
    sketch["pp"] = 1
    sketch["target"] = "enemy_highest_aggro"
    sketch["special_rules"] = [
        "Nachahmer kann pro Kampf genau einmal eingesetzt werden und ist danach für diesen Kampf verbraucht.",
        "Beim Einsatz werden alle aktuell bekannten, im normalen Kampf nutzbaren und kopierbaren Attacken des Gegners mit der höchsten Aggro übernommen.",
        "Die kopierten Attacken gelten nur im aktuellen Kampf und verschwinden danach vollständig; im nächsten Kampf steht wieder nur Nachahmer bereit.",
        "Kopier-/Zufalls-/Meta-Attacken wie Nachahmer, Mimikry, Copycat, Metronom und Schlafrede sind nicht kopierbar."
    ]

    var tags: Array[String] = _v23_string_array(sketch.get("optional_tags", []))
    tags.erase("persistent_copy")
    tags.erase("battle_local_copy")
    if not tags.has("battle_local_move_pool_copy"):
        tags.append("battle_local_move_pool_copy")
    if not tags.has("once_per_battle"):
        tags.append("once_per_battle")
    sketch["optional_tags"] = tags

    var runtime_value: Variant = sketch.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true)
        if runtime_value is Dictionary else {}
    )
    runtime["v23_sketch"] = true
    runtime["battle_local_copy"] = true
    runtime["copy_all_target_moves"] = true
    runtime["once_per_battle"] = true
    sketch["runtime"] = runtime

    moves[SKETCH_MOVE_ID] = sketch
    container["moves"] = moves
