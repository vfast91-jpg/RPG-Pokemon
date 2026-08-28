extends "res://scripts/battle_demo_gen3_moves_v1.gd"

# Gen-3 attack integration · spreadsheet entries 06–26.
# Additive layer: the first five Gen-3 moves remain owned by v1 and are never redefined here.

const GEN3_V2_MOVE_PACK_PATH: String = "res://data/gen3_moves_runtime_v2.json"
const Gen3MoveDisableState = preload("res://scripts/battle/move_disable_state.gd")

const GEN3_V2_COPY_MODIFIER_KINDS: Array[String] = [
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod",
    "status_value_mod",
    "status_mod",
    "special_mod",
]


func _load_data() -> void:
    super._load_data()
    _gen3_v2_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _gen3_v2_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(GEN3_V2_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("Gen-3-V2-Attackenpaket konnte nicht gelesen werden: " + GEN3_V2_MOVE_PACK_PATH)
        return

    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("Gen-3-V2-Attackenpaket besitzt kein moves-Dictionary.")
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


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["gen3_v2_grudge_armed"] = false
    combatant["gen3_v2_metal_burst_armed"] = false
    combatant["gen3_v2_mind_reader_armed"] = false
    combatant["gen3_v2_spiky_shield_armed"] = false
    combatant["gen3_v2_simple_beam_expires_action"] = 0
    if setup.has("weight_kg"):
        combatant["gen3_v2_battle_weight_kg"] = maxf(0.1, float(setup.get("weight_kg", 0.1)))
    elif setup.has("weight"):
        combatant["gen3_v2_battle_weight_kg"] = maxf(0.1, float(setup.get("weight", 0.1)))
    return combatant


func _begin_counted_action(actor: Dictionary) -> void:
    # These reactive states expire immediately before the owner's next counted action.
    actor["gen3_v2_grudge_armed"] = false
    actor["gen3_v2_metal_burst_armed"] = false
    super._begin_counted_action(actor)


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    super._choose_wait()
    if actor.is_empty():
        return
    actor["gen3_v2_grudge_armed"] = false
    actor["gen3_v2_metal_burst_armed"] = false
    actor["gen3_v2_mind_reader_armed"] = false


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var resolved_move_id: String = _tf_resolved_move_id(actor, move_id)
    var move: Dictionary = _move_data(resolved_move_id)
    if move.is_empty():
        super._execute_move(actor, move_id)
        return

    var before_log: String = log_label.get_parsed_text() if log_label != null else ""
    var targets_before: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    var hit_snapshots: Dictionary = {}
    if _gen3_v2_needs_connected_hit_snapshot(resolved_move_id):
        hit_snapshots = _pika_target_snapshots(actor, move)

    var hp_before: Dictionary = _gen3_v2_hp_snapshots()
    var attacking_move: bool = _gen3_v2_is_damaging_move(move)
    var contact_move: bool = bool(move.get("contact", false))

    var original_move: Dictionary = move.duplicate(true)
    var patched_move: Dictionary = move.duplicate(true)
    var patched: bool = false

    if resolved_move_id == "power_trip":
        patched_move["power"] = 20 + 20 * _gen3_v2_positive_attribute_count(actor)
        patched = true
    elif resolved_move_id == "water_spout":
        var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
        var current_hp: int = clampi(int(actor.get("hp", 0)), 0, max_hp)
        patched_move["power"] = maxi(1, int(floor(150.0 * float(current_hp) / float(max_hp))))
        patched = true

    var mind_reader_was_armed: bool = bool(actor.get("gen3_v2_mind_reader_armed", false))
    if mind_reader_was_armed and attacking_move:
        # Finte and Willensleser both skip the ordinary accuracy/evasion gate only.
        patched_move["accuracy"] = null
        patched = true

    if patched:
        _gen3_v2_set_runtime_move(resolved_move_id, patched_move)

    super._execute_move(actor, move_id)

    if patched:
        _gen3_v2_set_runtime_move(resolved_move_id, original_move)

    var successful_use: bool = _tf_move_was_successfully_used(resolved_move_id, move, before_log)
    var missed: bool = _tf_move_was_missed(resolved_move_id, move, before_log)

    # Willensleser lasts through exactly the next own action. A status action does
    # not consume it as a damage move, but the effect still expires after that action.
    if mind_reader_was_armed and resolved_move_id != "mind_reader":
        actor["gen3_v2_mind_reader_armed"] = false

    match resolved_move_id:
        "autotomize":
            if successful_use:
                _gen3_v2_autotomize(actor)
        "dragon_ascent":
            if _gen3_v2_any_connected(hit_snapshots):
                _gen3_v2_apply_modifier(actor, actor, "incoming_damage_mod", 1.25)
        "entrainment":
            if successful_use:
                for target_value: Variant in targets_before:
                    if target_value is Dictionary:
                        _gen3_v2_copy_timed_modifiers(actor, target_value as Dictionary)
        "grudge":
            if successful_use:
                actor["gen3_v2_grudge_armed"] = true
        "luster_purge":
            if _gen3_v2_any_connected(hit_snapshots) and randf() <= 0.50:
                for target_value: Variant in targets_before:
                    if target_value is Dictionary and _gen3_v2_target_connected(hit_snapshots, target_value as Dictionary):
                        _gen3_v2_apply_modifier(actor, target_value as Dictionary, "incoming_damage_mod", 1.0)
        "metal_burst":
            if successful_use:
                actor["gen3_v2_metal_burst_armed"] = true
        "mind_reader":
            if successful_use:
                actor["gen3_v2_mind_reader_armed"] = true
        "mist_ball":
            if _gen3_v2_any_connected(hit_snapshots) and randf() <= 0.50:
                for target_value: Variant in targets_before:
                    if target_value is Dictionary and _gen3_v2_target_connected(hit_snapshots, target_value as Dictionary):
                        _gen3_v2_apply_modifier(actor, target_value as Dictionary, "outgoing_damage_mod", -1.0)
        "noble_roar":
            if successful_use:
                for target_value: Variant in targets_before:
                    if target_value is Dictionary:
                        _gen3_v2_apply_modifier(actor, target_value as Dictionary, "outgoing_damage_mod", -1.25)
        "psycho_boost":
            if _gen3_v2_any_connected(hit_snapshots):
                _gen3_v2_apply_modifier(actor, actor, "outgoing_damage_mod", -1.25)
        "simple_beam":
            if successful_use:
                for target_value: Variant in targets_before:
                    if target_value is Dictionary:
                        var target: Dictionary = target_value as Dictionary
                        target["gen3_v2_simple_beam_expires_action"] = int(target.get("action_serial", 0)) + 3
        "tail_glow":
            if successful_use:
                _gen3_v2_apply_modifier(actor, actor, "outgoing_damage_mod", 1.50)
        _:
            pass

    if attacking_move:
        _gen3_v2_resolve_grudge(actor, resolved_move_id, hp_before)
        _gen3_v2_resolve_metal_burst(actor, hp_before)
        _gen3_v2_resolve_spiky_shield(actor, move, targets_before, hp_before, contact_move, missed)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind == "db_protect" and _gen3_v2_active_move_id() == "spiky_shield":
        var effect_value: float = super._effect(actor, target, mechanic)
        if effect_value > 0.0:
            actor["gen3_v2_spiky_shield_armed"] = true
        return effect_value
    return super._effect(actor, target, mechanic)


func _zf_apply_modifier(actor: Dictionary, target: Dictionary, proxy: Dictionary) -> float:
    if not _gen3_v2_simple_beam_active(target):
        return super._zf_apply_modifier(actor, target, proxy)

    var stage_weight: float = float(proxy.get("multiplier_from_special", 0.0))
    if not is_equal_approx(absf(stage_weight), 1.0):
        return super._zf_apply_modifier(actor, target, proxy)

    var patched: Dictionary = proxy.duplicate(true)
    patched["multiplier_from_special"] = 1.25 if stage_weight > 0.0 else -1.25
    return super._zf_apply_modifier(actor, target, patched)


func _gen3_v2_active_move_id() -> String:
    return str(_database_active_move.get("id", _database_move_id))


func _gen3_v2_needs_connected_hit_snapshot(move_id: String) -> bool:
    return ["dragon_ascent", "luster_purge", "mist_ball", "psycho_boost"].has(move_id)


func _gen3_v2_is_damaging_move(move: Dictionary) -> bool:
    if str(move.get("category", "status")) == "status":
        return false
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "damage":
                return true
    return false


func _gen3_v2_set_runtime_move(move_id: String, move: Dictionary) -> void:
    var runtime_value: Variant = data.get("moves", {})
    if runtime_value is Dictionary:
        (runtime_value as Dictionary)[move_id] = move.duplicate(true)
        data["moves"] = runtime_value
    var canonical_value: Variant = _canonical_pack.get("moves", {})
    if canonical_value is Dictionary:
        (canonical_value as Dictionary)[move_id] = move.duplicate(true)
        _canonical_pack["moves"] = canonical_value


func _gen3_v2_apply_modifier(actor: Dictionary, target: Dictionary, kind: String, stage_weight: float) -> void:
    var effect_aggro: float = _zf_apply_modifier(actor, target, {
        "modifier_kind": kind,
        "multiplier_from_special": stage_weight,
    })
    if effect_aggro > 0.0:
        actor["aggro"] = float(actor.get("aggro", 0.0)) + effect_aggro


func _gen3_v2_autotomize(actor: Dictionary) -> void:
    _gen3_v2_apply_modifier(actor, actor, "atb_cycle_mod", -1.25)
    if actor.has("gen3_v2_battle_weight_kg"):
        actor["gen3_v2_battle_weight_kg"] = maxf(0.1, float(actor.get("gen3_v2_battle_weight_kg", 0.1)) - 100.0)
    elif actor.has("weight_kg"):
        actor["weight_kg"] = maxf(0.1, float(actor.get("weight_kg", 0.1)) - 100.0)
    elif actor.has("weight"):
        actor["weight"] = maxf(0.1, float(actor.get("weight", 0.1)) - 100.0)


func _gen3_v2_copy_timed_modifiers(source: Dictionary, target: Dictionary) -> void:
    for kind: String in GEN3_V2_COPY_MODIFIER_KINDS:
        var source_modifiers: Array = _v24_10_active_modifiers(source, kind)
        if source_modifiers.is_empty():
            continue
        _v24_10_replace_modifiers(target, kind, source_modifiers)


func _gen3_v2_simple_beam_active(target: Dictionary) -> bool:
    return int(target.get("action_serial", 0)) < int(target.get("gen3_v2_simple_beam_expires_action", 0))


func _gen3_v2_positive_attribute_count(actor: Dictionary) -> int:
    var count: int = 0
    if _combined_timed_modifier(actor, "outgoing_damage_mod") > 1.0001:
        count += 1
    if _combined_timed_modifier(actor, "incoming_damage_mod") < 0.9999:
        count += 1
    if _combined_timed_modifier(actor, "atb_cycle_mod") < 0.9999:
        count += 1
    if _combined_timed_modifier(actor, "accuracy_mod") > 1.0001:
        count += 1

    var status_positive: bool = false
    for kind: String in ["status_value_mod", "status_mod", "special_mod"]:
        if _combined_timed_modifier(actor, kind) > 1.0001:
            status_positive = true
            break
    if status_positive:
        count += 1
    return clampi(count, 0, 5)


func _gen3_v2_target_connected(snapshots: Dictionary, target: Dictionary) -> bool:
    var target_id: String = str(target.get("id", ""))
    if target_id.is_empty():
        return false
    var snapshot_value: Variant = snapshots.get(target_id, {})
    return snapshot_value is Dictionary and _pika_snapshot_target_hit(snapshot_value as Dictionary)


func _gen3_v2_any_connected(snapshots: Dictionary) -> bool:
    for snapshot_value: Variant in snapshots.values():
        if snapshot_value is Dictionary and _pika_snapshot_target_hit(snapshot_value as Dictionary):
            return true
    return false


func _gen3_v2_hp_snapshots() -> Dictionary:
    var result: Dictionary = {}
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value as Dictionary
        result[str(combatant.get("id", ""))] = {
            "hp": int(combatant.get("hp", 0)),
            "substitute_hp": int(combatant.get("db_substitute_hp", 0)),
            "alive": bool(combatant.get("alive", false)),
        }
    return result


func _gen3_v2_resolve_grudge(attacker: Dictionary, move_id: String, before: Dictionary) -> void:
    for target_value: Variant in combatants:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value as Dictionary
        if not bool(target.get("gen3_v2_grudge_armed", false)):
            continue
        if str(target.get("side", "")) == str(attacker.get("side", "")):
            continue
        var target_id: String = str(target.get("id", ""))
        var snapshot_value: Variant = before.get(target_id, {})
        if not (snapshot_value is Dictionary):
            continue
        var old_hp: int = int((snapshot_value as Dictionary).get("hp", 0))
        if old_hp > 0 and int(target.get("hp", 0)) <= 0:
            Gen3MoveDisableState.apply(attacker, move_id, 3)
            target["gen3_v2_grudge_armed"] = false
            _spawn_feedback_label(attacker, "👻 NACHSPIEL · AUSSETZER", Color("c9b6e8"))


func _gen3_v2_resolve_metal_burst(attacker: Dictionary, before: Dictionary) -> void:
    for target_value: Variant in combatants:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value as Dictionary
        if not bool(target.get("gen3_v2_metal_burst_armed", false)):
            continue
        if str(target.get("side", "")) == str(attacker.get("side", "")):
            continue
        var target_id: String = str(target.get("id", ""))
        var snapshot_value: Variant = before.get(target_id, {})
        if not (snapshot_value is Dictionary):
            continue
        var old_hp: int = int((snapshot_value as Dictionary).get("hp", 0))
        var lost_hp: int = maxi(0, old_hp - int(target.get("hp", 0)))
        if lost_hp <= 0:
            continue
        target["gen3_v2_metal_burst_armed"] = false
        if not bool(target.get("alive", false)) or not bool(attacker.get("alive", false)):
            continue
        var retaliation: int = maxi(1, int(round(float(lost_hp) * 1.5)))
        var actual: int = mini(retaliation, int(attacker.get("hp", 0)))
        attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - actual)
        if int(attacker.get("hp", 0)) <= 0:
            attacker["alive"] = false
        target["aggro"] = float(target.get("aggro", 0.0)) + float(actual)
        _spawn_feedback_label(attacker, "🔩 METALLSTOSS −" + str(actual), Color("c8d0d6"))
        _refresh_cards()
        _check_end()


func _gen3_v2_resolve_spiky_shield(
    attacker: Dictionary,
    move: Dictionary,
    targets_before: Array,
    before: Dictionary,
    contact_move: bool,
    missed: bool
) -> void:
    for target_value: Variant in targets_before:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value as Dictionary
        if not bool(target.get("gen3_v2_spiky_shield_armed", false)):
            continue
        if str(target.get("side", "")) == str(attacker.get("side", "")):
            continue

        # The central Protect contract owns the actual block. This local flag is
        # only for the one-per-move contact retaliation.
        target["gen3_v2_spiky_shield_armed"] = false
        if not contact_move or missed or not bool(attacker.get("alive", false)):
            continue

        var target_id: String = str(target.get("id", ""))
        var snapshot_value: Variant = before.get(target_id, {})
        if not (snapshot_value is Dictionary):
            continue
        var snapshot: Dictionary = snapshot_value as Dictionary
        var hp_unchanged: bool = int(target.get("hp", 0)) == int(snapshot.get("hp", 0))
        var sub_unchanged: bool = int(target.get("db_substitute_hp", 0)) == int(snapshot.get("substitute_hp", 0))
        if not hp_unchanged or not sub_unchanged:
            continue
        if _type_effect(str(move.get("type", "normal")), target.get("types", [])) <= 0.0:
            continue

        var recoil: int = maxi(1, int(floor(float(maxi(1, int(attacker.get("max_hp", 1)))) / 8.0)))
        var actual: int = mini(recoil, int(attacker.get("hp", 0)))
        attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - actual)
        if int(attacker.get("hp", 0)) <= 0:
            attacker["alive"] = false
        target["aggro"] = float(target.get("aggro", 0.0)) + float(actual)
        _spawn_feedback_label(attacker, "🌵 SCHUTZSTACHELN −" + str(actual), Color("b7d5af"))
        _refresh_cards()
        _check_end()
