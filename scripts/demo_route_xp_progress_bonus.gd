extends "res://scripts/demo_route_no_storage.gd"

# XP reward correction:
# A +25% route reward is based on the complete XP requirement for each
# individual Pokémon's next level. It is NOT 25% of the battle reward and NOT
# 25% of the Pokémon's current XP progress.
#
# This active route layer also extends the established route pattern to 90
# stages and owns the local Bestenliste entry flow shown whenever a run ends.

const NEXT_LEVEL_XP_BONUS_FRACTION: float = 0.25
const ROUTE_STAGE_COUNT_90: int = 90
const LeaderboardStore = preload("res://scripts/demo_route_leaderboard.gd")

var _leaderboard_entry_overlay: Control
var _leaderboard_entry_summary: Label
var _leaderboard_name_input: LineEdit
var _leaderboard_entry_status: Label
var _leaderboard_pending_victory: bool = false
var _leaderboard_pending_outcome: String = "Niederlage"
var _leaderboard_return_to_menu_after: bool = false
var _run_has_ended: bool = false
var _leaderboard_recorded: bool = false


func _ready() -> void:
    super._ready()
    _build_leaderboard_entry_overlay()


func start_route() -> void:
    _run_has_ended = false
    _leaderboard_recorded = false
    _leaderboard_return_to_menu_after = false
    if _leaderboard_entry_overlay != null:
        _leaderboard_entry_overlay.visible = false
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    title_label.text = "Etappe %d von %d" % [stage, ROUTE_STAGE_COUNT_90]
    progress_label.text = _progress_text()


func _progress_text() -> String:
    var completed: int = clampi(stage - 1, 0, ROUTE_STAGE_COUNT_90)
    var percent: int = int(round(float(completed) / float(ROUTE_STAGE_COUNT_90) * 100.0))
    return "Fortschritt: %d%% · Etappe %d von %d" % [percent, clampi(stage, 1, ROUTE_STAGE_COUNT_90), ROUTE_STAGE_COUNT_90]


func _capture_level_for_stage(current_stage: int) -> int:
    if current_stage <= 20:
        return super._capture_level_for_stage(current_stage)
    return clampi(current_stage - 1, 1, 99)


func _enemy_level_for_stage(current_stage: int) -> int:
    if current_stage <= 20:
        return super._enemy_level_for_stage(current_stage)
    return clampi(current_stage, 1, 100)


func _max_reachable_level_from_stage(start_level: int, start_stage: int) -> int:
    var level: int = maxi(1, start_level)
    var xp_pool: int = 0

    for stage_index: int in range(clampi(start_stage, 1, ROUTE_STAGE_COUNT_90), ROUTE_STAGE_COUNT_90 + 1):
        var base_xp: int = 20 + stage_index * 12
        xp_pool += int(ceil(float(base_xp) * MAX_ROUTE_XP_MULTIPLIER))

    while xp_pool >= _xp_needed(level) and level < 100:
        xp_pool -= _xp_needed(level)
        level += 1
    return level


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == "battle":
            choice["hint"] = (
                "Keine Hilfe vor dem Kampf. Bei einem Sieg erhält jedes kampffähige Pokémon "
                + "Bonus-EP in Höhe von 25% seiner vollständigen EP-Anforderung bis zum nächsten Level."
            )
    return choices


func _choose_path(choice: Dictionary) -> void:
    super._choose_path(choice)
    if str(choice.get("kind", "")) != "battle":
        return

    event_label.text = (
        "[b]Direkter Pfad[/b]\nDu gehst ohne Unterstützung in den Kampf. "
        + "Bei einem Sieg erhält jedes kampffähige Pokémon zusätzlich [b]25% der vollständigen "
        + "EP-Anforderung bis zu seinem nächsten Level[/b]."
    )


func _begin_capture_event() -> void:
    super._begin_capture_event()
    # If the capture was accepted automatically, pending_capture has already
    # been cleared. A remaining capture therefore means the four-Pokémon team
    # is full and the player still has to choose.
    if pending_capture.is_empty():
        return

    var name: String = str(pending_capture.get("name", "Pokémon"))
    var level: int = maxi(1, int(pending_capture.get("level", 1)))
    event_label.text = (
        "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen. Dein Team mit vier Pokémon ist voll. "
        + "Möchtest du ein Team-Pokémon ersetzen oder den Fang nicht aufnehmen? Beim Nicht-Aufnehmen "
        + "erhält jedes kampffähige Team-Pokémon im nächsten Etappenkampf Bonus-EP in Höhe von "
        + "25%% seiner vollständigen EP-Anforderung bis zum nächsten Level."
    ) % [name, level]


func _show_full_team_capture_actions() -> void:
    super._show_full_team_capture_actions()
    if capture_actions == null:
        return

    for child: Node in capture_actions.get_children():
        if child is Button and (child as Button).text.contains("+25% EP"):
            (child as Button).tooltip_text = (
                "Das gefangene Pokémon wird nicht ins Team aufgenommen. Nach dem nächsten Sieg erhält "
                + "jedes kampffähige Team-Pokémon Bonus-EP in Höhe von 25% seiner vollständigen "
                + "EP-Anforderung bis zum nächsten Level."
            )


func _decline_pending_capture() -> void:
    if pending_capture.is_empty():
        return

    var name: String = str(pending_capture.get("name", "Pokémon"))
    super._decline_pending_capture()
    event_label.text = (
        "[b]%s wird nicht ins Team aufgenommen.[/b]\n"
        + "Als Ausgleich erhält jedes kampffähige Team-Pokémon nach dem unmittelbar folgenden Sieg "
        + "[b]Bonus-EP in Höhe von 25%% seiner vollständigen EP-Anforderung bis zum nächsten Level[/b]."
    ) % name


func _begin_capture_event_again() -> void:
    super._begin_capture_event_again()
    if pending_capture.is_empty():
        return

    var name: String = str(pending_capture.get("name", "Pokémon"))
    var level: int = maxi(1, int(pending_capture.get("level", 1)))
    event_label.text = (
        "[b]Fangwiese[/b]\n%s Lv.%d wartet auf deine Entscheidung: Team-Pokémon ersetzen oder nicht "
        + "aufnehmen und beim nächsten Sieg 25%% der vollständigen EP-Anforderung bis zum nächsten "
        + "Level als Bonus-EP erhalten?"
    ) % [name, level]


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    var adjusted_team: Array = updated_team.duplicate(true)
    var bonus_fraction: float = maxf(0.0, stage_xp_multiplier - 1.0)
    var bonus_lines: Array[String] = []

    if victory and bonus_fraction > 0.0:
        bonus_lines = _apply_next_level_progress_bonus(adjusted_team, bonus_fraction)
        stage_xp_multiplier = 1.0

    team = adjusted_team
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

    if not bonus_lines.is_empty():
        var percent: int = int(round(bonus_fraction * 100.0))
        summary += (
            "\n\n[b]+%d%% Bonus-EP[/b] – berechnet aus der vollständigen EP-Anforderung bis zum nächsten "
            + "Level, nicht aus dem aktuellen EP-Stand und nicht aus den Kampf-EP:\n%s"
        ) % [percent, "\n".join(bonus_lines)]

    last_route_message = summary

    if stage >= ROUTE_STAGE_COUNT_90:
        _finish_run(true, summary + "\n\nDu hast alle 90 Etappen der Demo-Route geschafft.")
        return

    stage += 1
    _show_stage_choices(summary + "\n\nDer Weg teilt sich erneut.")


func _apply_next_level_progress_bonus(members: Array, bonus_fraction: float) -> Array[String]:
    var messages: Array[String] = []
    if bonus_fraction <= 0.0:
        return messages

    var percent: int = int(round(bonus_fraction * 100.0))
    for member_value: Variant in members:
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue

        var level: int = maxi(1, int(member.get("level", 1)))
        var required_xp: int = _xp_needed(level)
        var bonus_xp: int = maxi(1, int(round(float(required_xp) * bonus_fraction)))
        member["xp"] = int(member.get("xp", 0)) + bonus_xp

        messages.append(
            "%s: +%d EP (%d%% von %d EP)"
            % [str(member.get("name", "Pokémon")), bonus_xp, percent, required_xp]
        )

    return messages


func _finish_run(victory: bool, message: String) -> void:
    _run_has_ended = true
    super._finish_run(victory, message)

    if _leaderboard_recorded:
        return

    _leaderboard_pending_victory = victory
    _leaderboard_pending_outcome = "Geschafft" if victory else ("Abbruch" if _leaderboard_return_to_menu_after else "Niederlage")
    _show_leaderboard_entry_overlay()


func _go_main_menu() -> void:
    if _run_has_ended:
        _leave_to_main_menu()
        return
    super._go_main_menu()


func _confirm_main_menu() -> void:
    if main_menu_confirmation != null:
        main_menu_confirmation.hide()

    if _run_has_ended:
        _leave_to_main_menu()
        return

    _leaderboard_return_to_menu_after = true
    _finish_run(false, "Du hast die Demo-Route auf Etappe %d abgebrochen." % stage)


func _build_leaderboard_entry_overlay() -> void:
    if root == null or _leaderboard_entry_overlay != null:
        return

    _leaderboard_entry_overlay = Control.new()
    _leaderboard_entry_overlay.name = "LeaderboardEntryOverlay"
    _leaderboard_entry_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _leaderboard_entry_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _leaderboard_entry_overlay.z_index = 220
    _leaderboard_entry_overlay.visible = false
    root.add_child(_leaderboard_entry_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.76)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _leaderboard_entry_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _leaderboard_entry_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(520, 330)
    panel.add_theme_stylebox_override("panel", _panel(Color("172923"), Color("ffe576"), 12, 14.0))
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 9)
    panel.add_child(content)

    var title := Label.new()
    title.text = "BESTENLISTE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color("ffe576"))
    content.add_child(title)

    _leaderboard_entry_summary = Label.new()
    _leaderboard_entry_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _leaderboard_entry_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _leaderboard_entry_summary.add_theme_font_size_override("font_size", 11)
    content.add_child(_leaderboard_entry_summary)

    var name_label := Label.new()
    name_label.text = "Dein Name:"
    name_label.add_theme_font_size_override("font_size", 11)
    content.add_child(name_label)

    _leaderboard_name_input = LineEdit.new()
    _leaderboard_name_input.placeholder_text = "Name eingeben"
    _leaderboard_name_input.max_length = 24
    _leaderboard_name_input.custom_minimum_size = Vector2(0, 38)
    _leaderboard_name_input.text_submitted.connect(_on_leaderboard_name_submitted)
    content.add_child(_leaderboard_name_input)

    _leaderboard_entry_status = Label.new()
    _leaderboard_entry_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _leaderboard_entry_status.add_theme_font_size_override("font_size", 10)
    _leaderboard_entry_status.add_theme_color_override("font_color", Color("ffd98a"))
    content.add_child(_leaderboard_entry_status)

    var save_button := Button.new()
    save_button.text = "IN BESTENLISTE EINTRAGEN"
    save_button.custom_minimum_size = Vector2(0, 38)
    save_button.pressed.connect(_submit_leaderboard_entry)
    content.add_child(save_button)

    var skip_button := Button.new()
    skip_button.text = "OHNE EINTRAG WEITER"
    skip_button.custom_minimum_size = Vector2(0, 32)
    skip_button.pressed.connect(_skip_leaderboard_entry)
    content.add_child(skip_button)


func _show_leaderboard_entry_overlay() -> void:
    if _leaderboard_entry_overlay == null:
        return

    _leaderboard_entry_summary.text = "Etappe %d von %d · %s\nTeam: %s" % [
        clampi(stage, 1, ROUTE_STAGE_COUNT_90),
        ROUTE_STAGE_COUNT_90,
        _leaderboard_pending_outcome,
        LeaderboardStore.team_text({"team": _leaderboard_team_snapshot()})
    ]
    _leaderboard_entry_status.text = ""
    _leaderboard_name_input.text = ""
    _leaderboard_entry_overlay.visible = true
    _leaderboard_name_input.grab_focus()


func _on_leaderboard_name_submitted(_text: String) -> void:
    _submit_leaderboard_entry()


func _submit_leaderboard_entry() -> void:
    if _leaderboard_recorded or _leaderboard_name_input == null:
        return

    var player_name: String = _leaderboard_name_input.text.strip_edges()
    if player_name.is_empty():
        _leaderboard_entry_status.text = "Bitte gib zuerst einen Namen ein."
        _leaderboard_name_input.grab_focus()
        return

    var success: bool = LeaderboardStore.add_entry({
        "name": player_name,
        "stage": clampi(stage, 1, ROUTE_STAGE_COUNT_90),
        "victory": _leaderboard_pending_victory,
        "outcome": _leaderboard_pending_outcome,
        "team": _leaderboard_team_snapshot(),
        "timestamp": int(Time.get_unix_time_from_system())
    })

    if not success:
        _leaderboard_entry_status.text = "Der Eintrag konnte nicht gespeichert werden."
        return

    _leaderboard_recorded = true
    _leaderboard_entry_overlay.visible = false
    if event_label != null:
        event_label.text += "\n\nBestenliste: %s wurde eingetragen." % player_name

    if _leaderboard_return_to_menu_after:
        _leave_to_main_menu()


func _skip_leaderboard_entry() -> void:
    if _leaderboard_entry_overlay != null:
        _leaderboard_entry_overlay.visible = false
    if _leaderboard_return_to_menu_after:
        _leave_to_main_menu()


func _leaderboard_team_snapshot() -> Array:
    var snapshot: Array = []
    for member_value: Variant in team:
        if member_value is Dictionary:
            snapshot.append((member_value as Dictionary).duplicate(true))
    return snapshot


func _leave_to_main_menu() -> void:
    _leaderboard_return_to_menu_after = false
    visible = false
    request_main_menu.emit()
