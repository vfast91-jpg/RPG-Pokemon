extends "res://scripts/battle_demo_user_polish.gd"

# Combat-lab family-selection layer.
# A setup row has exactly one source of truth: family root + level.
# The active evolution form is always derived from those two values.
#
# The project renders a 640x360 virtual viewport at 1280x720. Each team panel
# therefore has only about 291 logical pixels for its setup rows. Keep every
# row below that budget so the right-hand team can never push outside the frame.

const LAB_ROW_SEPARATION: int = 3
const LAB_ROW_SLOT_WIDTH: float = 16.0
const LAB_ROW_PICKER_WIDTH: float = 100.0
const LAB_ROW_FORM_WIDTH: float = 76.0
const LAB_ROW_LEVEL_WIDTH: float = 68.0
const LAB_ROW_MAXIMUM_MIN_WIDTH: float = 286.0


func _load_data() -> void:
    super._load_data()

    # Keep the lab on canonical evolution-family roots. Individual forms are
    # resolved from the selected level instead of being stored separately.
    lab_species_ids = species_ids.duplicate()


func _build_config(root: Control) -> void:
    super._build_config(root)

    if config_panel == null or config_panel.get_child_count() == 0:
        return
    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer == null or outer.get_child_count() <= 1:
        return
    var subtitle: Label = outer.get_child(1) as Label
    if subtitle != null:
        subtitle.text = "Pokemon-Familie waehlen · Level bestimmt die natuerliche Form · 1–4 pro Seite"


func _fill_rows(box: VBoxContainer, setup: Array, own: bool) -> void:
    # Do not use the prototype row builder here. It still contains the historic
    # Lv.10 cap and queue_free-based rebuild behavior that allowed stale rows to
    # be edited by later inheritance layers in the same frame.
    for child: Node in box.get_children():
        child.free()

    var families: Array = lab_species_ids if not lab_species_ids.is_empty() else species_ids
    if families.is_empty():
        return

    for index: int in range(setup.size()):
        var level_value: int = clampi(int(setup[index].get("level", 1)), 1, DATABASE_LEVEL_MAX)
        setup[index]["level"] = level_value

        var family_id: String = str(setup[index].get("species_id", ""))
        if not families.has(family_id):
            family_id = str(families[0])
            setup[index]["species_id"] = family_id

        var row := HBoxContainer.new()
        row.name = "SetupRow_%d" % index
        row.custom_minimum_size = Vector2(0.0, 28.0)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_theme_constant_override("separation", LAB_ROW_SEPARATION)
        box.add_child(row)

        var slot := Label.new()
        slot.name = "Slot"
        slot.text = "%d." % (index + 1)
        slot.custom_minimum_size = Vector2(LAB_ROW_SLOT_WIDTH, 24.0)
        slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        slot.add_theme_font_size_override("font_size", 10)
        row.add_child(slot)

        var picker := OptionButton.new()
        picker.name = "FamilyPicker"
        picker.custom_minimum_size = Vector2(LAB_ROW_PICKER_WIDTH, 24.0)
        picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        # Critical for the 640px virtual viewport: long names must be clipped,
        # never allowed to redefine the dropdown's minimum width.
        picker.fit_to_longest_item = false
        picker.clip_text = true
        picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        picker.tooltip_text = "Pokemon-Familie. Die aktive Form wird aus dem Level berechnet."

        var selected_index: int = -1
        for family_value: Variant in families:
            var candidate_id: String = str(family_value)
            picker.add_item("%s-Familie" % _species_name(candidate_id))
            picker.set_item_metadata(picker.item_count - 1, candidate_id)
            if candidate_id == family_id:
                selected_index = picker.item_count - 1
        if selected_index >= 0:
            picker.select(selected_index)
        row.add_child(picker)

        var form_badge: PanelContainer = _make_form_badge(family_id, level_value)
        row.add_child(form_badge)

        var level_spin := SpinBox.new()
        level_spin.name = "LevelPicker"
        level_spin.min_value = 1.0
        level_spin.max_value = float(DATABASE_LEVEL_MAX)
        level_spin.allow_greater = false
        level_spin.allow_lesser = false
        level_spin.step = 1.0
        level_spin.prefix = "Lv. "
        level_spin.value = float(level_value)
        level_spin.custom_minimum_size = Vector2(LAB_ROW_LEVEL_WIDTH, 24.0)
        level_spin.tooltip_text = "Level 1–%d. Die Entwicklungsform folgt automatisch." % DATABASE_LEVEL_MAX
        row.add_child(level_spin)

        picker.item_selected.connect(_species_changed.bind(own, index, picker))
        level_spin.value_changed.connect(_level_changed.bind(own, index))


func _make_form_badge(family_id: String, level: int) -> PanelContainer:
    var badge := PanelContainer.new()
    badge.name = "ActiveForm"
    badge.custom_minimum_size = Vector2(LAB_ROW_FORM_WIDTH, 23.0)
    badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    badge.clip_contents = true
    badge.mouse_filter = Control.MOUSE_FILTER_PASS

    var label := Label.new()
    label.name = "Label"
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.clip_text = true
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.add_theme_font_size_override("font_size", 8)
    badge.add_child(label)

    _update_form_badge(badge, family_id, level)
    return badge


func _update_form_badge(badge: PanelContainer, family_id: String, level: int) -> void:
    if badge == null:
        return

    var resolved_id: String = _lab_resolve_family(family_id, level)
    var root_name: String = _species_name(family_id)
    var active_name: String = root_name if resolved_id.is_empty() else _species_name(resolved_id)
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

    var label: Label = badge.get_node_or_null("Label") as Label
    if label != null:
        label.text = active_name
        label.add_theme_color_override("font_color", Color("d6ded9") if is_base else Color("c8f0d2"))

    badge.tooltip_text = "%s-Familie · Level %d · aktive Form: %s" % [root_name, level, active_name]


func _species_changed(_item_index: int, own: bool, index: int, picker: OptionButton) -> void:
    var setup: Array = player_setup if own else enemy_setup
    if index >= setup.size() or picker == null or picker.selected < 0:
        return

    setup[index]["species_id"] = str(picker.get_item_metadata(picker.selected))
    _refresh_setup_row(own, index)


func _level_changed(value: float, own: bool, index: int) -> void:
    var setup: Array = player_setup if own else enemy_setup
    if index >= setup.size():
        return

    # The canonical database is authoritative. Never pass through the original
    # prototype's LEVEL_MAX = 10 clamp.
    setup[index]["level"] = clampi(int(value), 1, DATABASE_LEVEL_MAX)
    _refresh_setup_row(own, index)


func _refresh_setup_row(own: bool, index: int) -> void:
    var setup: Array = player_setup if own else enemy_setup
    var rows: VBoxContainer = player_rows if own else enemy_rows
    if rows == null or index < 0 or index >= setup.size() or index >= rows.get_child_count():
        return

    var row: HBoxContainer = rows.get_child(index) as HBoxContainer
    if row == null:
        return

    var family_id: String = str(setup[index].get("species_id", ""))
    var level_value: int = clampi(int(setup[index].get("level", 1)), 1, DATABASE_LEVEL_MAX)
    setup[index]["level"] = level_value

    var picker: OptionButton = row.get_node_or_null("FamilyPicker") as OptionButton
    if picker != null:
        for item_index: int in range(picker.item_count):
            if str(picker.get_item_metadata(item_index)) == family_id:
                if picker.selected != item_index:
                    picker.select(item_index)
                break

    var level_spin: SpinBox = row.get_node_or_null("LevelPicker") as SpinBox
    if level_spin != null and int(level_spin.value) != level_value:
        level_spin.set_value_no_signal(float(level_value))

    _update_form_badge(row.get_node_or_null("ActiveForm") as PanelContainer, family_id, level_value)


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var normalized: Dictionary = setup.duplicate(true)
    var family_id: String = str(normalized.get("species_id", ""))
    var level: int = clampi(int(normalized.get("level", 1)), 1, DATABASE_LEVEL_MAX)

    var resolved_id: String = _lab_resolve_family(family_id, level)
    if resolved_id.is_empty():
        push_error(
            "Kampflabor: Familie %s kann auf Level %d nicht in eine gueltige Form aufgeloest werden."
            % [family_id, level]
        )
        resolved_id = family_id

    normalized["family_root_id"] = family_id
    normalized["species_id"] = resolved_id
    normalized["level"] = level
    return super._make_combatant(side, index, normalized)


func _randomize_setup() -> void:
    if lab_species_ids.is_empty():
        return

    var min_level: int = LAB_RANDOM_LEVEL_MIN_DEFAULT
    var max_level: int = LAB_RANDOM_LEVEL_MAX_DEFAULT
    if random_level_min != null:
        min_level = clampi(int(random_level_min.value), 1, DATABASE_LEVEL_MAX)
    if random_level_limit != null:
        max_level = clampi(int(random_level_limit.value), 1, DATABASE_LEVEL_MAX)
    if min_level > max_level:
        min_level = max_level

    var player_amount: int = randi_range(1, TEAM_MAX)
    var enemy_amount: int = randi_range(1, TEAM_MAX)
    player_setup.clear()
    enemy_setup.clear()

    for _index: int in range(player_amount):
        player_setup.append(_random_family_setup(min_level, max_level))
    for _index: int in range(enemy_amount):
        enemy_setup.append(_random_family_setup(min_level, max_level))

    player_count.set_value_no_signal(float(player_amount))
    enemy_count.set_value_no_signal(float(enemy_amount))
    _refresh_setup()


func _random_family_setup(min_level: int, max_level: int) -> Dictionary:
    for _attempt: int in range(32):
        var level: int = randi_range(min_level, max_level)
        var candidates: Array = []
        for family_value: Variant in lab_species_ids:
            var family_id: String = str(family_value)
            if not _lab_resolve_family(family_id, level).is_empty():
                candidates.append(family_id)
        if not candidates.is_empty():
            return {
                "species_id": str(candidates.pick_random()),
                "level": level
            }

    return {
        "species_id": str(lab_species_ids[0]),
        "level": min_level
    }


func _lab_resolve_family(family_id: String, level: int) -> String:
    if family_id.is_empty():
        return ""
    if has_method("route_resolve_species_for_level"):
        return str(call("route_resolve_species_for_level", family_id, clampi(level, 1, DATABASE_LEVEL_MAX)))
    return family_id


func _lab_family_label(family_id: String, level: int) -> String:
    var root_name: String = _species_name(family_id)
    var resolved_id: String = _lab_resolve_family(family_id, level)
    if resolved_id.is_empty():
        return "%s-Familie · auf Lv.%d nicht verfuegbar" % [root_name, level]

    var resolved_name: String = _species_name(resolved_id)
    return "%s-Familie → %s" % [root_name, resolved_name]
