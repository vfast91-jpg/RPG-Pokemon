extends "res://scripts/demo_route_evolution_ui.gd"

# Route TM reward layer.
#
# TM compatibility stays data-driven: every JSON data pack below res://data/
# may expose species.learnset.tm_hm as {tm_number: move_id}. A TM is offered
# only when at least one current travelling team member can still receive it.
# If no valid TM remains, the reward safely falls back to a full team heal.

const TM_DATA_DIR: String = "res://data"
const TM_OFFER_COUNT: int = 3

var _tm_catalog: Dictionary = {}
var _active_tm_offers: Array[Dictionary] = []


func start_route() -> void:
    _reload_tm_catalog()
    _active_tm_offers.clear()
    super.start_route()


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == "item":
            choice["label"] = "💿 TM-Fundstelle"
            choice["hint"] = "Wähle eine kompatible TM und weise sie einem Pokémon zu. Bereits bekannte TMs werden nicht angeboten."
    return choices


func _choose_path(choice: Dictionary) -> void:
    if str(choice.get("kind", "")) != "item":
        super._choose_path(choice)
        return

    _set_path_buttons_disabled(true)
    _clear_container(capture_actions)
    continue_button.visible = false
    stage_xp_multiplier = 1.0
    _begin_tm_event()
    _refresh_team_panel()
    path_box.visible = false


func _begin_tm_event() -> void:
    if _tm_catalog.is_empty():
        _reload_tm_catalog()

    var candidates: Array[Dictionary] = _eligible_tm_entries()
    _active_tm_offers.clear()

    if candidates.is_empty():
        _heal_team()
        event_label.text = (
            "[b]💿 TM-Fundstelle[/b]\n"
            + "Für dein aktuelles Team gibt es keine TM mehr, die noch sinnvoll zugewiesen werden kann. "
            + "Als Ersatz wird dein gesamtes Team vollständig geheilt."
        )
        continue_button.visible = true
        _refresh_team_panel()
        return

    candidates.shuffle()
    var offer_count: int = mini(TM_OFFER_COUNT, candidates.size())
    for index: int in range(offer_count):
        _active_tm_offers.append(candidates[index])

    _show_tm_offer_buttons()


func _show_tm_offer_buttons() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    event_label.text = (
        "[b]💿 TM-Fundstelle[/b]\n"
        + "Wähle eine TM. Angezeigt werden nur TMs, die mindestens eines deiner aktuellen Pokémon noch erhalten kann."
    )

    for entry: Dictionary in _active_tm_offers:
        var recipients: Array[Dictionary] = _tm_recipients(entry)
        if recipients.is_empty():
            continue

        var button := Button.new()
        button.text = "TM%s · %s" % [
            str(entry.get("number", "")),
            str(entry.get("name", entry.get("move_id", "TM")))
        ]
        button.custom_minimum_size = Vector2(0, 28)
        button.tooltip_text = _tm_offer_tooltip(entry, recipients)
        button.pressed.connect(_choose_tm_offer.bind(entry))
        capture_actions.add_child(button)


func _choose_tm_offer(entry: Dictionary) -> void:
    var recipients: Array[Dictionary] = _tm_recipients(entry)
    if recipients.is_empty():
        _begin_tm_event()
        return

    _clear_container(capture_actions)
    continue_button.visible = false
    event_label.text = "[b]TM%s · %s[/b]\nWelches Pokémon soll diese TM erhalten?" % [
        str(entry.get("number", "")),
        str(entry.get("name", entry.get("move_id", "TM")))
    ]

    for recipient: Dictionary in recipients:
        var team_index: int = int(recipient.get("team_index", -1))
        var member_value: Variant = recipient.get("member", {})
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value

        var button := Button.new()
        button.text = "%s Lv.%d" % [
            str(member.get("name", "Pokémon")),
            int(member.get("level", 1))
        ]
        button.custom_minimum_size = Vector2(0, 26)
        button.pressed.connect(_assign_tm.bind(entry, team_index))
        capture_actions.add_child(button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK ZUR TM-AUSWAHL"
    back_button.pressed.connect(_show_tm_offer_buttons)
    capture_actions.add_child(back_button)


func _assign_tm(entry: Dictionary, team_index: int) -> void:
    if team_index < 0 or team_index >= team.size():
        _begin_tm_event()
        return

    var member_value: Variant = team[team_index]
    if not (member_value is Dictionary):
        _begin_tm_event()
        return
    var member: Dictionary = member_value

    if not _member_can_receive_tm(member, entry):
        _begin_tm_event()
        return

    var move_id: String = str(entry.get("move_id", ""))
    var tm_number: String = str(entry.get("number", ""))

    var tm_moves_value: Variant = member.get("tm_moves", [])
    var tm_moves: Array = tm_moves_value.duplicate() if tm_moves_value is Array else []
    if not tm_moves.has(move_id):
        tm_moves.append(move_id)
    member["tm_moves"] = tm_moves

    var learned_value: Variant = member.get("learned_tms", [])
    var learned_tms: Array = learned_value.duplicate(true) if learned_value is Array else []
    learned_tms.append({"number": tm_number, "move_id": move_id})
    member["learned_tms"] = learned_tms
    team[team_index] = member

    _clear_container(capture_actions)
    event_label.text = "[b]TM%s · %s[/b]\n%s hat die Attacke erhalten." % [
        tm_number,
        str(entry.get("name", move_id)),
        str(member.get("name", "Pokémon"))
    ]
    continue_button.visible = true
    _refresh_team_panel()


func _eligible_tm_entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry_value: Variant in _tm_catalog.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        if not _tm_recipients(entry).is_empty():
            result.append(entry)
    return result


func _tm_recipients(entry: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if _member_can_receive_tm(member, entry):
            result.append({"team_index": index, "member": member})
    return result


func _member_can_receive_tm(member: Dictionary, entry: Dictionary) -> bool:
    var species_id: String = str(member.get("species_id", ""))
    var compatible_value: Variant = entry.get("species_ids", [])
    if not (compatible_value is Array) or not (compatible_value as Array).has(species_id):
        return false

    var move_id: String = str(entry.get("move_id", ""))
    var tm_number: String = str(entry.get("number", ""))
    if move_id.is_empty():
        return false

    var runtime_data_value: Variant = battle_demo.get("data") if battle_demo != null else {}
    if not (runtime_data_value is Dictionary):
        return false
    var runtime_moves_value: Variant = (runtime_data_value as Dictionary).get("moves", {})
    if not (runtime_moves_value is Dictionary) or not (runtime_moves_value as Dictionary).has(move_id):
        return false

    var tm_moves_value: Variant = member.get("tm_moves", [])
    if tm_moves_value is Array and (tm_moves_value as Array).has(move_id):
        return false

    var explicit_moves_value: Variant = member.get("moves", [])
    if explicit_moves_value is Array and (explicit_moves_value as Array).has(move_id):
        return false

    if battle_demo != null and battle_demo.has_method("route_moves_for_level"):
        var level_moves: Array = battle_demo.route_moves_for_level(
            species_id,
            maxi(1, int(member.get("level", 1)))
        )
        if level_moves.has(move_id):
            return false

    var learned_value: Variant = member.get("learned_tms", [])
    if learned_value is Array:
        for learned_entry_value: Variant in learned_value:
            if learned_entry_value is Dictionary:
                var learned_entry: Dictionary = learned_entry_value
                if str(learned_entry.get("number", "")) == tm_number:
                    return false
                if str(learned_entry.get("move_id", "")) == move_id:
                    return false
            elif str(learned_entry_value) == tm_number or str(learned_entry_value) == move_id:
                return false

    return true


func _tm_recipient_hint(recipients: Array[Dictionary]) -> String:
    var names: Array[String] = []
    for recipient: Dictionary in recipients:
        var member_value: Variant = recipient.get("member", {})
        if member_value is Dictionary:
            names.append(str((member_value as Dictionary).get("name", "Pokémon")))
    return "Mögliche Empfänger: " + ", ".join(names)


func _tm_offer_tooltip(entry: Dictionary, recipients: Array[Dictionary]) -> String:
    var recipient_hint: String = _tm_recipient_hint(recipients)
    var attack_hint: String = _tm_attack_tooltip(entry)
    if attack_hint.is_empty():
        return recipient_hint
    return recipient_hint + "\n\nAttacke:\n" + attack_hint


func _tm_attack_tooltip(entry: Dictionary) -> String:
    if battle_demo == null:
        return ""

    var move_id: String = str(entry.get("move_id", ""))
    if move_id.is_empty():
        return ""

    var runtime_data_value: Variant = battle_demo.get("data")
    if not (runtime_data_value is Dictionary):
        return ""
    var runtime_moves_value: Variant = (runtime_data_value as Dictionary).get("moves", {})
    if not (runtime_moves_value is Dictionary):
        return ""

    var move_value: Variant = (runtime_moves_value as Dictionary).get(move_id, {})
    if not (move_value is Dictionary):
        return ""
    var move: Dictionary = move_value

    # Reuse the central battle tooltip instead of maintaining a second move
    # description system for Fundstelle rewards. This keeps special mechanics,
    # AP/time cost, targets and future presentation fixes consistent everywhere.
    if battle_demo.has_method("_move_tooltip"):
        var standardized: String = str(battle_demo.call("_move_tooltip", move)).strip_edges()
        if not standardized.is_empty():
            return standardized

    # Defensive legacy fallback: if an isolated old BattleDemo layer does not
    # expose the standardized tooltip yet, keep the Fundstelle usable and show
    # a player-facing database description when one exists.
    return str(move.get("description", "")).strip_edges()


func _reload_tm_catalog() -> void:
    _tm_catalog.clear()
    if battle_demo == null:
        return

    var directory := DirAccess.open(TM_DATA_DIR)
    if directory == null:
        push_warning("TM-System: Datenordner konnte nicht geöffnet werden: " + TM_DATA_DIR)
        return

    directory.list_dir_begin()
    var file_name: String = directory.get_next()
    while not file_name.is_empty():
        if not directory.current_is_dir() and file_name.to_lower().ends_with(".json"):
            _load_tm_pack(TM_DATA_DIR + "/" + file_name)
        file_name = directory.get_next()
    directory.list_dir_end()


func _load_tm_pack(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return
    var pack: Dictionary = parsed

    var source_moves_value: Variant = pack.get("moves", {})
    var source_moves: Dictionary = source_moves_value if source_moves_value is Dictionary else {}

    for species: Dictionary in _tm_species_entries(pack):
        var species_id: String = str(species.get("species_id", species.get("id", "")))
        if species_id.is_empty():
            continue

        var learnset_value: Variant = species.get("learnset", {})
        if not (learnset_value is Dictionary):
            continue
        var tm_value: Variant = (learnset_value as Dictionary).get("tm_hm", {})
        if not (tm_value is Dictionary):
            continue
        var tm_map: Dictionary = tm_value

        for tm_key_value: Variant in tm_map.keys():
            var tm_number: String = _normalize_tm_number(tm_key_value)
            var move_id: String = str(tm_map.get(tm_key_value, ""))
            if tm_number.is_empty() or move_id.is_empty():
                continue

            var source_move_value: Variant = source_moves.get(move_id, {})
            var source_move: Dictionary = source_move_value if source_move_value is Dictionary else {}
            if not _ensure_runtime_tm_move(move_id, source_move):
                continue

            var catalog_key: String = tm_number + "|" + move_id
            var entry_value: Variant = _tm_catalog.get(catalog_key, {})
            var entry: Dictionary = entry_value if entry_value is Dictionary else {}
            if entry.is_empty():
                entry = {
                    "number": tm_number,
                    "move_id": move_id,
                    "name": _runtime_move_name(move_id, source_move),
                    "species_ids": []
                }

            var species_ids_value: Variant = entry.get("species_ids", [])
            var species_ids: Array = species_ids_value if species_ids_value is Array else []
            if not species_ids.has(species_id):
                species_ids.append(species_id)
            entry["species_ids"] = species_ids
            _tm_catalog[catalog_key] = entry


func _tm_species_entries(pack: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var species_value: Variant = pack.get("species", {})
    if not (species_value is Dictionary):
        return result

    var species_dict: Dictionary = species_value
    if species_dict.has("species_id") or species_dict.has("id"):
        result.append(species_dict)
        return result

    for entry_value: Variant in species_dict.values():
        if entry_value is Dictionary:
            result.append(entry_value)
    return result


func _normalize_tm_number(value: Variant) -> String:
    var raw: String = str(value).strip_edges().to_upper()
    if raw.begins_with("TM"):
        raw = raw.substr(2).strip_edges()
    if raw.is_valid_int():
        return "%03d" % int(raw)
    return raw


func _ensure_runtime_tm_move(move_id: String, source_move: Dictionary) -> bool:
    var runtime_data_value: Variant = battle_demo.get("data")
    if not (runtime_data_value is Dictionary):
        return false
    var runtime_data: Dictionary = runtime_data_value

    var runtime_moves_value: Variant = runtime_data.get("moves", {})
    if not (runtime_moves_value is Dictionary):
        return false
    var runtime_moves: Dictionary = runtime_moves_value

    if runtime_moves.has(move_id):
        return true
    if source_move.is_empty():
        return false

    var normalized: Dictionary = _normalize_tm_move(move_id, source_move)
    if normalized.is_empty():
        return false

    runtime_moves[move_id] = normalized
    runtime_data["moves"] = runtime_moves
    battle_demo.set("data", runtime_data)
    return true


func _normalize_tm_move(move_id: String, source: Dictionary) -> Dictionary:
    var mechanics: Array = []

    var mechanics_value: Variant = source.get("mechanics", null)
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            var converted_mechanic: Dictionary = _convert_tm_effect(mechanic_value, source)
            if converted_mechanic.is_empty():
                return {}
            mechanics.append(converted_mechanic)
    else:
        var effects_value: Variant = source.get("effects", [])
        if not (effects_value is Array):
            return {}
        for effect_value: Variant in effects_value:
            var converted_effect: Dictionary = _convert_tm_effect(effect_value, source)
            if converted_effect.is_empty():
                return {}
            mechanics.append(converted_effect)

    if mechanics.is_empty():
        return {}

    return {
        "id": move_id,
        "name": str(source.get("name", move_id)),
        "type": str(source.get("type", "normal")),
        "category": str(source.get("category", "status")),
        "power": source.get("power", null),
        "accuracy": source.get("accuracy", null),
        "ap": int(source.get("rpg_ap", source.get("ap", source.get("ap_cost", 1)))),
        "target": str(source.get("target", "enemy_highest_aggro")),
        "area": bool(source.get("area", false)),
        "priority": int(source.get("priority", 0)),
        "opening": bool(source.get("opening_phase", source.get("opening", false))),
        "mechanics": mechanics,
        "tm_runtime_generated": true
    }


func _convert_tm_effect(effect_value: Variant, source_move: Dictionary) -> Dictionary:
    if effect_value is Dictionary:
        var effect: Dictionary = (effect_value as Dictionary).duplicate(true)
        var kind: String = str(effect.get("kind", ""))
        if kind == "apply_status":
            effect["kind"] = "status"
            return effect
        if [
            "damage", "status", "outgoing_damage_mod", "incoming_damage_mod",
            "accuracy_mod", "atb_cycle_mod", "atb_knockback", "critical_focus",
            "seed", "binding", "cleanse_self", "recoil", "protective_guard"
        ].has(kind):
            return effect
        return {}

    var effect_text: String = str(effect_value).strip_edges()
    if effect_text == "damage":
        return {"kind": "damage"}

    if effect_text.begins_with("recoil("):
        return {
            "kind": "recoil",
            "fraction": _extract_decimal_before(effect_text, "*actual_damage_dealt", 0.25)
        }

    if effect_text.contains("outgoing_damage_reduction"):
        return {
            "kind": "outgoing_damage_mod",
            "scope": str(source_move.get("target", "enemy_highest_aggro")),
            "multiplier_from_special": -_extract_decimal_after(effect_text, "special*", 1.0),
            "uses_special_percent": true,
            "duration": "next_damage"
        }

    if effect_text.contains("protective_guard"):
        return {"kind": "protective_guard", "scope": "self"}

    return {}


func _extract_decimal_after(text: String, marker: String, fallback: float) -> float:
    var marker_index: int = text.find(marker)
    if marker_index < 0:
        return fallback
    var start: int = marker_index + marker.length()
    var token: String = ""
    for index: int in range(start, text.length()):
        var character: String = text.substr(index, 1)
        if character.is_valid_int() or character == "." or character == "-":
            token += character
        else:
            break
    return float(token) if token.is_valid_float() else fallback


func _extract_decimal_before(text: String, marker: String, fallback: float) -> float:
    var marker_index: int = text.find(marker)
    if marker_index <= 0:
        return fallback
    var prefix: String = text.substr(0, marker_index)
    var equals_index: int = prefix.rfind("=")
    if equals_index >= 0:
        prefix = prefix.substr(equals_index + 1)
    prefix = prefix.strip_edges()
    return float(prefix) if prefix.is_valid_float() else fallback


func _runtime_move_name(move_id: String, source_move: Dictionary) -> String:
    if battle_demo != null and battle_demo.has_method("route_move_name"):
        var routed_name: String = str(battle_demo.route_move_name(move_id))
        if routed_name != move_id:
            return routed_name
    return str(source_move.get("name", move_id))


func _refresh_team_panel() -> void:
    super._refresh_team_panel()
    if team_box == null:
        return

    var card_count: int = mini(team.size(), team_box.get_child_count())
    for index: int in range(card_count):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value

        var tm_moves_value: Variant = member.get("tm_moves", [])
        if not (tm_moves_value is Array) or (tm_moves_value as Array).is_empty():
            continue

        var names: Array[String] = []
        for move_value: Variant in tm_moves_value:
            names.append(_runtime_move_name(str(move_value), {}))

        var card: Node = team_box.get_child(index)
        if card.get_child_count() == 0:
            continue
        var label := card.get_child(0) as Label
        if label != null:
            label.text += "\nTM: " + ", ".join(names)
