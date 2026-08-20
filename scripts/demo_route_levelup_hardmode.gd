extends "res://scripts/demo_route_team4.gd"

# Demo-route polish:
# - Encounter strength adapts to the current travelling team and rises by stage.
# - Level-ups are shown in a mandatory visual popup after battle.
# - The popup uses the Pokémon sprite, distinct stat icons and a dedicated,
#   scrollable move-detail area for newly learned attacks.

var _levelup_queue: Array = []
var _levelup_overlay: Control
var _levelup_sprite: TextureRect
var _levelup_name: Label
var _levelup_transition: Label
var _levelup_stats: RichTextLabel
var _levelup_move: RichTextLabel
var _levelup_continue: Button


func _ready() -> void:
    super._ready()
    _build_levelup_popup()


func _enemy_party_for_stage(current_stage: int) -> Array:
    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        return []

    var living_team_levels: int = 0
    for member_value: Variant in team:
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) > 0:
            living_team_levels += maxi(1, int(member.get("level", 1)))

    # Harder baseline than the first route version, plus adaptive pressure.
    # Stage 1 starts at a total enemy level budget of 6 instead of 2.
    # Later stages also react to captures and player level-ups, so a growing
    # four-Pokémon team does not trivialize the route.
    var baseline_budget: int = 4 + current_stage * 2
    var adaptive_multiplier: float = 0.95 + float(current_stage) * 0.04
    var adaptive_budget: int = int(ceil(float(maxi(1, living_team_levels)) * adaptive_multiplier))
    var level_budget: int = maxi(baseline_budget, adaptive_budget)

    var enemy_count: int = _enemy_count_for_stage(current_stage, level_budget)
    var max_enemy_level: int = current_stage + 5
    while enemy_count < ROUTE_TEAM_MAX and level_budget > enemy_count * max_enemy_level:
        enemy_count += 1

    var levels: Array[int] = []
    for _index: int in range(enemy_count):
        levels.append(1)

    var remaining: int = level_budget - enemy_count
    while remaining > 0:
        var candidates: Array[int] = []
        for index: int in range(levels.size()):
            if levels[index] < max_enemy_level:
                candidates.append(index)

        if candidates.is_empty():
            # Extremely high player levels can exceed the soft per-enemy cap.
            levels[randi_range(0, levels.size() - 1)] += 1
        else:
            levels[candidates.pick_random()] += 1
        remaining -= 1

    levels.shuffle()

    var result: Array = []
    for level: int in levels:
        result.append({
            "species_id": str(ids.pick_random()),
            "level": level
        })
    return result


func _award_experience(amount: int) -> Array[String]:
    var messages: Array[String] = []
    _levelup_queue.clear()

    for member_value: Variant in team:
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue

        var xp: int = int(member.get("xp", 0)) + amount
        var level: int = int(member.get("level", 1))

        while xp >= _xp_needed(level):
            xp -= _xp_needed(level)

            var species_id: String = str(member.get("species_id", ""))
            var old_level: int = level
            var old_moves: Array = battle_demo.route_moves_for_level(species_id, old_level)
            var old_stats: Dictionary = _route_stats(species_id, old_level)
            var old_max_hp: int = int(member.get("max_hp", old_stats.get("max_hp", 1)))

            level += 1

            var refreshed: Dictionary = battle_demo.route_new_member(species_id, level)
            var new_stats: Dictionary = _route_stats(species_id, level)
            var new_max_hp: int = int(refreshed.get("max_hp", new_stats.get("max_hp", old_max_hp)))

            member["level"] = level
            member["max_hp"] = new_max_hp
            member["hp"] = mini(
                new_max_hp,
                int(member.get("hp", 0)) + maxi(0, new_max_hp - old_max_hp)
            )

            var new_moves: Array = battle_demo.route_moves_for_level(species_id, level)
            var learned_names: Array[String] = []
            var learned_move_ids: Array[String] = []
            for move_value: Variant in new_moves:
                if old_moves.has(move_value):
                    continue
                var move_id: String = str(move_value)
                learned_move_ids.append(move_id)
                learned_names.append(battle_demo.route_move_name(move_id))

            _levelup_queue.append({
                "species_id": species_id,
                "name": str(member.get("name", "Pokémon")),
                "old_level": old_level,
                "new_level": level,
                "before": old_stats.duplicate(true),
                "after": new_stats.duplicate(true),
                "learned": learned_names.duplicate(),
                "learned_move_ids": learned_move_ids.duplicate()
            })
            messages.append(
                "[b]⬆ %s erreicht Lv.%d![/b] · Details im Level-Up-Fenster."
                % [str(member.get("name", "Pokémon")), level]
            )

        member["xp"] = xp

    _refresh_team_panel()
    if not _levelup_queue.is_empty():
        call_deferred("_show_next_levelup_popup")
    return messages


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

    # The wider popup deliberately uses the formerly empty right half for the
    # newly learned move. It still fits inside the 640x360 base viewport.
    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -250.0
    panel.offset_top = -150.0
    panel.offset_right = 250.0
    panel.offset_bottom = 150.0
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("172923"), Color("ffe576"), 12, 10.0)
    )
    _levelup_overlay.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
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
    body.add_theme_constant_override("separation", 10)
    content.add_child(body)

    # Left column: Pokémon and its stat growth.
    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(185.0, 0.0)
    left.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.alignment = BoxContainer.ALIGNMENT_CENTER
    left.add_theme_constant_override("separation", 2)
    body.add_child(left)

    _levelup_sprite = TextureRect.new()
    _levelup_sprite.custom_minimum_size = Vector2(98, 88)
    _levelup_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _levelup_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    left.add_child(_levelup_sprite)

    _levelup_stats = RichTextLabel.new()
    _levelup_stats.bbcode_enabled = true
    _levelup_stats.fit_content = false
    _levelup_stats.scroll_active = false
    _levelup_stats.custom_minimum_size = Vector2(185, 108)
    _levelup_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _levelup_stats.add_theme_font_size_override("normal_font_size", 9)
    _levelup_stats.add_theme_font_size_override("bold_font_size", 9)
    left.add_child(_levelup_stats)

    # Right column: identity first, then the complete learned-move information.
    var right := VBoxContainer.new()
    right.custom_minimum_size = Vector2(275.0, 0.0)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 4)
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
    move_heading.text = "🔴 NEUE ATTACKEN"
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
    _levelup_move.custom_minimum_size = Vector2(255, 137)
    _levelup_move.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _levelup_move.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _levelup_move.add_theme_font_size_override("normal_font_size", 9)
    _levelup_move.add_theme_font_size_override("bold_font_size", 9)
    move_panel.add_child(_levelup_move)

    _levelup_continue = Button.new()
    _levelup_continue.text = "WEITER"
    _levelup_continue.custom_minimum_size = Vector2(150, 28)
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

    var before: Dictionary = event.get("before", {})
    var after: Dictionary = event.get("after", {})
    var stat_lines: Array[String] = []
    stat_lines.append(_popup_stat_line("❤️", "KP", before, after, "max_hp"))
    stat_lines.append(_popup_stat_line("⚔️", "Angriff", before, after, "attack"))
    stat_lines.append(_popup_stat_line("🛡️", "Verteidigung", before, after, "defense"))
    stat_lines.append(_popup_stat_line("🔮", "Status", before, after, "special"))
    stat_lines.append(_popup_stat_line("⚡", "Initiative", before, after, "speed"))
    _levelup_stats.text = "\n".join(stat_lines)

    var learned_ids_value: Variant = event.get("learned_move_ids", [])
    var learned_ids: Array = learned_ids_value if learned_ids_value is Array else []
    var learned_names_value: Variant = event.get("learned", [])
    var learned_names: Array = learned_names_value if learned_names_value is Array else []

    if learned_ids.is_empty():
        # Backward compatibility for queued events that only stored names.
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
    var move: Dictionary = _levelup_move_data(move_id)
    var fallback_name: String = move_id
    if battle_demo != null and battle_demo.has_method("route_move_name"):
        fallback_name = str(battle_demo.route_move_name(move_id))

    if move.is_empty():
        return "[color=#ffb0b0][b]🔴 %s[/b][/color]\nDetails zu dieser Attacke sind nicht verfügbar." % fallback_name

    var move_name: String = str(move.get("name", fallback_name))
    var move_type: String = str(move.get("type", "normal"))
    var category: String = str(move.get("category", "status"))
    var target: String = str(move.get("target", "enemy_highest_aggro"))

    var type_name: String = _levelup_localized_name("_type_name", move_type, move_type.capitalize())
    var category_name: String = _levelup_localized_name("_category_name", category, category.capitalize())
    var target_name: String = _levelup_localized_name("_target_name", target, target.replace("_", " ").capitalize())

    var ap: int = int(move.get("ap", move.get("rpg_ap", 1)))
    if battle_demo != null and battle_demo.has_method("_ap_value"):
        ap = int(battle_demo.call("_ap_value", move))

    var lines: Array[String] = []
    lines.append("[color=#ffb0b0][b]🔴 %s[/b][/color]" % move_name)
    lines.append("%s · %s · AP %d" % [type_name, category_name, ap])

    var combat_values: Array[String] = []
    var power_value: Variant = move.get("power", null)
    if power_value != null:
        combat_values.append("Stärke: %d" % int(round(float(power_value))))

    var accuracy_value: Variant = move.get("accuracy", null)
    if accuracy_value == null:
        combat_values.append("Genauigkeit: sicher")
    else:
        combat_values.append("Genauigkeit: %d%%" % int(round(float(accuracy_value))))

    if bool(move.get("opening", move.get("opening_phase", false))):
        combat_values.append("Runde 0")
    var priority: int = int(move.get("priority", 0))
    if priority != 0:
        combat_values.append("Priorität: %+d" % priority)

    if not combat_values.is_empty():
        lines.append(" · ".join(combat_values))
    lines.append("[b]Ziel:[/b] " + target_name)

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
        lines.append("[b]Effekt:[/b] " + effect_summary)
    elif description.is_empty():
        lines.append("Keine zusätzliche Effektbeschreibung.")

    return "\n".join(lines)


func _levelup_move_data(move_id: String) -> Dictionary:
    if battle_demo == null:
        return {}
    var data_value: Variant = battle_demo.get("data")
    if not (data_value is Dictionary):
        return {}
    var moves_value: Variant = (data_value as Dictionary).get("moves", {})
    if not (moves_value is Dictionary):
        return {}
    var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
    return move_value if move_value is Dictionary else {}


func _levelup_localized_name(method_name: String, value: String, fallback: String) -> String:
    if battle_demo != null and battle_demo.has_method(method_name):
        var resolved: String = str(battle_demo.call(method_name, value)).strip_edges()
        if not resolved.is_empty():
            return resolved
    return fallback


func _popup_stat_line(icon: String, label: String, before: Dictionary, after: Dictionary, key: String) -> String:
    var old_value: int = int(before.get(key, 0))
    var new_value: int = int(after.get(key, old_value))
    var delta: int = new_value - old_value
    var delta_text: String = "+%d" % delta if delta >= 0 else str(delta)
    return "%s [b]%s[/b]   %d → %d   [color=#9fe7bd]%s[/color]" % [
        icon, label, old_value, new_value, delta_text
    ]


func _on_levelup_continue() -> void:
    if _levelup_queue.is_empty():
        _levelup_overlay.visible = false
        return
    _show_next_levelup_popup()
