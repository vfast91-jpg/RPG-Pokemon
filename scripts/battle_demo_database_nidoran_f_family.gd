extends "res://scripts/battle_demo_database_sandshrew_family.gd"
const NIDO_SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_nidoran_f_family_v1.json"
const NIDO_MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_20_nidoran_f_family.json"
const NIDO_MANIFEST_PATH: String = "res://data/gen1_database_manifest_v4.json"
const NIDO_META_PATH: String = "res://data/gen1_database_meta_v4.json"
const NIDO_STATUS_DURATION_ACTIONS: int = 3
const NIDO_STATUS_MODIFIERS_KEY: String = "nido_status_effectiveness_modifiers"
var _nido_forced_target_id: String = ""
var _nido_active_move_id: String = ""
var _nido_drain_snapshots: Dictionary = {}
func _load_canonical_database() -> void:
    super._load_canonical_database()
    var species_pack: Dictionary = _database_read_json_dictionary(NIDO_SPECIES_PACK_PATH)
    var move_pack: Dictionary = _database_read_json_dictionary(NIDO_MOVE_PACK_PATH)
    var manifest: Dictionary = _database_read_json_dictionary(NIDO_MANIFEST_PATH)
    var meta: Dictionary = _database_read_json_dictionary(NIDO_META_PATH)
    var move_entries_value: Variant = move_pack.get("moves", {})
    var move_entries: Dictionary = move_entries_value if move_entries_value is Dictionary else {}
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_moves_value if canonical_moves_value is Dictionary else {}
    var runtime_moves_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_moves_value if runtime_moves_value is Dictionary else {}
    for move_id_value: Variant in move_entries.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = move_entries.get(move_id, {})
        if not (move_value is Dictionary):
            continue
        canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)
        runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
    _canonical_pack["moves"] = canonical_moves
    data["moves"] = runtime_moves
    var species_entries_value: Variant = species_pack.get("species", {})
    var species_entries: Dictionary = species_entries_value if species_entries_value is Dictionary else {}
    var canonical_species_value: Variant = _canonical_pack.get("species", {})
    var canonical_species: Dictionary = canonical_species_value if canonical_species_value is Dictionary else {}
    var runtime_species_value: Variant = data.get("species", {})
    var runtime_species: Dictionary = runtime_species_value if runtime_species_value is Dictionary else {}
    for species_id_value: Variant in species_entries.keys():
        var species_id: String = str(species_id_value)
        var species_value: Variant = species_entries.get(species_id, {})
        if not (species_value is Dictionary):
            continue
        var source_species: Dictionary = (species_value as Dictionary).duplicate(true)
        canonical_species[species_id] = source_species
        runtime_species[species_id] = _canonical_species_runtime(source_species)
    _canonical_pack["species"] = canonical_species
    data["species"] = runtime_species
    if not species_ids.has("nidoran_f"):
        species_ids.append("nidoran_f")
    data["species_order"] = species_ids.duplicate()
    if not meta.is_empty():
        for meta_key_value: Variant in meta.keys():
            var meta_key: String = str(meta_key_value)
            _canonical_pack[meta_key] = meta.get(meta_key_value)
    if not manifest.is_empty():
        _canonical_pack["manifest"] = manifest.duplicate(true)
        if runtime_species.size() != int(manifest.get("species_count", runtime_species.size())):
            push_error("Nidoran-Familie: Pokémon-Anzahl stimmt nicht mit V4-Manifest überein.")
        if runtime_moves.size() != int(manifest.get("move_count", runtime_moves.size())):
            push_error("Nidoran-Familie: Attacken-Anzahl stimmt nicht mit V4-Manifest überein.")
        if species_ids.size() != int(manifest.get("route_root_count", species_ids.size())):
            push_error("Nidoran-Familie: Basislinien-Anzahl stimmt nicht mit V4-Manifest überein.")
func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant[NIDO_STATUS_MODIFIERS_KEY] = []
    return combatant
func _choose_move(move_id: String) -> void:
    if move_id == "flatter" and not selected_actor.is_empty():
        var actor: Dictionary = selected_actor
        var allies: Array = _nido_living_allies_excluding(actor)
        if not allies.is_empty():
            _nido_show_flatter_targets(actor, allies)
            return
    super._choose_move(move_id)
func _choose_wait() -> void:
    var actor: Dictionary = selected_actor if not selected_actor.is_empty() else {}
    super._choose_wait()
    if not actor.is_empty():
        _nido_expire_status_effectiveness(actor)
        _refresh_cards()
func _targets(actor: Dictionary, rule: String) -> Array:
    if (
        _nido_active_move_id == "flatter"
        and rule == "enemy_highest_aggro"
        and not _nido_forced_target_id.is_empty()
    ):
        for candidate_value: Variant in combatants:
            if not (candidate_value is Dictionary):
                continue
            var candidate: Dictionary = candidate_value
            if (
                str(candidate.get("id", "")) == _nido_forced_target_id
                and str(candidate.get("id", "")) != str(actor.get("id", ""))
                and bool(candidate.get("alive", false))
            ):
                return [candidate]
        return []
    return super._targets(actor, rule)
func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        super._execute_move(actor, move_id)
        return
    var previous_active_move: String = _nido_active_move_id
    _nido_active_move_id = move_id
    var snapshots: Dictionary = _nido_target_snapshots(actor, move)
    _nido_drain_snapshots = snapshots.duplicate(true) if move_id == "drain_punch" else {}
    super._execute_move(actor, move_id)
    var attempted: bool = _database_move_was_attempted(move_id)
    var outcome: String = str(actor.get("tf_last_move_outcome", ""))
    var action_succeeded: bool = attempted and not ["miss", "immune", "failed", "blocked"].has(outcome)
    if move_id == "flatter" and action_succeeded:
        for snapshot_value: Variant in snapshots.values():
            if not (snapshot_value is Dictionary):
                continue
            var target_value: Variant = (snapshot_value as Dictionary).get("target", {})
            if target_value is Dictionary:
                _nido_apply_status_effectiveness_bonus(actor, target_value as Dictionary)
    if (
        move_id == "superpower"
        and attempted
        and _nido_any_target_damaged(snapshots)
    ):
        _nido_apply_superpower_self_debuff(actor)
    _nido_drain_snapshots.clear()
    _nido_expire_status_effectiveness(actor)
    _nido_active_move_id = previous_active_move
    _refresh_cards()
func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind == "db_drain_from_damage":
        return _nido_resolve_drain(actor, target, float(mechanic.get("fraction", 0.5)))
    var status_effectiveness: float = _nido_status_effectiveness_multiplier(actor)
    if status_effectiveness <= 1.0001:
        return super._effect(actor, target, mechanic)
    var original_special: Variant = actor.get("special", 0.0)
    actor["special"] = float(original_special) * status_effectiveness
    var result: float = super._effect(actor, target, mechanic)
    actor["special"] = original_special
    return result
func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if _nido_status_effectiveness_multiplier(combatant) > 1.0001:
        tokens.append("STATUS+")
    return tokens
func _nido_show_flatter_targets(actor: Dictionary, allies: Array) -> void:
    _clear_actions()
    _set_log("[b]" + _actor_name(actor) + "[/b] nutzt Schmeichler. Wähle das Ziel.")
    var enemy: Dictionary = _highest_aggro(actor)
    if not enemy.is_empty():
        var enemy_button := Button.new()
        enemy_button.text = "💬 " + _actor_name(enemy) + " · höchste Gegner-Aggro"
        enemy_button.custom_minimum_size = Vector2(285, 29)
        enemy_button.tooltip_text = "Schmeichler auf den Gegner mit der höchsten Aggro."
        enemy_button.pressed.connect(_nido_choose_flatter_target.bind(str(enemy.get("id", ""))))
        action_grid.add_child(enemy_button)
    for ally_value: Variant in allies:
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        var ally_button := Button.new()
        ally_button.text = "🤝 " + _actor_name(ally) + " · Verbündeter"
        ally_button.custom_minimum_size = Vector2(285, 29)
        ally_button.tooltip_text = "Schmeichler auf einen aktiven Verbündeten. Der Anwender selbst ist ausgeschlossen."
        ally_button.pressed.connect(_nido_choose_flatter_target.bind(str(ally.get("id", ""))))
        action_grid.add_child(ally_button)
    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.custom_minimum_size = Vector2(135, 29)
    back_button.pressed.connect(_nido_cancel_flatter_targeting)
    action_grid.add_child(back_button)
func _nido_choose_flatter_target(target_id: String) -> void:
    if selected_actor.is_empty() or target_id.is_empty():
        return
    _nido_forced_target_id = target_id
    super._choose_move("flatter")
    _nido_forced_target_id = ""
func _nido_cancel_flatter_targeting() -> void:
    if selected_actor.is_empty():
        return
    _prompt_player(selected_actor)
func _nido_living_allies_excluding(actor: Dictionary) -> Array:
    var result: Array = []
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if (
            bool(candidate.get("alive", false))
            and str(candidate.get("id", "")) != str(actor.get("id", ""))
        ):
            result.append(candidate)
    return result
func _nido_target_snapshots(actor: Dictionary, move: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for target_value: Variant in _targets(actor, str(move.get("target", "enemy_highest_aggro"))):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        result[str(target.get("id", ""))] = {
            "target": target,
            "hp": int(target.get("hp", 0)),
            "substitute_hp": int(target.get("db_substitute_hp", 0))
        }
    return result
func _nido_any_target_damaged(snapshots: Dictionary) -> bool:
    for snapshot_value: Variant in snapshots.values():
        if not (snapshot_value is Dictionary):
            continue
        var snapshot: Dictionary = snapshot_value
        var target_value: Variant = snapshot.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if int(target.get("hp", 0)) < int(snapshot.get("hp", 0)):
            return true
        if int(target.get("db_substitute_hp", 0)) < int(snapshot.get("substitute_hp", 0)):
            return true
    return false
func _nido_resolve_drain(actor: Dictionary, target: Dictionary, fraction: float) -> float:
    var snapshot_value: Variant = _nido_drain_snapshots.get(str(target.get("id", "")), {})
    if not (snapshot_value is Dictionary):
        return 0.0
    var snapshot: Dictionary = snapshot_value
    var hp_damage: int = maxi(0, int(snapshot.get("hp", 0)) - int(target.get("hp", 0)))
    var substitute_damage: int = maxi(
        0,
        int(snapshot.get("substitute_hp", 0)) - int(target.get("db_substitute_hp", 0))
    )
    var actual_damage: int = hp_damage + substitute_damage
    if actual_damage <= 0:
        return 0.0
    var missing_hp: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    if missing_hp <= 0:
        return 0.0
    var heal: int = mini(
        missing_hp,
        maxi(1, int(floor(float(actual_damage) * clampf(fraction, 0.0, 1.0))))
    )
    actor["hp"] = int(actor.get("hp", 0)) + heal
    if heal > 0:
        _spawn_feedback_label(actor, "💚 +" + str(heal) + " KP", Color("8fe39b"))
    return 0.0
func _nido_apply_status_effectiveness_bonus(actor: Dictionary, target: Dictionary) -> void:
    var ratio: float = _nido_status_ratio(float(actor.get("special", 0.0)))
    var multiplier: float = 1.0 + ratio
    var modifiers_value: Variant = target.get(NIDO_STATUS_MODIFIERS_KEY, [])
    var modifiers: Array = modifiers_value if modifiers_value is Array else []
    modifiers.append({
        "multiplier": multiplier,
        "expires_after_action": int(target.get("action_serial", 0)) + NIDO_STATUS_DURATION_ACTIONS,
        "source_actor": str(actor.get("id", ""))
    })
    target[NIDO_STATUS_MODIFIERS_KEY] = modifiers
    _spawn_feedback_label(target, "💬 STATUSWIRKUNG ↑ · 3 AKTIONEN", Color("e7c0ff"))
func _nido_apply_superpower_self_debuff(actor: Dictionary) -> void:
    var ratio: float = _nido_status_ratio(float(actor.get("special", 0.0)))
    var factor: float = clampf(1.0 - ratio, 0.25, 1.0)
    _add_timed_modifier(actor, "outgoing_damage_mod", factor, "Kraftkoloss", _actor_name(actor))
    _add_timed_modifier(actor, "incoming_damage_mod", factor, "Kraftkoloss", _actor_name(actor))
    _spawn_feedback_label(actor, "💥 ANGRIFF ↓ · VERTEIDIGUNG ↓", Color("e7b0a0"))
func _nido_status_ratio(status_value: float) -> float:
    var safe_value: float = maxf(0.0, status_value)
    return safe_value / (75.0 + safe_value)
func _nido_status_effectiveness_multiplier(combatant: Dictionary) -> float:
    var modifiers_value: Variant = combatant.get(NIDO_STATUS_MODIFIERS_KEY, [])
    if not (modifiers_value is Array):
        return 1.0
    var current_action: int = int(combatant.get("action_serial", 0))
    var result: float = 1.0
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if current_action <= int(modifier.get("expires_after_action", -1)):
            result *= maxf(1.0, float(modifier.get("multiplier", 1.0)))
    return clampf(result, 1.0, 4.0)
func _nido_expire_status_effectiveness(combatant: Dictionary) -> void:
    var modifiers_value: Variant = combatant.get(NIDO_STATUS_MODIFIERS_KEY, [])
    if not (modifiers_value is Array):
        combatant[NIDO_STATUS_MODIFIERS_KEY] = []
        return
    var current_action: int = int(combatant.get("action_serial", 0))
    var remaining: Array = []
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if current_action < int(modifier.get("expires_after_action", -1)):
            remaining.append(modifier)
    combatant[NIDO_STATUS_MODIFIERS_KEY] = remaining
