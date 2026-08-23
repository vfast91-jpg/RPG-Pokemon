extends "res://scripts/battle_demo_families_21_30_runtime_v1.gd"

# Families 31 -> 40 attack block (V21).
# This layer loads the new move pack and only adds mechanics that are not
# already covered by the shared database / Abra-Dodri / families-21-30 systems.

const F40_MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_28_families_31_40.json"
const F40_GLOBAL_MISS_RECOVERY_MULTIPLIER: float = 0.75

var _f40_active_move_id: String = ""
var _f40_action_damage_total: int = 0
var _f40_move_missed: bool = false
var _f40_mat_block_by_side: Dictionary = {}


func _load_data() -> void:
    super._load_data()
    _f40_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _f40_load_move_pack() -> void:
    var text: String = FileAccess.get_file_as_string(F40_MOVE_PACK_PATH)
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary):
        push_error("Familien-31-40-Attackenpaket konnte nicht gelesen werden: " + F40_MOVE_PACK_PATH)
        return

    var entries_value: Variant = (parsed as Dictionary).get("moves", {})
    if not (entries_value is Dictionary):
        push_error("Familien-31-40-Attackenpaket besitzt kein moves-Dictionary.")
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
    combatant["f40_heal_block_expires_before_serial"] = -1
    combatant["f40_physical_output_mult"] = 1.0
    combatant["f40_physical_output_expires_before_serial"] = -1
    combatant["f40_special_output_mult"] = 1.0
    combatant["f40_special_output_expires_before_serial"] = -1
    combatant["f40_bind_source_id"] = ""
    combatant["f40_bind_aggro_floor"] = 0.0
    combatant["f40_triple_kick_hit_index"] = 0
    combatant["f40_triple_kick_failed"] = false
    return combatant


func _start_battle() -> void:
    _f40_mat_block_by_side.clear()
    super._start_battle()


func open_config() -> void:
    _f40_mat_block_by_side.clear()
    super.open_config()


func _process(delta: float) -> void:
    super._process(delta)
    _f40_enforce_bind_aggro_floors()
    if not opening_phase_active:
        _f40_mat_block_by_side.clear()


func _set_log(text: String) -> void:
    if (
        not _f40_active_move_id.is_empty()
        and text.contains(" verfehlt mit ")
    ):
        _f40_move_missed = true
    super._set_log(text)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return

    var original: Dictionary = _move_data(move_id)
    if original.is_empty():
        super._execute_move(actor, move_id)
        return

    var runtime_value: Variant = original.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if (
        move_id in ["high_jump_kick", "high_jump_kick_alt"]
        and bool(runtime.get("f40_gravity_crash", false))
        and _ad_gravity_active()
    ):
        _spawn_feedback_label(actor, "✖ ERDANZIEHUNG", Color("d9a5a5"))
        _ad_execute_empty_action(actor, move_id, original)
        _ad_apply_fixed_self_cost(actor, 0.5, "💥 FEHLSCHLAG")
        _refresh_cards()
        _check_end()
        return

    var temp: Dictionary = original.duplicate(true)
    var changed_move: bool = false

    if move_id == "triple_kick":
        actor["f40_triple_kick_hit_index"] = 0
        actor["f40_triple_kick_failed"] = false
        # Triple Kick checks accuracy separately for every hit. Disable the
        # database layer's one-time move-level accuracy gate for this move only.
        temp["accuracy"] = null
        changed_move = true

    if changed_move:
        _ad_replace_runtime_move(move_id, temp)

    var serial_before: int = int(actor.get("action_serial", 0))
    _f40_active_move_id = move_id
    _f40_action_damage_total = 0
    _f40_move_missed = false

    super._execute_move(actor, move_id)

    if changed_move:
        _ad_replace_runtime_move(move_id, original)

    var action_completed: bool = int(actor.get("action_serial", 0)) > serial_before

    if (
        action_completed
        and bool(runtime.get("f40_self_ko_on_any_damage", false))
        and _f40_action_damage_total > 0
        and bool(actor.get("alive", false))
    ):
        _ad_self_ko(actor)

    if (
        action_completed
        and _f40_move_missed
        and runtime.has("f40_miss_recovery_multiplier")
    ):
        var desired: float = clampf(
            float(runtime.get("f40_miss_recovery_multiplier", F40_GLOBAL_MISS_RECOVERY_MULTIPLIER)),
            0.1,
            2.0
        )
        actor["cycle"] = (
            float(actor.get("cycle", 1.0))
            * desired
            / F40_GLOBAL_MISS_RECOVERY_MULTIPLIER
        )

    _f40_active_move_id = ""
    _f40_move_missed = false
    _refresh_cards()
    _check_end()


func _database_launch_multi_hit(state: Dictionary) -> void:
    if str(state.get("move_id", "")) == "triple_kick":
        var actor_value: Variant = state.get("actor", {})
        if actor_value is Dictionary and bool((actor_value as Dictionary).get("f40_triple_kick_failed", false)):
            _database_finish_multi_hit_sequence(state)
            return
    super._database_launch_multi_hit(state)


func _database_finish_multi_hit_sequence(state: Dictionary) -> void:
    super._database_finish_multi_hit_sequence(state)
    if str(state.get("move_id", "")) != "triple_kick":
        return
    var actor_value: Variant = state.get("actor", {})
    if actor_value is Dictionary:
        var actor: Dictionary = actor_value as Dictionary
        actor["f40_triple_kick_hit_index"] = 0
        actor["f40_triple_kick_failed"] = false


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    var move_id: String = _f30_current_move_id()
    if move_id.is_empty():
        move_id = _f40_active_move_id
    var move: Dictionary = _move_data(move_id)

    if _f40_mat_block_blocks(actor, target, move):
        _spawn_feedback_label(target, "🥋 RAPIDSCHUTZ", Color("b8d9ff"))
        return 0

    var effective_power: int = power
    if move_id == "triple_kick":
        var hit_index: int = clampi(int(actor.get("f40_triple_kick_hit_index", 0)), 0, 2)
        if bool(actor.get("f40_triple_kick_failed", false)):
            return 0
        if randf() > 0.90:
            actor["f40_triple_kick_failed"] = true
            _spawn_feedback_label(target, "✖ VERFEHLT", Color("d9a5a5"))
            return 0
        effective_power = [10, 20, 30][hit_index]
        actor["f40_triple_kick_hit_index"] = hit_index + 1

    var damage: int = super._damage(actor, target, effective_power, move_type, category)
    if damage <= 0:
        return damage

    if category == "physical" and _f40_physical_output_active(actor):
        damage = maxi(
            1,
            int(round(float(damage) * float(actor.get("f40_physical_output_mult", 1.0))))
        )
    elif category == "special" and _f40_special_output_active(actor):
        damage = maxi(
            1,
            int(round(float(damage) * float(actor.get("f40_special_output_mult", 1.0))))
        )

    if move_id == "explosion":
        _f40_action_damage_total += damage

    return damage


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    var active_move_id: String = _f30_current_move_id()
    if active_move_id.is_empty():
        active_move_id = _f40_active_move_id
    if _f40_mat_block_blocks(actor, target, _move_data(active_move_id)):
        if kind == "damage":
            _spawn_feedback_label(target, "🥋 RAPIDSCHUTZ", Color("b8d9ff"))
        return 0.0

    if kind in ["db_heal_self", "db_swallow"]:
        var heal_target: Dictionary = actor
        if _f40_heal_block_active(heal_target):
            _f40_heal_block_feedback(heal_target)
            return 0.0

    match kind:
        "f40_burn_on_damage":
            return _f40_burn_on_damage(actor, target, mechanic)
        "f40_horn_drill":
            return _f30_ohko(actor, target, "horn_drill")
        "f40_defense_down_on_damage":
            return _f40_defense_down_on_damage(actor, target)
        "f40_flinch_on_damage":
            return _f40_flinch_on_damage(actor, target, mechanic)
        "f40_meditate":
            return _f40_meditate(actor)
        "f40_heal_block_on_damage":
            return _f40_heal_block_on_damage(actor, target, mechanic)
        "f40_block":
            return _f30_mean_look(actor, target)
        "f40_mat_block":
            return _f40_mat_block(actor)
        "f40_bind_on_damage":
            return _f40_bind_on_damage(actor, target)
        "f40_acid_spray_on_damage":
            return _f40_acid_spray_on_damage(actor, target)
        "f40_clear_smog_on_damage":
            return _f40_clear_smog_on_damage(actor, target)
        _:
            return super._effect(actor, target, mechanic)


func _ad_heal(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if _f40_heal_block_active(target):
        _f40_heal_block_feedback(target)
        return 0.0
    return super._ad_heal(actor, target, mechanic)


func _f30_trigger_aqua_ring_after_action(actor: Dictionary) -> void:
    var expiry: int = int(actor.get("f40_heal_block_expires_before_serial", -1))
    var serial: int = int(actor.get("action_serial", 0))
    # Aqua Ring resolves after the action serial has already advanced. The <=
    # comparison therefore blocks the post-action heal for both blocked actions.
    if expiry >= 0 and serial <= expiry:
        actor["f30_aqua_ring_last_heal_serial"] = serial
        _f40_heal_block_feedback(actor)
        return
    super._f30_trigger_aqua_ring_after_action(actor)


func _f40_burn_on_damage(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > float(mechanic.get("chance", 0.10)):
        return 0.0
    return super._effect(
        actor,
        target,
        {"kind": "status", "status": "burn", "chance": 1.0}
    )


func _f40_defense_down_on_damage(actor: Dictionary, target: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    var aggro: float = _f30_apply_exact_modifier(
        actor,
        target,
        "incoming_damage_mod",
        1.0,
        "Blitzkick"
    )
    _spawn_feedback_label(target, "🛡️ VERTEIDIGUNG ↓ · 3 AKTIONEN", Color("e7b2a7"))
    return aggro


func _f40_flinch_on_damage(
    _actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > float(mechanic.get("chance", 0.30)):
        return 0.0
    var fraction: float = clampf(float(mechanic.get("atb_fraction", 0.50)), 0.0, 1.0)
    var knockback: float = 100.0 * fraction
    target["atb"] = maxf(0.0, float(target.get("atb", 0.0)) - knockback)
    _spawn_feedback_label(target, "💫 ATB -" + str(int(round(knockback))), Color("e7d3a7"))
    return fraction * 8.0


func _f40_meditate(actor: Dictionary) -> float:
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var multiplier: float = clampf(1.0 + ratio, 1.0, 2.0)
    actor["f40_physical_output_mult"] = multiplier
    # The casting action itself advances action_serial once, therefore +4
    # leaves exactly the following three offensive action opportunities active.
    actor["f40_physical_output_expires_before_serial"] = int(actor.get("action_serial", 0)) + 4
    _spawn_feedback_label(actor, "🧘 ANGRIFF ↑ · 3 AKTIONEN", Color("c9d7ff"))
    return ratio * 8.0


func _f40_physical_output_active(actor: Dictionary) -> bool:
    var expiry: int = int(actor.get("f40_physical_output_expires_before_serial", -1))
    if expiry < 0:
        return false
    if int(actor.get("action_serial", 0)) >= expiry:
        actor["f40_physical_output_mult"] = 1.0
        actor["f40_physical_output_expires_before_serial"] = -1
        return false
    return true


func _f40_special_output_active(actor: Dictionary) -> bool:
    var expiry: int = int(actor.get("f40_special_output_expires_before_serial", -1))
    if expiry < 0:
        return false
    if int(actor.get("action_serial", 0)) >= expiry:
        actor["f40_special_output_mult"] = 1.0
        actor["f40_special_output_expires_before_serial"] = -1
        return false
    return true


func _f40_heal_block_on_damage(
    _actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    var duration: int = maxi(1, int(mechanic.get("duration_actions", 2)))
    var expiry: int = int(target.get("action_serial", 0)) + duration
    target["f40_heal_block_expires_before_serial"] = maxi(
        int(target.get("f40_heal_block_expires_before_serial", -1)),
        expiry
    )
    _spawn_feedback_label(target, "🔇 HEILUNG GESPERRT · " + str(duration) + " AKTIONEN", Color("d7b6df"))
    return 4.0


func _f40_heal_block_active(target: Dictionary) -> bool:
    return (
        bool(target.get("alive", false))
        and int(target.get("action_serial", 0))
        < int(target.get("f40_heal_block_expires_before_serial", -1))
    )


func _f40_heal_block_feedback(target: Dictionary) -> void:
    _spawn_feedback_label(target, "⛔ HEILUNG BLOCKIERT", Color("e6b3b3"))


func _f40_mat_block(actor: Dictionary) -> float:
    if not opening_phase_active:
        _spawn_feedback_label(actor, "✖ NUR ERÖFFNUNG", Color("d9a5a5"))
        return 0.0
    var side: String = str(actor.get("side", ""))
    if side.is_empty():
        return 0.0
    if _f40_mat_block_by_side.has(side):
        return 0.0
    _f40_mat_block_by_side[side] = {"source_id": str(actor.get("id", ""))}
    _spawn_feedback_label(actor, "🥋 RAPIDSCHUTZ", Color("b8d9ff"))
    return 4.0


func _f40_mat_block_blocks(
    actor: Dictionary,
    target: Dictionary,
    move: Dictionary
) -> bool:
    if not opening_phase_active or move.is_empty():
        return false
    if str(actor.get("side", "")) == str(target.get("side", "")):
        return false
    var target_side: String = str(target.get("side", ""))
    if not _f40_mat_block_by_side.has(target_side):
        return false
    if not bool(move.get("opening", false)):
        return false
    return move.get("power", null) != null


func _f40_bind_on_damage(actor: Dictionary, target: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0

    var source_id: String = str(actor.get("id", ""))
    var turns_left: int = int(target.get("bound_turns", 0))
    var current_source: String = str(target.get("bound_source", ""))

    if turns_left > 0 and not current_source.is_empty() and current_source != source_id:
        _spawn_feedback_label(target, "🪢 BEREITS GEFESSELT", Color("d4c0a6"))
        return 0.0

    target["bound_turns"] = randi_range(4, 5)
    target["bound_source"] = source_id
    target["f40_bind_source_id"] = source_id
    target["f40_bind_aggro_floor"] = float(target.get("aggro", 0.0))
    _spawn_feedback_label(target, "🪢 KLAMMERGRIFF", Color("d4c0a6"))
    return 4.0


func _f40_enforce_bind_aggro_floors() -> void:
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value as Dictionary
        var source_id: String = str(candidate.get("f40_bind_source_id", ""))
        var active: bool = (
            bool(candidate.get("alive", false))
            and int(candidate.get("bound_turns", 0)) > 0
            and not source_id.is_empty()
            and str(candidate.get("bound_source", "")) == source_id
        )
        if not active:
            candidate["f40_bind_source_id"] = ""
            candidate["f40_bind_aggro_floor"] = 0.0
            continue

        var current_aggro: float = float(candidate.get("aggro", 0.0))
        var floor_value: float = float(candidate.get("f40_bind_aggro_floor", current_aggro))
        if current_aggro > floor_value:
            floor_value = current_aggro
            candidate["f40_bind_aggro_floor"] = floor_value
        elif current_aggro < floor_value:
            candidate["aggro"] = floor_value


func _f40_acid_spray_on_damage(actor: Dictionary, target: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var multiplier: float = clampf(1.0 - ratio, 0.25, 1.0)
    target["f40_special_output_mult"] = multiplier
    target["f40_special_output_expires_before_serial"] = int(target.get("action_serial", 0)) + 3
    _spawn_feedback_label(target, "🧪 SPEZIALSCHADEN ↓ · 3 AKTIONEN", Color("c8b5da"))
    return ratio * 8.0


func _f40_clear_smog_on_damage(_actor: Dictionary, target: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0

    target["timed_modifiers"] = []
    target["attack_mult"] = 1.0
    target["defense_mult"] = 1.0
    target["accuracy_mult"] = 1.0
    target["db_incoming_accuracy_mult"] = 1.0
    target["db_incoming_accuracy_expires"] = -1
    target["f40_physical_output_mult"] = 1.0
    target["f40_physical_output_expires_before_serial"] = -1
    target["f40_special_output_mult"] = 1.0
    target["f40_special_output_expires_before_serial"] = -1

    if target.has("f30_minimize_expires_serial"):
        target["f30_minimize_expires_serial"] = -1

    _spawn_feedback_label(target, "🌫️ MODIFIKATOREN NEUTRAL", Color("c7d1cc"))
    return 5.0
