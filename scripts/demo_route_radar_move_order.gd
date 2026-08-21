extends "res://scripts/demo_route_team_panel_fit.gd"

# Between-battle presentation polish:
# - five-axis radar charts in level-up and team-member views,
# - the established stat/move emojis everywhere those values are scanned,
# - full move tooltips in the member view,
# - persistent one-click move ordering that is respected by route battles.

const StatRadarChart = preload("res://scripts/ui/stat_radar_chart.gd")

var _levelup_radar: Control

var _route_info_member_index: int = -1
var _route_info_stats: RichTextLabel
var _route_info_radar: Control
var _route_info_moves: VBoxContainer
var _route_info_move_scroll: ScrollContainer


func _build_levelup_popup() -> void:
    if root == null:
        return

    _levelup_overlay = Control.new()
    _levelup_overlay.name = "LevelUpOverlay"
    _levelup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _levelup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _levelup_overlay.z_index = 100
    _levelup_overlay.visible = false
    root.add_child(_levelup_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.70)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _levelup_overlay.add_child(shade)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -260.0
    panel.offset_top = -165.0
    panel.offset_right = 260.0
    panel.offset_bottom = 165.0
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("172923"), Color("ffe576"), 12, 9.0)
    )
    _levelup_overlay.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    panel.add_child(content)

    var heading := Label.new()
    heading.text = "✨ LEVELAUFSTIEG!"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 18)
    heading.add_theme_color_override("font_color", Color("ffe576"))
    content.add_child(heading)

    var body := HBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 9)
    content.add_child(body)

    # Left side deliberately starts at the top. The slightly smaller sprite and
    # compact stat rows make room for the visual stat silhouette underneath.
    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(196.0, 0.0)
    left.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.alignment = BoxContainer.ALIGNMENT_BEGIN
    left.add_theme_constant_override("separation", 1)
    body.add_child(left)

    _levelup_sprite = TextureRect.new()
    _levelup_sprite.custom_minimum_size = Vector2(96.0, 61.0)
    _levelup_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _levelup_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    left.add_child(_levelup_sprite)

    _levelup_stats = RichTextLabel.new()
    _levelup_stats.bbcode_enabled = true
    _levelup_stats.fit_content = false
    _levelup_stats.scroll_active = false
    _levelup_stats.custom_minimum_size = Vector2(196.0, 69.0)
    _levelup_stats.add_theme_font_size_override("normal_font_size", 9)
    _levelup_stats.add_theme_font_size_override("bold_font_size", 9)
    left.add_child(_levelup_stats)

    _levelup_radar = StatRadarChart.new()
    _levelup_radar.custom_minimum_size = Vector2(196.0, 118.0)
    _levelup_radar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _levelup_radar.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.add_child(_levelup_radar)

    var right := VBoxContainer.new()
    right.custom_minimum_size = Vector2(286.0, 0.0)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 3)
    body.add_child(right)

    var identity := VBoxContainer.new()
    identity.alignment = BoxContainer.ALIGNMENT_CENTER
    right.add_child(identity)

    _levelup_name = Label.new()
    _levelup_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _levelup_name.add_theme_font_size_override("font_size", 17)
    _levelup_name.add_theme_color_override("font_color", Color("ffffff"))
    identity.add_child(_levelup_name)

    _levelup_transition = Label.new()
    _levelup_transition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _levelup_transition.add_theme_font_size_override("font_size", 13)
    _levelup_transition.add_theme_color_override("font_color", Color("9fe7bd"))
    identity.add_child(_levelup_transition)

    var move_heading := Label.new()
    move_heading.text = "✨ NEUE ATTACKEN"
    move_heading.add_theme_font_size_override("font_size", 11)
    move_heading.add_theme_color_override("font_color", Color("ffe576"))
    right.add_child(move_heading)

    var move_panel := PanelContainer.new()
    move_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    move_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    move_panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("0f1d19cc"), Color("5f8d78"), 8, 6.0)
    )
    right.add_child(move_panel)

    _levelup_move = RichTextLabel.new()
    _levelup_move.bbcode_enabled = true
    _levelup_move.fit_content = false
    _levelup_move.scroll_active = true
    _levelup_move.scroll_following = false
    _levelup_move.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _levelup_move.custom_minimum_size = Vector2(270.0, 165.0)
    _levelup_move.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _levelup_move.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _levelup_move.add_theme_font_size_override("normal_font_size", 9)
    _levelup_move.add_theme_font_size_override("bold_font_size", 9)
    move_panel.add_child(_levelup_move)

    _levelup_continue = Button.new()
    _levelup_continue.text = "WEITER"
    _levelup_continue.custom_minimum_size = Vector2(150.0, 27.0)
    _levelup_continue.pressed.connect(_on_levelup_continue)
    content.add_child(_levelup_continue)


func _show_next_levelup_popup() -> void:
    if _levelup_overlay == null:
        return
    if _levelup_queue.is_empty():
        _levelup_overlay.visible = false
        return

    var event_value: Variant = _levelup_queue.pop_front()
    if not (event_value is Dictionary):
        _show_next_levelup_popup()
        return
    var event: Dictionary = event_value

    _levelup_name.text = str(event.get("name", "Pokémon"))
    _levelup_transition.text = "Lv.%d  →  Lv.%d" % [
        int(event.get("old_level", 1)),
        int(event.get("new_level", 1))
    ]

    _levelup_sprite.texture = null
    if battle_demo != null and battle_demo.has_method("route_species_texture"):
        var texture_value: Variant = battle_demo.route_species_texture(str(event.get("species_id", "")))
        if texture_value is Texture2D:
            _levelup_sprite.texture = texture_value

    var before_value: Variant = event.get("before", {})
    var after_value: Variant = event.get("after", {})
    var before: Dictionary = before_value if before_value is Dictionary else {}
    var after: Dictionary = after_value if after_value is Dictionary else {}

    var stat_lines: Array[String] = []
    stat_lines.append(_popup_stat_line("❤️", "KP", before, after, "max_hp"))
    stat_lines.append(_popup_stat_line("⚔️", "Angriff", before, after, "attack"))
    stat_lines.append(_popup_stat_line("🛡️", "Verteidigung", before, after, "defense"))
    stat_lines.append(_popup_stat_line("🔮", "Status", before, after, "special"))
    stat_lines.append(_popup_stat_line("⚡", "Initiative", before, after, "speed"))
    _levelup_stats.text = "\n".join(stat_lines)

    if _levelup_radar != null and _levelup_radar.has_method("set_stats"):
        _levelup_radar.call("set_stats", after)

    var learned_ids_value: Variant = event.get("learned_move_ids", [])
    var learned_ids: Array = learned_ids_value if learned_ids_value is Array else []
    var learned_names_value: Variant = event.get("learned", [])
    var learned_names: Array = learned_names_value if learned_names_value is Array else []

    if learned_ids.is_empty():
        if learned_names.is_empty():
            _levelup_move.text = "Keine neue Attacke auf diesem Level."
        else:
            var fallback_names: Array[String] = []
            for name_value: Variant in learned_names:
                fallback_names.append(str(name_value))
            _levelup_move.text = "[b]Neu gelernt:[/b]\n" + "\n".join(fallback_names)
    else:
        var move_blocks: Array[String] = []
        for move_id_value: Variant in learned_ids:
            move_blocks.append(_levelup_move_detail_text(str(move_id_value)))
        _levelup_move.text = "\n\n".join(move_blocks)

    _levelup_move.scroll_to_line(0)
    _levelup_overlay.visible = true
    _levelup_continue.grab_focus()


func _levelup_move_detail_text(move_id: String) -> String:
    var detail: String = super._levelup_move_detail_text(move_id)
    var emoji: String = _route_move_emoji(move_id, _route_move_data(move_id))
    return detail.replace("🔴 ", emoji + " ")


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
    shade.color = Color(0.0, 0.0, 0.0, 0.76)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _route_info_overlay.add_child(shade)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -295.0
    panel.offset_top = -168.0
    panel.offset_right = 295.0
    panel.offset_bottom = 168.0
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("172923"), Color("ffe576"), 12, 8.0)
    )
    _route_info_overlay.add_child(panel)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 4)
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
    close_top.custom_minimum_size = Vector2(32.0, 26.0)
    close_top.pressed.connect(_hide_route_member_info)
    header.add_child(close_top)

    var body_row := HBoxContainer.new()
    body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_row.add_theme_constant_override("separation", 9)
    outer.add_child(body_row)

    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(202.0, 0.0)
    left.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.alignment = BoxContainer.ALIGNMENT_BEGIN
    left.add_theme_constant_override("separation", 1)
    body_row.add_child(left)

    _route_info_sprite = TextureRect.new()
    _route_info_sprite.custom_minimum_size = Vector2(202.0, 66.0)
    _route_info_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _route_info_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    left.add_child(_route_info_sprite)

    _route_info_stats = RichTextLabel.new()
    _route_info_stats.bbcode_enabled = true
    _route_info_stats.fit_content = false
    _route_info_stats.scroll_active = false
    _route_info_stats.custom_minimum_size = Vector2(202.0, 72.0)
    _route_info_stats.add_theme_font_size_override("normal_font_size", 9)
    _route_info_stats.add_theme_font_size_override("bold_font_size", 9)
    left.add_child(_route_info_stats)

    _route_info_radar = StatRadarChart.new()
    _route_info_radar.custom_minimum_size = Vector2(202.0, 112.0)
    _route_info_radar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _route_info_radar.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.add_child(_route_info_radar)

    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 3)
    body_row.add_child(right)

    var moves_heading := Label.new()
    moves_heading.text = "ATTACKEN · REIHENFOLGE IM KAMPF"
    moves_heading.add_theme_font_size_override("font_size", 11)
    moves_heading.add_theme_color_override("font_color", Color("ffe576"))
    right.add_child(moves_heading)

    var move_hint := Label.new()
    move_hint.text = "Über Attacke fahren = Details · ▲/▼ = Reihenfolge ändern"
    move_hint.add_theme_font_size_override("font_size", 8)
    move_hint.add_theme_color_override("font_color", Color("a7c6ba"))
    right.add_child(move_hint)

    _route_info_move_scroll = ScrollContainer.new()
    _route_info_move_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _route_info_move_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _route_info_move_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    right.add_child(_route_info_move_scroll)

    _route_info_moves = VBoxContainer.new()
    _route_info_moves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _route_info_moves.add_theme_constant_override("separation", 3)
    _route_info_move_scroll.add_child(_route_info_moves)

    var close_bottom := Button.new()
    close_bottom.text = "SCHLIESSEN"
    close_bottom.custom_minimum_size = Vector2(140.0, 26.0)
    close_bottom.pressed.connect(_hide_route_member_info)
    outer.add_child(close_bottom)


func _show_route_member_info(index: int) -> void:
    if index < 0 or index >= team.size() or _route_info_overlay == null:
        return
    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return
    var member: Dictionary = member_value
    _route_info_member_index = index

    var species_id: String = str(member.get("species_id", ""))
    var level: int = maxi(1, int(member.get("level", 1)))
    _route_info_title.text = "%s · Lv.%d" % [str(member.get("name", "Pokémon")), level]
    _route_info_sprite.texture = _route_member_texture(str(member.get("name", "")))

    var stats := _route_member_stats(member)
    var type_names: Array[String] = []
    var species: Dictionary = _route_runtime_species(species_id)
    var types_value: Variant = species.get("types", [])
    if types_value is Array:
        for type_value: Variant in types_value:
            type_names.append(_route_type_name(str(type_value)))

    var max_hp: int = int(stats.get("max_hp", member.get("max_hp", 1)))
    var hp: int = clampi(int(member.get("hp", 0)), 0, maxi(1, max_hp))
    var status_text: String = _route_status_text(str(member.get("major_status", "")))
    var xp_needed: int = maxi(1, _xp_needed(level))
    var xp: int = clampi(int(member.get("xp", 0)), 0, xp_needed)

    var stat_lines: Array[String] = []
    stat_lines.append("[b]Typ:[/b] " + (" / ".join(type_names) if not type_names.is_empty() else "–"))
    stat_lines.append("❤️ [b]KP[/b] %d/%d" % [hp, max_hp])
    stat_lines.append("⚔️ [b]Angriff[/b] %d   🛡️ [b]Verteidigung[/b] %d" % [
        int(stats.get("attack", 0)), int(stats.get("defense", 0))
    ])
    stat_lines.append("🔮 [b]Status[/b] %d   ⚡ [b]Initiative[/b] %d" % [
        int(stats.get("special", 0)), int(stats.get("speed", 0))
    ])
    stat_lines.append("EP %d/%d · %s" % [
        xp, xp_needed, status_text if not status_text.is_empty() else "OK"
    ])
    _route_info_stats.text = "\n".join(stat_lines)

    if _route_info_radar != null and _route_info_radar.has_method("set_stats"):
        _route_info_radar.call("set_stats", stats)

    _rebuild_route_move_list(member)
    _route_info_move_scroll.scroll_vertical = 0
    _route_info_overlay.visible = true


func _hide_route_member_info() -> void:
    _route_info_member_index = -1
    if _route_info_overlay != null:
        _route_info_overlay.visible = false


func _route_member_stats(member: Dictionary) -> Dictionary:
    var species_id: String = str(member.get("species_id", ""))
    var level: int = maxi(1, int(member.get("level", 1)))
    if battle_demo != null and battle_demo.has_method("route_stat_snapshot"):
        var stats_value: Variant = battle_demo.route_stat_snapshot(species_id, level)
        if stats_value is Dictionary:
            return (stats_value as Dictionary).duplicate(true)
    return {
        "max_hp": int(member.get("max_hp", 1)),
        "attack": 0,
        "defense": 0,
        "special": 0,
        "speed": 0
    }


func _rebuild_route_move_list(member: Dictionary) -> void:
    if _route_info_moves == null:
        return
    for child: Node in _route_info_moves.get_children():
        child.queue_free()

    var move_ids: Array[String] = _ordered_route_move_ids(member)
    if move_ids.is_empty():
        var empty_label := Label.new()
        empty_label.text = "Keine verfügbare Attacke."
        empty_label.add_theme_font_size_override("font_size", 10)
        _route_info_moves.add_child(empty_label)
        return

    for move_index: int in range(move_ids.size()):
        var move_id: String = move_ids[move_index]
        var move: Dictionary = _route_move_data(move_id)
        var move_name: String = str(move.get("name", move_id))
        if move.is_empty() and battle_demo != null and battle_demo.has_method("route_move_name"):
            move_name = str(battle_demo.route_move_name(move_id))
        var emoji: String = _route_move_emoji(move_id, move)
        var tooltip: String = _route_move_tooltip(move_id, move)

        var row_panel := PanelContainer.new()
        row_panel.add_theme_stylebox_override(
            "panel",
            _panel(Color("0f1d19cc"), Color("46695b"), 7, 3.0)
        )
        row_panel.tooltip_text = tooltip
        _route_info_moves.add_child(row_panel)

        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 3)
        row_panel.add_child(row)

        var move_label := Label.new()
        move_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        move_label.text = "%d. %s %s · AP %d" % [
            move_index + 1,
            emoji,
            move_name,
            _route_move_ap(move)
        ]
        move_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        move_label.add_theme_font_size_override("font_size", 10)
        move_label.tooltip_text = tooltip
        move_label.mouse_filter = Control.MOUSE_FILTER_STOP
        move_label.mouse_default_cursor_shape = Control.CURSOR_HELP
        row.add_child(move_label)

        var up_button := Button.new()
        up_button.text = "▲"
        up_button.custom_minimum_size = Vector2(28.0, 25.0)
        up_button.focus_mode = Control.FOCUS_NONE
        up_button.disabled = move_index == 0
        up_button.tooltip_text = "Im Kampf weiter nach oben"
        up_button.pressed.connect(_move_route_move.bind(move_id, -1))
        row.add_child(up_button)

        var down_button := Button.new()
        down_button.text = "▼"
        down_button.custom_minimum_size = Vector2(28.0, 25.0)
        down_button.focus_mode = Control.FOCUS_NONE
        down_button.disabled = move_index == move_ids.size() - 1
        down_button.tooltip_text = "Im Kampf weiter nach unten"
        down_button.pressed.connect(_move_route_move.bind(move_id, 1))
        row.add_child(down_button)


func _move_route_move(move_id: String, direction: int) -> void:
    if _route_info_member_index < 0 or _route_info_member_index >= team.size():
        return
    var member_value: Variant = team[_route_info_member_index]
    if not (member_value is Dictionary):
        return
    var member: Dictionary = member_value
    var order: Array[String] = _ordered_route_move_ids(member)
    var current_index: int = order.find(move_id)
    if current_index < 0:
        return
    var target_index: int = clampi(current_index + direction, 0, order.size() - 1)
    if target_index == current_index:
        return

    var other_id: String = order[target_index]
    order[target_index] = order[current_index]
    order[current_index] = other_id
    member["move_order"] = order.duplicate()
    team[_route_info_member_index] = member
    _rebuild_route_move_list(member)


func _ordered_route_move_ids(member: Dictionary) -> Array[String]:
    var available: Array[String] = []
    var species_id: String = str(member.get("species_id", ""))
    var level: int = maxi(1, int(member.get("level", 1)))

    if battle_demo != null and battle_demo.has_method("route_moves_for_level"):
        var level_moves: Array = battle_demo.route_moves_for_level(species_id, level)
        for move_value: Variant in level_moves:
            var move_id: String = str(move_value)
            if not move_id.is_empty() and not available.has(move_id):
                available.append(move_id)

    var tm_value: Variant = member.get("tm_moves", [])
    if tm_value is Array:
        for move_value: Variant in tm_value:
            var move_id: String = str(move_value)
            if not move_id.is_empty() and not available.has(move_id):
                available.append(move_id)

    var ordered: Array[String] = []
    var stored_value: Variant = member.get("move_order", [])
    if stored_value is Array:
        for move_value: Variant in stored_value:
            var move_id: String = str(move_value)
            if available.has(move_id) and not ordered.has(move_id):
                ordered.append(move_id)

    for move_id: String in available:
        if not ordered.has(move_id):
            ordered.append(move_id)

    member["move_order"] = ordered.duplicate()
    return ordered


func _route_move_data(move_id: String) -> Dictionary:
    if battle_demo == null:
        return {}
    var data_value: Variant = battle_demo.get("data")
    if not (data_value is Dictionary):
        return {}
    var moves_value: Variant = (data_value as Dictionary).get("moves", {})
    if not (moves_value is Dictionary):
        return {}
    var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
    return (move_value as Dictionary) if move_value is Dictionary else {}


func _route_move_emoji(move_id: String, move: Dictionary) -> String:
    if battle_demo != null and battle_demo.has_method("_move_emoji"):
        var resolved: String = str(battle_demo.call("_move_emoji", move_id, move)).strip_edges()
        if not resolved.is_empty():
            return resolved

    match str(move.get("type", "normal")):
        "fire":
            return "🔥"
        "water":
            return "💦"
        "electric":
            return "⚡"
        "grass":
            return "🌿"
        "poison":
            return "☠️"
        _:
            return "💥" if str(move.get("category", "status")) != "status" else "✨"


func _route_move_ap(move: Dictionary) -> int:
    if battle_demo != null and battle_demo.has_method("_ap_value"):
        return int(battle_demo.call("_ap_value", move))
    return int(move.get("ap", move.get("rpg_ap", 1)))


func _route_move_tooltip(move_id: String, move: Dictionary) -> String:
    var move_name: String = str(move.get("name", move_id))
    if move.is_empty() and battle_demo != null and battle_demo.has_method("route_move_name"):
        move_name = str(battle_demo.route_move_name(move_id))

    var lines: Array[String] = []
    lines.append(_route_move_emoji(move_id, move) + " " + move_name)

    if move.is_empty():
        lines.append("Details zu dieser Attacke sind nicht verfügbar.")
        return "\n".join(lines)

    var type_id: String = str(move.get("type", "normal"))
    var category_id: String = str(move.get("category", "status"))
    var target_id: String = str(move.get("target", "enemy_highest_aggro"))
    lines.append("%s · %s · AP %d" % [
        _route_battle_name("_type_name", type_id, type_id.capitalize()),
        _route_battle_name("_category_name", category_id, category_id.capitalize()),
        _route_move_ap(move)
    ])

    var combat_values: Array[String] = []
    if move.get("power", null) != null:
        combat_values.append("Stärke: %d" % int(round(float(move.get("power", 0)))))
    if move.get("accuracy", null) == null:
        combat_values.append("Genauigkeit: sicher")
    else:
        combat_values.append("Genauigkeit: %d%%" % int(round(float(move.get("accuracy", 100)))))
    var priority: int = int(move.get("priority", 0))
    if priority != 0:
        combat_values.append("Priorität: %+d" % priority)
    if bool(move.get("opening", move.get("opening_phase", false))):
        combat_values.append("Runde 0")
    if not combat_values.is_empty():
        lines.append(" · ".join(combat_values))

    lines.append("Ziel: " + _route_battle_name(
        "_target_name",
        target_id,
        target_id.replace("_", " ").capitalize()
    ))

    var description: String = str(move.get("description", "")).strip_edges()
    if not description.is_empty():
        lines.append(description)

    var effect_summary: String = ""
    if battle_demo != null and battle_demo.has_method("_compact_effect_summary"):
        effect_summary = str(battle_demo.call("_compact_effect_summary", move)).strip_edges()
        effect_summary = effect_summary.replace("nächster ATB-Zyklus kürzer", "Aktionsleiste füllt sich schneller")
        effect_summary = effect_summary.replace("nächster ATB-Zyklus länger", "Aktionsleiste füllt sich langsamer")
        effect_summary = effect_summary.replace("ATB-Zyklen kürzer", "Aktionsleiste füllt sich schneller")
        effect_summary = effect_summary.replace("ATB-Zyklen länger", "Aktionsleiste füllt sich langsamer")
        effect_summary = effect_summary.replace("ATB schneller", "Aktionsleiste füllt sich schneller")
        effect_summary = effect_summary.replace("ATB langsamer", "Aktionsleiste füllt sich langsamer")

    if not effect_summary.is_empty():
        lines.append("Effekt: " + effect_summary)
    elif description.is_empty():
        lines.append("Keine zusätzliche Effektbeschreibung.")

    return "\n".join(lines)


func _route_battle_name(method_name: String, value: String, fallback: String) -> String:
    if battle_demo != null and battle_demo.has_method(method_name):
        var resolved: String = str(battle_demo.call(method_name, value)).strip_edges()
        if not resolved.is_empty():
            return resolved
    return fallback
