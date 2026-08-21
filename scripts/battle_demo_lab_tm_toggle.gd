extends "res://scripts/battle_demo_type_help_button_polish.gd"

# Combat-lab-only switch for exhaustive TM testing.
# The route keeps its normal progression rules: this toggle is ignored whenever
# the shared battle scene is running in route mode.

var lab_all_tms_toggle: CheckBox


func _build_config(root: Control) -> void:
    super._build_config(root)
    _build_lab_all_tms_toggle()


func _build_lab_all_tms_toggle() -> void:
    if config_panel == null or config_panel.get_child_count() == 0:
        return

    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer == null:
        return

    var row := HBoxContainer.new()
    row.name = "AllTMsRow"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.custom_minimum_size = Vector2(0.0, 22.0)
    outer.add_child(row)

    lab_all_tms_toggle = CheckBox.new()
    lab_all_tms_toggle.name = "AllTMsToggle"
    lab_all_tms_toggle.text = "Alle verfügbaren TMs aktivieren"
    lab_all_tms_toggle.button_pressed = false
    lab_all_tms_toggle.focus_mode = Control.FOCUS_NONE
    lab_all_tms_toggle.tooltip_text = (
        "Testmodus: Fügt jedem Pokémon alle für seine aktive Form hinterlegten "
        + "und im Kampfsystem verfügbaren TM-Attacken hinzu. Die Demo-Route bleibt unverändert."
    )
    lab_all_tms_toggle.add_theme_font_size_override("font_size", 10)
    row.add_child(lab_all_tms_toggle)

    # Put the option directly below the team-count controls and above the two
    # setup panels. This keeps it visible without widening either 4v4 team row.
    outer.move_child(row, mini(3, outer.get_child_count() - 1))


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)

    if route_mode or lab_all_tms_toggle == null or not lab_all_tms_toggle.button_pressed:
        return combatant

    var species_id: String = str(combatant.get("species_id", setup.get("species_id", "")))
    if species_id.is_empty():
        return combatant

    var moves_value: Variant = combatant.get("moves", [])
    var moves: Array = moves_value.duplicate() if moves_value is Array else []
    for move_value: Variant in _lab_available_tm_moves(species_id):
        var move_id: String = str(move_value)
        if not moves.has(move_id):
            moves.append(move_id)
    combatant["moves"] = moves
    return combatant


func _lab_available_tm_moves(species_id: String) -> Array:
    var candidates: Array = []
    var species_value: Variant = data.get("species", {})
    if not (species_value is Dictionary):
        return candidates

    var entry_value: Variant = (species_value as Dictionary).get(species_id, {})
    if not (entry_value is Dictionary):
        return candidates
    var entry: Dictionary = entry_value

    var learnset_value: Variant = entry.get("source_learnset", {})
    if not (learnset_value is Dictionary):
        return candidates
    var tm_value: Variant = (learnset_value as Dictionary).get("tm_hm", {})
    if not (tm_value is Dictionary):
        return candidates
    var tm_map: Dictionary = tm_value

    var tm_ids: Array = tm_map.keys()
    tm_ids.sort()
    for tm_id_value: Variant in tm_ids:
        var move_id: String = str(tm_map.get(tm_id_value, ""))
        if move_id.is_empty() or candidates.has(move_id):
            continue
        if _runtime_has_move(move_id):
            candidates.append(move_id)

    # Keep the test list consistent with the normal battle action menu. Moves
    # explicitly marked unavailable for normal battles are not advertised as
    # usable TMs until their runtime implementation is ready.
    return _database_normal_battle_moves(candidates)
