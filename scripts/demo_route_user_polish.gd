extends "res://scripts/demo_route_database.gd"

# Final player-requested route layer.
# Extends the test route to 20 stages, scales encounters/captures into the
# evolution range, gives the travelling team visual HP/XP bars and sprites,
# adds a reusable member detail overlay, and removes conflicting historical TM
# numbers from the player-facing route UI while preserving compatibility data.

const ROUTE_STAGE_COUNT: int = 20
const CAPTURE_LEVELS_20: Array[int] = [
    3, 3, 4, 4, 5, 5, 6, 7, 8, 9,
    10, 11, 12, 13, 14, 15, 16, 17, 18, 19
]
const ENEMY_LEVELS_20: Array[int] = [
    2, 3, 3, 4, 4, 5, 6, 7, 8, 9,
    10, 11, 12, 13, 14, 15, 16, 17, 18, 20
]

var _route_info_overlay: Control
var _route_info_title: Label
var _route_info_sprite: TextureRect
var _route_info_body: RichTextLabel


func _ready() -> void:
    super._ready()
    _build_route_member_overlay()


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    title_label.text = "DEMO-ROUTE · ETAPPE %d/%d" % [stage, ROUTE_STAGE_COUNT]
    progress_label.text = _progress_text()


func _progress_text() -> String:
    var tokens: Array[String] = []
    for index: int in range(1, ROUTE_STAGE_COUNT + 1):
        if index < stage:
            tokens.append("●")
        elif index == stage:
            tokens.append("◆")
        else:
            tokens.append("○")
    return " ".join(tokens)


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    # Reuse the established ten path patterns so all inherited TM/capture
    # transformations remain active. In the second half we rotate their order
    # so stages 11-20 do not visually repeat the first half one-for-one.
    var mapped_stage: int = ((maxi(1, current_stage) - 1) % 10) + 1
    var choices: Array[Dictionary] = super._choices_for_stage(mapped_stage)

    if current_stage > 10 and choices.size() > 1:
        var rotations: int = ((current_stage - 11) % choices.size()) + 1
        for _step: int in range(rotations):
            var first: Dictionary = choices.pop_front()
            choices.append(first)

    var capture_level: int = _capture_level_for_stage(current_stage)
    for choice: Dictionary in choices:
        var kind: String = str(choice.get("kind", ""))
        if kind == "catch":
            choice["hint"] = "Du erhältst ein zufälliges Pokémon auf Level %d; nötige Entwicklungen werden berücksichtigt." % capture_level
        elif kind == "battle" and current_stage > 10:
            choice["hint"] = "Direkter Kampf mit 25% mehr EP. In der späten Route treten durch die höheren Level häufiger entwickelte Formen auf."
    return choices


func _capture_level_for_stage(current_stage: int) -> int:
    return CAPTURE_LEVELS_20[clampi(current_stage - 1, 0, CAPTURE_LEVELS_20.size() - 1)]


func _enemy_level_for_stage(current_stage: int) -> int:
    return ENEMY_LEVELS_20[clampi(current_stage - 1, 0, ENEMY_LEVELS_20.size() - 1)]


func _max_reachable_level_from_stage(start_level: int, start_stage: int) -> int:
    var level: int = maxi(1, start_level)
    var xp_pool: int = 0

    for stage_index: int in range(clampi(start_stage, 1, ROUTE_STAGE_COUNT), ROUTE_STAGE_COUNT + 1):
        var base_xp: int = 20 + stage_index * 12
        xp_pool += int(ceil(float(base_xp) * MAX_ROUTE_XP_MULTIPLIER))

    while xp_pool >= _xp_needed(level):
        xp_pool -= _xp_needed(level)
        level += 1
    return level


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    team = updated_team.duplicate(true)
    visible = true

    if not victory:
        _finish_run(false, "Du hast den Kampf auf Etappe %d verloren." % stage)
        return

    var base_xp: int = 20 + stage * 12
    var gained_xp: int = maxi(1, int(round(float(base_xp) * stage_xp_multiplier)))
    var level_messages: Array[String] = _award_experience(gained_xp)
    var summary: String = "[b]Etappe %d geschafft![/b]\nDein Team erhält %d EP." % [stage, gained_xp]
    if not level_messages.is_empty():
        summary += "\n" + "\n".join(level_messages)

    if stage >= ROUTE_STAGE_COUNT:
        _finish_run(true, summary + "\n\nDu hast alle 20 Etappen der Demo-Route geschafft.")
        return

    stage += 1
    _show_stage_choices(summary + "\n\nDer Weg teilt sich erneut.")


func _reload_tm_catalog() -> void:
    super._reload_tm_catalog()

    # Historical TM/TR numbers come from different source games and can name
    # different moves. The RPG therefore treats the move identity as canonical
    # and unions all source compatibilities for that move. A stable internal
    # RPG key remains for duplicate-learning checks; the number is not shown.
    var collapsed: Dictionary = {}
    for entry_value: Variant in _tm_catalog.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var move_id: String = str(entry.get("move_id", ""))
        if move_id.is_empty():
            continue

        var merged_value: Variant = collapsed.get(move_id, {})
        var merged: Dictionary = merged_value if merged_value is Dictionary else {}
        if merged.is_empty():
            merged = entry.duplicate(true)
            merged["number"] = "RPG:" + move_id
            merged["species_ids"] = []

        var target_species: Array = merged.get("species_ids", [])
        var source_species_value: Variant = entry.get("species_ids", [])
        if source_species_value is Array:
            for species_id_value: Variant in source_species_value:
                var species_id: String = str(species_id_value)
                if not target_species.has(species_id):
                    target_species.append(species_id)
        merged["species_ids"] = target_species
        collapsed[move_id] = merged

    _tm_catalog = collapsed


func _database_tm_label(_number: String) -> String:
    # Until a dedicated RPG-wide numbering table is deliberately designed,
    # showing no number is safer than presenting contradictory historic ones.
    return "TM"


func _refresh_team_panel() -> void:
    if team_box == null:
        return
    _clear_container(team_box)

    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        team_box.add_child(_make_route_team_card(member, index))

    var stored_names: Array[String] = []
    for stored_value: Variant in storage:
        if stored_value is Dictionary:
            stored_names.append(str((stored_value as Dictionary).get("name", "Pokémon")))
    storage_label.text = "Lager: %d%s" % [
        storage.size(),
        (" · " + ", ".join(stored_names)) if not stored_names.is_empty() else ""
    ]


func _make_route_team_card(member: Dictionary, index: int) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 58)
    card.add_theme_stylebox_override(
        "panel",
        _panel(Color("182822"), Color("55796a"), 6, 4.0)
    )

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    card.add_child(row)

    var sprite := TextureRect.new()
    sprite.custom_minimum_size = Vector2(44, 44)
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.texture = _route_member_texture(str(member.get("name", "")))
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(sprite)

    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 1)
    row.add_child(content)

    var name_label := Label.new()
    name_label.text = "%d. %s  Lv.%d" % [
        index + 1,
        str(member.get("name", "Pokémon")),
        int(member.get("level", 1))
    ]
    name_label.add_theme_font_size_override("font_size", 10)
    name_label.add_theme_color_override("font_color", Color("ffffff"))
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    content.add_child(name_label)

    var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
    var hp: int = clampi(int(member.get("hp", 0)), 0, max_hp)
    var hp_bar: ProgressBar = _route_progress_bar(
        float(max_hp),
        float(hp),
        Color("55b85a"),
        "KP %d/%d" % [hp, max_hp]
    )
    hp_bar.custom_minimum_size.y = 10.0
    content.add_child(hp_bar)

    var level: int = maxi(1, int(member.get("level", 1)))
    var xp_needed: int = maxi(1, _xp_needed(level))
    var xp: int = clampi(int(member.get("xp", 0)), 0, xp_needed)
    var xp_bar: ProgressBar = _route_progress_bar(
        float(xp_needed),
        float(xp),
        Color("42aef5"),
        "EP %d/%d" % [xp, xp_needed]
    )
    xp_bar.custom_minimum_size.y = 9.0
    content.add_child(xp_bar)

    var status_text: String = _route_status_text(str(member.get("major_status", "")))
    if not status_text.is_empty():
        var status_label := Label.new()
        status_label.text = status_text
        status_label.add_theme_font_size_override("font_size", 7)
        status_label.add_theme_color_override("font_color", Color("ffd98a"))
        content.add_child(status_label)

    var click_area := Button.new()
    click_area.flat = true
    click_area.text = ""
    click_area.focus_mode = Control.FOCUS_NONE
    click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    click_area.tooltip_text = "Pokémon ansehen"
    click_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    click_area.pressed.connect(_show_route_member_info.bind(index))
    card.add_child(click_area)

    return card


func _route_progress_bar(maximum: float, current: float, fill_color: Color, text: String) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.max_value = maxf(1.0, maximum)
    bar.value = clampf(current, 0.0, bar.max_value)
    bar.show_percentage = false
    bar.add_theme_stylebox_override("background", _route_bar_style(Color("33443e")))
    bar.add_theme_stylebox_override("fill", _route_bar_style(fill_color))

    var label := Label.new()
    label.text = text
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 7)
    label.add_theme_color_override("font_color", Color("ffffff"))
    label.add_theme_color_override("font_outline_color", Color("17211f"))
    label.add_theme_constant_override("outline_size", 1)
    bar.add_child(label)
    return bar


func _route_bar_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(3)
    return style


func _route_status_text(status: String) -> String:
    match status:
        "paralysis":
            return "⚡ PARALYSE"
        "burn":
            return "🔥 VERBRANNT"
        "poison":
            return "☠ VERGIFTET"
        _:
            return "" if status.is_empty() else status.to_upper()


func _route_member_texture(display_name: String) -> Texture2D:
    for folder_value: Variant in ["res://assets/monsters/", "res://assets/"]:
        var folder: String = str(folder_value)
        for extension_value: Variant in ["png", "webp", "jpg", "jpeg", "svg"]:
            var path: String = folder + display_name + "." + str(extension_value)
            if ResourceLoader.exists(path):
                var texture: Texture2D = load(path) as Texture2D
                if texture != null:
                    return texture
    return null


func _build_route_member_overlay() -> void:
    if root == null:
        return

    _route_info_overlay = Control.new()
    _route_info_overlay.name = "RouteMemberInfoOverlay"
    _route_info_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _route_info_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _route_info_overlay.z_index = 120
    _route_info_overlay.visible = false
    root.add_child(_route_info_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.74)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _route_info_overlay.add_child(shade)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -245.0
    panel.offset_top = -150.0
    panel.offset_right = 245.0
    panel.offset_bottom = 150.0
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("172923"), Color("ffe576"), 12, 10.0)
    )
    _route_info_overlay.add_child(panel)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 6)
    panel.add_child(outer)

    var header := HBoxContainer.new()
    outer.add_child(header)

    _route_info_title = Label.new()
    _route_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _route_info_title.add_theme_font_size_override("font_size", 18)
    _route_info_title.add_theme_color_override("font_color", Color("ffe576"))
    header.add_child(_route_info_title)

    var close_top := Button.new()
    close_top.text = "×"
    close_top.custom_minimum_size = Vector2(32, 28)
    close_top.pressed.connect(_hide_route_member_info)
    header.add_child(close_top)

    var body_row := HBoxContainer.new()
    body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_row.add_theme_constant_override("separation", 10)
    outer.add_child(body_row)

    _route_info_sprite = TextureRect.new()
    _route_info_sprite.custom_minimum_size = Vector2(118, 150)
    _route_info_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _route_info_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    body_row.add_child(_route_info_sprite)

    _route_info_body = RichTextLabel.new()
    _route_info_body.bbcode_enabled = true
    _route_info_body.scroll_active = true
    _route_info_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _route_info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _route_info_body.custom_minimum_size = Vector2(0, 205)
    _route_info_body.add_theme_font_size_override("normal_font_size", 11)
    _route_info_body.add_theme_font_size_override("bold_font_size", 11)
    body_row.add_child(_route_info_body)

    var close_bottom := Button.new()
    close_bottom.text = "SCHLIESSEN"
    close_bottom.custom_minimum_size = Vector2(140, 28)
    close_bottom.pressed.connect(_hide_route_member_info)
    outer.add_child(close_bottom)


func _show_route_member_info(index: int) -> void:
    if index < 0 or index >= team.size() or _route_info_overlay == null:
        return
    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return
    var member: Dictionary = member_value

    _route_info_title.text = "%s · Lv.%d" % [
        str(member.get("name", "Pokémon")),
        int(member.get("level", 1))
    ]
    _route_info_sprite.texture = _route_member_texture(str(member.get("name", "")))
    _route_info_body.text = _route_member_detail_text(member)
    _route_info_overlay.visible = true


func _hide_route_member_info() -> void:
    if _route_info_overlay != null:
        _route_info_overlay.visible = false


func _route_member_detail_text(member: Dictionary) -> String:
    var species_id: String = str(member.get("species_id", ""))
    var level: int = maxi(1, int(member.get("level", 1)))
    var lines: Array[String] = []

    var species: Dictionary = _route_runtime_species(species_id)
    var type_names: Array[String] = []
    var types_value: Variant = species.get("types", [])
    if types_value is Array:
        for type_value: Variant in types_value:
            type_names.append(_route_type_name(str(type_value)))

    lines.append("[b]STATUS[/b]")
    lines.append("Typ: " + (" / ".join(type_names) if not type_names.is_empty() else "–"))
    lines.append("KP: %d/%d" % [int(member.get("hp", 0)), int(member.get("max_hp", 1))])
    lines.append("EP: %d/%d" % [int(member.get("xp", 0)), _xp_needed(level)])
    var status_text: String = _route_status_text(str(member.get("major_status", "")))
    lines.append("Zustand: " + (status_text if not status_text.is_empty() else "OK"))

    var stats: Dictionary = {}
    if battle_demo != null and battle_demo.has_method("route_stat_snapshot"):
        var stats_value: Variant = battle_demo.route_stat_snapshot(species_id, level)
        if stats_value is Dictionary:
            stats = stats_value

    lines.append("")
    lines.append("[b]WERTE[/b]")
    lines.append("Angriff %d · Verteidigung %d" % [int(stats.get("attack", 0)), int(stats.get("defense", 0))])
    lines.append("Status %d · Initiative %d" % [int(stats.get("special", 0)), int(stats.get("speed", 0))])

    var move_ids: Array = []
    if battle_demo != null and battle_demo.has_method("route_moves_for_level"):
        var level_moves: Array = battle_demo.route_moves_for_level(species_id, level)
        for move_value: Variant in level_moves:
            if not move_ids.has(move_value):
                move_ids.append(move_value)
    var tm_value: Variant = member.get("tm_moves", [])
    if tm_value is Array:
        for move_value: Variant in tm_value:
            if not move_ids.has(move_value):
                move_ids.append(move_value)

    lines.append("")
    lines.append("[b]ATTACKEN[/b]")
    if move_ids.is_empty():
        lines.append("• Keine verfügbare Attacke")
    else:
        for move_value: Variant in move_ids:
            var move_id: String = str(move_value)
            var move_name: String = move_id
            if battle_demo != null and battle_demo.has_method("route_move_name"):
                move_name = battle_demo.route_move_name(move_id)
            lines.append("• " + move_name)

    var evolution_value: Variant = species.get("evolution", {})
    if evolution_value is Dictionary and not (evolution_value as Dictionary).is_empty():
        var evolution: Dictionary = evolution_value
        var target_id: String = str(evolution.get("target_species_id", ""))
        var evolution_level: int = int(evolution.get("level", 0))
        if not target_id.is_empty() and evolution_level > 0:
            lines.append("")
            lines.append("[b]ENTWICKLUNG[/b]")
            lines.append("Lv.%d → %s" % [evolution_level, battle_demo.route_species_name(target_id)])

    return "\n".join(lines)


func _route_runtime_species(species_id: String) -> Dictionary:
    if battle_demo == null:
        return {}
    var runtime_value: Variant = battle_demo.get("data")
    if not (runtime_value is Dictionary):
        return {}
    var species_value: Variant = (runtime_value as Dictionary).get("species", {})
    if not (species_value is Dictionary):
        return {}
    var entry_value: Variant = (species_value as Dictionary).get(species_id, {})
    return entry_value if entry_value is Dictionary else {}


func _route_type_name(type_id: String) -> String:
    var names: Dictionary = {
        "normal": "Normal", "fire": "Feuer", "water": "Wasser",
        "electric": "Elektro", "grass": "Pflanze", "ice": "Eis",
        "fighting": "Kampf", "poison": "Gift", "ground": "Boden",
        "flying": "Flug", "psychic": "Psycho", "bug": "Käfer",
        "rock": "Gestein", "ghost": "Geist", "dragon": "Drache",
        "dark": "Unlicht", "steel": "Stahl", "fairy": "Fee"
    }
    return str(names.get(type_id, type_id))
