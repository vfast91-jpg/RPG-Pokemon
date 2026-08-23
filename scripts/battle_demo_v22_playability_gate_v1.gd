extends "res://scripts/battle_demo_v22_consistency_v1.gd"

# Final playability gate for the V22 attack set.
# This layer intentionally sits above every historical family/runtime layer.
# It owns only cross-generation invariants: canonical move completeness,
# canonical target resolution and V22 sequence rules that older family layers
# must not silently override.

const V22MoveCatalog = preload("res://scripts/battle/v22_move_catalog.gd")

const V22_HYBRID_TARGET_MOVE_IDS: Array[String] = ["swagger", "flatter"]
const V22_RUNTIME_ONLY_METADATA_KEYS: Array[String] = [
    "runtime_supported", "strict_contract", "contract_validated",
    "contract_errors", "partial", "notes", "normal_battle_available"
]

# Immediate multi-hit attacks. Uproar is deliberately not in this list: its
# three hits are three complete own actions and are handled as a forced sequence.
const V22_IMMEDIATE_MULTI_HIT_MOVE_IDS: Array[String] = [
    "fury_attack", "pin_missile", "bullet_seed", "scale_shot", "fury_swipes",
    "double_kick", "dual_wingbeat", "double_hit", "rock_blast", "dual_chop",
    "icicle_spear", "triple_axel", "bonemerang", "triple_kick"
]

const V22_MULTI_HIT_CONTRACTS: Dictionary = {
    "fury_attack": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "pin_missile": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "bullet_seed": {"min": 2, "max": 5, "weights": [7, 7, 3, 3]},
    "scale_shot": {"min": 2, "max": 5, "weights": [7, 7, 3, 3]},
    "fury_swipes": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "double_kick": {"min": 2, "max": 2, "weights": [1]},
    "dual_wingbeat": {"min": 2, "max": 2, "weights": [1]},
    "double_hit": {"min": 2, "max": 2, "weights": [1]},
    "rock_blast": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "dual_chop": {"min": 2, "max": 2, "weights": [1]},
    "icicle_spear": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "triple_axel": {"min": 3, "max": 3, "weights": [1]},
    "bonemerang": {"min": 2, "max": 2, "weights": [1]},
    "triple_kick": {"min": 3, "max": 3, "weights": [1]}
}

var _v22_hybrid_picker_move_id: String = ""


func _v22_apply_runtime_fixes() -> void:
    super._v22_apply_runtime_fixes()

    # Canonical V22 targeting contracts that are neither simple highest-aggro
    # enemy nor the already-supported single ally/self-or-ally cases.
    for move_id: String in V22_HYBRID_TARGET_MOVE_IDS:
        _v22_set_target(move_id, "enemy_highest_aggro_or_single_ally", false)

    _v22_set_target("dragon_cheer", "all_allies_except_self", true)
    _v22_apply_sequence_contracts()


func _v22_apply_sequence_contracts() -> void:
    # The database sequence engine owns the actual hit timing. These contracts
    # pin V22's exact hit-count distributions after all historical move packs
    # have finished loading.
    for move_id_value: Variant in V22_MULTI_HIT_CONTRACTS.keys():
        var move_id: String = str(move_id_value)
        var spec_value: Variant = V22_MULTI_HIT_CONTRACTS.get(move_id, {})
        if spec_value is Dictionary:
            _v22_set_multi_hit_contract(move_id, spec_value as Dictionary)

    # Uproar is exactly three full own actions; Rollout is at most five full own
    # actions and only continues while each forced execution actually damages.
    _v22_set_forced_sequence_contract("uproar", 3, 3)
    _v22_set_forced_sequence_contract("rollout", 5, 5)
    _v22_set_rollout_power_chain()


func _v22_set_multi_hit_contract(move_id: String, canonical_spec: Dictionary) -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return
    var moves: Dictionary = moves_value
    var move_value: Variant = moves.get(move_id, {})
    if not (move_value is Dictionary):
        return

    var move: Dictionary = (move_value as Dictionary).duplicate(true)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true) if runtime_value is Dictionary else {}
    )
    var current_spec_value: Variant = runtime.get("multi_hit", {})
    var current_spec: Dictionary = (
        (current_spec_value as Dictionary).duplicate(true)
        if current_spec_value is Dictionary else {}
    )

    current_spec["min"] = int(canonical_spec.get("min", 2))
    current_spec["max"] = int(canonical_spec.get("max", current_spec.get("min", 2)))
    current_spec["weights"] = (canonical_spec.get("weights", []) as Array).duplicate()
    current_spec["repeat_kinds"] = ["damage"]
    current_spec["v22_target_aggro_once"] = true
    runtime["multi_hit"] = current_spec
    move["runtime"] = runtime
    moves[move_id] = move
    data["moves"] = moves


func _v22_set_forced_sequence_contract(move_id: String, minimum: int, maximum: int) -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return
    var moves: Dictionary = moves_value
    var move_value: Variant = moves.get(move_id, {})
    if not (move_value is Dictionary):
        return

    var move: Dictionary = (move_value as Dictionary).duplicate(true)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true) if runtime_value is Dictionary else {}
    )
    var sequence_value: Variant = runtime.get("forced_sequence", {})
    var sequence: Dictionary = (
        (sequence_value as Dictionary).duplicate(true)
        if sequence_value is Dictionary else {}
    )
    sequence["min"] = minimum
    sequence["max"] = maximum
    sequence["confuse_after"] = false
    runtime["forced_sequence"] = sequence
    move["runtime"] = runtime
    moves[move_id] = move
    data["moves"] = moves


func _v22_set_rollout_power_chain() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return
    var moves: Dictionary = moves_value
    var move_value: Variant = moves.get("rollout", {})
    if not (move_value is Dictionary):
        return

    var move: Dictionary = (move_value as Dictionary).duplicate(true)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true) if runtime_value is Dictionary else {}
    )
    runtime["consecutive_power_chain"] = [30, 60, 120, 240, 480]
    move["runtime"] = runtime
    moves["rollout"] = move
    data["moves"] = moves


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if move_id not in ["rollout", "uproar"]:
        super._execute_move(actor, move_id)
        return

    var hp_before: Dictionary = _v22_opponent_hp_snapshot(actor)
    var chain_before: int = int(actor.get("db_fury_cutter_chain", 0))
    var serial_before: int = int(actor.get("action_serial", 0))
    var forced_before: bool = str(actor.get("db_forced_move_id", "")) == move_id

    super._execute_move(actor, move_id)

    if int(actor.get("action_serial", 0)) <= serial_before:
        return

    var damaged: bool = _v22_any_opponent_lost_hp(actor, hp_before)
    if move_id == "uproar":
        # V22: a forced repetition that cannot actually resolve ends Uproar.
        if not damaged:
            _database_interrupt_forced_sequence(actor)
        return

    # Rollout only advances its power stage after a successful damaging stage.
    # The historical database layer hard-capped this counter at index 2; V22 has
    # five stages (indices 0..4).
    if not damaged:
        actor["db_fury_cutter_chain"] = 0
        _database_interrupt_forced_sequence(actor)
        return

    var sequence_finished: bool = (
        forced_before and str(actor.get("db_forced_move_id", "")) != "rollout"
    )
    if sequence_finished:
        actor["db_fury_cutter_chain"] = 0
        return

    actor["db_fury_cutter_chain"] = mini(4, chain_before + 1)


func _v22_opponent_hp_snapshot(actor: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for target_value: Variant in _living_opponents(actor):
        if target_value is Dictionary:
            var target: Dictionary = target_value
            result[str(target.get("id", ""))] = int(target.get("hp", 0))
    return result


func _v22_any_opponent_lost_hp(actor: Dictionary, hp_before: Dictionary) -> bool:
    for target_value: Variant in _team_for_side("enemy" if str(actor.get("side", "")) == "player" else "player"):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        if not hp_before.has(target_id):
            continue
        if int(target.get("hp", 0)) < int(hp_before.get(target_id, int(target.get("hp", 0)))):
            return true
    return false


func _database_launch_multi_hit(state: Dictionary) -> void:
    # Triple Kick already has this guard in its family layer. Triple Axel used
    # the same per-hit accuracy model but lacked the matching launch guard, so a
    # miss could still animate a later hit. Stop before that extra phase exists.
    if str(state.get("move_id", "")) == "triple_axel":
        var actor_value: Variant = state.get("actor", {})
        if (
            actor_value is Dictionary
            and bool((actor_value as Dictionary).get("f30_triple_axel_failed", false))
        ):
            _database_finish_multi_hit_sequence(state)
            return
    super._database_launch_multi_hit(state)


func _database_apply_multi_hit(state: Dictionary, hit_index: int) -> void:
    var move_id: String = str(state.get("move_id", ""))
    if not V22_IMMEDIATE_MULTI_HIT_MOVE_IDS.has(move_id):
        super._database_apply_multi_hit(state, hit_index)
        return

    # The normal first hit already applies the game's single-target Aggro
    # reduction. Historical follow-up-hit code applied the same 50% reduction
    # again on every extra hit. Snapshot the post-first-hit value and preserve it
    # across follow-up hits so the whole move reduces target Aggro at most once.
    var target_snapshots: Dictionary = {}
    for target_value: Variant in state.get("targets", []):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        target_snapshots[str(target.get("id", ""))] = {
            "hp": int(target.get("hp", 0)),
            "aggro": float(target.get("aggro", 0.0))
        }

    super._database_apply_multi_hit(state, hit_index)

    for target_value: Variant in state.get("targets", []):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        var snapshot_value: Variant = target_snapshots.get(target_id, {})
        if not (snapshot_value is Dictionary):
            continue
        var snapshot: Dictionary = snapshot_value
        if int(target.get("hp", 0)) >= int(snapshot.get("hp", int(target.get("hp", 0)))):
            continue
        if bool(target.get("alive", false)):
            target["aggro"] = float(snapshot.get("aggro", target.get("aggro", 0.0)))
        else:
            target["aggro"] = 0.0


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return

    if (
        V22_HYBRID_TARGET_MOVE_IDS.has(move_id)
        and _v22_hybrid_picker_move_id.is_empty()
    ):
        _v22_show_enemy_or_ally_picker(selected_actor, move_id)
        return

    super._choose_move(move_id)


func _v22_show_enemy_or_ally_picker(actor: Dictionary, move_id: String) -> void:
    paused = true
    selected_actor = actor
    _v22_hybrid_picker_move_id = move_id
    _clear_actions()

    var highest_enemy: Dictionary = _highest_aggro(actor)
    var ally_candidates: Array = []
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue
        if str(candidate.get("id", "")) == str(actor.get("id", "")):
            continue
        ally_candidates.append(candidate)

    if highest_enemy.is_empty() and ally_candidates.is_empty():
        _v22_hybrid_picker_move_id = ""
        _set_log("Für " + str(_move_data(move_id).get("name", move_id)) + " gibt es kein gültiges Ziel.")
        _prompt_player(actor)
        return

    _set_log(
        "[b]%s[/b]: Ziel für %s wählen."
        % [_actor_name(actor), str(_move_data(move_id).get("name", move_id))]
    )

    if not highest_enemy.is_empty():
        var enemy_button := Button.new()
        enemy_button.text = "Gegner · " + _actor_name(highest_enemy) + " (höchste Aggro)"
        enemy_button.custom_minimum_size = Vector2(220, 29)
        enemy_button.pressed.connect(_v22_confirm_hybrid_enemy.bind(actor, move_id))
        action_grid.add_child(enemy_button)

    for ally_value: Variant in ally_candidates:
        var ally: Dictionary = ally_value
        var ally_button := Button.new()
        ally_button.text = "Verbündeter · " + _actor_name(ally)
        ally_button.custom_minimum_size = Vector2(220, 29)
        ally_button.pressed.connect(
            _v22_confirm_hybrid_ally.bind(
                actor, move_id, str(ally.get("id", ""))
            )
        )
        action_grid.add_child(ally_button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.custom_minimum_size = Vector2(220, 29)
    back_button.pressed.connect(_v22_cancel_hybrid_picker.bind(actor))
    action_grid.add_child(back_button)


func _v22_confirm_hybrid_enemy(actor: Dictionary, move_id: String) -> void:
    if actor.is_empty():
        return
    _zf_selected_target_id = ""
    _v22_hybrid_picker_move_id = "__resolving__"
    selected_actor = actor
    super._choose_move(move_id)
    _v22_hybrid_picker_move_id = ""


func _v22_confirm_hybrid_ally(actor: Dictionary, move_id: String, target_id: String) -> void:
    if actor.is_empty():
        return
    _zf_selected_target_id = target_id
    _v22_hybrid_picker_move_id = "__resolving__"
    selected_actor = actor
    super._choose_move(move_id)
    _v22_hybrid_picker_move_id = ""


func _v22_cancel_hybrid_picker(actor: Dictionary) -> void:
    _zf_selected_target_id = ""
    _v22_hybrid_picker_move_id = ""
    _prompt_player(actor)


func _targets(actor: Dictionary, rule: String) -> Array:
    match rule:
        "enemy_field", "global_battlefield", "battlefield":
            # Field mechanics resolve exactly once. Their mechanic handler owns
            # which side/global state is affected; they do not need a combatant
            # target merely to execute.
            return [actor]
        _:
            return super._targets(actor, rule)


func _target_name(rule: String) -> String:
    match rule:
        "single_enemy":
            return "gewählter Gegner"
        "all_others", "all_other_active_pokemon":
            return "alle anderen aktiven Pokémon"
        "all_combatants":
            return "alle aktiven Pokémon"
        "all_allies_except_self":
            return "alle Verbündeten außer Anwender"
        "enemy_highest_aggro_or_single_ally":
            return "Gegner mit höchster Aggro oder gewählter Verbündeter"
        "enemy_field":
            return "gegnerische Feldseite"
        "global_battlefield", "battlefield":
            return "Kampffeld"
        _:
            return super._target_name(rule)


func _v22_audit_final_move_set() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        push_error("V22-Audit: finaler Attackenbestand fehlt.")
        return

    var moves: Dictionary = moves_value
    if V22MoveCatalog.count() != V22_EXPECTED_MOVE_COUNT:
        push_error(
            "V22-Audit: kanonischer Katalog enthält %d statt %d IDs."
            % [V22MoveCatalog.count(), V22_EXPECTED_MOVE_COUNT]
        )

    for move_id: String in V22MoveCatalog.IDS:
        if not moves.has(move_id):
            push_error("V22-Audit: kanonische Attacke fehlt im finalen Runtime-Bestand: " + move_id)
            continue

        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            push_error("V22-Audit: " + move_id + " ist keine gültige Attackendefinition.")
            continue
        var move: Dictionary = move_value

        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        if not bool(runtime.get("runtime_supported", true)):
            push_error("V22-Audit: " + move_id + " ist als runtime_supported=false markiert.")

        if not _v22_move_has_executable_path(move):
            push_error(
                "V22-Audit: " + move_id
                + " besitzt weder ausführbare mechanics noch einen Runtime-Spezialpfad."
            )

    # Extras are allowed as compatibility aliases, but every canonical ID above
    # is mandatory. This prevents a stale count from hiding a missing V22 move.
    if moves.size() < V22MoveCatalog.count():
        push_error(
            "V22-Audit: finaler Runtime-Bestand enthält nur %d Einträge für %d kanonische Attacken."
            % [moves.size(), V22MoveCatalog.count()]
        )


func _v22_move_has_executable_path(move: Dictionary) -> bool:
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array and not (mechanics_value as Array).is_empty():
        return true

    # A small number of older attacks intentionally execute entirely through
    # runtime flags in an inherited _execute_move hook (Dragon Cheer is one).
    # Metadata-only runtime dictionaries do NOT count as an execution path.
    var runtime_value: Variant = move.get("runtime", {})
    if not (runtime_value is Dictionary):
        return false
    var runtime: Dictionary = runtime_value
    for key_value: Variant in runtime.keys():
        var key: String = str(key_value)
        if V22_RUNTIME_ONLY_METADATA_KEYS.has(key):
            continue
        return true
    return false
