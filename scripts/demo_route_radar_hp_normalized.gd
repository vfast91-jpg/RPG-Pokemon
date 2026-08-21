extends "res://scripts/demo_route_radar_move_order.gd"

# The runtime HP formula has an extra +level+10 term while the other four
# attributes use +5. The radar chart now accepts the Pokemon level and removes
# only that formula-specific HP offset for visual comparison. Displayed HP and
# all battle calculations remain unchanged.


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

    var new_level: int = maxi(1, int(event.get("new_level", 1)))
    _levelup_name.text = str(event.get("name", "Pokémon"))
    _levelup_transition.text = "Lv.%d  →  Lv.%d" % [
        int(event.get("old_level", 1)),
        new_level
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
        _levelup_radar.call("set_stats", after, new_level)

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


func _show_route_member_info(index: int) -> void:
    super._show_route_member_info(index)

    if index < 0 or index >= team.size() or _route_info_radar == null:
        return
    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return
    var member: Dictionary = member_value
    var level: int = maxi(1, int(member.get("level", 1)))
    var stats: Dictionary = _route_member_stats(member)

    if _route_info_radar.has_method("set_stats"):
        _route_info_radar.call("set_stats", stats, level)
