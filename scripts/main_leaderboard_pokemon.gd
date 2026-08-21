extends "res://scripts/main.gd"

const LEADERBOARD_NAME_MAX_LENGTH := 14
const LEADERBOARD_POKEMON_SIZE := 46
const LEADERBOARD_MEMBER_WIDTH := 58

var leaderboard_entries: VBoxContainer
var leaderboard_empty_label: Label


func _build_leaderboard_overlay() -> void:
    leaderboard_overlay = Control.new()
    leaderboard_overlay.name = "LeaderboardOverlay"
    leaderboard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    leaderboard_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    leaderboard_overlay.z_index = 30
    leaderboard_overlay.visible = false
    menu_root.add_child(leaderboard_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.76)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    leaderboard_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    leaderboard_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(620, 344)
    panel.add_theme_stylebox_override("panel", _panel(Color("172823"), Color("e0c95f"), 14, 10.0))
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    panel.add_child(content)

    var title := Label.new()
    title.text = "BESTENLISTE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Höchste erreichte Etappe zuerst · letztes Team"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 11)
    subtitle.add_theme_color_override("font_color", Color("b7cfc4"))
    content.add_child(subtitle)

    var scroll := ScrollContainer.new()
    scroll.name = "LeaderboardScroll"
    scroll.custom_minimum_size = Vector2(580, 224)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(scroll)

    leaderboard_entries = VBoxContainer.new()
    leaderboard_entries.name = "LeaderboardEntries"
    leaderboard_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    leaderboard_entries.add_theme_constant_override("separation", 6)
    scroll.add_child(leaderboard_entries)

    leaderboard_empty_label = Label.new()
    leaderboard_empty_label.text = "Noch keine Läufe gespeichert.\nSchließe eine Demo-Route ab."
    leaderboard_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    leaderboard_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    leaderboard_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    leaderboard_empty_label.custom_minimum_size = Vector2(560, 190)
    leaderboard_empty_label.add_theme_font_size_override("font_size", 15)
    leaderboard_empty_label.add_theme_color_override("font_color", Color("c4d9d0"))
    leaderboard_empty_label.visible = false
    leaderboard_entries.add_child(leaderboard_empty_label)

    var button_row := HBoxContainer.new()
    button_row.alignment = BoxContainer.ALIGNMENT_CENTER
    button_row.add_theme_constant_override("separation", 10)
    content.add_child(button_row)

    var reset_button := Button.new()
    reset_button.name = "ResetLeaderboardButton"
    reset_button.text = "Liste löschen"
    reset_button.custom_minimum_size = Vector2(150, 34)
    reset_button.pressed.connect(_on_reset_leaderboard)
    button_row.add_child(reset_button)

    var close_button := Button.new()
    close_button.text = "ZURÜCK"
    close_button.custom_minimum_size = Vector2(150, 34)
    close_button.pressed.connect(_hide_leaderboard)
    button_row.add_child(close_button)


func _refresh_leaderboard() -> void:
    if leaderboard_entries == null:
        return

    for child: Node in leaderboard_entries.get_children():
        if child != leaderboard_empty_label:
            child.queue_free()

    var entries: Array = LeaderboardStore.load_entries()
    leaderboard_empty_label.visible = entries.is_empty()
    if entries.is_empty():
        return

    for i in range(mini(entries.size(), 10)):
        var entry_value: Variant = entries[i]
        if not (entry_value is Dictionary):
            continue
        _add_leaderboard_entry(i, entry_value)


func _add_leaderboard_entry(index: int, entry: Dictionary) -> void:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(560, 78)
    var border_color := Color("5d786d")
    if index < 3:
        border_color = Color("d7bd55")
    card.add_theme_stylebox_override("panel", _panel(Color("20362f"), border_color, 10, 7.0))
    leaderboard_entries.add_child(card)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    card.add_child(row)

    var summary := VBoxContainer.new()
    summary.custom_minimum_size = Vector2(150, 0)
    summary.alignment = BoxContainer.ALIGNMENT_CENTER
    summary.add_theme_constant_override("separation", 2)
    row.add_child(summary)

    var rank_stage := Label.new()
    rank_stage.text = "%d.  ·  ETAPPE %d" % [index + 1, int(entry.get("stage", 0))]
    rank_stage.add_theme_font_size_override("font_size", 11)
    rank_stage.add_theme_color_override("font_color", Color("ffe46f") if index < 3 else Color("b7cfc4"))
    summary.add_child(rank_stage)

    var player_name := Label.new()
    player_name.text = _short_leaderboard_name(str(entry.get("name", "Trainer")))
    player_name.add_theme_font_size_override("font_size", 17)
    player_name.add_theme_color_override("font_color", Color("f3f7f5"))
    summary.add_child(player_name)

    var team := HBoxContainer.new()
    team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    team.alignment = BoxContainer.ALIGNMENT_END
    team.add_theme_constant_override("separation", 2)
    row.add_child(team)

    _append_leaderboard_team(team, entry)


func _append_leaderboard_team(team_row: HBoxContainer, entry: Dictionary) -> void:
    var team_value: Variant = entry.get("team", [])
    if not (team_value is Array):
        _add_no_team_label(team_row)
        return

    var team: Array = team_value
    var valid_members: Array[Dictionary] = []
    for raw_member: Variant in team:
        if raw_member is Dictionary:
            valid_members.append(raw_member)

    if valid_members.is_empty():
        _add_no_team_label(team_row)
        return

    for member: Dictionary in valid_members:
        _add_team_member(team_row, member)


func _add_team_member(team_row: HBoxContainer, member: Dictionary) -> void:
    var pokemon_name := str(member.get("name", "?"))
    var level := int(member.get("level", 1))

    var member_box := VBoxContainer.new()
    member_box.custom_minimum_size = Vector2(LEADERBOARD_MEMBER_WIDTH, 62)
    member_box.alignment = BoxContainer.ALIGNMENT_CENTER
    member_box.add_theme_constant_override("separation", 0)
    team_row.add_child(member_box)

    var texture := _leaderboard_monster_texture(pokemon_name)
    if texture != null:
        var portrait := TextureRect.new()
        portrait.custom_minimum_size = Vector2(LEADERBOARD_POKEMON_SIZE, LEADERBOARD_POKEMON_SIZE)
        portrait.texture = texture
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        member_box.add_child(portrait)
    else:
        var fallback := Label.new()
        fallback.text = pokemon_name
        fallback.custom_minimum_size = Vector2(LEADERBOARD_POKEMON_SIZE, LEADERBOARD_POKEMON_SIZE)
        fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        fallback.add_theme_font_size_override("font_size", 8)
        fallback.add_theme_color_override("font_color", Color("dbe7e2"))
        member_box.add_child(fallback)

    var level_label := Label.new()
    level_label.text = "Lv.%d" % level
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    level_label.add_theme_font_size_override("font_size", 10)
    level_label.add_theme_color_override("font_color", Color("e7f0eb"))
    member_box.add_child(level_label)


func _add_no_team_label(team_row: HBoxContainer) -> void:
    var label := Label.new()
    label.text = "Kein Team gespeichert"
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", Color("91b0a3"))
    team_row.add_child(label)


func _short_leaderboard_name(player_name: String) -> String:
    var clean_name := player_name.strip_edges()
    if clean_name.is_empty():
        return "Trainer"
    if clean_name.length() <= LEADERBOARD_NAME_MAX_LENGTH:
        return clean_name
    return clean_name.left(LEADERBOARD_NAME_MAX_LENGTH - 1) + "…"


func _leaderboard_monster_texture(pokemon_name: String) -> Texture2D:
    var clean_name := pokemon_name.strip_edges()
    if clean_name.is_empty():
        return null

    var path := "res://assets/monsters/%s.png" % clean_name
    if not ResourceLoader.exists(path):
        return null
    return ResourceLoader.load(path) as Texture2D


func _on_reset_leaderboard() -> void:
    var save_path := ProjectSettings.globalize_path(LeaderboardStore.SAVE_PATH)
    if FileAccess.file_exists(LeaderboardStore.SAVE_PATH):
        var remove_error := DirAccess.remove_absolute(save_path)
        if remove_error != OK:
            push_warning("Bestenliste konnte nicht gelöscht werden: %s" % error_string(remove_error))
    _refresh_leaderboard()
