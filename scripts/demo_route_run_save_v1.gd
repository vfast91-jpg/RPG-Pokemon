extends "res://scripts/demo_route_viewport_guard_v1.gd"

# Single-slot adventure persistence layer.
# Saves the route state only; MetaProgression and the leaderboard stay separate.
# Battles are resumed from the safe checkpoint immediately before battle start.

const AUTOSAVE_SECONDS: float = 4.0

var _run_save_restoring: bool = false
var _run_save_finished: bool = false
var _autosave_timer: Timer
var _run_exit_dialog: ConfirmationDialog


func _ready() -> void:
    super._ready()
    _build_run_exit_dialog()
    _install_autosave_timer()


func start_route() -> void:
    # Starting a new adventure deliberately replaces the one existing run slot.
    RunSaveManager.clear_run_save()
    _run_save_finished = false
    _run_save_restoring = true
    super.start_route()
    _run_save_restoring = false
    _autosave_run("new_adventure")


func continue_saved_route() -> void:
    if not RunSaveManager.has_run_save():
        start_route()
        return

    _run_save_finished = false
    _run_save_restoring = true
    var restored: bool = RunSaveManager.restore_route(self)

    if not restored or team.is_empty():
        _run_save_restoring = false
        RunSaveManager.clear_run_save()
        start_route()
        return

    visible = true
    _show_stage_choices(
        "[b]Spielstand geladen.[/b]\nDu setzt dein Abenteuer bei Etappe %d fort." % stage
    )
    _run_save_restoring = false
    _autosave_run("continued")


func _show_stage_choices(message: String = "") -> void:
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
    # Dangerous paths, rare encounters and superbosses use this battle path.
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
        _run_exit_dialog.popup_centered(Vector2i(430, 190))
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
    RunSaveManager.save_route(self, checkpoint)


func _build_run_exit_dialog() -> void:
    _run_exit_dialog = ConfirmationDialog.new()
    _run_exit_dialog.name = "RunExitDialog"
    _run_exit_dialog.title = "Abenteuer unterbrechen"
    _run_exit_dialog.dialog_text = (
        "Dein aktueller Lauf wird automatisch gespeichert.\n"
        + "Du kannst ihn später über ‚Abenteuer fortführen‘ wieder aufnehmen."
    )
    _run_exit_dialog.ok_button_text = "ZUM HAUPTMENÜ"
    _run_exit_dialog.cancel_button_text = "ZURÜCK ZUM SPIEL"
    _run_exit_dialog.confirmed.connect(_leave_run_to_main_menu)
    _run_exit_dialog.custom_action.connect(_on_run_exit_custom_action)
    add_child(_run_exit_dialog)

    var abandon_button: Button = _run_exit_dialog.add_button(
        "LAUF BEENDEN",
        true,
        "abandon_run"
    )
    abandon_button.tooltip_text = "Löscht nur diesen Lauf. Pokédex und dauerhafter Fortschritt bleiben erhalten."


func _leave_run_to_main_menu() -> void:
    _autosave_run("main_menu")
    visible = false
    request_main_menu.emit()


func _on_run_exit_custom_action(action: StringName) -> void:
    if str(action) != "abandon_run":
        return

    _run_exit_dialog.hide()
    _run_save_finished = true
    RunSaveManager.clear_run_save()
    visible = false
    request_main_menu.emit()
