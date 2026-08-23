extends "res://scripts/battle_demo_families_31_40_runtime_v1.gd"

# Families 41 -> 64 / Gen-1 finish (V22).
# Data loading, combatant state and the one genuinely new UI choice (Conversion)
# live here. Combat logic stays in the higher effect/runtime layers.

const F64_MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_30_families_41_64.json"
const F64_ALL_TYPES: Array[String] = [
    "normal", "fire", "water", "electric", "grass", "ice", "fighting",
    "poison", "ground", "flying", "psychic", "bug", "rock", "ghost",
    "dragon", "dark", "steel", "fairy"
]

var _f64_conversion_type_choice_by_actor: Dictionary = {}
var _f64_stealth_rock_by_side: Dictionary = {}


func _load_data() -> void:
    super._load_data()
    _f64_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _f64_load_move_pack() -> void:
    var text: String = FileAccess.get_file_as_string(F64_MOVE_PACK_PATH)
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary):
        push_error("Familien-41-64-Attackenpaket konnte nicht gelesen werden: " + F64_MOVE_PACK_PATH)
        return

    var entries_value: Variant = (parsed as Dictionary).get("moves", {})
    if not (entries_value is Dictionary):
        push_error("Familien-41-64-Attackenpaket besitzt kein moves-Dictionary.")
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
    combatant["f64_torment_expires_serial"] = -1
    combatant["f64_last_action_move"] = ""
    combatant["f64_last_used_move_type"] = ""
    combatant["f64_mist_expires_serial"] = -1

    combatant["f64_wish_pending"] = false
    combatant["f64_wish_trigger_serial"] = -1
    combatant["f64_wish_amount"] = 0

    combatant["f64_guard_split_active"] = false
    combatant["f64_guard_split_original_defense"] = int(combatant.get("defense", 1))
    combatant["f64_guard_split_expires_serial"] = -1

    combatant["f64_transformed"] = false
    return combatant


func _start_battle() -> void:
    _f64_conversion_type_choice_by_actor.clear()
    _f64_stealth_rock_by_side.clear()
    super._start_battle()


func open_config() -> void:
    _f64_conversion_type_choice_by_actor.clear()
    _f64_stealth_rock_by_side.clear()
    super.open_config()


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return

    if move_id == "conversion":
        var actor_id: String = str(selected_actor.get("id", ""))
        if str(_f64_conversion_type_choice_by_actor.get(actor_id, "")).is_empty():
            _f64_show_conversion_type_picker(selected_actor)
            return

    super._choose_move(move_id)


func _f64_show_conversion_type_picker(actor: Dictionary) -> void:
    var valid_types: Array[String] = _f64_valid_conversion_types(actor)
    if valid_types.is_empty():
        _spawn_feedback_label(actor, "✖ KEIN NEUER TYP", Color("d9a5a5"))
        _set_log("Umwandlung hat keinen gültigen neuen Typ.")
        _prompt_player(actor)
        return

    paused = true
    selected_actor = actor
    _clear_actions()
    _set_log("[b]%s[/b]: Typ für Umwandlung wählen." % _actor_name(actor))

    for type_id: String in valid_types:
        var button := Button.new()
        button.text = _type_name(type_id)
        button.custom_minimum_size = Vector2(135, 29)
        button.pressed.connect(_f64_confirm_conversion_type.bind(actor, type_id))
        action_grid.add_child(button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.custom_minimum_size = Vector2(135, 29)
    back_button.pressed.connect(_f64_cancel_conversion_type_picker.bind(actor))
    action_grid.add_child(back_button)


func _f64_confirm_conversion_type(actor: Dictionary, type_id: String) -> void:
    if actor.is_empty():
        return
    _f64_conversion_type_choice_by_actor[str(actor.get("id", ""))] = type_id
    selected_actor = actor
    call_deferred("_choose_move", "conversion")


func _f64_cancel_conversion_type_picker(actor: Dictionary) -> void:
    _f64_conversion_type_choice_by_actor.erase(str(actor.get("id", "")))
    _prompt_player(actor)


func _f64_take_conversion_type_choice(actor: Dictionary) -> String:
    var actor_id: String = str(actor.get("id", ""))
    var chosen: String = str(_f64_conversion_type_choice_by_actor.get(actor_id, ""))
    _f64_conversion_type_choice_by_actor.erase(actor_id)
    if not chosen.is_empty():
        return chosen

    var options: Array[String] = _f64_valid_conversion_types(actor)
    return "" if options.is_empty() else options.pick_random()


func _f64_valid_conversion_types(actor: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var seen: Dictionary = {}
    var current_types: Array = _type_array(actor.get("types", []))
    var current_single: String = str(current_types[0]) if current_types.size() == 1 else ""

    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        return result

    for move_id_value: Variant in moves_value:
        var move: Dictionary = _move_data(str(move_id_value))
        if move.is_empty():
            continue
        var type_id: String = str(move.get("type", "normal"))
        if type_id.is_empty() or type_id == current_single or seen.has(type_id):
            continue
        seen[type_id] = true
        result.append(type_id)

    return result


func _f64_resistant_types(attack_type: String, actor: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var current_types: Array = _type_array(actor.get("types", []))
    var current_single: String = str(current_types[0]) if current_types.size() == 1 else ""

    for candidate: String in F64_ALL_TYPES:
        if candidate == current_single:
            continue
        var multiplier: float = TypeSystem.get_multiplier(attack_type, [candidate])
        if multiplier <= 0.5:
            result.append(candidate)
    return result


func _f64_living_team_count(side: String) -> int:
    var count: int = 0
    for candidate_value: Variant in _team_for_side(side):
        if candidate_value is Dictionary and bool((candidate_value as Dictionary).get("alive", false)):
            count += 1
    return count


func _f64_guard_base_defense(combatant: Dictionary) -> int:
    if bool(combatant.get("f64_guard_split_active", false)):
        return maxi(1, int(combatant.get(
            "f64_guard_split_original_defense",
            combatant.get("defense", 1)
        )))
    return maxi(1, int(combatant.get("defense", 1)))


func _f64_mist_active(combatant: Dictionary) -> bool:
    if combatant.is_empty() or not bool(combatant.get("alive", false)):
        return false
    var expiry: int = int(combatant.get("f64_mist_expires_serial", -1))
    return expiry >= 0 and int(combatant.get("action_serial", 0)) < expiry
