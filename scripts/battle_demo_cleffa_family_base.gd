extends "res://scripts/battle_demo_rattata_family.gd"

# Pii / Piepi / Pixi integration (Pokemon Timeflow).
# This layer is intentionally inserted into the active BattleDemo chain.
# It loads the V5/V14 spreadsheet-derived family data and owns only mechanics
# that do not already exist in the central runtime.

const CLEFFA_SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_cleffa_family_v1.json"
const CLEFFA_MOVE_PACK_PATHS: Array[String] = [
    "res://data/gen1_moves_runtime_v3_22_1_cleffa_family.json",
    "res://data/gen1_moves_runtime_v3_22_2_cleffa_family.json",
    "res://data/gen1_moves_runtime_v3_22_3_cleffa_family.json"
]

const CLEFFA_GRAVITY_BLOCKED: Array[String] = [
    "splash", "fly", "bounce", "flying_press", "high_jump_kick",
    "jump_kick", "magnet_rise", "sky_drop", "telekinesis"
]
const CLEFFA_COPY_CALL_EXCLUDED: Array[String] = ["copycat", "metronome", "sleep_talk"]
const CLEFFA_MAIN_STATUS_IDS: Array[String] = [
    "sleep", "paralysis", "burn", "poison", "bad_poison", "freeze", "confusion"
]

var _cleffa_last_resolved_move_id: String = ""
var _cleffa_indirect_call_depth: int = 0
var _cleffa_active_move_id: String = ""
var _cleffa_gravity: Dictionary = {}
var _cleffa_misty_terrain: Dictionary = {}
var _cleffa_future_sight_events: Array = []

func _load_data() -> void:
    super._load_data()
    _cleffa_load_family_data()

func _cleffa_load_family_data() -> void:
    var species_pack: Dictionary = _database_read_json_dictionary(CLEFFA_SPECIES_PACK_PATH)
    var runtime_moves_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_moves_value if runtime_moves_value is Dictionary else {}
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_moves_value if canonical_moves_value is Dictionary else {}
    for move_pack_path: String in CLEFFA_MOVE_PACK_PATHS:
        var move_pack: Dictionary = _database_read_json_dictionary(move_pack_path)
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

    if not species_ids.has("cleffa"):
        species_ids.append("cleffa")
    data["species_order"] = species_ids.duplicate()

func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["cleffa_imprison_active"] = false
    combatant["cleffa_meteor_beam_charging"] = false
    combatant["cleffa_meteor_beam_firing"] = false
    return combatant

func _process(delta: float) -> void:
    if battle_active and not paused and not opening_phase_active and not _cleffa_future_sight_events.is_empty():
        var ready_events: Array = []
        for event_value: Variant in _cleffa_future_sight_events:
            if not (event_value is Dictionary):
                continue
            var event: Dictionary = event_value
            event["remaining"] = maxf(0.0, float(event.get("remaining", 0.0)) - delta)
            if float(event.get("remaining", 0.0)) <= 0.0:
                ready_events.append(event)
        for event_value: Variant in ready_events:
            if event_value is Dictionary:
                _cleffa_resolve_future_sight(event_value as Dictionary)
                _cleffa_future_sight_events.erase(event_value)
    super._process(delta)

func _prompt_player(actor: Dictionary) -> void:
    if bool(actor.get("cleffa_meteor_beam_charging", false)):
        actor["cleffa_meteor_beam_firing"] = true
        _execute_move(actor, "meteor_beam")
        return
    super._prompt_player(actor)

func _enemy_act(actor: Dictionary) -> void:
    if bool(actor.get("cleffa_meteor_beam_charging", false)):
        actor["cleffa_meteor_beam_firing"] = true
        _execute_move(actor, "meteor_beam")
        return
    if _database_run_forced_action(actor):
        return
    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        _cleffa_enemy_wait(actor)
        return
    var legal: Array[String] = []
    for move_value: Variant in moves_value:
        var move_id: String = str(move_value)
        if move_id.is_empty() or not _runtime_has_move(move_id):
            continue
        if _cleffa_move_is_imprisoned(actor, move_id):
            continue
        if _cleffa_gravity_is_active() and _cleffa_move_gravity_blocked(move_id):
            continue
        legal.append(move_id)
    if legal.is_empty():
        _cleffa_enemy_wait(actor)
        return
    var move_id: String = legal.pick_random()
    var move: Dictionary = _move_data(move_id)
    if str(move.get("target", "")) == "single_ally":
        var allies: Array = _bulba_living_other_allies(actor)
        if allies.is_empty():
            _cleffa_enemy_wait(actor)
            return
        var ally: Dictionary = allies.pick_random()
        _bulba_selected_ally_id = str(ally.get("id", ""))
    _execute_move(actor, move_id)

func _cleffa_enemy_wait(actor: Dictionary) -> void:
    _begin_counted_action(actor)
    actor["aggro"] = float(actor.get("aggro", 0.0)) * 0.55
    actor["atb"] = 0.0
    actor["cycle"] = 0.70
    _expire_finished_modifiers(actor)
    _set_log(_actor_name(actor) + " wartet.")
    _refresh_cards()

func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    var actor: Dictionary = selected_actor
    if _cleffa_move_is_imprisoned(actor, move_id):
        _set_log("🚫 Begrenzer blockiert " + str(_move_data(move_id).get("name", move_id)) + ".")
        return
    if _cleffa_gravity_is_active() and _cleffa_move_gravity_blocked(move_id):
        _set_log("🌍 Diese Attacke ist unter Erdanziehung nicht einsetzbar.")
        return
    if move_id == "trick":
        var allies: Array = _bulba_living_other_allies(actor)
        if allies.is_empty():
            _set_log("Trickbetrug braucht ein anderes aktives verbündetes Pokémon.")
            return
        if allies.size() == 1:
            var only_ally: Dictionary = allies[0]
            _bulba_selected_ally_id = str(only_ally.get("id", ""))
            super._choose_move(move_id)
            return
        _bulba_pending_ally_move_id = move_id
        _bulba_pending_ally_actor = actor
        _clear_actions()
        for ally_value: Variant in allies:
            if not (ally_value is Dictionary):
                continue
            var ally: Dictionary = ally_value
            var button := Button.new()
            button.text = "🔄 " + _actor_name(ally)
            button.tooltip_text = "Aggro mit diesem verbündeten Pokémon tauschen"
            button.pressed.connect(_bulba_choose_ally_target.bind(str(ally.get("id", ""))))
            action_grid.add_child(button)
        return
    super._choose_move(move_id)

func _cleffa_gravity_is_active() -> bool:
    if _cleffa_gravity.is_empty():
        return false
    var source: Dictionary = _cleffa_find_combatant(str(_cleffa_gravity.get("source_id", "")))
    if source.is_empty() or not bool(source.get("alive", false)):
        _cleffa_gravity = {}
        return false
    return int(source.get("action_serial", 0)) <= int(_cleffa_gravity.get("expires_after_action", -1))

func _cleffa_move_gravity_blocked(move_id: String) -> bool:
    if CLEFFA_GRAVITY_BLOCKED.has(move_id):
        return true
    var runtime_value: Variant = _move_data(move_id).get("runtime", {})
    return runtime_value is Dictionary and bool((runtime_value as Dictionary).get("gravity_blocked", false))

func _cleffa_misty_is_active() -> bool:
    if _cleffa_misty_terrain.is_empty():
        return false
    var source: Dictionary = _cleffa_find_combatant(str(_cleffa_misty_terrain.get("source_id", "")))
    if source.is_empty() or not bool(source.get("alive", false)):
        _cleffa_misty_terrain = {}
        return false
    return int(source.get("action_serial", 0)) <= int(_cleffa_misty_terrain.get("expires_after_action", -1))

func _cleffa_is_grounded(target: Dictionary) -> bool:
    if _cleffa_gravity_is_active():
        return true
    return _tf_is_grounded(target)

func _database_status_is_blocked(target: Dictionary, status_id: String) -> bool:
    if _cleffa_misty_is_active() and _cleffa_is_grounded(target) and CLEFFA_MAIN_STATUS_IDS.has(status_id):
        return true
    return super._database_status_is_blocked(target, status_id)

func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    var status_id: String = str(mechanic.get("status", ""))
    if kind in ["status", "db_status"] and status_id == "sleep" and _cleffa_uproar_is_active():
        _spawn_feedback_label(target, "📣 SCHLAF BLOCKIERT", Color("f2cc8f"))
        return 0.0
    return super._effect(actor, target, mechanic)

func _cleffa_uproar_is_active() -> bool:
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if bool(candidate.get("alive", false)) and str(candidate.get("db_forced_move_id", "")) == "uproar":
            return true
    return _cleffa_active_move_id == "uproar"

func _cleffa_move_is_imprisoned(actor: Dictionary, move_id: String) -> bool:
    if move_id.is_empty() or _cleffa_indirect_call_depth > 0:
        return false
    for opponent_value: Variant in _living_opponents(actor):
        if not (opponent_value is Dictionary):
            continue
        var opponent: Dictionary = opponent_value
        if not bool(opponent.get("cleffa_imprison_active", false)):
            continue
        var known_value: Variant = opponent.get("moves", [])
        if known_value is Array and (known_value as Array).has(move_id):
            return true
    return false

func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var original_attack: Variant = actor.get("attack", 0)
    if _cleffa_active_move_id == "psyshock":
        actor["attack"] = actor.get("special", original_attack)
    var damage: int = super._damage(actor, target, power, move_type, category)
    actor["attack"] = original_attack
    if damage <= 0:
        return damage
    if _cleffa_misty_is_active() and move_type == "dragon" and _cleffa_is_grounded(target):
        damage = maxi(1, int(round(float(damage) * (1.0 - float(_cleffa_misty_terrain.get("dragon_reduction", 0.0))))))
    return damage

func _resolve_after_action_effects(combatant: Dictionary) -> void:
    super._resolve_after_action_effects(combatant)
    if not _cleffa_gravity.is_empty() and str(combatant.get("id", "")) == str(_cleffa_gravity.get("source_id", "")):
        if int(combatant.get("action_serial", 0)) >= int(_cleffa_gravity.get("expires_after_action", 999999)):
            _cleffa_gravity = {}
    if not _cleffa_misty_terrain.is_empty() and str(combatant.get("id", "")) == str(_cleffa_misty_terrain.get("source_id", "")):
        if int(combatant.get("action_serial", 0)) >= int(_cleffa_misty_terrain.get("expires_after_action", 999999)):
            _cleffa_misty_terrain = {}

func _cleffa_find_combatant(combatant_id: String) -> Dictionary:
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            if str(candidate.get("id", "")) == combatant_id:
                return candidate
    return {}
