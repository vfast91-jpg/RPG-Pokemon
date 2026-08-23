extends "res://scripts/battle_demo_remaining_gen1_species_v1.gd"

# Data/targeting layer for the ten-family attack batch Zubat -> Quapsel.
# Species source data already reference move IDs. These packs only add the
# missing move definitions, then rebuild the runtime learnset view.

const ZF_MOVE_PACK_PATHS: Array[String] = [
    "res://data/gen1_moves_runtime_v3_25_1_zubat_to_poliwag.json",
    "res://data/gen1_moves_runtime_v3_25_2_zubat_to_poliwag.json",
    "res://data/gen1_moves_runtime_v3_25_3_zubat_to_poliwag.json",
    "res://data/gen1_moves_runtime_v3_25_4_zubat_to_poliwag.json"
]

var _zf_selected_target_id: String = ""
var _zf_target_selection_move_id: String = ""


func _load_data() -> void:
    super._load_data()
    _zf_load_move_packs()
    _zf_rebuild_species_runtime_after_move_load()


func _zf_load_move_packs() -> void:
    var runtime_moves_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_moves_value if runtime_moves_value is Dictionary else {}
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_moves_value if canonical_moves_value is Dictionary else {}

    for path: String in ZF_MOVE_PACK_PATHS:
        var text: String = FileAccess.get_file_as_string(path)
        var parsed: Variant = JSON.parse_string(text)
        if not (parsed is Dictionary):
            push_error("Attackenpaket konnte nicht gelesen werden: " + path)
            continue
        var entries_value: Variant = (parsed as Dictionary).get("moves", {})
        if not (entries_value is Dictionary):
            push_error("Attackenpaket besitzt kein moves-Dictionary: " + path)
            continue
        for move_id_value: Variant in (entries_value as Dictionary).keys():
            var move_id: String = str(move_id_value)
            var move_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
            if not (move_value is Dictionary):
                continue
            runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
            canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)

    data["moves"] = runtime_moves
    _canonical_pack["moves"] = canonical_moves


func _zf_rebuild_species_runtime_after_move_load() -> void:
    var source_value: Variant = _canonical_pack.get("species", {})
    if not (source_value is Dictionary):
        return

    var runtime_species: Dictionary = {}
    for species_id_value: Variant in (source_value as Dictionary).keys():
        var species_id: String = str(species_id_value)
        var entry_value: Variant = (source_value as Dictionary).get(species_id_value, {})
        if entry_value is Dictionary:
            runtime_species[species_id] = _canonical_species_runtime(entry_value as Dictionary)

    data["species"] = runtime_species
    _remaining_rebuild_tm_move_universe()


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return

    var move: Dictionary = _move_data(move_id)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if _zf_target_selection_move_id.is_empty():
        if bool(runtime.get("requires_ally_selection", false)):
            _zf_show_target_picker(selected_actor, move_id, true)
            return
        if bool(runtime.get("requires_enemy_selection", false)):
            _zf_show_target_picker(selected_actor, move_id, false)
            return

    super._choose_move(move_id)


func _zf_show_target_picker(actor: Dictionary, move_id: String, ally_target: bool) -> void:
    paused = true
    selected_actor = actor
    _zf_target_selection_move_id = move_id
    _clear_actions()

    var candidates: Array = []
    if ally_target:
        for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
            if not (candidate_value is Dictionary):
                continue
            var candidate: Dictionary = candidate_value
            if not bool(candidate.get("alive", false)):
                continue
            if str(candidate.get("id", "")) == str(actor.get("id", "")):
                continue
            candidates.append(candidate)
    else:
        for candidate_value: Variant in _living_opponents(actor):
            if candidate_value is Dictionary:
                candidates.append(candidate_value)

    if candidates.is_empty():
        _zf_target_selection_move_id = ""
        _set_log("Für " + str(_move_data(move_id).get("name", move_id)) + " gibt es kein gültiges Ziel.")
        _prompt_player(actor)
        return

    _set_log(
        "[b]%s[/b]: Ziel für %s wählen."
        % [_actor_name(actor), str(_move_data(move_id).get("name", move_id))]
    )
    for candidate_value: Variant in candidates:
        var candidate: Dictionary = candidate_value
        var button := Button.new()
        button.text = _actor_name(candidate)
        button.custom_minimum_size = Vector2(135, 29)
        button.pressed.connect(_zf_confirm_target.bind(move_id, str(candidate.get("id", ""))))
        action_grid.add_child(button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.custom_minimum_size = Vector2(135, 29)
    back_button.pressed.connect(_zf_cancel_target_picker.bind(actor))
    action_grid.add_child(back_button)


func _zf_confirm_target(move_id: String, target_id: String) -> void:
    if selected_actor.is_empty():
        return
    _zf_selected_target_id = target_id
    var requested_move: String = _zf_target_selection_move_id
    _zf_target_selection_move_id = "__resolving__"
    super._choose_move(requested_move if not requested_move.is_empty() else move_id)
    _zf_target_selection_move_id = ""


func _zf_cancel_target_picker(actor: Dictionary) -> void:
    _zf_selected_target_id = ""
    _zf_target_selection_move_id = ""
    _prompt_player(actor)


func _targets(actor: Dictionary, rule: String) -> Array:
    if not _zf_selected_target_id.is_empty():
        var selected: Dictionary = _zf_find_combatant(_zf_selected_target_id)
        if not selected.is_empty() and bool(selected.get("alive", false)):
            if rule == "single_ally" and str(selected.get("side", "")) == str(actor.get("side", "")):
                return [selected]
            if (
                (rule == "enemy_highest_aggro" or rule == "single_enemy")
                and str(selected.get("side", "")) != str(actor.get("side", ""))
            ):
                return [selected]

    if rule == "single_ally":
        var allies: Array = []
        for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
            if not (candidate_value is Dictionary):
                continue
            var candidate: Dictionary = candidate_value
            if bool(candidate.get("alive", false)) and str(candidate.get("id", "")) != str(actor.get("id", "")):
                allies.append(candidate)
        return [] if allies.is_empty() else [allies.pick_random()]

    if rule == "single_enemy":
        var opponents: Array = []
        for candidate_value: Variant in _living_opponents(actor):
            if candidate_value is Dictionary:
                opponents.append(candidate_value)
        return [] if opponents.is_empty() else [opponents.pick_random()]

    if rule == "battlefield":
        return [actor]

    return super._targets(actor, rule)


func _zf_prepare_auto_target(actor: Dictionary, move: Dictionary) -> void:
    if not _zf_selected_target_id.is_empty():
        return
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    if bool(runtime.get("requires_ally_selection", false)):
        _zf_selected_target_id = _zf_random_ally_id(actor)
    elif bool(runtime.get("requires_enemy_selection", false)):
        _zf_selected_target_id = _zf_random_enemy_id(actor)


func _zf_find_combatant(combatant_id: String) -> Dictionary:
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            if str(candidate.get("id", "")) == combatant_id:
                return candidate
    return {}


func _zf_random_ally_id(actor: Dictionary) -> String:
    var candidates: Array[String] = []
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if bool(candidate.get("alive", false)) and str(candidate.get("id", "")) != str(actor.get("id", "")):
            candidates.append(str(candidate.get("id", "")))
    return "" if candidates.is_empty() else candidates.pick_random()


func _zf_random_enemy_id(actor: Dictionary) -> String:
    var candidates: Array[String] = []
    for candidate_value: Variant in _living_opponents(actor):
        if candidate_value is Dictionary:
            candidates.append(str((candidate_value as Dictionary).get("id", "")))
    return "" if candidates.is_empty() else candidates.pick_random()
