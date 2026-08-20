extends CanvasLayer

signal request_main_menu

const MAX_TEAM_SIZE: int = 6
const CAPTURE_LEVEL: int = 3
const STAGE_COUNT: int = 10

var battle_demo: Node
var team: Array = []
var storage: Array = []
var stage: int = 1
var stage_xp_multiplier: float = 1.0
var pending_capture: Dictionary = {}
var last_route_message: String = ""

var root: Control
var title_label: Label
var progress_label: Label
var path_box: VBoxContainer
var event_label: RichTextLabel
var continue_button: Button
var restart_button: Button
var team_box: VBoxContainer
var storage_label: Label
var capture_actions: VBoxContainer


func _ready() -> void:
    layer = 40
    _build_ui()
    visible = false


func configure(combat_lab: Node) -> void:
    battle_demo = combat_lab
    if battle_demo != null and battle_demo.has_signal("route_battle_finished"):
        var callback := Callable(self, "_on_route_battle_finished")
        if not battle_demo.is_connected("route_battle_finished", callback):
            battle_demo.connect("route_battle_finished", callback)


func start_route() -> void:
    if battle_demo == null:
        push_error("Demo-Route: Kampflabor wurde nicht verbunden.")
        return

    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        push_error("Demo-Route: Keine Pokémon-Daten verfügbar.")
        return

    team.clear()
    storage.clear()
    stage = 1
    stage_xp_multiplier = 1.0
    pending_capture = {}

    var starter_id: String = str(ids.pick_random())
    team.append(battle_demo.route_new_member(starter_id, 5))
    visible = true
    _show_stage_choices(
        "Deine Route beginnt mit [b]%s Lv.5[/b].\nWähle deinen ersten Weg." % battle_demo.route_species_name(starter_id)
    )


func _build_ui() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)

    var background := ColorRect.new()
    background.color = Color("10201b")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(background)

    var frame := PanelContainer.new()
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    frame.offset_left = 8.0
    frame.offset_top = 8.0
    frame.offset_right = -8.0
    frame.offset_bottom = -8.0
    frame.add_theme_stylebox_override("panel", _panel(Color("172923"), Color("d9c968"), 10, 8.0))
    root.add_child(frame)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 5)
    frame.add_child(outer)

    title_label = Label.new()
    title_label.text = "DEMO-ROUTE"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 20)
    title_label.add_theme_color_override("font_color", Color("ffe576"))
    outer.add_child(title_label)

    progress_label = Label.new()
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_label.add_theme_font_size_override("font_size", 10)
    progress_label.add_theme_color_override("font_color", Color("bad7c9"))
    outer.add_child(progress_label)

    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation", 6)
    outer.add_child(columns)

    var route_panel := PanelContainer.new()
    route_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    route_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    route_panel.add_theme_stylebox_override("panel", _panel(Color("0f1b18"), Color("506c60"), 8, 6.0))
    columns.add_child(route_panel)

    var route_content := VBoxContainer.new()
    route_content.add_theme_constant_override("separation", 4)
    route_panel.add_child(route_content)

    var route_title := Label.new()
    route_title.text = "DEIN WEG"
    route_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    route_title.add_theme_font_size_override("font_size", 12)
    route_content.add_child(route_title)

    path_box = VBoxContainer.new()
    path_box.add_theme_constant_override("separation", 4)
    route_content.add_child(path_box)

    event_label = RichTextLabel.new()
    event_label.bbcode_enabled = true
    event_label.fit_content = false
    event_label.scroll_active = true
    event_label.custom_minimum_size = Vector2(0, 58)
    event_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    event_label.add_theme_font_size_override("normal_font_size", 10)
    event_label.add_theme_font_size_override("bold_font_size", 10)
    route_content.add_child(event_label)

    capture_actions = VBoxContainer.new()
    capture_actions.add_theme_constant_override("separation", 2)
    route_content.add_child(capture_actions)

    continue_button = Button.new()
    continue_button.text = "ZUM ETAPPENKAMPF"
    continue_button.custom_minimum_size = Vector2(0, 28)
    continue_button.pressed.connect(_start_stage_battle)
    route_content.add_child(continue_button)

    restart_button = Button.new()
    restart_button.text = "NEUE DEMO-ROUTE"
    restart_button.custom_minimum_size = Vector2(0, 28)
    restart_button.pressed.connect(start_route)
    restart_button.visible = false
    route_content.add_child(restart_button)

    var team_panel := PanelContainer.new()
    team_panel.custom_minimum_size = Vector2(178, 0)
    team_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    team_panel.add_theme_stylebox_override("panel", _panel(Color("101d19"), Color("506c60"), 8, 5.0))
    columns.add_child(team_panel)

    var team_content := VBoxContainer.new()
    team_content.add_theme_constant_override("separation", 2)
    team_panel.add_child(team_content)

    var team_title := Label.new()
    team_title.text = "TEAM"
    team_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    team_title.add_theme_font_size_override("font_size", 12)
    team_content.add_child(team_title)

    var team_scroll := ScrollContainer.new()
    team_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    team_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    team_content.add_child(team_scroll)

    team_box = VBoxContainer.new()
    team_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    team_box.add_theme_constant_override("separation", 2)
    team_scroll.add_child(team_box)

    storage_label = Label.new()
    storage_label.add_theme_font_size_override("font_size", 9)
    storage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    team_content.add_child(storage_label)

    var footer := HBoxContainer.new()
    footer.alignment = BoxContainer.ALIGNMENT_CENTER
    outer.add_child(footer)

    var menu_button := Button.new()
    menu_button.text = "HAUPTMENÜ"
    menu_button.custom_minimum_size = Vector2(120, 26)
    menu_button.pressed.connect(_go_main_menu)
    footer.add_child(menu_button)


func _panel(bg: Color, border: Color, radius: int = 8, margin: float = 6.0) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.content_margin_left = margin
    style.content_margin_right = margin
    style.content_margin_top = margin
    style.content_margin_bottom = margin
    return style


func _show_stage_choices(message: String = "") -> void:
    visible = true
    pending_capture = {}
    stage_xp_multiplier = 1.0
    restart_button.visible = false
    continue_button.visible = false
    _clear_container(capture_actions)
    _clear_container(path_box)

    title_label.text = "DEMO-ROUTE · ETAPPE %d/%d" % [stage, STAGE_COUNT]
    progress_label.text = _progress_text()
    event_label.text = message if not message.is_empty() else "Wähle einen Weg. Danach wartet der Kampf dieser Etappe."

    for choice: Dictionary in _choices_for_stage(stage):
        var button := Button.new()
        button.text = str(choice.get("label", "Weg"))
        button.custom_minimum_size = Vector2(0, 30)
        button.tooltip_text = str(choice.get("hint", ""))
        button.pressed.connect(_choose_path.bind(choice))
        path_box.add_child(button)

    _refresh_team_panel()


func _progress_text() -> String:
    var tokens: Array[String] = []
    for index: int in range(1, STAGE_COUNT + 1):
        if index < stage:
            tokens.append("●")
        elif index == stage:
            tokens.append("◆")
        else:
            tokens.append("○")
    return " ".join(tokens)


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var sets: Array = [
        ["heal", "catch", "battle"],
        ["item", "battle", "catch"],
        ["catch", "heal", "battle"],
        ["battle", "item", "catch"],
        ["heal", "battle", "item"],
        ["catch", "item", "battle"],
        ["battle", "heal", "catch"],
        ["item", "catch", "battle"],
        ["heal", "catch", "battle"],
        ["battle", "item", "heal"]
    ]
    var labels: Dictionary = {
        "heal": ["💧 Heilquelle", "Dein gesamtes Team wird vollständig geheilt."],
        "item": ["🎒 Fundstelle", "Später gäbe es hier ein Item; aktuell wird stattdessen geheilt."],
        "catch": ["🌿 Fangwiese", "Du erhältst ein zufälliges Pokémon auf Level 3."],
        "battle": ["⚔ Direkter Pfad", "Keine Hilfe vor dem Kampf, dafür 25% mehr EP für diesen Sieg."]
    }

    var result: Array[Dictionary] = []
    var set_value: Array = sets[clampi(current_stage - 1, 0, sets.size() - 1)]
    for kind_value: Variant in set_value:
        var kind: String = str(kind_value)
        var info: Array = labels.get(kind, [kind, ""])
        result.append({"kind": kind, "label": str(info[0]), "hint": str(info[1])})
    return result


func _choose_path(choice: Dictionary) -> void:
    _set_path_buttons_disabled(true)
    _clear_container(capture_actions)
    continue_button.visible = false
    stage_xp_multiplier = 1.0

    var kind: String = str(choice.get("kind", "battle"))
    match kind:
        "heal":
            _heal_team()
            event_label.text = "[b]Heilquelle[/b]\nDein gesamtes Team ist wieder vollständig kampfbereit."
            continue_button.visible = true
        "item":
            _heal_team()
            event_label.text = "[b]Fundstelle[/b]\nHier würdest du normalerweise ein Item erhalten. Für die Demo wird dein Team stattdessen vollständig geheilt."
            continue_button.visible = true
        "catch":
            _begin_capture_event()
        _:
            stage_xp_multiplier = 1.25
            event_label.text = "[b]Direkter Pfad[/b]\nDu gehst ohne Unterstützung in den Kampf. Bei einem Sieg erhält dein Team 25% mehr EP."
            continue_button.visible = true

    _refresh_team_panel()


func _begin_capture_event() -> void:
    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        event_label.text = "An dieser Fangstelle taucht heute kein Pokémon auf."
        continue_button.visible = true
        return

    var sid: String = str(ids.pick_random())
    pending_capture = battle_demo.route_new_member(sid, CAPTURE_LEVEL)
    var name: String = str(pending_capture.get("name", battle_demo.route_species_name(sid)))

    if team.size() < MAX_TEAM_SIZE:
        team.append(pending_capture)
        pending_capture = {}
        event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen und deinem Team hinzugefügt." % [name, CAPTURE_LEVEL]
        continue_button.visible = true
        _refresh_team_panel()
        return

    event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen. Dein Team ist voll. Möchtest du es einlagern oder ein Team-Pokémon ersetzen?" % [name, CAPTURE_LEVEL]

    var store_button := Button.new()
    store_button.text = "EINLAGERN"
    store_button.pressed.connect(_store_pending_capture)
    capture_actions.add_child(store_button)

    var replace_button := Button.new()
    replace_button.text = "TEAM-POKÉMON ERSETZEN"
    replace_button.pressed.connect(_show_replace_choices)
    capture_actions.add_child(replace_button)


func _store_pending_capture() -> void:
    if pending_capture.is_empty():
        return
    var name: String = str(pending_capture.get("name", "Pokémon"))
    storage.append(pending_capture)
    pending_capture = {}
    _clear_container(capture_actions)
    event_label.text = "%s wurde eingelagert." % name
    continue_button.visible = true
    _refresh_team_panel()


func _show_replace_choices() -> void:
    _clear_container(capture_actions)

    var prompt := Label.new()
    prompt.text = "Welches Pokémon soll ins Lager?"
    prompt.add_theme_font_size_override("font_size", 9)
    capture_actions.add_child(prompt)

    for index: int in range(team.size()):
        var member: Dictionary = team[index]
        var button := Button.new()
        button.text = "%d. %s Lv.%d" % [index + 1, str(member.get("name", "Pokémon")), int(member.get("level", 1))]
        button.custom_minimum_size = Vector2(0, 24)
        button.pressed.connect(_replace_team_member.bind(index))
        capture_actions.add_child(button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.pressed.connect(_begin_capture_event_again)
    capture_actions.add_child(back_button)


func _begin_capture_event_again() -> void:
    if pending_capture.is_empty():
        return
    _clear_container(capture_actions)
    var name: String = str(pending_capture.get("name", "Pokémon"))
    event_label.text = "%s wartet auf deine Entscheidung: einlagern oder Team-Pokémon ersetzen?" % name

    var store_button := Button.new()
    store_button.text = "EINLAGERN"
    store_button.pressed.connect(_store_pending_capture)
    capture_actions.add_child(store_button)

    var replace_button := Button.new()
    replace_button.text = "TEAM-POKÉMON ERSETZEN"
    replace_button.pressed.connect(_show_replace_choices)
    capture_actions.add_child(replace_button)


func _replace_team_member(index: int) -> void:
    if pending_capture.is_empty() or index < 0 or index >= team.size():
        return
    var old_member: Dictionary = team[index]
    var new_name: String = str(pending_capture.get("name", "Pokémon"))
    storage.append(old_member)
    team[index] = pending_capture
    pending_capture = {}
    _clear_container(capture_actions)
    event_label.text = "%s kommt ins Team. %s wurde eingelagert." % [new_name, str(old_member.get("name", "Pokémon"))]
    continue_button.visible = true
    _refresh_team_panel()


func _heal_team() -> void:
    for member_value: Variant in team:
        var member: Dictionary = member_value
        member["hp"] = int(member.get("max_hp", 1))
        member["major_status"] = ""


func _start_stage_battle() -> void:
    if battle_demo == null:
        return
    continue_button.visible = false

    if not _team_has_living_member():
        _finish_run(false, "Dein gesamtes Team ist kampfunfähig.")
        return

    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        return
    var enemy_id: String = str(ids.pick_random())

    event_label.text = "Ein wildes [b]%s Lv.%d[/b] stellt sich dir in den Weg." % [battle_demo.route_species_name(enemy_id), stage]
    last_route_message = event_label.text
    visible = false
    battle_demo.start_route_battle(team, enemy_id, stage)


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    team = updated_team.duplicate(true)
    visible = true

    if not victory:
        _finish_run(false, "Du hast den Kampf auf Etappe %d verloren." % stage)
        return

    var base_xp: int = 20 + stage * 12
    var gained_xp: int = maxi(1, int(round(float(base_xp) * stage_xp_multiplier)))
    var level_messages: Array[String] = _award_experience(gained_xp)
    var summary: String = "[b]Etappe %d geschafft![/b]\nDein kampffähiges Team erhält %d EP." % [stage, gained_xp]
    if not level_messages.is_empty():
        summary += "\n" + "\n".join(level_messages)

    if stage >= STAGE_COUNT:
        _finish_run(true, summary + "\n\nDu hast alle zehn Etappen der Demo-Route geschafft.")
        return

    stage += 1
    _show_stage_choices(summary + "\n\nDer Weg teilt sich erneut.")


func _award_experience(amount: int) -> Array[String]:
    var messages: Array[String] = []
    for member_value: Variant in team:
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue

        var xp: int = int(member.get("xp", 0)) + amount
        var level: int = int(member.get("level", 1))
        var learned_total: Array[String] = []
        var leveled: bool = false

        while xp >= _xp_needed(level):
            xp -= _xp_needed(level)
            var old_moves: Array = battle_demo.route_moves_for_level(str(member.get("species_id", "")), level)
            var old_max_hp: int = int(member.get("max_hp", 1))
            level += 1
            var refreshed: Dictionary = battle_demo.route_new_member(str(member.get("species_id", "")), level)
            var new_max_hp: int = int(refreshed.get("max_hp", old_max_hp))
            member["level"] = level
            member["max_hp"] = new_max_hp
            member["hp"] = mini(new_max_hp, int(member.get("hp", 0)) + maxi(0, new_max_hp - old_max_hp))

            var new_moves: Array = battle_demo.route_moves_for_level(str(member.get("species_id", "")), level)
            for move_value: Variant in new_moves:
                if not old_moves.has(move_value):
                    learned_total.append(battle_demo.route_move_name(str(move_value)))
            leveled = true

        member["xp"] = xp
        if leveled:
            var text: String = "%s erreicht Lv.%d!" % [str(member.get("name", "Pokémon")), level]
            if not learned_total.is_empty():
                text += " Neue Attacke: " + ", ".join(learned_total)
            messages.append(text)

    _refresh_team_panel()
    return messages


func _xp_needed(level: int) -> int:
    return 50 + maxi(1, level) * 15


func _team_has_living_member() -> bool:
    for member_value: Variant in team:
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) > 0:
            return true
    return false


func _refresh_team_panel() -> void:
    if team_box == null:
        return
    _clear_container(team_box)

    for index: int in range(team.size()):
        var member: Dictionary = team[index]
        var card := PanelContainer.new()
        card.add_theme_stylebox_override("panel", _panel(Color("182822"), Color("3c574c"), 5, 3.0))
        team_box.add_child(card)

        var text := Label.new()
        var status: String = _status_short(str(member.get("major_status", "")))
        text.text = "%d. %s  Lv.%d\nKP %d/%d · EP %d/%d%s" % [
            index + 1,
            str(member.get("name", "Pokémon")),
            int(member.get("level", 1)),
            int(member.get("hp", 0)),
            int(member.get("max_hp", 1)),
            int(member.get("xp", 0)),
            _xp_needed(int(member.get("level", 1))),
            status
        ]
        text.add_theme_font_size_override("font_size", 9)
        card.add_child(text)

    var stored_names: Array[String] = []
    for stored_value: Variant in storage:
        var stored: Dictionary = stored_value
        stored_names.append(str(stored.get("name", "Pokémon")))
    storage_label.text = "Lager: %d%s" % [storage.size(), (" · " + ", ".join(stored_names)) if not stored_names.is_empty() else ""]


func _status_short(status: String) -> String:
    match status:
        "paralysis":
            return " · PAR"
        "burn":
            return " · BRN"
        "poison":
            return " · GIF"
        _:
            return ""


func _finish_run(victory: bool, message: String) -> void:
    visible = true
    _clear_container(path_box)
    _clear_container(capture_actions)
    continue_button.visible = false
    restart_button.visible = true
    title_label.text = "ROUTE GESCHAFFT!" if victory else "ROUTE BEENDET"
    progress_label.text = _progress_text()
    event_label.text = message
    _refresh_team_panel()


func _set_path_buttons_disabled(disabled: bool) -> void:
    for child: Node in path_box.get_children():
        if child is Button:
            (child as Button).disabled = disabled


func _clear_container(container: Node) -> void:
    if container == null:
        return
    for child: Node in container.get_children():
        child.queue_free()


func _go_main_menu() -> void:
    visible = false
    request_main_menu.emit()
