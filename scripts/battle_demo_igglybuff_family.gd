extends "res://scripts/battle_demo_vulpix_family.gd"

# Fluffeluff -> Pummeluff -> Knuddeluff integration (Pokemon Timeflow).
# Loads the V7/V16 spreadsheet-derived family data and implements only the
# mechanics not already provided by the central battle runtime.

const IGGLYBUFF_SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_igglybuff_family_v1.json"
const IGGLYBUFF_MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_24_igglybuff_family.json"
const IGGLY_MIMIC_EXCLUDED: Array[String] = ["mimic", "copycat", "metronome", "sleep_talk"]
const IGGLY_PSYCHIC_NOISE_ACTIONS: int = 3

var _iggly_active_move_id: String = ""


func _load_data() -> void:
    super._load_data()
    _iggly_load_family_data()


func _iggly_load_family_data() -> void:
    var species_pack: Dictionary = _database_read_json_dictionary(IGGLYBUFF_SPECIES_PACK_PATH)
    var move_pack: Dictionary = _database_read_json_dictionary(IGGLYBUFF_MOVE_PACK_PATH)

    var runtime_moves_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_moves_value if runtime_moves_value is Dictionary else {}
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_moves_value if canonical_moves_value is Dictionary else {}
    var move_entries_value: Variant = move_pack.get("moves", {})
    var move_entries: Dictionary = move_entries_value if move_entries_value is Dictionary else {}
    for move_id_value: Variant in move_entries.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = move_entries.get(move_id_value, {})
        if move_value is Dictionary:
            runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
            canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)
    data["moves"] = runtime_moves
    _canonical_pack["moves"] = canonical_moves

    var species_entries_value: Variant = species_pack.get("species", {})
    var species_entries: Dictionary = species_entries_value if species_entries_value is Dictionary else {}
    var runtime_species_value: Variant = data.get("species", {})
    var runtime_species: Dictionary = runtime_species_value if runtime_species_value is Dictionary else {}
    var canonical_species_value: Variant = _canonical_pack.get("species", {})
    var canonical_species: Dictionary = canonical_species_value if canonical_species_value is Dictionary else {}
    for species_id_value: Variant in species_entries.keys():
        var species_id: String = str(species_id_value)
        var species_value: Variant = species_entries.get(species_id_value, {})
        if not (species_value is Dictionary):
            continue
        var source_species: Dictionary = (species_value as Dictionary).duplicate(true)
        canonical_species[species_id] = source_species
        runtime_species[species_id] = _canonical_species_runtime(source_species)
    data["species"] = runtime_species
    _canonical_pack["species"] = canonical_species

    if not species_ids.has("igglybuff"):
        species_ids.append("igglybuff")
    data["species_order"] = species_ids.duplicate()


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["iggly_mimic_copy_id"] = ""
    combatant["iggly_last_team_move"] = ""
    combatant["iggly_heal_block_actions"] = 0
    return combatant


func _prompt_player(actor: Dictionary) -> void:
    var original_moves_value: Variant = actor.get("moves", [])
    var original_moves: Array = original_moves_value.duplicate() if original_moves_value is Array else []
    actor["moves"] = _iggly_moves_with_mimic_replacement(actor, original_moves)
    super._prompt_player(actor)
    actor["moves"] = original_moves


func _enemy_act(actor: Dictionary) -> void:
    var original_moves_value: Variant = actor.get("moves", [])
    var original_moves: Array = original_moves_value.duplicate() if original_moves_value is Array else []
    actor["moves"] = _iggly_moves_with_mimic_replacement(actor, original_moves)
    super._enemy_act(actor)
    actor["moves"] = original_moves


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    var had_heal_block: bool = not actor.is_empty() and _iggly_heal_block_active(actor)
    var serial_before: int = int(actor.get("action_serial", 0)) if not actor.is_empty() else -1
    super._choose_wait()
    if actor.is_empty():
        return
    _iggly_record_team_move(actor, "__wait")
    if had_heal_block and int(actor.get("action_serial", 0)) > serial_before:
        _iggly_consume_heal_block_action(actor)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    var original_move: Dictionary = _move_data(move_id)
    if original_move.is_empty():
        super._execute_move(actor, move_id)
        return

    var outer_action: bool = _cleffa_indirect_call_depth <= 0
    var serial_before: int = int(actor.get("action_serial", 0))
    var had_heal_block: bool = outer_action and _iggly_heal_block_active(actor)
    var hp_before_all: Dictionary = _iggly_hp_snapshot()
    var actor_aggro_before: float = float(actor.get("aggro", 0.0))

    var move: Dictionary = original_move.duplicate(true)
    if move_id == "round" and outer_action and str(actor.get("iggly_last_team_move", "")) == "round":
        var round_runtime_value: Variant = move.get("runtime", {})
        var round_runtime: Dictionary = round_runtime_value if round_runtime_value is Dictionary else {}
        move["power"] = int(round_runtime.get("chained_power", 120))

    if move_id == "expanding_force" and _iggly_psychic_terrain_is_active() and _cleffa_is_grounded(actor):
        var force_runtime_value: Variant = move.get("runtime", {})
        var force_runtime: Dictionary = force_runtime_value if force_runtime_value is Dictionary else {}
        move["power"] = int(force_runtime.get("psychic_terrain_power", 120))
        move["target"] = "all_enemies"
        move["area"] = true

    var targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    var hp_before_targets: Dictionary = {}
    for target_value: Variant in targets:
        if target_value is Dictionary:
            var target: Dictionary = target_value
            hp_before_targets[str(target.get("id", ""))] = int(target.get("hp", 0))

    var moves_value: Variant = data.get("moves", {})
    if moves_value is Dictionary:
        (moves_value as Dictionary)[move_id] = move
        data["moves"] = moves_value

    _iggly_active_move_id = move_id
    super._execute_move(actor, move_id)
    _iggly_active_move_id = ""

    var restored_moves_value: Variant = data.get("moves", {})
    if restored_moves_value is Dictionary:
        (restored_moves_value as Dictionary)[move_id] = original_move
        data["moves"] = restored_moves_value

    _iggly_revert_blocked_healing(actor, hp_before_all, actor_aggro_before)

    var attempted: bool = _database_move_was_attempted(move_id)
    var action_consumed: bool = int(actor.get("action_serial", 0)) > serial_before
    var actual_damage: int = _iggly_total_actual_damage(targets, hp_before_targets)

    if attempted:
        match move_id:
            "covet":
                _iggly_apply_covet_heal(actor, actual_damage, original_move)
            "mimic":
                _iggly_apply_mimic(actor, targets)
            "psychic_noise":
                _iggly_apply_psychic_noise(actor, targets, hp_before_targets, original_move)

    if outer_action:
        if attempted:
            _iggly_record_team_move(actor, move_id)
        elif action_consumed:
            _iggly_record_team_move(actor, "__failed_action")
        if had_heal_block and action_consumed:
            _iggly_consume_heal_block_action(actor)

    _refresh_cards()
    _check_end()


func _iggly_moves_with_mimic_replacement(actor: Dictionary, source_moves: Array) -> Array:
    var copied_id: String = str(actor.get("iggly_mimic_copy_id", ""))
    if copied_id.is_empty() or not _runtime_has_move(copied_id):
        return source_moves.duplicate()
    var result: Array = []
    for move_value: Variant in source_moves:
        var move_id: String = str(move_value)
        var resolved_id: String = copied_id if move_id == "mimic" else move_id
        if not result.has(resolved_id):
            result.append(resolved_id)
    return result


func _iggly_record_team_move(actor: Dictionary, move_id: String) -> void:
    var team: Array = _team_for_side(str(actor.get("side", "")))
    for ally_value: Variant in team:
        if ally_value is Dictionary:
            (ally_value as Dictionary)["iggly_last_team_move"] = move_id


func _iggly_total_actual_damage(targets: Array, hp_before: Dictionary) -> int:
    var total: int = 0
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        var before: int = int(hp_before.get(target_id, int(target.get("hp", 0))))
        total += maxi(0, before - int(target.get("hp", 0)))
    return total


func _iggly_apply_covet_heal(actor: Dictionary, actual_damage: int, move: Dictionary) -> void:
    if actual_damage <= 0 or _iggly_heal_block_active(actor):
        if actual_damage > 0 and _iggly_heal_block_active(actor):
            _spawn_feedback_label(actor, "🔇 HEILUNG BLOCKIERT", Color("d9a5c4"))
        return
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var fraction: float = clampf(float(runtime.get("drain_fraction_actual_damage", 0.5)), 0.0, 1.0)
    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    if missing <= 0:
        return
    var requested: int = maxi(1, int(floor(float(actual_damage) * fraction)))
    var healed: int = mini(missing, requested)
    if healed <= 0:
        return
    actor["hp"] = int(actor.get("hp", 0)) + healed
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(healed)
    _spawn_feedback_label(actor, "🤲 +" + str(healed) + " KP", Color("8fe39b"))


func _iggly_apply_mimic(actor: Dictionary, targets: Array) -> void:
    if targets.is_empty() or not (targets[0] is Dictionary):
        return
    var target: Dictionary = targets[0]
    var copied_id: String = str(target.get("db_last_move", ""))
    if not _iggly_mimic_move_is_eligible(copied_id):
        _spawn_feedback_label(actor, "🎭 KEINE KOPIERBARE ATTACKE", Color("d9a5a5"))
        return
    actor["iggly_mimic_copy_id"] = copied_id
    actor["aggro"] = float(actor.get("aggro", 0.0)) + 4.0
    _spawn_feedback_label(actor, "🎭 " + str(_move_data(copied_id).get("name", copied_id)), Color("d8c5ef"))


func _iggly_mimic_move_is_eligible(move_id: String) -> bool:
    if move_id.is_empty() or move_id.begins_with("__") or IGGLY_MIMIC_EXCLUDED.has(move_id):
        return false
    if not _runtime_has_move(move_id):
        return false
    var move: Dictionary = _move_data(move_id)
    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary:
        var runtime: Dictionary = runtime_value
        if runtime.has("copycat_eligible") and not bool(runtime.get("copycat_eligible", true)):
            return false
    return true


func _iggly_apply_psychic_noise(actor: Dictionary, targets: Array, hp_before: Dictionary, move: Dictionary) -> void:
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var duration: int = maxi(1, int(runtime.get("heal_block_actions", IGGLY_PSYCHIC_NOISE_ACTIONS)))
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        var before: int = int(hp_before.get(target_id, int(target.get("hp", 0))))
        if int(target.get("hp", 0)) >= before:
            continue
        if _iggly_heal_block_active(target):
            continue
        target["iggly_heal_block_actions"] = duration
        actor["aggro"] = float(actor.get("aggro", 0.0)) + 3.0
        _spawn_feedback_label(target, "🔊 HEILSPERRE · " + str(duration) + " AKTIONEN", Color("d9a5c4"))


func _iggly_heal_block_active(target: Dictionary) -> bool:
    return int(target.get("iggly_heal_block_actions", 0)) > 0


func _iggly_consume_heal_block_action(target: Dictionary) -> void:
    var remaining: int = maxi(0, int(target.get("iggly_heal_block_actions", 0)) - 1)
    target["iggly_heal_block_actions"] = remaining
    if remaining <= 0:
        _spawn_feedback_label(target, "🔊 HEILSPERRE ENDET", Color("c9d8ef"))


func _iggly_hp_snapshot() -> Dictionary:
    var result: Dictionary = {}
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            result[str(candidate.get("id", ""))] = int(candidate.get("hp", 0))
    return result


func _iggly_revert_blocked_healing(actor: Dictionary, hp_before: Dictionary, actor_aggro_before: float) -> void:
    var blocked_same_side_healing: int = 0
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not _iggly_heal_block_active(candidate):
            continue
        var candidate_id: String = str(candidate.get("id", ""))
        var before: int = int(hp_before.get(candidate_id, int(candidate.get("hp", 0))))
        var after: int = int(candidate.get("hp", 0))
        if after <= before:
            continue
        var blocked: int = after - before
        candidate["hp"] = before
        if str(candidate.get("side", "")) == str(actor.get("side", "")):
            blocked_same_side_healing += blocked
        _spawn_feedback_label(candidate, "🔇 HEILUNG BLOCKIERT", Color("d9a5c4"))

    if blocked_same_side_healing > 0:
        actor["aggro"] = maxf(actor_aggro_before, float(actor.get("aggro", 0.0)) - float(blocked_same_side_healing))


func _iggly_psychic_terrain_is_active() -> bool:
    # Psychofeld itself is not yet part of the move database. The hook is
    # intentionally generic so the future terrain implementation can activate
    # Flächenmacht without changing this attack again.
    return str(get_meta("timeflow_terrain", "")) == "psychic"


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var heal_block: int = int(combatant.get("iggly_heal_block_actions", 0))
    if heal_block > 0:
        tokens.append("🔊 HEILSPERRE " + str(heal_block))
    return tokens
