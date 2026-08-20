extends SceneTree

const CombatLabScript = preload("res://scripts/battle_demo_adaptive_family_ui.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = CombatLabScript.new()
    root.add_child(lab)

    _check(lab.random_level_min != null, "Zufallslevel-Untergrenze fehlt.")
    _check(lab.random_level_limit != null, "Zufallslevel-Obergrenze fehlt.")
    _check(not lab.lab_species_ids.is_empty(), "Keine Familien im Kampflabor geladen.")

    if lab.random_level_min != null:
        lab.random_level_min.set_value_no_signal(17.0)
    if lab.random_level_limit != null:
        lab.random_level_limit.set_value_no_signal(20.0)

    # Repeated randomization is the regression case from the broken lab: every
    # stored and visible level must stay in the chosen 17–20 range, and family
    # plus active form must always belong to the same row.
    for attempt: int in range(100):
        lab._randomize_setup()
        _validate_side(lab, lab.player_setup, lab.player_rows, 17, 20, "Spieler", attempt)
        _validate_side(lab, lab.enemy_setup, lab.enemy_rows, 17, 20, "Gegner", attempt)

    # Force the maximum 4v4 setup and verify the compact rows stay structurally
    # bounded instead of growing out of their half of the 640px virtual screen.
    lab.player_setup.clear()
    lab.enemy_setup.clear()
    for index: int in range(4):
        lab.player_setup.append(lab._random_family_setup(17, 20))
        lab.enemy_setup.append(lab._random_family_setup(17, 20))
    lab.player_count.set_value_no_signal(4.0)
    lab.enemy_count.set_value_no_signal(4.0)
    lab._refresh_setup()
    _validate_side(lab, lab.player_setup, lab.player_rows, 17, 20, "Spieler 4v4", 100)
    _validate_side(lab, lab.enemy_setup, lab.enemy_rows, 17, 20, "Gegner 4v4", 100)

    # A direct level change must update only that row and may never fall back to
    # the old prototype cap of 10.
    if not lab.player_setup.is_empty():
        var before_count: int = lab.player_rows.get_child_count()
        lab._level_changed(19.0, true, 0)
        _check(int(lab.player_setup[0].get("level", 0)) == 19, "Direkter Levelwechsel wurde nicht als Lv.19 gespeichert.")
        _check(lab.player_rows.get_child_count() == before_count, "Levelwechsel hat die komplette Zeilenliste neu aufgebaut.")
        _validate_side(lab, lab.player_setup, lab.player_rows, 1, 100, "Spieler nach Levelwechsel", 101)

    # Changing the family must keep the visible active form tied to the newly
    # selected family instead of leaking a form from another row.
    if not lab.player_setup.is_empty() and lab.lab_species_ids.size() > 1:
        var row: HBoxContainer = lab.player_rows.get_child(0) as HBoxContainer
        var picker: OptionButton = row.get_node_or_null("FamilyPicker") as OptionButton
        if picker != null and picker.item_count > 1:
            var next_index: int = 1 if picker.selected != 1 else 0
            picker.select(next_index)
            lab._species_changed(next_index, true, 0, picker)
            _validate_side(lab, lab.player_setup, lab.player_rows, 1, 100, "Spieler nach Familienwechsel", 102)

    lab.queue_free()

    if failures == 0:
        print("Combat lab config test: PASS")
        quit(0)
    else:
        push_error("Combat lab config test: %d Fehler" % failures)
        quit(1)


func _validate_side(lab, setup: Array, rows: VBoxContainer, min_level: int, max_level: int, side_name: String, attempt: int) -> void:
    _check(rows != null, "%s: Zeilencontainer fehlt." % side_name)
    if rows == null:
        return

    _check(
        rows.get_child_count() == setup.size(),
        "%s Versuch %d: UI hat %d Zeilen, Setup aber %d Eintraege."
        % [side_name, attempt, rows.get_child_count(), setup.size()]
    )

    for index: int in range(setup.size()):
        var entry: Dictionary = setup[index]
        var family_id: String = str(entry.get("species_id", ""))
        var level_value: int = int(entry.get("level", 0))

        _check(
            level_value >= min_level and level_value <= max_level,
            "%s Versuch %d Zeile %d: Level %d liegt ausserhalb %d–%d."
            % [side_name, attempt, index + 1, level_value, min_level, max_level]
        )
        _check(lab.lab_species_ids.has(family_id), "%s Zeile %d: %s ist keine gueltige Familienwurzel." % [side_name, index + 1, family_id])

        var resolved_id: String = lab._lab_resolve_family(family_id, level_value)
        _check(not resolved_id.is_empty(), "%s Zeile %d: Familie %s konnte auf Lv.%d nicht aufgeloest werden." % [side_name, index + 1, family_id, level_value])

        if index >= rows.get_child_count():
            continue
        var row: HBoxContainer = rows.get_child(index) as HBoxContainer
        _check(row != null, "%s Zeile %d: UI-Zeile hat falschen Typ." % [side_name, index + 1])
        if row == null:
            continue

        _check(
            row.get_combined_minimum_size().x <= lab.LAB_ROW_MAXIMUM_MIN_WIDTH,
            "%s Zeile %d: Mindestbreite %.1f ist zu gross fuer eine Teamhaelfte (Limit %.1f)."
            % [side_name, index + 1, row.get_combined_minimum_size().x, lab.LAB_ROW_MAXIMUM_MIN_WIDTH]
        )

        var picker: OptionButton = row.get_node_or_null("FamilyPicker") as OptionButton
        var badge: PanelContainer = row.get_node_or_null("ActiveForm") as PanelContainer
        var level_spin: SpinBox = row.get_node_or_null("LevelPicker") as SpinBox
        _check(picker != null, "%s Zeile %d: Familienauswahl fehlt." % [side_name, index + 1])
        _check(badge != null, "%s Zeile %d: Formanzeige fehlt." % [side_name, index + 1])
        _check(level_spin != null, "%s Zeile %d: Levelauswahl fehlt." % [side_name, index + 1])

        if picker != null:
            _check(not picker.fit_to_longest_item, "%s Zeile %d: Familienauswahl darf sich nicht am laengsten Namen verbreitern." % [side_name, index + 1])
            if picker.selected >= 0:
                _check(
                    str(picker.get_item_metadata(picker.selected)) == family_id,
                    "%s Zeile %d: Sichtbare Familie passt nicht zum Setup." % [side_name, index + 1]
                )

        if level_spin != null:
            _check(
                int(level_spin.value) == level_value,
                "%s Zeile %d: Sichtbares Level %d passt nicht zum Setup-Level %d."
                % [side_name, index + 1, int(level_spin.value), level_value]
            )
            _check(int(level_spin.max_value) == 100, "%s Zeile %d: Levelauswahl ist nicht bis 100 freigeschaltet." % [side_name, index + 1])

        if badge != null:
            var form_label: Label = badge.get_node_or_null("Label") as Label
            _check(form_label != null, "%s Zeile %d: Formtext fehlt." % [side_name, index + 1])
            if form_label != null and not resolved_id.is_empty():
                var expected_name: String = lab._species_name(resolved_id)
                _check(
                    form_label.text == expected_name,
                    "%s Zeile %d: Formanzeige '%s' erwartet '%s' fuer Familie %s Lv.%d."
                    % [side_name, index + 1, form_label.text, expected_name, family_id, level_value]
                )


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
