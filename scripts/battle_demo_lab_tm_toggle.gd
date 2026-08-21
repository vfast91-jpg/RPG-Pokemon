extends "res://scripts/battle_demo_type_help_button_polish.gd"

const BULBASAUR_TM_MOVE_PATH: String = "res://data/gen1_moves_runtime_v3_bulbasaur_tms.json"
const BULBASAUR_WEIGHT_PATH: String = "res://data/gen1_species_weights_v4.json"
const BULBASAUR_TM_IDS: Array[String] = [
    "take_down", "charm", "protect", "trailblaze", "facade", "magical_leaf",
    "endure", "sunny_day", "bullet_seed", "sleep_talk", "seed_bomb",
    "grass_knot", "rest", "substitute", "giga_drain", "energy_ball",
    "helping_hand", "grassy_terrain", "grass_pledge", "sludge_bomb",
    "solar_beam"
]
const SLEEP_TALK_FORBIDDEN_IDS: Array[String] = ["sleep_talk", "solar_beam"]

var lab_all_tms_toggle: CheckBox
var _bulba_weights_kg: Dictionary = {}
var _bulba_selected_ally_id: String = ""
var _bulba_pending_ally_move_id: String = ""
var _bulba_pending_ally_actor: Dictionary = {}
var _bulba_absorbed_damage_this_action: int = 0
var _bulba_substitute_blocked_targets: Dictionary = {}
var _bulba_grassy_terrain: Dictionary = {}
var _bulba_pledge_pending: Dictionary = {}

func _load_data() -> void:
    super._load_data()
    _bulba_load_tm_move_pack()
    _bulba_load_weights()
    _bulba_strip_tera_runtime()

func _bulba_load_tm_move_pack() -> void:
    var pack: Dictionary = _database_read_json_dictionary(BULBASAUR_TM_MOVE_PATH)
    var moves_value: Variant = pack.get("moves", {})
    if not (moves_value is Dictionary):
        push_error("Bisasam-TM-Daten konnten nicht geladen werden: " + BULBASAUR_TM_MOVE_PATH)
        return
    var runtime_moves_value: Variant = data.get("moves", {})
    if not (runtime_moves_value is Dictionary):
        runtime_moves_value = {}
        data["moves"] = runtime_moves_value
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    if not (canonical_moves_value is Dictionary):
        canonical_moves_value = {}
        _canonical_pack["moves"] = canonical_moves_value
    for move_id_value: Variant in (moves_value as Dictionary).keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
        if not (move_value is Dictionary):
            continue
        (runtime_moves_value as Dictionary)[move_id] = (move_value as Dictionary).duplicate(true)
        (canonical_moves_value as Dictionary)[move_id] = (move_value as Dictionary).duplicate(true)

func _bulba_load_weights() -> void:
    _bulba_weights_kg.clear()
    var pack: Dictionary = _database_read_json_dictionary(BULBASAUR_WEIGHT_PATH)
    var weights_value: Variant = pack.get("weights_kg", {})
    if weights_value is Dictionary:
        _bulba_weights_kg = (weights_value as Dictionary).duplicate(true)

func _bulba_strip_tera_runtime() -> void:
    var runtime_moves_value: Variant = data.get("moves", {})
    if runtime_moves_value is Dictionary:
        (runtime_moves_value as Dictionary).erase("tera_blast")

    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    if canonical_moves_value is Dictionary:
        (canonical_moves_value as Dictionary).erase("tera_blast")

    _bulba_strip_tera_from_species_dictionary(data.get("species", {}), true)
    _bulba_strip_tera_from_species_dictionary(_canonical_pack.get("species", {}), false)

func _bulba_strip_tera_from_species_dictionary(species_value: Variant, runtime_shape: bool) -> void:
    if not (species_value is Dictionary):
        return
    for entry_value: Variant in (species_value as Dictionary).values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var learnset_value: Variant = entry.get("source_learnset", {}) if runtime_shape else entry.get("learnset", {})
        if not (learnset_value is Dictionary):
            continue
        var tm_value: Variant = (learnset_value as Dictionary).get("tm_hm", {})
        if not (tm_value is Dictionary):
            continue
        var tm_map: Dictionary = tm_value
        var erase_keys: Array = []
        for tm_key: Variant in tm_map.keys():
            if str(tm_map.get(tm_key, "")) == "tera_blast":
                erase_keys.append(tm_key)
        for tm_key: Variant in erase_keys:
            tm_map.erase(tm_key)

func _build_config(root: Control) -> void:
    super._build_config(root)
    _build_lab_all_tms_toggle()

func _build_lab_all_tms_toggle() -> void:
    if config_panel == null or config_panel.get_child_count() == 0:
        return

    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer == null:
        return

    var row := HBoxContainer.new()
    row.name = "AllTMsRow"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.custom_minimum_size = Vector2(0.0, 22.0)
    outer.add_child(row)

    lab_all_tms_toggle = CheckBox.new()
    lab_all_tms_toggle.name = "AllTMsToggle"
    lab_all_tms_toggle.text = "Alle verfügbaren TMs aktivieren"
    lab_all_tms_toggle.button_pressed = false
    lab_all_tms_toggle.focus_mode = Control.FOCUS_NONE
    lab_all_tms_toggle.tooltip_text = (
        "Testmodus: Fügt jedem Pokémon alle für seine aktive Form hinterlegten "
        + "und im Kampfsystem verfügbaren TM-Attacken hinzu. Die Demo-Route bleibt unverändert."
    )
    lab_all_tms_toggle.add_theme_font_size_override("font_size", 10)
    row.add_child(lab_all_tms_toggle)

    outer.move_child(row, mini(3, outer.get_child_count() - 1))

func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["db_guard_family_chain"] = 0
    combatant["db_endure_expires_after_action"] = 0
    combatant["db_substitute_hp"] = 0
    combatant["db_substitute_max_hp"] = 0
    combatant["db_pledge_fire_expires_after_action"] = 0
    combatant["db_pledge_fire_source_id"] = ""
    combatant["db_sleep_talk_originally_asleep"] = false

    var species_id: String = str(combatant.get("species_id", setup.get("species_id", "")))
    combatant["db_weight_kg"] = float(_bulba_weights_kg.get(species_id, 0.0))

    if route_mode or lab_all_tms_toggle == null or not lab_all_tms_toggle.button_pressed:
        return combatant
    if species_id.is_empty():
        return combatant

    var moves_value: Variant = combatant.get("moves", [])
    var moves: Array = moves_value.duplicate() if moves_value is Array else []
    for move_value: Variant in _lab_available_tm_moves(species_id):
        var move_id: String = str(move_value)
        if not moves.has(move_id):
            moves.append(move_id)
    combatant["moves"] = moves
    return combatant

func _lab_available_tm_moves(species_id: String) -> Array:
    var candidates: Array = []
    var species_value: Variant = data.get("species", {})
    if not (species_value is Dictionary):
        return candidates

    var entry_value: Variant = (species_value as Dictionary).get(species_id, {})
    if not (entry_value is Dictionary):
        return candidates
    var entry: Dictionary = entry_value

    var learnset_value: Variant = entry.get("source_learnset", {})
    if not (learnset_value is Dictionary):
        return candidates
    var tm_value: Variant = (learnset_value as Dictionary).get("tm_hm", {})
    if not (tm_value is Dictionary):
        return candidates
    var tm_map: Dictionary = tm_value

    var tm_ids: Array = tm_map.keys()
    tm_ids.sort()
    for tm_id_value: Variant in tm_ids:
        var move_id: String = str(tm_map.get(tm_id_value, ""))
        if move_id.is_empty() or move_id == "tera_blast" or candidates.has(move_id):
            continue
        if _runtime_has_move(move_id):
            candidates.append(move_id)

    return _database_normal_battle_moves(candidates)

func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    var move: Dictionary = _move_data(move_id)
    if str(move.get("target", "")) != "single_ally":
        super._choose_move(move_id)
        return

    var actor: Dictionary = selected_actor
    var allies: Array = _bulba_living_other_allies(actor)
    if allies.size() <= 1:
        _bulba_selected_ally_id = str((allies[0] as Dictionary).get("id", "")) if allies.size() == 1 else ""
        super._choose_move(move_id)
        return

    _bulba_pending_ally_move_id = move_id
    _bulba_pending_ally_actor = actor
    _clear_actions()
    _set_log("[b]Rechte Hand[/b]: Verbündetes Pokémon wählen.")
    for ally_value: Variant in allies:
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        var button := Button.new()
        button.text = "🤝 " + _actor_name(ally)
        button.tooltip_text = "Dieses Pokémon mit Rechte Hand unterstützen"
        button.pressed.connect(_bulba_choose_ally_target.bind(str(ally.get("id", ""))))
        action_grid.add_child(button)

func _bulba_choose_ally_target(target_id: String) -> void:
    if _bulba_pending_ally_actor.is_empty() or _bulba_pending_ally_move_id.is_empty():
        return
    _bulba_selected_ally_id = target_id
    selected_actor = _bulba_pending_ally_actor
    var move_id: String = _bulba_pending_ally_move_id
    _bulba_pending_ally_actor = {}
    _bulba_pending_ally_move_id = ""
    super._choose_move(move_id)

func _targets(actor: Dictionary, rule: String) -> Array:
    if rule != "single_ally":
        return super._targets(actor, rule)

    var allies: Array = _bulba_living_other_allies(actor)
    for ally_value: Variant in allies:
        if ally_value is Dictionary and str((ally_value as Dictionary).get("id", "")) == _bulba_selected_ally_id:
            return [ally_value]
    if allies.is_empty():
        return []
    var best: Dictionary = allies[0]
    var best_ratio: float = _bulba_hp_ratio(best)
    for ally_value: Variant in allies:
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        var ratio: float = _bulba_hp_ratio(ally)
        if ratio < best_ratio:
            best = ally
            best_ratio = ratio
    return [best]

func _bulba_living_other_allies(actor: Dictionary) -> Array:
    var result: Array = []
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if bool(candidate.get("alive", false)) and str(candidate.get("id", "")) != str(actor.get("id", "")):
            result.append(candidate)
    return result

func _bulba_hp_ratio(combatant: Dictionary) -> float:
    return float(combatant.get("hp", 0)) / maxf(1.0, float(combatant.get("max_hp", 1)))

func _choose_wait() -> void:
    if selected_actor.is_empty():
        super._choose_wait()
        return
    var actor: Dictionary = selected_actor
    actor["db_guard_family_chain"] = 0
    _bulba_resolve_pending_pledge_before_action(actor, "__wait")
    var terrain_before: bool = _bulba_is_terrain_source(actor)
    super._choose_wait()
    _bulba_after_own_action(actor, "__wait", terrain_before)

func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    _bulba_absorbed_damage_this_action = 0
    _bulba_substitute_blocked_targets.clear()
    if move_id != "protect" and move_id != "endure":
        actor["db_guard_family_chain"] = 0

    var pledge_combo: String = _bulba_resolve_pending_pledge_before_action(actor, move_id)
    var terrain_before: bool = _bulba_is_terrain_source(actor)

    if move_id == "sleep_talk" and str(actor.get("major_status", "")) == "sleep":
        _bulba_execute_sleep_talk(actor)
        _bulba_selected_ally_id = ""
        return

    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        super._execute_move(actor, move_id)
        return

    var hp_before: Dictionary = _bulba_snapshot_target_hp(actor, move)
    var original_move: Dictionary = move.duplicate(true)
    var adjusted_move: Dictionary = move.duplicate(true)

    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    if bool(runtime.get("bulba_facade", false)) and _bulba_facade_is_boosted(actor):
        adjusted_move["power"] = 140
    if bool(runtime.get("bulba_weight_power", false)):
        adjusted_move["power"] = _bulba_grass_knot_power(actor, move)

    var prepared_pledge: bool = false
    if move_id == "grass_pledge" and pledge_combo.is_empty() and _bulba_can_prepare_grass_pledge(actor):
        prepared_pledge = true
        var target_list: Array = _targets(actor, "enemy_highest_aggro")
        var target_id: String = ""
        if not target_list.is_empty() and target_list[0] is Dictionary:
            target_id = str((target_list[0] as Dictionary).get("id", ""))
        _bulba_pledge_pending = {
            "source_id": str(actor.get("id", "")),
            "source_side": str(actor.get("side", "")),
            "target_id": target_id
        }
        adjusted_move["power"] = null
        adjusted_move["accuracy"] = null
        adjusted_move["mechanics"] = []

    if not pledge_combo.is_empty():
        adjusted_move["power"] = 150

    data["moves"][move_id] = adjusted_move
    super._execute_move(actor, move_id)
    data["moves"][move_id] = original_move

    var real_damage: int = _bulba_damage_since_snapshot(hp_before)
    if move_id == "trailblaze" and real_damage + _bulba_absorbed_damage_this_action > 0:
        _bulba_apply_trailblaze_speed(actor)
    if move_id == "giga_drain" and real_damage > 0:
        _bulba_apply_drain_heal(actor, real_damage, float(runtime.get("bulba_drain_fraction", 0.5)))
    if move_id == "energy_ball" and real_damage > 0 and randf() <= 0.10:
        _bulba_apply_energy_ball_debuff(actor, hp_before)
    if prepared_pledge:
        _spawn_feedback_label(actor, "🌿 SÄULEN BEREIT", Color("b9e893"))
        _set_log(_actor_name(actor) + " bereitet [b]Pflanzensäulen[/b] für eine mögliche Kombination vor.")
    if not pledge_combo.is_empty():
        _bulba_apply_pledge_combo_field(actor, pledge_combo)

    _bulba_after_own_action(actor, move_id, terrain_before)
    _bulba_selected_ally_id = ""

func _bulba_snapshot_target_hp(actor: Dictionary, move: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for target_value: Variant in _targets(actor, str(move.get("target", "enemy_highest_aggro"))):
        if target_value is Dictionary:
            var target: Dictionary = target_value
            result[str(target.get("id", ""))] = {"target": target, "hp": int(target.get("hp", 0))}
    return result

func _bulba_damage_since_snapshot(snapshot: Dictionary) -> int:
    var total: int = 0
    for snapshot_value: Variant in snapshot.values():
        if not (snapshot_value is Dictionary):
            continue
        var entry: Dictionary = snapshot_value
        var target_value: Variant = entry.get("target", {})
        if target_value is Dictionary:
            total += maxi(0, int(entry.get("hp", 0)) - int((target_value as Dictionary).get("hp", 0)))
    return total

func _bulba_facade_is_boosted(actor: Dictionary) -> bool:
    var status: String = str(actor.get("major_status", ""))
    return status in ["burn", "poison", "bad_poison", "paralysis"] or bool(actor.get("paralyzed", false))

func _bulba_grass_knot_power(actor: Dictionary, move: Dictionary) -> int:
    var targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    if targets.is_empty() or not (targets[0] is Dictionary):
        return 20
    var weight: float = float((targets[0] as Dictionary).get("db_weight_kg", 0.0))
    if weight < 10.0:
        return 20
    if weight < 25.0:
        return 40
    if weight < 50.0:
        return 60
    if weight < 100.0:
        return 80
    if weight < 200.0:
        return 100
    return 120

func _bulba_apply_trailblaze_speed(actor: Dictionary) -> void:
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var type_bonus: float = TypeSystem.get_same_type_status_multiplier("grass", _type_array(actor.get("types", [])))
    var multiplier: float = 1.0 / (1.0 + ratio * type_bonus)
    _bulba_refresh_timed_modifier(actor, "atb_cycle_mod", multiplier, "Wegbereiter", _actor_name(actor))
    actor["aggro"] = float(actor.get("aggro", 0.0)) + _status_effect_aggro("atb_cycle_mod", multiplier)
    _spawn_feedback_label(actor, "GESCHWINDIGKEIT ↑ · 3 AKTIONEN", Color("a8e7a2"))

func _bulba_apply_energy_ball_debuff(actor: Dictionary, snapshot: Dictionary) -> void:
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var type_bonus: float = TypeSystem.get_same_type_status_multiplier("grass", _type_array(actor.get("types", [])))
    var multiplier: float = 1.0 / (1.0 + ratio * type_bonus)
    for snapshot_value: Variant in snapshot.values():
        if not (snapshot_value is Dictionary):
            continue
        var target_value: Variant = (snapshot_value as Dictionary).get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if int((snapshot_value as Dictionary).get("hp", 0)) <= int(target.get("hp", 0)):
            continue
        _bulba_refresh_timed_modifier(target, "incoming_damage_mod", multiplier, "Energieball", _actor_name(actor))
        actor["aggro"] = float(actor.get("aggro", 0.0)) + _status_effect_aggro("incoming_damage_mod", multiplier)
        _spawn_feedback_label(target, "VERTEIDIGUNG ↓ · 3 AKTIONEN", Color("d9b0a4"))

func _bulba_apply_drain_heal(actor: Dictionary, damage: int, fraction: float) -> void:
    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    if missing <= 0:
        return
    var heal: int = mini(missing, maxi(1, int(floor(float(damage) * clampf(fraction, 0.0, 1.0)))))
    actor["hp"] = int(actor.get("hp", 0)) + heal
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(heal)
    _spawn_feedback_label(actor, "💚 +" + str(heal) + " KP", Color("8fe39b"))

func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    if _bulba_substitute_blocks_effect(actor, target, mechanic):
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return 0.0

    match kind:
        "db_protect":
            return _bulba_guard_attempt(actor, false)
        "bulba_endure":
            return _bulba_guard_attempt(actor, true)
        "bulba_rest":
            return _bulba_rest(actor)
        "bulba_sleep_talk":
            _spawn_feedback_label(actor, "💤 NUR IM SCHLAF", Color("c8b9e8"))
            return 0.0
        "bulba_substitute":
            return _bulba_create_substitute(actor)
        "bulba_grassy_terrain":
            return _bulba_activate_grassy_terrain(actor)
        "bulba_helping_hand":
            return _bulba_helping_hand(actor, target)
        "bulba_self_speed_boost":
            _bulba_apply_trailblaze_speed(actor)
            return 0.0
    return super._effect(actor, target, mechanic)

func _bulba_refresh_timed_modifier(
    target: Dictionary,
    kind: String,
    multiplier: float,
    source_move: String,
    source_actor: String
) -> void:
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    var kept: Array = []
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if not (modifier_value is Dictionary):
                continue
            var modifier: Dictionary = modifier_value
            if str(modifier.get("kind", "")) == kind and str(modifier.get("source_move", "")) == source_move:
                continue
            kept.append(modifier)
    target["timed_modifiers"] = kept
    _add_timed_modifier(target, kind, multiplier, source_move, source_actor)

func _bulba_helping_hand(actor: Dictionary, target: Dictionary) -> float:
    if str(actor.get("id", "")) == str(target.get("id", "")):
        return 0.0
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var multiplier: float = 1.0 + ratio
    _bulba_refresh_timed_modifier(target, "outgoing_damage_mod", multiplier, "Rechte Hand", _actor_name(actor))
    _spawn_feedback_label(target, "ANGRIFF " + _signed_percent_delta(multiplier) + " · 3 AKTIONEN", Color("a8e7a2"))
    return _status_effect_aggro("outgoing_damage_mod", multiplier)

func _bulba_guard_attempt(actor: Dictionary, endure: bool) -> float:
    var chain: int = maxi(0, int(actor.get("db_guard_family_chain", 0)))
    var chance: float = pow(1.0 / 3.0, float(chain))
    actor["db_guard_family_chain"] = chain + 1
    if randf() > chance:
        _spawn_feedback_label(actor, "✖ SCHUTZ FEHLGESCHLAGEN", Color("d9a5a5"))
        return 0.0
    if endure:
        actor["db_endure_expires_after_action"] = int(actor.get("action_serial", 0)) + 3
        _spawn_feedback_label(actor, "💪 AUSDAUER · 3 AKTIONEN", Color("f1d88d"))
    else:
        actor["protective_guard"] = true
        _spawn_feedback_label(actor, "🛡️ SCHUTZSCHILD", Color("9fe7bd"))
    return 4.0

func _bulba_rest(actor: Dictionary) -> float:
    if bool(actor.get("db_sleep_talk_originally_asleep", false)):
        _spawn_feedback_label(actor, "✖ ERHOLUNG FEHLGESCHLAGEN", Color("d9a5a5"))
        return 0.0
    if int(actor.get("hp", 0)) >= int(actor.get("max_hp", 1)):
        _spawn_feedback_label(actor, "✖ KP BEREITS VOLL", Color("d9a5a5"))
        return 0.0
    if _database_status_is_blocked(actor, "sleep"):
        _spawn_feedback_label(actor, "🛡️ SCHLAF VERHINDERT", Color("b8d9ff"))
        return 0.0

    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    var had_major_status: bool = not str(actor.get("major_status", "")).is_empty() or bool(actor.get("paralyzed", false))
    actor["hp"] = int(actor.get("max_hp", 1))
    actor["major_status"] = "sleep"
    actor["paralyzed"] = false
    actor["db_sleep_actions"] = 2
    _spawn_feedback_label(actor, "🛌 VOLLE KP · SCHLAF 2", Color("bfc8ff"))
    return float(missing) + (3.0 if had_major_status else 0.0)

func _bulba_create_substitute(actor: Dictionary) -> float:
    if int(actor.get("db_substitute_hp", 0)) > 0:
        _spawn_feedback_label(actor, "🧸 DELEGATOR BEREITS AKTIV", Color("edcf9b"))
        return 0.0
    var cost: int = maxi(1, int(floor(float(actor.get("max_hp", 1)) * 0.25)))
    if int(actor.get("hp", 0)) <= cost:
        _spawn_feedback_label(actor, "✖ ZU WENIG KP", Color("d9a5a5"))
        return 0.0
    actor["hp"] = int(actor.get("hp", 0)) - cost
    actor["db_substitute_hp"] = cost
    actor["db_substitute_max_hp"] = cost
    _spawn_feedback_label(actor, "🧸 DELEGATOR " + str(cost) + " KP", Color("edcf9b"))
    return 4.0

func _bulba_activate_grassy_terrain(actor: Dictionary) -> float:
    _bulba_grassy_terrain = {
        "source_id": str(actor.get("id", "")),
        "source_side": str(actor.get("side", "")),
        "expires_after_action": int(actor.get("action_serial", 0)) + 3
    }
    _spawn_feedback_label(actor, "🌱 GRASFELD · 3 AKTIONEN", Color("9ee28d"))
    return 4.0

func _database_any_target_damaged(snapshots: Dictionary) -> bool:
    return _bulba_absorbed_damage_this_action > 0 or super._database_any_target_damaged(snapshots)

func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0:
        return damage

    if _bulba_grassy_terrain_active() and move_type == "grass" and _bulba_is_grounded(actor):
        damage = maxi(1, int(round(float(damage) * 1.30)))

    var hostile: bool = str(actor.get("side", "")) != str(target.get("side", ""))
    if hostile and int(target.get("db_substitute_hp", 0)) > 0 and not _bulba_current_move_ignores_substitute():
        var substitute_hp: int = int(target.get("db_substitute_hp", 0))
        var absorbed: int = mini(substitute_hp, damage)
        target["db_substitute_hp"] = maxi(0, substitute_hp - damage)
        _bulba_absorbed_damage_this_action += absorbed
        _bulba_substitute_blocked_targets[str(target.get("id", ""))] = true
        actor["aggro"] = float(actor.get("aggro", 0.0)) + float(absorbed)
        if int(target.get("db_substitute_hp", 0)) <= 0:
            _spawn_feedback_label(target, "🧸 DELEGATOR ZERSTÖRT", Color("e6b18c"))
        else:
            _spawn_feedback_label(target, "🧸 −" + str(absorbed) + " KP", Color("edcf9b"))
        return 0

    if hostile and _bulba_endure_active(target):
        var allowed: int = maxi(0, int(target.get("hp", 0)) - 1)
        if damage > allowed:
            damage = allowed
            _spawn_feedback_label(target, "💪 HÄLT DURCH", Color("f1d88d"))
    return damage

func _bulba_endure_active(target: Dictionary) -> bool:
    return int(target.get("action_serial", 0)) < int(target.get("db_endure_expires_after_action", 0))

func _bulba_current_move_ignores_substitute() -> bool:
    var runtime_value: Variant = _database_active_move.get("runtime", {})
    return runtime_value is Dictionary and bool((runtime_value as Dictionary).get("ignore_substitute", false))

func _bulba_substitute_blocks_effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> bool:
    if str(actor.get("side", "")) == str(target.get("side", "")):
        return false
    if _bulba_current_move_ignores_substitute():
        return false
    var target_id: String = str(target.get("id", ""))
    if int(target.get("db_substitute_hp", 0)) <= 0 and not bool(_bulba_substitute_blocked_targets.get(target_id, false)):
        return false

    var kind: String = str(mechanic.get("kind", ""))
    if kind in ["status", "db_status", "binding", "seed", "atb_knockback", "db_atb_pause", "db_incoming_accuracy"]:
        return true
    var weight: float = float(mechanic.get("multiplier_from_special", 0.0))
    if kind == "outgoing_damage_mod" and weight < 0.0:
        return true
    if kind == "incoming_damage_mod" and weight > 0.0:
        return true
    if kind == "accuracy_mod" and weight < 0.0:
        return true
    if kind == "atb_cycle_mod" and weight > 0.0:
        return true
    return false

func _bulba_execute_sleep_talk(actor: Dictionary) -> void:
    var candidates: Array = []
    var moves_value: Variant = actor.get("moves", [])
    if moves_value is Array:
        for move_value: Variant in moves_value:
            var candidate_id: String = str(move_value)
            if SLEEP_TALK_FORBIDDEN_IDS.has(candidate_id):
                continue
            var candidate: Dictionary = _move_data(candidate_id)
            if candidate.is_empty():
                continue
            var runtime_value: Variant = candidate.get("runtime", {})
            if runtime_value is Dictionary and not bool((runtime_value as Dictionary).get("sleep_talk_eligible", true)):
                continue
            if _runtime_has_move(candidate_id):
                candidates.append(candidate_id)

    var sleep_left: int = maxi(0, int(actor.get("db_sleep_actions", 0)))
    var remaining: int = maxi(0, sleep_left - 1)
    if candidates.is_empty():
        actor["major_status"] = ""
        _execute_move(actor, "sleep_talk")
        actor["major_status"] = "sleep" if remaining > 0 else ""
        actor["db_sleep_actions"] = remaining
        return

    var chosen_id: String = str(candidates.pick_random())
    var chosen: Dictionary = _move_data(chosen_id)
    var original: Dictionary = chosen.duplicate(true)
    var sleep_talk: Dictionary = _move_data("sleep_talk")
    var triggered: Dictionary = chosen.duplicate(true)
    triggered["ap"] = int(sleep_talk.get("ap", 7))
    triggered["name"] = "Schlafrede → " + str(chosen.get("name", chosen_id))

    data["moves"][chosen_id] = triggered
    actor["db_sleep_talk_originally_asleep"] = true
    actor["major_status"] = ""
    _spawn_feedback_label(actor, "😴 → " + str(chosen.get("name", chosen_id)), Color("c8b9e8"))
    _execute_move(actor, chosen_id)
    data["moves"][chosen_id] = original
    actor["db_sleep_talk_originally_asleep"] = false

    if not bool(actor.get("alive", false)):
        return
    if remaining > 0:
        actor["major_status"] = "sleep"
        actor["db_sleep_actions"] = remaining
    else:
        if str(actor.get("major_status", "")) == "sleep":
            actor["major_status"] = ""
        actor["db_sleep_actions"] = 0
        _spawn_feedback_label(actor, "✨ WACHT AUF", Color("f0e7a6"))

func _bulba_is_grounded(combatant: Dictionary) -> bool:
    return not _type_array(combatant.get("types", [])).has("flying")

func _bulba_grassy_terrain_active() -> bool:
    _bulba_validate_grassy_terrain()
    return not _bulba_grassy_terrain.is_empty()

func _bulba_is_terrain_source(actor: Dictionary) -> bool:
    return _bulba_grassy_terrain_active() and str(_bulba_grassy_terrain.get("source_id", "")) == str(actor.get("id", ""))

func _bulba_validate_grassy_terrain() -> void:
    if _bulba_grassy_terrain.is_empty():
        return
    var source_id: String = str(_bulba_grassy_terrain.get("source_id", ""))
    var source: Dictionary = _bulba_find_combatant(source_id)
    if source.is_empty() or not bool(source.get("alive", false)):
        _bulba_grassy_terrain.clear()
        return
    if int(source.get("action_serial", 0)) > int(_bulba_grassy_terrain.get("expires_after_action", 0)):
        _bulba_grassy_terrain.clear()

func _bulba_after_own_action(actor: Dictionary, move_id: String, terrain_was_active_before: bool) -> void:
    if terrain_was_active_before and _bulba_is_terrain_source(actor) and move_id != "grassy_terrain":
        _bulba_grassy_pulse(actor)
        if int(actor.get("action_serial", 0)) >= int(_bulba_grassy_terrain.get("expires_after_action", 0)):
            _bulba_grassy_terrain.clear()
    _bulba_tick_fire_pledge_field(actor)
    _refresh_cards()

func _bulba_grassy_pulse(source: Dictionary) -> void:
    var source_aggro: float = 0.0
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)) or not _bulba_is_grounded(combatant):
            continue
        var missing: int = maxi(0, int(combatant.get("max_hp", 1)) - int(combatant.get("hp", 0)))
        if missing <= 0:
            continue
        var heal: int = mini(missing, maxi(1, int(floor(float(combatant.get("max_hp", 1)) / 16.0))))
        combatant["hp"] = int(combatant.get("hp", 0)) + heal
        _spawn_feedback_label(combatant, "🌱 +" + str(heal) + " KP", Color("9ee28d"))
        if str(combatant.get("side", "")) == str(source.get("side", "")):
            source_aggro += float(heal)
    source["aggro"] = float(source.get("aggro", 0.0)) + source_aggro

func _bulba_can_prepare_grass_pledge(actor: Dictionary) -> bool:
    for ally_value: Variant in _bulba_living_other_allies(actor):
        if not (ally_value is Dictionary):
            continue
        var moves_value: Variant = (ally_value as Dictionary).get("moves", [])
        if not (moves_value is Array):
            continue
        for pledge_id: String in ["fire_pledge", "water_pledge"]:
            if (moves_value as Array).has(pledge_id) and _runtime_has_move(pledge_id):
                return true
    return false

func _bulba_resolve_pending_pledge_before_action(actor: Dictionary, move_id: String) -> String:
    if _bulba_pledge_pending.is_empty():
        return ""
    if str(actor.get("side", "")) != str(_bulba_pledge_pending.get("source_side", "")):
        return ""
    if str(actor.get("id", "")) == str(_bulba_pledge_pending.get("source_id", "")):
        return ""

    if move_id == "fire_pledge" or move_id == "water_pledge":
        var combo: String = "fire" if move_id == "fire_pledge" else "water"
        _bulba_pledge_pending.clear()
        return combo

    _bulba_resolve_pending_grass_pledge()
    return ""

func _bulba_resolve_pending_grass_pledge() -> void:
    if _bulba_pledge_pending.is_empty():
        return
    var source: Dictionary = _bulba_find_combatant(str(_bulba_pledge_pending.get("source_id", "")))
    var target: Dictionary = _bulba_find_combatant(str(_bulba_pledge_pending.get("target_id", "")))
    if source.is_empty() or not bool(source.get("alive", false)):
        _bulba_pledge_pending.clear()
        return
    if target.is_empty() or not bool(target.get("alive", false)):
        var targets: Array = super._targets(source, "enemy_highest_aggro")
        if not targets.is_empty() and targets[0] is Dictionary:
            target = targets[0]
    if not target.is_empty():
        var damage: int = _damage(source, target, 80, "grass", "special")
        if damage > 0:
            target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
            target["alive"] = int(target.get("hp", 0)) > 0
            source["aggro"] = float(source.get("aggro", 0.0)) + float(damage)
            target["aggro"] = float(target.get("aggro", 0.0)) * 0.5
            _spawn_feedback_label(target, "🌿 −" + str(damage) + " KP", Color("a9dc8e"))
            _set_log(_actor_name(source) + " löst [b]Pflanzensäulen[/b] normal aus → " + str(damage) + " Schaden.")
    _bulba_pledge_pending.clear()
    _check_end()

func _bulba_apply_pledge_combo_field(finisher: Dictionary, combo: String) -> void:
    var opponents: Array = _living_opponents(finisher)
    if combo == "water":
        for target_value: Variant in opponents:
            if target_value is Dictionary:
                var target: Dictionary = target_value
                _add_timed_modifier(target, "atb_cycle_mod", 2.0, "Moor", _actor_name(finisher))
                _spawn_feedback_label(target, "🌫️ GESCHWINDIGKEIT −50% · 3 AKTIONEN", Color("a8c5a0"))
        return
    if combo == "fire":
        for target_value: Variant in opponents:
            if not (target_value is Dictionary):
                continue
            var target: Dictionary = target_value
            target["db_pledge_fire_expires_after_action"] = int(target.get("action_serial", 0)) + 3
            target["db_pledge_fire_source_id"] = str(finisher.get("id", ""))
            _spawn_feedback_label(target, "🔥 FEUERMEER · 3 AKTIONEN", Color("efb07c"))

func _bulba_tick_fire_pledge_field(actor: Dictionary) -> void:
    var expires: int = int(actor.get("db_pledge_fire_expires_after_action", 0))
    if expires <= 0:
        return
    var current: int = int(actor.get("action_serial", 0))
    if current > expires:
        actor["db_pledge_fire_expires_after_action"] = 0
        actor["db_pledge_fire_source_id"] = ""
        return
    if not _type_array(actor.get("types", [])).has("fire") and bool(actor.get("alive", false)):
        var damage: int = mini(int(actor.get("hp", 0)), maxi(1, int(floor(float(actor.get("max_hp", 1)) / 8.0))))
        actor["hp"] = maxi(0, int(actor.get("hp", 0)) - damage)
        actor["alive"] = int(actor.get("hp", 0)) > 0
        _spawn_feedback_label(actor, "🔥 −" + str(damage) + " KP", Color("ef936c"))
        var source: Dictionary = _bulba_find_combatant(str(actor.get("db_pledge_fire_source_id", "")))
        if not source.is_empty():
            source["aggro"] = float(source.get("aggro", 0.0)) + float(damage)
    if current >= expires:
        actor["db_pledge_fire_expires_after_action"] = 0
        actor["db_pledge_fire_source_id"] = ""

func _bulba_find_combatant(combatant_id: String) -> Dictionary:
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary and str((candidate_value as Dictionary).get("id", "")) == combatant_id:
            return candidate_value
    return {}

func _refresh_cards() -> void:
    _bulba_validate_grassy_terrain()
    super._refresh_cards()
    _bulba_refresh_substitute_markers()

func _bulba_refresh_substitute_markers() -> void:
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var card_value: Variant = cards.get(str(combatant.get("id", "")), {})
        if not (card_value is Dictionary):
            continue
        var texture_value: Variant = (card_value as Dictionary).get("texture", null)
        if not (texture_value is TextureRect):
            continue
        var texture: TextureRect = texture_value
        var marker: Label = texture.get_node_or_null("SubstituteMarker") as Label
        if marker == null:
            marker = Label.new()
            marker.name = "SubstituteMarker"
            marker.text = "🧸"
            marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
            marker.z_index = 30
            marker.add_theme_font_size_override("font_size", 18)
            texture.add_child(marker)
        var active: bool = int(combatant.get("db_substitute_hp", 0)) > 0 and bool(combatant.get("alive", false))
        marker.visible = active
        if active:
            if str(combatant.get("side", "")) == "player":
                marker.position = Vector2(23.0, 14.0)
            else:
                marker.position = Vector2(-5.0, 14.0)

func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if int(combatant.get("db_substitute_hp", 0)) > 0:
        tokens.append("🧸 " + str(combatant.get("db_substitute_hp", 0)) + " KP")
    if _bulba_endure_active(combatant):
        tokens.append("💪 AUSDAUER")
    if _bulba_grassy_terrain_active() and _bulba_is_grounded(combatant):
        tokens.append("🌱 GRASFELD")
    return tokens

func _detail_info(combatant: Dictionary) -> String:
    var text: String = super._detail_info(combatant)
    var extra: Array[String] = []
    if int(combatant.get("db_substitute_hp", 0)) > 0:
        extra.append("🧸 Delegator: %d/%d KP" % [int(combatant.get("db_substitute_hp", 0)), int(combatant.get("db_substitute_max_hp", 0))])
    if _bulba_endure_active(combatant):
        var remaining: int = maxi(0, int(combatant.get("db_endure_expires_after_action", 0)) - int(combatant.get("action_serial", 0)))
        extra.append("💪 Ausdauer: noch %d eigene Aktion(en)" % remaining)
    if _bulba_grassy_terrain_active():
        extra.append("🌱 Grasfeld: Pflanzen-Attacken am Boden +30 %, Heilpuls 1/16 max. KP")
    if extra.is_empty():
        return text
    return text + "\n\n[b]SONDEREFFEKTE[/b]\n• " + "\n• ".join(extra)
