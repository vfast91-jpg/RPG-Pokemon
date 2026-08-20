extends "res://scripts/battle_demo_adaptive_cards.gd"

# Compact family chooser layered on top of the current adaptive battle cards.
# The family/evolution logic is unchanged; only the combat-lab setup rows are
# made concise enough to stay inside both team panels.


func _build_config(root: Control) -> void:
    super._build_config(root)

    if config_panel == null or config_panel.get_child_count() == 0:
        return
    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer == null or outer.get_child_count() <= 1:
        return
    var subtitle: Label = outer.get_child(1) as Label
    if subtitle != null:
        subtitle.text = "Familie waehlen · Level bestimmt die Form · 1–4 pro Seite"


func _fill_rows(box: VBoxContainer, setup: Array, own: bool) -> void:
    super._fill_rows(box, setup, own)

    for index: int in range(mini(box.get_child_count(), setup.size())):
        var row: HBoxContainer = box.get_child(index) as HBoxContainer
        if row == null:
            continue

        var picker: OptionButton = null
        var level_spin: SpinBox = null
        for child: Node in row.get_children():
            if child is OptionButton:
                picker = child as OptionButton
            elif child is SpinBox:
                level_spin = child as SpinBox

        if picker == null or level_spin == null:
            continue

        # The chooser only names the family root. The separate compact badge
        # shows which form that family has at the selected level.
        for item_index: int in range(picker.item_count):
            var family_id: String = str(picker.get_item_metadata(item_index))
            picker.set_item_text(item_index, _species_name(family_id))

        picker.custom_minimum_size = Vector2(96.0, 23.0)
        picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        picker.clip_text = true
        picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

        var family_id: String = str(setup[index].get("species_id", ""))
        var level: int = maxi(1, int(setup[index].get("level", 1)))
        var resolved_id: String = _lab_resolve_family(family_id, level)
        var badge: Control = _make_compact_form_badge(family_id, resolved_id, level)

        row.add_child(badge)
        row.move_child(badge, level_spin.get_index())

        level_spin.prefix = "Lv."
        level_spin.custom_minimum_size = Vector2(68.0, 23.0)


func _make_compact_form_badge(family_id: String, resolved_id: String, level: int) -> Control:
    var badge := PanelContainer.new()
    badge.custom_minimum_size = Vector2(70.0, 22.0)
    badge.mouse_filter = Control.MOUSE_FILTER_PASS

    var is_base: bool = resolved_id.is_empty() or resolved_id == family_id
    var style := StyleBoxFlat.new()
    style.bg_color = Color("2e3c37") if is_base else Color("2e493b")
    style.border_color = Color("5d746a") if is_base else Color("72a17f")
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 4.0
    style.content_margin_right = 4.0
    style.content_margin_top = 1.0
    style.content_margin_bottom = 1.0
    badge.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.clip_text = true
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.add_theme_font_size_override("font_size", 8)
    label.add_theme_color_override("font_color", Color("d6ded9") if is_base else Color("c8f0d2"))
    label.text = "Basis" if is_base else _species_name(resolved_id)
    badge.add_child(label)

    var root_name: String = _species_name(family_id)
    var active_name: String = root_name if resolved_id.is_empty() else _species_name(resolved_id)
    badge.tooltip_text = "%s-Familie · Level %d · aktive Form: %s" % [root_name, level, active_name]
    return badge
