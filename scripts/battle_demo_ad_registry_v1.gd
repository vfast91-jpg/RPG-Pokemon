extends "res://scripts/battle_demo_landscape_background_v1.gd"

# Data/targeting layer for the Abra -> Dodri ten-family attack batch.
# The complete species registry already contains these move IDs. This layer
# only merges the newly approved move definitions and rebuilds runtime learnsets.

const AD_MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_26_abra_to_doduo.json"

var _ad_self_ally_picker_move_id: String = ""


func _load_data() -> void:
    super._load_data()
    _ad_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _ad_load_move_pack() -> void:
    var text: String = FileAccess.get_file_as_string(AD_MOVE_PACK_PATH)
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary):
        push_error("Abra-Dodri-Attackenpaket konnte nicht gelesen werden: " + AD_MOVE_PACK_PATH)
        return

    var entries_value: Variant = (parsed as Dictionary).get("moves", {})
    if not (entries_value is Dictionary):
        push_error("Abra-Dodri-Attackenpaket besitzt kein moves-Dictionary.")
        return

    var runtime_moves_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = (
        runtime_moves_value if runtime_moves_value is Dictionary else {}
    )
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = (
        canonical_moves_value if canonical_moves_value is Dictionary else {}
    )

    for move_id_value: Variant in (entries_value as Dictionary).keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
        if not (move_value is Dictionary):
            continue
        runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
        canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)

    data["moves"] = runtime_moves
    _canonical_pack["moves"] = canonical_moves


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return

    var move: Dictionary = _move_data(move_id)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if (
        bool(runtime.get("requires_self_or_ally_selection", false))
        and _ad_self_ally_picker_move_id.is_empty()
    ):
        _ad_show_self_or_ally_picker(selected_actor, move_id)
        return

    super._choose_move(move_id)


func _ad_show_self_or_ally_picker(actor: Dictionary, move_id: String) -> void:
    paused = true
    selected_actor = actor
    _ad_self_ally_picker_move_id = move_id
    _clear_actions()

    var candidates: Array = []
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if bool(candidate.get("alive", false)):
            candidates.append(candidate)

    if candidates.is_empty():
        _ad_self_ally_picker_move_id = ""
        _set_log(
            "Für " + str(_move_data(move_id).get("name", move_id))
            + " gibt es kein gültiges Ziel."
        )
        _prompt_player(actor)
        return

    _set_log(
        "[b]%s[/b]: Ziel für %s wählen."
        % [_actor_name(actor), str(_move_data(move_id).get("name", move_id))]
    )
    for candidate_value: Variant in candidates:
        var candidate: Dictionary = candidate_value
        var button := Button.new()
        var self_suffix: String = " (selbst)" if (
            str(candidate.get("id", "")) == str(actor.get("id", ""))
        ) else ""
        button.text = _actor_name(candidate) + self_suffix
        button.custom_minimum_size = Vector2(135, 29)
        button.pressed.connect(
            _ad_confirm_self_or_ally_target.bind(
                move_id, str(candidate.get("id", ""))
            )
        )
        action_grid.add_child(button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.custom_minimum_size = Vector2(135, 29)
    back_button.pressed.connect(_ad_cancel_self_or_ally_picker.bind(actor))
    action_grid.add_child(back_button)


func _ad_confirm_self_or_ally_target(move_id: String, target_id: String) -> void:
    if selected_actor.is_empty():
        return
    _zf_selected_target_id = target_id
    var requested_move: String = _ad_self_ally_picker_move_id
    _ad_self_ally_picker_move_id = "__resolving__"
    super._choose_move(requested_move if not requested_move.is_empty() else move_id)
    _ad_self_ally_picker_move_id = ""


func _ad_cancel_self_or_ally_picker(actor: Dictionary) -> void:
    _zf_selected_target_id = ""
    _ad_self_ally_picker_move_id = ""
    _prompt_player(actor)


func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == "self_or_single_ally":
        if not _zf_selected_target_id.is_empty():
            var selected: Dictionary = _zf_find_combatant(_zf_selected_target_id)
            if (
                not selected.is_empty()
                and bool(selected.get("alive", false))
                and str(selected.get("side", "")) == str(actor.get("side", ""))
            ):
                return [selected]
        return [actor]

    if rule == "battlefield":
        # A field effect resolves exactly once and does not need an enemy target.
        return [actor]

    if rule == "all_allies":
        var allies: Array = []
        for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
            if candidate_value is Dictionary:
                var candidate: Dictionary = candidate_value
                if bool(candidate.get("alive", false)):
                    allies.append(candidate)
        return allies

    if rule == "all_other_active_pokemon":
        var everyone_else: Array = []
        for candidate_value: Variant in combatants:
            if not (candidate_value is Dictionary):
                continue
            var candidate: Dictionary = candidate_value
            if not bool(candidate.get("alive", false)):
                continue
            if str(candidate.get("id", "")) == str(actor.get("id", "")):
                continue
            everyone_else.append(candidate)
        return everyone_else

    return super._targets(actor, rule)


func _target_name(rule: String) -> String:
    match rule:
        "self_or_single_ally":
            return "Anwender oder gewählter Verbündeter"
        "battlefield":
            return "Kampffeld"
        "all_allies":
            return "alle aktiven Verbündeten"
        "all_other_active_pokemon":
            return "alle anderen aktiven Pokémon"
        _:
            return super._target_name(rule)


func _zf_prepare_auto_target(actor: Dictionary, move: Dictionary) -> void:
    super._zf_prepare_auto_target(actor, move)
    if not _zf_selected_target_id.is_empty():
        return
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    if not bool(runtime.get("requires_self_or_ally_selection", false)):
        return

    var candidates: Array[String] = []
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if candidate_value is Dictionary and bool((candidate_value as Dictionary).get("alive", false)):
            candidates.append(str((candidate_value as Dictionary).get("id", "")))
    if not candidates.is_empty():
        _zf_selected_target_id = candidates.pick_random()
