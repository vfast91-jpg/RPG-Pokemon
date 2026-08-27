extends "res://scripts/demo_route_boss_reward_two_pick_v1.gd"

# Single-slot adventure persistence layer.
# Saves the route state only; MetaProgression and the leaderboard stay separate.
# Battles are resumed from the safe checkpoint immediately before battle start.

const AUTOSAVE_SECONDS: float = 4.0

# These three values are intentionally regular script variables so the save
# manager can persist an already rolled special encounter without serializing
# the live battle itself.
var saved_special_battle_kind: String = ""
var saved_special_enemy_party: Array = []
var saved_special_battle_heading: String = ""

var _run_save_restoring: bool = false
var _run_save_finished: bool = false
var _autosave_timer: Timer
var _run_exit_dialog: Control
var _run_exit_resume_button: Button


func _ready() -> void:
    super._ready()
    _build_run_exit_dialog()
    _install_autosave_timer()


func start_route() -> void:
    # Starting a new adventure deliberately replaces the one existing run slot.
    RunSaveManager.clear_run_save()
    _clear_saved_special_battle()
    _run_save_finished = false
    _run_save_restoring = true
    super.start_route()
    _run_save_restoring = false
    _autosave_run("new_adventure")


func continue_saved_route() -> void:
    if not RunSaveManager.has_run_save():
        start_route()
        return

    var checkpoint: String = RunSaveManager.saved_checkpoint()
    _run_save_finished = false
    _run_save_restoring = true
    var restored: bool = RunSaveManager.restore_route(self)

    if not restored or team.is_empty():
        _run_save_restoring = false
        RunSaveManager.clear_run_save()
        start_route()
        return

    visible = true
    match checkpoint:
        "pending_capture":
            _show_pending_capture_resume()
        "before_battle", "ready_for_battle":
            _show_ready_battle_resume()
        "before_special_battle":
            if saved_special_enemy_party.is_empty():
                _show_stage_choices(
                    "[b]Spielstand geladen.[/b]\nDu setzt dein Abenteuer bei Etappe %d fort." % stage
                )
            else:
                _show_special_battle_resume()
        "boss_reward_pending":
            _show_boss_reward_pending_resume()
        "boss_fundstelle":
            _show_boss_fundstelle_resume()
        "boss_reward_complete":
            _show_boss_reward_complete_resume()
        _:
            _show_stage_choices(
                "[b]Spielstand geladen.[/b]\nDu setzt dein Abenteuer bei Etappe %d fort." % stage
            )

    _run_save_restoring = false
    _autosave_run(checkpoint if not checkpoint.is_empty() else "continued")


func _show_stage_choices(message: String = "") -> void:
    if not _run_save_restoring:
        _clear_saved_special_battle()
    super._show_stage_choices(message)
    _autosave_run("stage_checkpoint")


func _refresh_team_panel() -> void:
    super._refresh_team_panel()
    if not _run_save_restoring and not _run_save_finished and is_inside_tree():
        call_deferred("_autosave_run", "team_change")


func _start_stage_battle() -> void:
    # If the game closes during the fight, this is the state that will resume.
    _autosave_run("before_battle")
    super._start_stage_battle()


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    # Dangerous paths, rare encounters and superbosses keep their already rolled
    # opponent party so reloading cannot reroll the encounter.
    saved_special_battle_kind = kind
    saved_special_enemy_party = enemy_party.duplicate(true)
    saved_special_battle_heading = heading
    _autosave_run("before_special_battle")
    super._start_special_battle(kind, enemy_party, heading)


func _finish_run(victory: bool, message: String) -> void:
    super._finish_run(victory, message)
    _run_save_finished = true
    RunSaveManager.clear_run_save()


func _go_main_menu() -> void:
    # Leaving for the menu is not the same as abandoning the run.
    _autosave_run("main_menu")
    if _run_exit_dialog != null:
        _run_exit_dialog.visible = true
        _run_exit_dialog.move_to_front()
        call_deferred("_focus_run_exit_resume_button")
        return

    _leave_run_to_main_menu()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        # During battle the route is hidden; the pre-battle checkpoint already
        # exists and must not be replaced by a half-finished combat state.
        if visible:
            _autosave_run("application_close")


func _install_autosave_timer() -> void:
    _autosave_timer = Timer.new()
    _autosave_timer.name = "RunAutosaveTimer"
    _autosave_timer.wait_time = AUTOSAVE_SECONDS
    _autosave_timer.one_shot = false
    _autosave_timer.autostart = true
    _autosave_timer.timeout.connect(_on_autosave_timer_timeout)
    add_child(_autosave_timer)


func _on_autosave_timer_timeout() -> void:
    if visible:
        _autosave_run("autosave")


func _autosave_run(checkpoint: String = "autosave") -> void:
    if _run_save_restoring or _run_save_finished:
        return
    if team.is_empty() or stage <= 0:
        return

    var effective_checkpoint: String = checkpoint
    if _boss_fundstelle_pending:
        if _boss_fundstelle_choices_remaining > 0:
            effective_checkpoint = "boss_fundstelle"
        elif not _boss_fundstelle_final_reward_text.is_empty():
            effective_checkpoint = "boss_reward_complete"
        else:
            # Boss victory is already committed, but the post-victory progression
            # presentation may still be running and the Fundstelle may not have
            # rolled its offers yet. Never mistake this window for a completed reward.
            effective_checkpoint = "boss_reward_pending"
    elif not pending_capture.is_empty():
        effective_checkpoint = "pending_capture"
    elif (
        visible
        and continue_button != null
        and continue_button.visible
        and checkpoint in ["autosave", "team_change", "main_menu", "application_close", "continued"]
    ):
        # The path reward/capture/heal is already committed. Resume directly at
        # the battle button instead of allowing the same route reward twice.
        effective_checkpoint = "ready_for_battle"

    RunSaveManager.save_route(self, effective_checkpoint)


func _show_ready_battle_resume() -> void:
    _prepare_resume_surface()
    path_box.visible = false
    continue_button.visible = true
    event_label.text = (
        "[b]Spielstand geladen.[/b]\n"
        + "Deine Wegentscheidung und alle bisherigen Änderungen dieser Etappe wurden übernommen.\n\n"
        + "Du kannst den Etappenkampf jetzt fortsetzen."
    )
    _refresh_team_panel()


func _show_pending_capture_resume() -> void:
    _prepare_resume_surface()
    path_box.visible = false
    continue_button.visible = false
    event_label.text = "[b]Spielstand geladen.[/b]\nDer gefangene Kandidat wartet weiter auf deine Entscheidung."
    _begin_capture_event_again()
    _refresh_team_panel()


func _show_special_battle_resume() -> void:
    _prepare_resume_surface()
    # This state rebuilds the special encounter directly instead of passing
    # through _show_stage_choices(). Apply the same compact, viewport-safe route
    # layout explicitly so the redundant progress row cannot push the footer
    # below the visible game window.
    _tf_prepare_route_choice_layout(false)
    continue_button.visible = false

    var enemy_lines: Array[String] = []
    for enemy_value: Variant in saved_special_enemy_party:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value as Dictionary
        var species_name: String = str(enemy.get("species_id", "Pokémon"))
        if battle_demo != null:
            species_name = battle_demo.route_species_name(str(enemy.get("species_id", "")))
        enemy_lines.append("%s Lv.%d" % [species_name, int(enemy.get("level", 1))])

    event_label.text = (
        "[b]Spielstand geladen.[/b]\n"
        + "%s wartet weiter auf dich.\nGegner: %s"
    ) % [saved_special_battle_heading, ", ".join(enemy_lines)]

    var resume_button := Button.new()
    resume_button.text = "KAMPF FORTSETZEN  →"
    resume_button.custom_minimum_size = Vector2(330, 44)
    resume_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    resume_button.pressed.connect(_resume_saved_special_battle)
    path_box.add_child(resume_button)
    _tf_refresh_local_scroll_state()
    _tf_install_route_viewport_guard()
    _refresh_team_panel()


func _show_boss_reward_pending_resume() -> void:
    _prepare_resume_surface()
    path_box.visible = false
    continue_button.visible = false

    if not _boss_fundstelle_pending:
        _show_stage_choices(
            "[b]Spielstand geladen.[/b]\nDie Bossbelohnung war bereits abgeschlossen."
        )
        return

    # The boss victory and its team/progression changes are already in the save.
    # Only the not-yet-rolled reward screen still has to begin.
    _begin_fundstelle()
    _refresh_team_panel()


func _show_boss_fundstelle_resume() -> void:
    _prepare_resume_surface()
    path_box.visible = false
    continue_button.visible = false

    if not _boss_fundstelle_pending:
        _show_stage_choices(
            "[b]Spielstand geladen.[/b]\nDie Bossbelohnung war bereits abgeschlossen."
        )
        return

    if _boss_fundstelle_choices_remaining <= 0:
        _boss_fundstelle_choices_remaining = BOSS_FUNDSTELLE_PICK_COUNT

    _fundstelle_active = true
    _remove_consumed_boss_tm_offers()
    _show_fundstelle_options()
    _refresh_team_panel()


func _show_boss_reward_complete_resume() -> void:
    _prepare_resume_surface()
    path_box.visible = false
    continue_button.visible = false

    if not _boss_fundstelle_pending:
        _show_stage_choices(
            "[b]Spielstand geladen.[/b]\nDie Bossbelohnung war bereits abgeschlossen."
        )
        return

    _boss_fundstelle_choices_remaining = 0
    _fundstelle_active = false
    _prepare_boss_reward_finish(_boss_fundstelle_final_reward_text)
    _refresh_team_panel()


func _resume_saved_special_battle() -> void:
    if saved_special_enemy_party.is_empty():
        _show_stage_choices("Der gespeicherte Spezialkampf konnte nicht wiederhergestellt werden.")
        return
    _start_special_battle(
        saved_special_battle_kind,
        saved_special_enemy_party.duplicate(true),
        saved_special_battle_heading
    )


func _prepare_resume_surface() -> void:
    visible = true
    pending_capture = pending_capture.duplicate(true)
    restart_button.visible = false
    _clear_container(path_box)
    _clear_container(capture_actions)
    title_label.text = "Etappe %d von %d" % [stage, ENDGAME_ROUTE_STAGE_COUNT]
    progress_label.text = _progress_text()


func _clear_saved_special_battle() -> void:
    saved_special_battle_kind = ""
    saved_special_enemy_party.clear()
    saved_special_battle_heading = ""


func _build_run_exit_dialog() -> void:
    var overlay := ColorRect.new()
    overlay.name = "RunExitDialog"
    overlay.color = Color("07100de0")
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.visible = false
    overlay.gui_input.connect(_on_run_exit_overlay_input)
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _run_exit_dialog = overlay

    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(520.0, 0.0)
    card.add_theme_stylebox_override(
        "panel",
        _run_exit_card_style()
    )
    center.add_child(card)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    card.add_child(content)

    var eyebrow := Label.new()
    eyebrow.text = "DEIN SPIELSTAND IST SICHER"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", Color("9fe7bd"))
    content.add_child(eyebrow)

    var title := Label.new()
    title.text = "⏸  Abenteuer unterbrechen?"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 19)
    title.add_theme_color_override("font_color", Color("fff0ad"))
    content.add_child(title)

    var save_note := PanelContainer.new()
    save_note.add_theme_stylebox_override(
        "panel",
        _panel(Color("182822"), Color("55796a"), 8, 9.0)
    )
    content.add_child(save_note)

    var note_row := HBoxContainer.new()
    note_row.add_theme_constant_override("separation", 10)
    save_note.add_child(note_row)

    var save_icon := Label.new()
    save_icon.text = "💾"
    save_icon.custom_minimum_size = Vector2(34.0, 34.0)
    save_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    save_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    save_icon.add_theme_font_size_override("font_size", 21)
    note_row.add_child(save_icon)

    var note_copy := VBoxContainer.new()
    note_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    note_copy.add_theme_constant_override("separation", 2)
    note_row.add_child(note_copy)

    var save_title := Label.new()
    save_title.text = "Automatisch gespeichert"
    save_title.add_theme_font_size_override("font_size", 13)
    save_title.add_theme_color_override("font_color", Color("f4f7f5"))
    note_copy.add_child(save_title)

    var save_text := Label.new()
    save_text.text = "Über „Abenteuer fortführen“ kannst du später genau hier weitermachen."
    save_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    save_text.add_theme_font_size_override("font_size", 10)
    save_text.add_theme_color_override("font_color", Color("b8cbc2"))
    note_copy.add_child(save_text)

    _run_exit_resume_button = Button.new()
    _run_exit_resume_button.name = "ResumeRunButton"
    _run_exit_resume_button.text = "ZURÜCK ZUM SPIEL  →"
    _run_exit_resume_button.pressed.connect(_dismiss_run_exit_dialog)
    _style_route_decision_button(_run_exit_resume_button, true)
    content.add_child(_run_exit_resume_button)

    var secondary_actions := HBoxContainer.new()
    secondary_actions.add_theme_constant_override("separation", 8)
    content.add_child(secondary_actions)

    var main_menu_button := Button.new()
    main_menu_button.name = "LeaveToMainMenuButton"
    main_menu_button.text = "⌂  ZUM HAUPTMENÜ"
    main_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_menu_button.pressed.connect(_leave_run_to_main_menu)
    _style_route_decision_button(main_menu_button, false)
    secondary_actions.add_child(main_menu_button)

    var abandon_button := Button.new()
    abandon_button.name = "AbandonRunButton"
    abandon_button.text = "LAUF BEENDEN"
    abandon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    abandon_button.tooltip_text = "Löscht nur diesen Lauf. Pokédex und dauerhafter Fortschritt bleiben erhalten."
    abandon_button.pressed.connect(_on_run_exit_custom_action.bind(&"abandon_run"))
    _style_run_exit_danger_button(abandon_button)
    secondary_actions.add_child(abandon_button)


func _run_exit_card_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = _panel(Color("12251f"), Color("e0c968"), 12, 16.0)
    style.set_border_width_all(2)
    style.shadow_color = Color("00000099")
    style.shadow_size = 10
    return style


func _style_run_exit_danger_button(button: Button) -> void:
    button.custom_minimum_size = Vector2(0.0, 44.0)
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_size_override("font_size", 11)
    button.add_theme_color_override("font_color", Color("f2c6c2"))
    button.add_theme_color_override("font_hover_color", Color("ffe5e2"))
    button.add_theme_color_override("font_pressed_color", Color("ffffff"))
    button.add_theme_color_override("font_focus_color", Color("ffe5e2"))
    button.add_theme_stylebox_override(
        "normal",
        _panel(Color("2b1d1b"), Color("8f514b"), 7, 6.0)
    )
    button.add_theme_stylebox_override(
        "hover",
        _panel(Color("412522"), Color("d47a70"), 7, 6.0)
    )
    button.add_theme_stylebox_override(
        "pressed",
        _panel(Color("4b2925"), Color("f0a097"), 7, 6.0)
    )
    button.add_theme_stylebox_override(
        "focus",
        _panel(Color("35211f"), Color("d47a70"), 7, 6.0)
    )


func _focus_run_exit_resume_button() -> void:
    if _run_exit_resume_button != null and is_instance_valid(_run_exit_resume_button):
        _run_exit_resume_button.grab_focus()


func _dismiss_run_exit_dialog() -> void:
    if _run_exit_dialog != null and is_instance_valid(_run_exit_dialog):
        _run_exit_dialog.hide()


func _on_run_exit_overlay_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _dismiss_run_exit_dialog()
        get_viewport().set_input_as_handled()


func _leave_run_to_main_menu() -> void:
    _dismiss_run_exit_dialog()
    _autosave_run("main_menu")
    visible = false
    request_main_menu.emit()


func _on_run_exit_custom_action(action: StringName) -> void:
    if str(action) != "abandon_run":
        return

    _dismiss_run_exit_dialog()
    _run_save_finished = true
    RunSaveManager.clear_run_save()
    visible = false
    request_main_menu.emit()
