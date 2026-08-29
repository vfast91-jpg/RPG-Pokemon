extends "res://scripts/demo_route_run_save_v1.gd"

# The route is no longer presented as a demo to the player. Keep the stage
# heading focused on the only information that belongs there.
#
# This layer also closes the run-save resume gap: the persistence layer hides
# path_box while restoring a pre-battle checkpoint, so every normal stage-choice
# screen must explicitly restore the canonical path visibility before rebuilding
# its buttons. Save feedback is derived only from a confirmed save write.

var _run_save_feedback_suffix: String = ""
var _run_save_last_write_ok: bool = true
var _run_save_skip_guarded_checkpoint: String = ""


func _show_stage_choices(message: String = "") -> void:
    # A pre-battle resume deliberately hides the path choices. Normal stage
    # presentation owns the complete UI state and must always undo that hide.
    if path_box != null:
        path_box.visible = true

    super._show_stage_choices(message)
    _apply_clean_stage_header()

    # The viewport guard only exposes the route-choice viewport when path_box is
    # visible. Refresh it after the buttons have been rebuilt so a resumed battle
    # can never leave the next stage present-but-invisible.
    if has_method("_tf_refresh_local_scroll_state"):
        _tf_refresh_local_scroll_state()


func _prepare_resume_surface() -> void:
    super._prepare_resume_surface()
    _apply_clean_stage_header()


func _autosave_run(checkpoint: String = "autosave") -> void:
    # Guarded battle starts save once before entering combat. The inherited
    # wrapper asks for the same checkpoint again; skip only that duplicate write.
    if not _run_save_skip_guarded_checkpoint.is_empty() and checkpoint == _run_save_skip_guarded_checkpoint:
        _run_save_skip_guarded_checkpoint = ""
        return

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
            effective_checkpoint = "boss_reward_pending"
    elif not pending_capture.is_empty():
        effective_checkpoint = "pending_capture"
    elif (
        visible
        and continue_button != null
        and continue_button.visible
        and checkpoint in ["autosave", "team_change", "main_menu", "application_close", "continued"]
    ):
        effective_checkpoint = "ready_for_battle"

    _run_save_last_write_ok = RunSaveManager.save_route(self, effective_checkpoint)
    _present_save_feedback(_run_save_last_write_ok, effective_checkpoint)


func _start_stage_battle() -> void:
    # Never enter a normal fight without a confirmed pre-battle safety point.
    # During a fight no half-finished combat state is serialized, so this exact
    # checkpoint is what intentionally makes an interrupted fight start again.
    _autosave_run("before_battle")
    if not _run_save_last_write_ok:
        if continue_button != null:
            continue_button.visible = true
        return

    _run_save_skip_guarded_checkpoint = "before_battle"
    super._start_stage_battle()
    _run_save_skip_guarded_checkpoint = ""


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    # Persist the already rolled encounter before combat so reloading cannot
    # reroll a rare encounter, dangerous path or superboss.
    saved_special_battle_kind = kind
    saved_special_enemy_party = enemy_party.duplicate(true)
    saved_special_battle_heading = heading
    _autosave_run("before_special_battle")
    if not _run_save_last_write_ok:
        return

    _run_save_skip_guarded_checkpoint = "before_special_battle"
    super._start_special_battle(kind, enemy_party, heading)
    _run_save_skip_guarded_checkpoint = ""


func _go_main_menu() -> void:
    # Do not show the reassuring exit dialog unless the current route state was
    # actually written successfully.
    _autosave_run("main_menu")
    if not _run_save_last_write_ok:
        return

    if _run_exit_dialog != null:
        _run_exit_dialog.visible = true
        _run_exit_dialog.move_to_front()
        call_deferred("_focus_run_exit_resume_button")
        return

    _leave_run_to_main_menu()


func _leave_run_to_main_menu() -> void:
    _dismiss_run_exit_dialog()
    _autosave_run("main_menu")
    if not _run_save_last_write_ok:
        visible = true
        return

    visible = false
    request_main_menu.emit()


func _present_save_feedback(saved_ok: bool, checkpoint: String) -> void:
    if event_label == null or not is_instance_valid(event_label) or not visible:
        return

    var feedback: String = ""
    if not saved_ok:
        feedback = "[b]⚠ Speichern fehlgeschlagen – Spiel bitte noch nicht schließen.[/b]"
    else:
        match checkpoint:
            "stage_checkpoint", "new_adventure":
                feedback = "[b]💾 Fortschritt gespeichert.[/b] Beim Fortsetzen startest du auf Etappe %d." % stage
            "ready_for_battle", "before_battle":
                feedback = "[b]💾 Gespeichert: vor diesem Kampf.[/b] Wenn du während des Kampfes unterbrichst, beginnt dieser Kampf beim Fortsetzen erneut."
            "before_special_battle":
                feedback = "[b]💾 Gespeichert: vor diesem Spezialkampf.[/b] Bei einer Unterbrechung beginnt dieser Kampf beim Fortsetzen erneut; die Gegner bleiben gleich."
            "pending_capture":
                feedback = "[b]💾 Fangentscheidung gespeichert.[/b] Beim Fortsetzen wartet dieselbe Entscheidung weiter auf dich."
            "boss_reward_pending", "boss_fundstelle", "boss_reward_complete":
                feedback = "[b]💾 Bossfortschritt gespeichert.[/b] Bereits erhaltene Fortschritte und Belohnungen bleiben erhalten."
            _:
                return

    _replace_save_feedback(feedback)


func _replace_save_feedback(feedback: String) -> void:
    if event_label == null or not is_instance_valid(event_label):
        return

    if not _run_save_feedback_suffix.is_empty() and event_label.text.ends_with(_run_save_feedback_suffix):
        event_label.text = event_label.text.left(event_label.text.length() - _run_save_feedback_suffix.length())

    _run_save_feedback_suffix = "\n\n" + feedback
    event_label.text += _run_save_feedback_suffix


func _apply_clean_stage_header() -> void:
    if title_label == null:
        return
    title_label.text = "Etappe %d von %d" % [stage, ENDGAME_ROUTE_STAGE_COUNT]
