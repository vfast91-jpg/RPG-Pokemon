extends "res://scripts/demo_route_boss_reward_two_pick_v1.gd"

# Single-slot adventure persistence layer.
#
# New-format runs have exactly ONE regular checkpoint per stage: the fully
# prepared start of that stage. There are deliberately no timer, team-change,
# menu-close, application-close or pre-battle saves. Quitting partway through a
# stage therefore returns to that stage's saved start.
#
# Version-1 saves remain readable through their historical resume screens. Once
# such a run reaches the next canonical stage start it is overwritten as V2 and
# thereafter follows the new rule.

const CANONICAL_STAGE_CHECKPOINT: String = "stage_start"
const CANONICAL_NORMAL_ROUTE_LAST_STAGE: int = 90
const RUN_SAVE_FEEDBACK_SECONDS: float = 1.7

# Legacy-only state. Old V1 saves may still contain an already rolled special
# battle and need these members for their one-time compatibility restore.
var saved_special_battle_kind: String = ""
var saved_special_enemy_party: Array = []
var saved_special_battle_heading: String = ""

# Normal route offers are part of the canonical stage start. Keeping the rolled
# dictionaries makes repeated loads of a V2 checkpoint rebuild the same three
# route choices instead of rerolling the stage menu. Companion-search results are
# intentionally NOT frozen here; that separate concern was explicitly left alone.
var canonical_stage_choice_stage: int = 0
var canonical_stage_choices: Array = []

var _run_save_restoring: bool = false
var _run_save_finished: bool = false
var _run_save_feedback_label: Label
var _run_save_feedback_sequence_id: int = 0
var _run_save_failure_blocked: bool = false
var _run_exit_dialog: Control
var _run_exit_resume_button: Button


func _ready() -> void:
    super._ready()
    _build_run_exit_dialog()


func start_route() -> void:
    # Starting a new adventure deliberately replaces the one existing run slot.
    RunSaveManager.clear_run_save()
    _clear_saved_special_battle()
    canonical_stage_choice_stage = 0
    canonical_stage_choices.clear()
    _run_save_finished = false
    _run_save_restoring = true
    super.start_route()
    _run_save_restoring = false

    # Etappe 1 has the fixed meadow landscape, so its canonical checkpoint is
    # created automatically after the complete initial route surface exists.
    _commit_canonical_stage_start(true)


func continue_saved_route() -> void:
    if not RunSaveManager.has_run_save():
        start_route()
        return

    var save_version: int = RunSaveManager.saved_version()
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
    if save_version >= 2 and checkpoint == CANONICAL_STAGE_CHECKPOINT:
        _show_canonical_stage_start_resume()
    else:
        _restore_legacy_checkpoint(checkpoint)

    # Never write merely because a save was loaded. A V1 run converts only when
    # it naturally reaches the next canonical stage boundary.
    _run_save_restoring = false


func _show_canonical_stage_start_resume() -> void:
    _clear_run_save_feedback()
    if path_box != null:
        path_box.visible = true
    _show_stage_choices(
        "[b]Spielstand geladen.[/b]\n"
        + "Du setzt dein Abenteuer am gespeicherten Start von Etappe %d fort." % stage
    )


func _restore_legacy_checkpoint(checkpoint: String) -> void:
    match checkpoint:
        "pending_capture":
            _show_pending_capture_resume()
        "before_battle", "ready_for_battle":
            _show_ready_battle_resume()
        "before_special_battle":
            if saved_special_enemy_party.is_empty():
                _show_stage_choices(
                    "[b]Alter Spielstand geladen.[/b]\nDu setzt dein Abenteuer bei Etappe %d fort." % stage
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
                "[b]Alter Spielstand geladen.[/b]\nDu setzt dein Abenteuer bei Etappe %d fort." % stage
            )


func _show_stage_choices(message: String = "") -> void:
    if not _run_save_restoring:
        _clear_saved_special_battle()
    if path_box != null:
        # Legacy resume surfaces used to hide this container and were the source
        # of the original invisible-next-stage softlock. Every genuine stage
        # build starts from an explicitly visible route surface.
        path_box.visible = true

    super._show_stage_choices(message)

    # Stages 2-95 commit from the landscape click itself. Stages 96-100 have no
    # random landscape screen, so the finished stage surface is their boundary.
    if not _run_save_restoring and stage > RANDOM_LANDSCAPE_LAST_STAGE:
        _commit_canonical_stage_start(true)


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    # Stages 91-100 are mandatory superboss stages and do not use the normal
    # three-choice route menu. Their actual boss target is persisted separately.
    if current_stage > CANONICAL_NORMAL_ROUTE_LAST_STAGE:
        return super._choices_for_stage(current_stage)

    if current_stage == canonical_stage_choice_stage:
        var restored_choices: Array[Dictionary] = []
        for value: Variant in canonical_stage_choices:
            if value is Dictionary:
                restored_choices.append((value as Dictionary).duplicate(true))
        return restored_choices

    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    if current_stage == stage:
        canonical_stage_choice_stage = current_stage
        canonical_stage_choices = choices.duplicate(true)
    return choices


func _start_stage_battle() -> void:
    # The save confirmation belongs only to the route screen and must never leak
    # into combat. This override performs no save at all.
    _clear_run_save_feedback()
    super._start_stage_battle()


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    # Same rule for special/boss fights: route feedback is removed before the
    # battle layer becomes visible. No pre-battle checkpoint is written.
    _clear_run_save_feedback()
    super._start_special_battle(kind, enemy_party, heading)


func _finish_run(victory: bool, message: String) -> void:
    _clear_run_save_feedback()
    super._finish_run(victory, message)
    _run_save_finished = true
    # A finished or failed run must never remain available as "Fortführen".
    RunSaveManager.clear_run_save()


func _go_main_menu() -> void:
    # Opening or leaving through this dialog deliberately does NOT create a new
    # checkpoint. The text explains that only the last stage start is retained.
    if _run_exit_dialog != null:
        _run_exit_dialog.visible = true
        _run_exit_dialog.move_to_front()
        call_deferred("_focus_run_exit_resume_button")
        return

    _leave_run_to_main_menu()


func _autosave_run(_checkpoint: String = "autosave") -> void:
    # Compatibility shim for older feature layers that may still call the former
    # helper. Keeping the method prevents inheritance breakage while guaranteeing
    # that no hidden mid-stage checkpoint can be emitted anymore.
    pass


func _commit_canonical_stage_start(show_feedback: bool = true) -> bool:
    if _run_save_restoring or _run_save_finished:
        return false
    if team.is_empty() or stage <= 0:
        return false

    # The active Gen-3 endgame layer resolves stages 91-100 here. For stages
    # outside that range the method simply returns true. This fixes legendary
    # pool/Deoxys results before the checkpoint is written without freezing
    # normal battle RNG or companion-search rolls.
    if has_method("_prepare_canonical_endgame_target"):
        if not bool(call("_prepare_canonical_endgame_target")):
            _show_run_save_failure()
            return false

    var saved: bool = RunSaveManager.save_route(self, CANONICAL_STAGE_CHECKPOINT)
    if not saved:
        _show_run_save_failure()
        return false

    _clear_run_save_failure_surface()
    if show_feedback:
        _show_run_save_feedback()
    return true


func _show_run_save_feedback() -> void:
    _clear_run_save_feedback()
    if not visible or capture_actions == null:
        return

    _run_save_feedback_sequence_id += 1
    var sequence_id: int = _run_save_feedback_sequence_id

    var label := Label.new()
    label.name = "RunSaveFeedback"
    label.text = "💾 Spielstand gespeichert"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 10)
    label.add_theme_color_override("font_color", Color("9fe7bd"))
    capture_actions.add_child(label)
    _run_save_feedback_label = label

    _hide_run_save_feedback_later(sequence_id, label)


func _hide_run_save_feedback_later(sequence_id: int, label: Label) -> void:
    await get_tree().create_timer(RUN_SAVE_FEEDBACK_SECONDS).timeout
    if sequence_id != _run_save_feedback_sequence_id:
        return
    if label != null and is_instance_valid(label):
        label.queue_free()
    if _run_save_feedback_label == label:
        _run_save_feedback_label = null


func _clear_run_save_feedback() -> void:
    _run_save_feedback_sequence_id += 1
    if _run_save_feedback_label != null and is_instance_valid(_run_save_feedback_label):
        _run_save_feedback_label.queue_free()
    _run_save_feedback_label = null


func _show_run_save_failure() -> void:
    _clear_run_save_feedback()
    _run_save_failure_blocked = true
    if path_box != null:
        path_box.visible = true
    _set_path_buttons_disabled(true)
    if continue_button != null:
        continue_button.visible = false

    if capture_actions == null:
        return
    _clear_container(capture_actions)

    var warning := Label.new()
    warning.name = "RunSaveFailureWarning"
    warning.text = "⚠ Spielstand konnte nicht gespeichert werden. Bitte erneut versuchen."
    warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    warning.add_theme_font_size_override("font_size", 10)
    warning.add_theme_color_override("font_color", Color("f0c08a"))
    capture_actions.add_child(warning)

    var retry := Button.new()
    retry.name = "RetryCanonicalStageSave"
    retry.text = "💾 SPEICHERN ERNEUT VERSUCHEN"
    retry.custom_minimum_size = Vector2(0.0, 32.0)
    retry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    retry.pressed.connect(_retry_canonical_stage_start)
    _style_route_decision_button(retry, true)
    capture_actions.add_child(retry)


func _retry_canonical_stage_start() -> void:
    _commit_canonical_stage_start(true)


func _clear_run_save_failure_surface() -> void:
    if not _run_save_failure_blocked:
        return
    _run_save_failure_blocked = false
    _set_path_buttons_disabled(false)
    if capture_actions != null:
        _clear_container(capture_actions)


func _show_ready_battle_resume() -> void:
    _prepare_resume_surface()
    path_box.visible = false
    continue_button.visible = true
    event_label.text = (
        "[b]Alter Spielstand geladen.[/b]\n"
        + "Deine damalige Wegentscheidung wurde übernommen.\n\n"
        + "Du kannst den Etappenkampf jetzt fortsetzen. Sobald diese Etappe beendet ist, "
        + "wechselt der Lauf automatisch auf das neue Etappenstart-Speichersystem."
    )
    _refresh_team_panel()


func _show_pending_capture_resume() -> void:
    _prepare_resume_surface()
    path_box.visible = false
    continue_button.visible = false
    event_label.text = "[b]Alter Spielstand geladen.[/b]\nDer gefangene Kandidat wartet weiter auf deine Entscheidung."
    _begin_capture_event_again()
    _refresh_team_panel()


func _show_special_battle_resume() -> void:
    _prepare_resume_surface()
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
        "[b]Alter Spielstand geladen.[/b]\n"
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
            "[b]Alter Spielstand geladen.[/b]\nDie Bossbelohnung war bereits abgeschlossen."
        )
        return

    _begin_fundstelle()
    _refresh_team_panel()


func _show_boss_fundstelle_resume() -> void:
    _prepare_resume_surface()
    path_box.visible = false
    continue_button.visible = false

    if not _boss_fundstelle_pending:
        _show_stage_choices(
            "[b]Alter Spielstand geladen.[/b]\nDie Bossbelohnung war bereits abgeschlossen."
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
            "[b]Alter Spielstand geladen.[/b]\nDie Bossbelohnung war bereits abgeschlossen."
        )
        return

    _boss_fundstelle_choices_remaining = 0
    _fundstelle_active = false
    _prepare_boss_reward_finish(_boss_fundstelle_final_reward_text)
    _refresh_team_panel()


func _resume_saved_special_battle() -> void:
    if saved_special_enemy_party.is_empty():
        _show_stage_choices("Der alte Spezialkampf konnte nicht wiederhergestellt werden.")
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
    eyebrow.text = "LETZTER ETAPPENSTART GESPEICHERT"
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
    save_title.text = "Gespeicherter Etappenstart"
    save_title.add_theme_font_size_override("font_size", 13)
    save_title.add_theme_color_override("font_color", Color("f4f7f5"))
    note_copy.add_child(save_title)

    var save_text := Label.new()
    save_text.text = (
        "Beim Fortführen beginnst du am letzten gespeicherten Etappenstart. "
        + "Fortschritt innerhalb der laufenden Etappe wird nicht zusätzlich gespeichert."
    )
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
    _clear_run_save_feedback()
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
