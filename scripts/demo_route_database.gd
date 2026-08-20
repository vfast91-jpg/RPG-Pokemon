extends "res://scripts/demo_route_forced_evolution.gd"

# Canonical TM bridge for the demo route.
# Only the spreadsheet-export species packs listed in the manifest contribute
# TM/TR compatibility; legacy demo packs are intentionally ignored.

const DATABASE_MANIFEST_PATH: String = "res://data/gen1_database_manifest_v3.json"


func _reload_tm_catalog() -> void:
    _tm_catalog.clear()
    if battle_demo == null:
        return

    var file: FileAccess = FileAccess.open(DATABASE_MANIFEST_PATH, FileAccess.READ)
    if file == null:
        push_warning("TM-System: Kanonisches Datenbank-Manifest fehlt.")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_warning("TM-System: Kanonisches Datenbank-Manifest ist ungültig.")
        return

    var species_files_value: Variant = (parsed as Dictionary).get("species_files", [])
    if not (species_files_value is Array):
        push_warning("TM-System: species_files fehlen im Manifest.")
        return

    for path_value: Variant in species_files_value:
        _load_tm_pack(str(path_value))


func _show_tm_offer_buttons() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    event_label.text = (
        "[b]💿 TM-Fundstelle[/b]\n"
        + "Wähle eine TM. Angezeigt werden nur Einträge, die mindestens eines deiner aktuellen Pokémon noch erhalten kann."
    )

    for entry: Dictionary in _active_tm_offers:
        var recipients: Array[Dictionary] = _tm_recipients(entry)
        if recipients.is_empty():
            continue

        var button := Button.new()
        button.text = "%s · %s" % [
            _database_tm_label(str(entry.get("number", ""))),
            str(entry.get("name", entry.get("move_id", "TM")))
        ]
        button.custom_minimum_size = Vector2(0, 28)
        button.tooltip_text = _tm_recipient_hint(recipients)
        button.pressed.connect(_choose_tm_offer.bind(entry))
        capture_actions.add_child(button)


func _choose_tm_offer(entry: Dictionary) -> void:
    var recipients: Array[Dictionary] = _tm_recipients(entry)
    if recipients.is_empty():
        _begin_tm_event()
        return

    _clear_container(capture_actions)
    continue_button.visible = false
    event_label.text = "[b]%s · %s[/b]\nWelches Pokémon soll diese Attacke erhalten?" % [
        _database_tm_label(str(entry.get("number", ""))),
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
    event_label.text = "[b]%s · %s[/b]\n%s hat die Attacke erhalten." % [
        _database_tm_label(tm_number),
        str(entry.get("name", move_id)),
        str(member.get("name", "Pokémon"))
    ]
    continue_button.visible = true
    _refresh_team_panel()


func _database_tm_label(number: String) -> String:
    var normalized: String = number.strip_edges().to_upper()
    if normalized.begins_with("TR") or normalized.begins_with("TM"):
        return normalized
    return "TM" + normalized
