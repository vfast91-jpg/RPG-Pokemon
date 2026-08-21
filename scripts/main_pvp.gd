extends "res://scripts/main_leaderboard_pokemon.gd"

# Main-menu and local draft flow for Player vs Player. The underlying battle is
# still the same BattleDemo node; only the setup/controller mode changes.

var pvp_overlay: Control
var pvp_detail_overlay: Control
var pvp_detail_title: Label
var pvp_detail_body: RichTextLabel
var pvp_title: Label
var pvp_subtitle: Label
var pvp_level_section: VBoxContainer
var pvp_draft_section: VBoxContainer
var pvp_review_section: VBoxContainer
var pvp_level_picker: SpinBox
var pvp_draft_status: Label
var pvp_team_one_row: HBoxContainer
var pvp_team_two_row: HBoxContainer
var pvp_review_team_one_row: HBoxContainer
var pvp_review_team_two_row: HBoxContainer
var pvp_candidate_row: HBoxContainer

var pvp_level: int = 50
var pvp_turn: int = 0
var pvp_catalog_entries: Array = []
var pvp_candidates: Array = []
var pvp_player_one: Array = []
var pvp_player_two: Array = []


func _ready() -> void:
    super._ready()
    if battle_demo.has_signal("pvp_request_main_menu"):
        battle_demo.connect("pvp_request_main_menu", Callable(self, "_on_pvp_request_main_menu"))


func _build_main_menu() -> void:
    super._build_main_menu()
    _install_pvp_menu_button()
    _build_pvp_overlay()


func _install_pvp_menu_button() -> void:
    var test_button: Button = _find_menu_button(menu_root, "TESTKAMPF")
    if test_button == null:
        push_warning("PvP-Menü: TESTKAMPF-Button wurde nicht gefunden.")
        return

    var parent: Node = test_button.get_parent()
    if parent == null:
        return
    var old_index: int = test_button.get_index()

    var row := HBoxContainer.new()
    row.name = "BattleModeRow"
    row.custom_minimum_size = Vector2(240, 44)
    row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    row.add_theme_constant_override("separation", 8)
    parent.add_child(row)
    parent.move_child(row, old_index)

    test_button.reparent(row)
    test_button.custom_minimum_size = Vector2(116, 44)
    test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    test_button.add_theme_font_size_override("font_size", 10)

    var pvp_button := Button.new()
    pvp_button.name = "PlayerVsPlayerButton"
    pvp_button.text = "PLAYER VS PLAYER"
    pvp_button.custom_minimum_size = Vector2(116, 44)
    pvp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pvp_button.add_theme_font_size_override("font_size", 9)
    pvp_button.tooltip_text = "Lokales 4-gegen-4: gemeinsames Level wählen, Teams abwechselnd draften und an einem Bildschirm gegeneinander kämpfen."
    pvp_button.pressed.connect(_open_pvp_setup)
    row.add_child(pvp_button)


func _find_menu_button(node: Node, text: String) -> Button:
    for child: Node in node.get_children():
        if child is Button and (child as Button).text == text:
            return child as Button
        var nested: Button = _find_menu_button(child, text)
        if nested != null:
            return nested
    return null


func _build_pvp_overlay() -> void:
    pvp_overlay = Control.new()
    pvp_overlay.name = "PvpSetupOverlay"
    pvp_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pvp_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    pvp_overlay.z_index = 70
    pvp_overlay.visible = false
    menu_root.add_child(pvp_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.80)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    pvp_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pvp_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(606, 334)
    panel.add_theme_stylebox_override("panel", _panel(Color("172823"), Color("e0c95f"), 12, 10.0))
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 5)
    panel.add_child(content)

    pvp_title = Label.new()
    pvp_title.text = "PLAYER VS PLAYER"
    pvp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pvp_title.add_theme_font_size_override("font_size", 22)
    pvp_title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(pvp_title)

    pvp_subtitle = Label.new()
    pvp_subtitle.text = "Lokaler Timeflow-Kampf · ein Bildschirm · zwei Spieler"
    pvp_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pvp_subtitle.add_theme_font_size_override("font_size", 10)
    pvp_subtitle.add_theme_color_override("font_color", Color("b7cfc4"))
    content.add_child(pvp_subtitle)

    _build_pvp_level_section(content)
    _build_pvp_draft_section(content)
    _build_pvp_review_section(content)
    _build_pvp_detail_overlay()
    _set_pvp_stage("level")


func _build_pvp_level_section(parent: VBoxContainer) -> void:
    pvp_level_section = VBoxContainer.new()
    pvp_level_section.alignment = BoxContainer.ALIGNMENT_CENTER
    pvp_level_section.add_theme_constant_override("separation", 10)
    pvp_level_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(pvp_level_section)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 18)
    pvp_level_section.add_child(spacer)

    var label := Label.new()
    label.text = "Welches Level sollen alle Pokémon haben?"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color("e7f0eb"))
    pvp_level_section.add_child(label)

    pvp_level_picker = SpinBox.new()
    pvp_level_picker.min_value = 1.0
    pvp_level_picker.max_value = 100.0
    pvp_level_picker.step = 1.0
    pvp_level_picker.value = 50.0
    pvp_level_picker.custom_minimum_size = Vector2(150, 34)
    pvp_level_picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    pvp_level_section.add_child(pvp_level_picker)

    var hint := Label.new()
    hint.text = "Das gewählte Level gilt für alle acht Pokémon. Verfügbare Formen und Attacken richten sich danach."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.custom_minimum_size = Vector2(500, 32)
    hint.add_theme_font_size_override("font_size", 10)
    hint.add_theme_color_override("font_color", Color("a9c2b7"))
    pvp_level_section.add_child(hint)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 10)
    pvp_level_section.add_child(buttons)

    var back := Button.new()
    back.text = "ZURÜCK"
    back.custom_minimum_size = Vector2(130, 34)
    back.pressed.connect(_close_pvp_overlay)
    buttons.add_child(back)

    var begin := Button.new()
    begin.text = "DRAFT STARTEN"
    begin.custom_minimum_size = Vector2(170, 34)
    begin.pressed.connect(_begin_pvp_draft)
    buttons.add_child(begin)


func _build_pvp_draft_section(parent: VBoxContainer) -> void:
    pvp_draft_section = VBoxContainer.new()
    pvp_draft_section.add_theme_constant_override("separation", 4)
    pvp_draft_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(pvp_draft_section)

    var teams := HBoxContainer.new()
    teams.alignment = BoxContainer.ALIGNMENT_CENTER
    teams.add_theme_constant_override("separation", 8)
    pvp_draft_section.add_child(teams)

    var left: Dictionary = _make_pvp_team_panel("SPIELER 1")
    pvp_team_one_row = left["row"] as HBoxContainer
    teams.add_child(left["panel"] as PanelContainer)

    var right: Dictionary = _make_pvp_team_panel("SPIELER 2")
    pvp_team_two_row = right["row"] as HBoxContainer
    teams.add_child(right["panel"] as PanelContainer)

    pvp_draft_status = Label.new()
    pvp_draft_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pvp_draft_status.add_theme_font_size_override("font_size", 14)
    pvp_draft_status.add_theme_color_override("font_color", Color("ffe46f"))
    pvp_draft_section.add_child(pvp_draft_status)

    pvp_candidate_row = HBoxContainer.new()
    pvp_candidate_row.alignment = BoxContainer.ALIGNMENT_CENTER
    pvp_candidate_row.add_theme_constant_override("separation", 8)
    pvp_candidate_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    pvp_draft_section.add_child(pvp_candidate_row)

    var cancel := Button.new()
    cancel.text = "DRAFT ABBRECHEN"
    cancel.custom_minimum_size = Vector2(150, 28)
    cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    cancel.pressed.connect(_close_pvp_overlay)
    pvp_draft_section.add_child(cancel)


func _build_pvp_review_section(parent: VBoxContainer) -> void:
    pvp_review_section = VBoxContainer.new()
    pvp_review_section.alignment = BoxContainer.ALIGNMENT_CENTER
    pvp_review_section.add_theme_constant_override("separation", 10)
    pvp_review_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(pvp_review_section)

    var ready := Label.new()
    ready.text = "BEIDE TEAMS STEHEN"
    ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ready.add_theme_font_size_override("font_size", 17)
    ready.add_theme_color_override("font_color", Color("ffe46f"))
    pvp_review_section.add_child(ready)

    var level_label := Label.new()
    level_label.name = "ReviewLevel"
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    level_label.add_theme_font_size_override("font_size", 11)
    level_label.add_theme_color_override("font_color", Color("c7d9d1"))
    pvp_review_section.add_child(level_label)

    var teams := HBoxContainer.new()
    teams.alignment = BoxContainer.ALIGNMENT_CENTER
    teams.add_theme_constant_override("separation", 8)
    pvp_review_section.add_child(teams)

    var left: Dictionary = _make_pvp_team_panel("SPIELER 1")
    pvp_review_team_one_row = left["row"] as HBoxContainer
    teams.add_child(left["panel"] as PanelContainer)

    var right: Dictionary = _make_pvp_team_panel("SPIELER 2")
    pvp_review_team_two_row = right["row"] as HBoxContainer
    teams.add_child(right["panel"] as PanelContainer)

    var note := Label.new()
    note.text = "Im normalen Timeflow wird jede Aktion sofort ausgeführt. Nur Runde 0 nutzt beim Seitenwechsel einen neutralen Übergabebildschirm."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.custom_minimum_size = Vector2(520, 38)
    note.add_theme_font_size_override("font_size", 9)
    note.add_theme_color_override("font_color", Color("a9c2b7"))
    pvp_review_section.add_child(note)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 10)
    pvp_review_section.add_child(buttons)

    var restart := Button.new()
    restart.text = "DRAFT NEU STARTEN"
    restart.custom_minimum_size = Vector2(170, 34)
    restart.pressed.connect(_begin_pvp_draft)
    buttons.add_child(restart)

    var fight := Button.new()
    fight.text = "KAMPF STARTEN"
    fight.custom_minimum_size = Vector2(170, 34)
    fight.pressed.connect(_start_pvp_battle)
    buttons.add_child(fight)


func _make_pvp_team_panel(title_text: String) -> Dictionary:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(284, 66)
    panel.add_theme_stylebox_override("panel", _panel(Color("20362f"), Color("557368"), 8, 5.0))

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 1)
    panel.add_child(content)

    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 10)
    title.add_theme_color_override("font_color", Color("dfeae5"))
    content.add_child(title)

    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 2)
    content.add_child(row)

    return {"panel": panel, "row": row}


func _build_pvp_detail_overlay() -> void:
    pvp_detail_overlay = Control.new()
    pvp_detail_overlay.name = "PvpPokemonDetails"
    pvp_detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pvp_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    pvp_detail_overlay.z_index = 20
    pvp_detail_overlay.visible = false
    pvp_overlay.add_child(pvp_detail_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    pvp_detail_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pvp_detail_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(440, 270)
    panel.add_theme_stylebox_override("panel", _panel(Color("172823"), Color("e0c95f"), 10, 9.0))
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    panel.add_child(content)

    pvp_detail_title = Label.new()
    pvp_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pvp_detail_title.add_theme_font_size_override("font_size", 18)
    pvp_detail_title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(pvp_detail_title)

    pvp_detail_body = RichTextLabel.new()
    pvp_detail_body.bbcode_enabled = true
    pvp_detail_body.scroll_active = true
    pvp_detail_body.custom_minimum_size = Vector2(410, 190)
    pvp_detail_body.add_theme_font_size_override("normal_font_size", 10)
    pvp_detail_body.add_theme_font_size_override("bold_font_size", 10)
    pvp_detail_body.add_theme_color_override("default_color", Color("e3ede8"))
    content.add_child(pvp_detail_body)

    var close := Button.new()
    close.text = "SCHLIESSEN"
    close.custom_minimum_size = Vector2(140, 30)
    close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    close.pressed.connect(_hide_pvp_detail)
    content.add_child(close)


func _open_pvp_setup() -> void:
    _hide_leaderboard()
    _hide_timeflow_help()
    pvp_level = 50
    pvp_level_picker.value = 50.0
    pvp_player_one.clear()
    pvp_player_two.clear()
    pvp_catalog_entries.clear()
    pvp_candidates.clear()
    pvp_turn = 0
    pvp_subtitle.text = "Lokaler Timeflow-Kampf · ein Bildschirm · zwei Spieler"
    _hide_pvp_detail()
    _set_pvp_stage("level")
    pvp_overlay.visible = true


func _close_pvp_overlay() -> void:
    _hide_pvp_detail()
    if pvp_overlay != null:
        pvp_overlay.visible = false


func _begin_pvp_draft() -> void:
    pvp_level = clampi(int(pvp_level_picker.value), 1, 100)
    var catalog_value: Variant = battle_demo.call("pvp_catalog", pvp_level)
    pvp_catalog_entries = catalog_value.duplicate(true) if catalog_value is Array else []

    if pvp_catalog_entries.size() < 3:
        pvp_subtitle.text = "Für dieses Level stehen noch nicht genug vollständig spielbare Pokémon zur Verfügung."
        _set_pvp_stage("level")
        return

    pvp_player_one.clear()
    pvp_player_two.clear()
    pvp_candidates.clear()
    pvp_turn = 0
    pvp_subtitle.text = "Jeder Pick zeigt drei zufällige Pokémon · keine Doppelung im eigenen Team"
    _set_pvp_stage("draft")
    _roll_pvp_candidates()


func _roll_pvp_candidates() -> void:
    var own_team: Array = pvp_player_one if pvp_turn % 2 == 0 else pvp_player_two
    var pool: Array = []

    for entry_value: Variant in pvp_catalog_entries:
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var species_id: String = str(entry.get("id", ""))
        if species_id.is_empty() or own_team.has(species_id):
            continue
        pool.append(entry.duplicate(true))

    if pool.size() < 3:
        pvp_subtitle.text = "Der Draft-Pool ist zu klein, um drei unterschiedliche Kandidaten anzubieten."
        return

    pool.shuffle()
    pvp_candidates = []
    for index: int in range(3):
        pvp_candidates.append((pool[index] as Dictionary).duplicate(true))
    _refresh_pvp_draft()


func _refresh_pvp_draft() -> void:
    _populate_pvp_team_row(pvp_team_one_row, pvp_player_one)
    _populate_pvp_team_row(pvp_team_two_row, pvp_player_two)

    var player_number: int = 1 if pvp_turn % 2 == 0 else 2
    var pick_number: int = int(floor(float(pvp_turn) / 2.0)) + 1
    pvp_draft_status.text = "SPIELER %d · WÄHLE POKÉMON %d/4" % [player_number, pick_number]

    _clear_pvp_container(pvp_candidate_row)
    for entry_value: Variant in pvp_candidates:
        if entry_value is Dictionary:
            pvp_candidate_row.add_child(_make_pvp_candidate_card(entry_value as Dictionary))


func _make_pvp_candidate_card(entry: Dictionary) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(184, 142)
    panel.add_theme_stylebox_override("panel", _panel(Color("20362f"), Color("6c8e80"), 8, 5.0))

    var content := VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 1)
    panel.add_child(content)

    var portrait := TextureRect.new()
    portrait.custom_minimum_size = Vector2(56, 56)
    portrait.texture = battle_demo.call("pvp_species_texture", str(entry.get("id", ""))) as Texture2D
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    content.add_child(portrait)

    var name := Label.new()
    name.text = str(entry.get("name", "Pokémon"))
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.add_theme_font_size_override("font_size", 13)
    name.add_theme_color_override("font_color", Color("f1f6f3"))
    content.add_child(name)

    var types := Label.new()
    types.text = _pvp_type_text(entry.get("types", []))
    types.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    types.add_theme_font_size_override("font_size", 9)
    types.add_theme_color_override("font_color", Color("b9d1c6"))
    content.add_child(types)

    var count := Label.new()
    var moves_value: Variant = entry.get("moves", [])
    var move_count: int = moves_value.size() if moves_value is Array else 0
    count.text = "%d Attacken auf Lv.%d" % [move_count, pvp_level]
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count.add_theme_font_size_override("font_size", 8)
    count.add_theme_color_override("font_color", Color("8faea0"))
    content.add_child(count)

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 4)
    content.add_child(buttons)

    var choose := Button.new()
    choose.text = "WÄHLEN"
    choose.custom_minimum_size = Vector2(104, 25)
    choose.pressed.connect(_choose_pvp_candidate.bind(str(entry.get("id", ""))))
    buttons.add_child(choose)

    var info := Button.new()
    info.text = "i"
    info.custom_minimum_size = Vector2(28, 25)
    info.tooltip_text = "Werte und Attacken ansehen"
    info.pressed.connect(_show_pvp_detail.bind(entry.duplicate(true)))
    buttons.add_child(info)

    return panel


func _choose_pvp_candidate(species_id: String) -> void:
    if species_id.is_empty() or pvp_turn >= 8:
        return

    var own_team: Array = pvp_player_one if pvp_turn % 2 == 0 else pvp_player_two
    if own_team.has(species_id):
        return
    own_team.append(species_id)

    pvp_turn += 1
    if pvp_turn >= 8:
        _show_pvp_review()
        return
    _roll_pvp_candidates()


func _show_pvp_review() -> void:
    _set_pvp_stage("review")
    _populate_pvp_team_row(pvp_review_team_one_row, pvp_player_one)
    _populate_pvp_team_row(pvp_review_team_two_row, pvp_player_two)
    var level_label := pvp_review_section.get_node_or_null("ReviewLevel") as Label
    if level_label != null:
        level_label.text = "Gemeinsames Level: %d" % pvp_level
    pvp_subtitle.text = "Der Draft ist abgeschlossen. Jetzt startet echter Mensch-gegen-Mensch-Timeflow."


func _start_pvp_battle() -> void:
    if pvp_player_one.size() != 4 or pvp_player_two.size() != 4:
        pvp_subtitle.text = "Beide Spieler brauchen genau vier Pokémon."
        return

    var started: bool = bool(battle_demo.call(
        "start_pvp_battle",
        pvp_player_one.duplicate(),
        pvp_player_two.duplicate(),
        pvp_level
    ))
    if not started:
        pvp_subtitle.text = "Der PvP-Kampf konnte nicht gestartet werden."
        return

    _hide_pvp_detail()
    pvp_overlay.visible = false
    menu_layer.visible = false
    demo_route.visible = false
    battle_demo.visible = true


func _set_pvp_stage(stage: String) -> void:
    if pvp_level_section != null:
        pvp_level_section.visible = stage == "level"
    if pvp_draft_section != null:
        pvp_draft_section.visible = stage == "draft"
    if pvp_review_section != null:
        pvp_review_section.visible = stage == "review"


func _populate_pvp_team_row(row: HBoxContainer, picks: Array) -> void:
    if row == null:
        return
    _clear_pvp_container(row)

    for index: int in range(4):
        var slot := VBoxContainer.new()
        slot.custom_minimum_size = Vector2(64, 42)
        slot.alignment = BoxContainer.ALIGNMENT_CENTER
        slot.add_theme_constant_override("separation", 0)
        row.add_child(slot)

        if index >= picks.size():
            var empty := Label.new()
            empty.text = "—"
            empty.custom_minimum_size = Vector2(32, 32)
            empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            empty.add_theme_font_size_override("font_size", 18)
            empty.add_theme_color_override("font_color", Color("708b80"))
            slot.add_child(empty)

            var number := Label.new()
            number.text = str(index + 1)
            number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            number.add_theme_font_size_override("font_size", 7)
            number.add_theme_color_override("font_color", Color("708b80"))
            slot.add_child(number)
            continue

        var species_id: String = str(picks[index])
        var entry: Dictionary = _pvp_catalog_entry(species_id)
        var portrait := TextureRect.new()
        portrait.custom_minimum_size = Vector2(32, 32)
        portrait.texture = battle_demo.call("pvp_species_texture", species_id) as Texture2D
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        slot.add_child(portrait)

        var name := Label.new()
        name.text = _pvp_short_name(str(entry.get("name", species_id)))
        name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name.add_theme_font_size_override("font_size", 7)
        name.add_theme_color_override("font_color", Color("dbe8e2"))
        slot.add_child(name)


func _pvp_catalog_entry(species_id: String) -> Dictionary:
    for entry_value: Variant in pvp_catalog_entries:
        if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == species_id:
            return entry_value as Dictionary
    return {"id": species_id, "name": species_id, "types": [], "moves": [], "stats": {}}


func _pvp_short_name(value: String) -> String:
    if value.length() <= 10:
        return value
    return value.left(9) + "…"


func _pvp_type_text(types_value: Variant) -> String:
    if not (types_value is Array):
        return "–"
    var names: Array[String] = []
    for type_value: Variant in types_value:
        names.append(str(battle_demo.call("pvp_type_name", str(type_value))))
    return " / ".join(names) if not names.is_empty() else "–"


func _show_pvp_detail(entry: Dictionary) -> void:
    pvp_detail_title.text = "%s · Lv.%d" % [str(entry.get("name", "Pokémon")), pvp_level]

    var stats_value: Variant = entry.get("stats", {})
    var stats: Dictionary = stats_value if stats_value is Dictionary else {}
    var lines: Array[String] = []
    lines.append("[b]TYPEN[/b]  " + _pvp_type_text(entry.get("types", [])))
    lines.append("")
    lines.append("[b]WERTE[/b]")
    lines.append(
        "KP %d · Angriff %d · Verteidigung %d · Status %d · Geschwindigkeit %d"
        % [
            int(stats.get("hp", 0)),
            int(stats.get("attack", 0)),
            int(stats.get("defense", 0)),
            int(stats.get("status", 0)),
            int(stats.get("speed", 0))
        ]
    )
    lines.append("")
    lines.append("[b]VERFÜGBARE ATTACKEN[/b]")

    var moves_value: Variant = entry.get("moves", [])
    if moves_value is Array and not (moves_value as Array).is_empty():
        for move_value: Variant in moves_value:
            lines.append("• " + str(move_value))
    else:
        lines.append("• Keine normale Kampfattacke verfügbar")

    pvp_detail_body.text = "\n".join(lines)
    pvp_detail_body.scroll_to_line(0)
    pvp_detail_overlay.visible = true


func _hide_pvp_detail() -> void:
    if pvp_detail_overlay != null:
        pvp_detail_overlay.visible = false


func _clear_pvp_container(container: Container) -> void:
    if container == null:
        return
    for child: Node in container.get_children():
        container.remove_child(child)
        child.queue_free()


func _on_pvp_request_main_menu() -> void:
    _show_main_menu()


func _show_main_menu() -> void:
    _hide_pvp_detail()
    if pvp_overlay != null:
        pvp_overlay.visible = false
    super._show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and pvp_overlay != null and pvp_overlay.visible:
        if pvp_detail_overlay != null and pvp_detail_overlay.visible:
            _hide_pvp_detail()
        else:
            _close_pvp_overlay()
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)
