extends "res://scripts/battle_demo_start_aggro_v1.gd"

# Vulpix -> Vulnona integration (Pokemon Timeflow).
# Loads the V6/V15 spreadsheet-derived family data and implements only the
# mechanics that are not already provided by the central battle runtime.
#
# Existing central systems are reused for:
# - confusion
# - burn
# - spread damage scaling
# - flinch ATB reset
# - normal damage/type/STAB/crit/aggro handling

const FlinchRules = preload("res://scripts/battle/flinch_rules.gd")
const VULPIX_SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_vulpix_family_v1.json"
const VULPIX_MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_23_vulpix_family.json"
const VULPIX_DISABLE_ACTIONS: int = 4
const VULPIX_MAJOR_STATUS_IDS: Array[String] = [
    "burn", "paralysis", "poison", "bad_poison", "toxic", "sleep", "freeze"
]

var _vulpix_active_move_id: String = ""


func _load_data() -> void:
    super._load_data()
    _vulpix_load_family_data()


func _vulpix_load_family_data() -> void:
    var species_pack: Dictionary = _database_read_json_dictionary(VULPIX_SPECIES_PACK_PATH)
    var move_pack: Dictionary = _database_read_json_dictionary(VULPIX_MOVE_PACK_PATH)

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

    if not species_ids.has("vulpix"):
        species_ids.append("vulpix")
    data["species_order"] = species_ids.duplicate()


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["vulpix_disabled_move_id"] = ""
    combatant["vulpix_disable_until_action"] = 0
    combatant["vulpix_last_successful_move_id"] = ""
    combatant["vulpix_attribute_raised_since_own_action"] = false
    return combatant


func _begin_counted_action(actor: Dictionary) -> void:
    # Neidflammen only cares about buffs received since this combatant's last
    # own action window. Starting a new own action closes that window.
    actor["vulpix_attribute_raised_since_own_action"] = false
    super._begin_counted_action(actor)


func _add_timed_modifier(
    target: Dictionary,
    kind: String,
    multiplier: float,
    source_move: String,
    source_actor: String
) -> void:
    super._add_timed_modifier(target, kind, multiplier, source_move, source_actor)

    # Map Timeflow's timed modifier representation back to the four core
    # attributes named by Neidflammen: Attack, Defense, Status, Speed.
    var raised_core_attribute: bool = false
    match kind:
        "outgoing_damage_mod":
            raised_core_attribute = multiplier > 1.0001
        "incoming_damage_mod":
            raised_core_attribute = multiplier < 0.9999
        "atb_cycle_mod":
            raised_core_attribute = multiplier < 0.9999
    if raised_core_attribute:
        target["vulpix_attribute_raised_since_own_action"] = true


func _choose_move(move_id: String) -> void:
    if not selected_actor.is_empty() and _vulpix_move_is_disabled(selected_actor, move_id):
        var move_name: String = str(_move_data(move_id).get("name", move_id))
        _set_log("🚫 [b]Aussetzer[/b] blockiert " + move_name + ". Wähle eine andere Attacke oder Warten.")
        _spawn_feedback_label(selected_actor, "🚫 AUSSETZER", Color("e6b1b1"))
        return
    super._choose_move(move_id)


func _enemy_act(actor: Dictionary) -> void:
    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        super._enemy_act(actor)
        return

    var original_moves: Array = (moves_value as Array).duplicate()
    var legal_moves: Array = []
    for move_value: Variant in original_moves:
        var move_id: String = str(move_value)
        if not _vulpix_move_is_disabled(actor, move_id):
            legal_moves.append(move_id)

    if legal_moves.is_empty():
        _begin_counted_action(actor)
        actor["aggro"] = float(actor.get("aggro", 0.0)) * 0.55
        actor["atb"] = 0.0
        actor["cycle"] = 0.70
        _expire_finished_modifiers(actor)
        _set_log(_actor_name(actor) + " wartet, weil Aussetzer die einzig verfügbare Attacke blockiert.")
        _refresh_cards()
        return

    actor["moves"] = legal_moves
    super._enemy_act(actor)
    actor["moves"] = original_moves


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if _vulpix_move_is_disabled(actor, move_id):
        _database_interrupt_forced_sequence(actor)
        _vulpix_consume_disabled_action(actor, move_id)
        return

    var original_move: Dictionary = _move_data(move_id)
    if original_move.is_empty():
        super._execute_move(actor, move_id)
        return

    var move: Dictionary = original_move.duplicate(true)
    var target_snapshot: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    var hp_before: Dictionary = {}
    var stats_before: Dictionary = {}
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        stats_before[str(candidate.get("id", ""))] = _vulpix_raw_core_stats(candidate)
    for target_value: Variant in target_snapshot:
        if target_value is Dictionary:
            var target: Dictionary = target_value
            hp_before[str(target.get("id", ""))] = int(target.get("hp", 0))

    if move_id == "hex" and not target_snapshot.is_empty() and target_snapshot[0] is Dictionary:
        var hex_target: Dictionary = target_snapshot[0]
        if _vulpix_has_major_status(hex_target):
            var hex_runtime_value: Variant = move.get("runtime", {})
            var hex_runtime: Dictionary = (
                hex_runtime_value if hex_runtime_value is Dictionary else {}
            )
            move["power"] = int(hex_runtime.get("status_power", 130))

    var moves_value: Variant = data.get("moves", {})
    if moves_value is Dictionary:
        (moves_value as Dictionary)[move_id] = move
        data["moves"] = moves_value

    _vulpix_active_move_id = move_id
    super._execute_move(actor, move_id)
    _vulpix_active_move_id = ""

    var restored_moves_value: Variant = data.get("moves", {})
    if restored_moves_value is Dictionary:
        (restored_moves_value as Dictionary)[move_id] = original_move
        data["moves"] = restored_moves_value

    _vulpix_mark_raw_stat_increases(stats_before)

    var attempted: bool = _database_move_was_attempted(move_id)
    var any_damage_hit: bool = _vulpix_any_target_damaged(target_snapshot, hp_before)
    var custom_success: bool = true

    if attempted:
        match move_id:
            "disable":
                custom_success = _vulpix_apply_disable(actor, target_snapshot)
            "extrasensory":
                _vulpix_apply_extrasensory_flinch(actor, target_snapshot, hp_before, original_move)
            "burning_jealousy":
                _vulpix_apply_burning_jealousy(actor, target_snapshot, hp_before)

    if attempted and custom_success and _vulpix_move_counts_as_success(original_move, any_damage_hit):
        actor["vulpix_last_successful_move_id"] = move_id

    _refresh_cards()
    _check_end()


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    if _vulpix_active_move_id != "foul_play":
        return super._damage(actor, target, power, move_type, category)

    var original_attack: Variant = actor.get("attack", 0)
    var original_modifiers_value: Variant = actor.get("timed_modifiers", [])
    var original_modifiers: Array = (
        (original_modifiers_value as Array).duplicate(true)
        if original_modifiers_value is Array
        else []
    )

    actor["attack"] = target.get("attack", original_attack)
    actor["timed_modifiers"] = _vulpix_foul_play_modifiers(original_modifiers, target)

    var damage: int = super._damage(actor, target, power, move_type, category)

    actor["attack"] = original_attack
    actor["timed_modifiers"] = original_modifiers
    return damage


func _vulpix_foul_play_modifiers(actor_modifiers: Array, target: Dictionary) -> Array:
    var result: Array = []
    for modifier_value: Variant in actor_modifiers:
        if modifier_value is Dictionary:
            var modifier: Dictionary = modifier_value
            if str(modifier.get("kind", "")) != "outgoing_damage_mod":
                result.append(modifier.duplicate(true))

    var target_modifiers_value: Variant = target.get("timed_modifiers", [])
    if target_modifiers_value is Array:
        for target_modifier_value: Variant in target_modifiers_value:
            if not (target_modifier_value is Dictionary):
                continue
            var target_modifier: Dictionary = target_modifier_value
            if str(target_modifier.get("kind", "")) == "outgoing_damage_mod":
                result.append(target_modifier.duplicate(true))
    return result


func _vulpix_apply_disable(actor: Dictionary, targets: Array) -> bool:
    if targets.is_empty() or not (targets[0] is Dictionary):
        return false
    var target: Dictionary = targets[0]

    if _vulpix_disable_is_active(target):
        _spawn_feedback_label(target, "🚫 BEREITS GESPERRT", Color("d9a5a5"))
        return false

    var last_move_id: String = str(target.get("vulpix_last_successful_move_id", ""))
    if last_move_id.is_empty() or _move_data(last_move_id).is_empty():
        _spawn_feedback_label(target, "✖ KEINE ATTACKE", Color("d9a5a5"))
        return false

    target["vulpix_disabled_move_id"] = last_move_id
    target["vulpix_disable_until_action"] = (
        int(target.get("action_serial", 0)) + VULPIX_DISABLE_ACTIONS
    )
    actor["aggro"] = float(actor.get("aggro", 0.0)) + 8.0
    _spawn_feedback_label(
        target,
        "🚫 " + str(_move_data(last_move_id).get("name", last_move_id)) + " · 4 AKTIONEN",
        Color("e6b1b1")
    )
    return true


func _vulpix_disable_is_active(target: Dictionary) -> bool:
    var move_id: String = str(target.get("vulpix_disabled_move_id", ""))
    if move_id.is_empty():
        return false
    if int(target.get("action_serial", 0)) >= int(target.get("vulpix_disable_until_action", 0)):
        target["vulpix_disabled_move_id"] = ""
        target["vulpix_disable_until_action"] = 0
        return false
    return true


func _vulpix_move_is_disabled(actor: Dictionary, move_id: String) -> bool:
    if move_id.is_empty() or not _vulpix_disable_is_active(actor):
        return false
    return move_id == str(actor.get("vulpix_disabled_move_id", ""))


func _vulpix_consume_disabled_action(actor: Dictionary, move_id: String) -> void:
    _begin_counted_action(actor)
    var move: Dictionary = _move_data(move_id)
    actor["atb"] = 0.0
    actor["cycle"] = _ap_cycle(int(move.get("ap", 1)))
    _expire_finished_modifiers(actor)
    _set_log(
        _actor_name(actor) + " kann [b]"
        + str(move.get("name", move_id))
        + "[/b] wegen Aussetzer nicht einsetzen."
    )
    _spawn_feedback_label(actor, "🚫 AUSSETZER", Color("e6b1b1"))
    _refresh_cards()


func _vulpix_apply_extrasensory_flinch(
    actor: Dictionary,
    targets: Array,
    hp_before: Dictionary,
    move: Dictionary
) -> void:
    var runtime_value: Variant = move.get("runtime", {})
    var chance: float = (
        float((runtime_value as Dictionary).get("timeflow_flinch_chance", 0.10))
        if runtime_value is Dictionary
        else 0.10
    )
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if not _vulpix_target_was_damaged(target, hp_before):
            continue
        if FlinchRules.apply(target, chance):
            actor["aggro"] = float(actor.get("aggro", 0.0)) + 3.0
            _spawn_feedback_label(target, "💫 ZURÜCKGESCHRECKT", Color("d7c9ff"))


func _vulpix_apply_burning_jealousy(
    actor: Dictionary,
    targets: Array,
    hp_before: Dictionary
) -> void:
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if (
            not _vulpix_target_was_damaged(target, hp_before)
            or not bool(target.get("vulpix_attribute_raised_since_own_action", false))
        ):
            continue
        var status_aggro: float = _effect(
            actor,
            target,
            {"kind": "status", "status": "burn", "chance": 1.0}
        )
        actor["aggro"] = float(actor.get("aggro", 0.0)) + status_aggro
        if status_aggro > 0.0:
            _spawn_feedback_label(target, "🔥 NEIDFLAMMEN", Color("ffad7d"))


func _vulpix_has_major_status(target: Dictionary) -> bool:
    var major_status: String = str(target.get("major_status", ""))
    if VULPIX_MAJOR_STATUS_IDS.has(major_status):
        return true
    # Compatibility with older combatants that still expose paralysis as a
    # dedicated boolean in addition to major_status.
    return bool(target.get("paralyzed", false))


func _vulpix_move_counts_as_success(move: Dictionary, any_damage_hit: bool) -> bool:
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "damage":
                return any_damage_hit
    return true


func _vulpix_any_target_damaged(targets: Array, hp_before: Dictionary) -> bool:
    for target_value: Variant in targets:
        if target_value is Dictionary and _vulpix_target_was_damaged(target_value as Dictionary, hp_before):
            return true
    return false


func _vulpix_target_was_damaged(target: Dictionary, hp_before: Dictionary) -> bool:
    var target_id: String = str(target.get("id", ""))
    if not hp_before.has(target_id):
        return false
    return int(target.get("hp", 0)) < int(hp_before.get(target_id, int(target.get("hp", 0))))


func _vulpix_raw_core_stats(target: Dictionary) -> Dictionary:
    return {
        "attack": float(target.get("attack", 0.0)),
        "defense": float(target.get("defense", 0.0)),
        "special": float(target.get("special", 0.0)),
        "speed": float(target.get("speed", 0.0))
    }


func _vulpix_mark_raw_stat_increases(before: Dictionary) -> void:
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        var candidate_id: String = str(candidate.get("id", ""))
        var old_value: Variant = before.get(candidate_id, {})
        if not (old_value is Dictionary):
            continue
        var old: Dictionary = old_value
        if (
            float(candidate.get("attack", 0.0)) > float(old.get("attack", 0.0)) + 0.0001
            or float(candidate.get("defense", 0.0)) > float(old.get("defense", 0.0)) + 0.0001
            or float(candidate.get("special", 0.0)) > float(old.get("special", 0.0)) + 0.0001
            or float(candidate.get("speed", 0.0)) > float(old.get("speed", 0.0)) + 0.0001
        ):
            candidate["vulpix_attribute_raised_since_own_action"] = true
