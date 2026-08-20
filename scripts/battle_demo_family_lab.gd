extends "res://scripts/battle_demo_user_polish.gd"

# Combat-lab family-selection layer.
# The lab no longer lets an evolution form exist at an impossible level.
# Players choose a family root; the selected level determines the active form
# through the same mandatory evolution resolver used by the demo route.


func _load_data() -> void:
    super._load_data()

    # `species_ids` is the canonical route-root list. Reuse exactly those roots
    # as the lab choices so each row represents one Pokemon family instead of
    # one individual evolution form.
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
    super._fill_rows(box, setup, own)

    # The original combat-lab row still creates its level SpinBox with the old
    # prototype cap LEVEL_MAX = 10. The database-backed lab supports Lv.1–100,
    # so repair every generated row after the inherited UI has been built.
    # This also restores randomized values above 10 instead of displaying them
    # as Lv.10.
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

        var level: int = clampi(int(setup[index].get("level", 1)), 1, DATABASE_LEVEL_MAX)
        if level_spin != null:
            level_spin.min_value = 1.0
            level_spin.max_value = float(DATABASE_LEVEL_MAX)
            level_spin.allow_greater = false
            level_spin.set_value_no_signal(float(level))
            level_spin.tooltip_text = "Level 1–%d. Die aktive Entwicklungsform folgt automatisch dem Level." % DATABASE_LEVEL_MAX

        if picker == null:
            continue

        # Make the rule visible instead of hiding it in the battle start logic.
        # Example at Lv.18: "Schiggy-Familie -> Schillok".
        for item_index: int in range(picker.item_count):
            var family_id: String = str(picker.get_item_metadata(item_index))
            picker.set_item_text(item_index, _lab_family_label(family_id, level))


func _species_changed(_item_index: int, own: bool, index: int, picker: OptionButton) -> void:
    super._species_changed(_item_index, own, index, picker)
    # Rebuild immediately so the selected family shows the form implied by the
    # current level.
    _refresh_setup()


func _level_changed(value: float, own: bool, index: int) -> void:
    # Do not call the prototype implementation here: it still clamps to the old
    # LEVEL_MAX = 10. The canonical database and random-level controls support
    # the full Lv.1–100 range.
    var setup: Array = player_setup if own else enemy_setup
    if index >= setup.size():
        return
    setup[index]["level"] = clampi(int(value), 1, DATABASE_LEVEL_MAX)

    # The displayed form changes exactly at evolution thresholds.
    _refresh_setup()


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var normalized: Dictionary = setup.duplicate(true)
    var family_id: String = str(normalized.get("species_id", ""))
    var level: int = maxi(1, int(normalized.get("level", 1)))

    var resolved_id: String = _lab_resolve_family(family_id, level)
    if resolved_id.is_empty():
        push_error(
            "Kampflabor: Familie %s kann auf Level %d nicht in eine gueltige Form aufgeloest werden."
            % [family_id, level]
        )
        # This should only happen when required species data is missing. Keep
        # the original id as a last-resort parse-safe fallback instead of
        # crashing the whole lab; generated setups filter these cases out.
        resolved_id = family_id

    normalized["family_root_id"] = family_id
    normalized["species_id"] = resolved_id
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
    # Pick the level first, then only families that can legally exist at it.
    # This prevents fallback cases such as Turtok Lv.10 or Glutexo Lv.10.
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

    # Canonical data currently contains complete families, so this is only a
    # defensive fallback for future partially designed data packs.
    return {
        "species_id": str(lab_species_ids[0]),
        "level": min_level
    }


func _lab_resolve_family(family_id: String, level: int) -> String:
    if family_id.is_empty():
        return ""
    if has_method("route_resolve_species_for_level"):
        return str(call("route_resolve_species_for_level", family_id, maxi(1, level)))
    return family_id


func _lab_family_label(family_id: String, level: int) -> String:
    var root_name: String = _species_name(family_id)
    var resolved_id: String = _lab_resolve_family(family_id, level)
    if resolved_id.is_empty():
        return "%s-Familie · auf Lv.%d nicht verfuegbar" % [root_name, level]

    var resolved_name: String = _species_name(resolved_id)
    return "%s-Familie → %s" % [root_name, resolved_name]
