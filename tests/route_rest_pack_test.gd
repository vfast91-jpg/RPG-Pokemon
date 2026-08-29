extends SceneTree

const RouteScript = preload("res://scripts/demo_route_rest_pack_v1.gd")
const RunSaveManagerScript = preload("res://scripts/run_save_manager.gd")
const TEST_SAVE_PATH: String = "user://timeflow_rest_pack_test.dat"

var failures: Array[String] = []


func _initialize() -> void:
    _remove_test_save()
    _test_exact_milestone_rewards_and_idempotence()
    _test_reward_popup_is_queued_for_every_grant()
    _test_use_heals_team_and_cannot_be_wasted()
    _test_save_restore_keeps_count_and_claims()
    _test_compact_rest_pack_footer_ui_state()
    _remove_test_save()

    if failures.is_empty():
        print("PASS: Poké-Rastpaket route tests")
        quit(0)
        return

    for failure: String in failures:
        push_error(failure)
    quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _test_exact_milestone_rewards_and_idempotence() -> void:
    var route = RouteScript.new()
    var expected_stages: Array[int] = [5, 15, 25, 35, 45, 55, 65, 75, 85, 95]

    # The reward belongs to the milestone that was actually COMPLETED. It is not
    # granted merely because the player opened that milestone's route screen.
    _expect(not route._grant_rest_pack_for_completed_stage(4), "Vor Abschluss von Etappe 5 darf noch kein Rastpaket vergeben werden.")
    _expect(route._grant_rest_pack_for_completed_stage(5), "Nach erfolgreichem Abschluss von Etappe 5 muss das erste Rastpaket vergeben werden.")
    _expect(route.rest_pack_count == 1, "Nach Abschluss von Etappe 5 muss der Bestand ×1 sein.")
    _expect(not route._grant_rest_pack_for_completed_stage(5), "Etappe 5 darf beim erneuten Anzeigen niemals doppelt auszahlen.")

    route.free()
    route = RouteScript.new()

    for completed_stage: int in range(1, 101):
        var granted: bool = route._grant_rest_pack_for_completed_stage(completed_stage)
        _expect(
            granted == expected_stages.has(completed_stage),
            "Nur abgeschlossene Etappen 5/15/.../95 dürfen ein Rastpaket vergeben (Etappe %d)." % completed_stage
        )

    _expect(route.rest_pack_count == 10, "Bis nach Etappe 95 müssen exakt zehn Rastpakete vergeben worden sein.")
    _expect(route.rest_pack_claimed_stages.size() == 10, "Jede der zehn Meilenstein-Etappen darf nur einmal markiert sein.")
    _expect(not route._grant_rest_pack_for_completed_stage(5), "Etappe 5 darf auch später niemals ein zweites Mal auszahlen.")
    _expect(route.rest_pack_count == 10, "Doppelte Meilenstein-Aufrufe dürfen den Bestand nicht erhöhen.")
    _expect(not route._grant_rest_pack_for_completed_stage(100), "Etappe 100 darf ausdrücklich kein Rastpaket vergeben.")
    route.free()


func _test_reward_popup_is_queued_for_every_grant() -> void:
    var route = RouteScript.new()
    var expected_stages: Array[int] = [5, 15, 25, 35, 45, 55, 65, 75, 85, 95]

    for completed_stage: int in expected_stages:
        _expect(
            route._award_rest_pack_for_completed_stage(completed_stage),
            "Jede echte Rastpaket-Vergabe muss auch das Vergabe-Fenster einplanen (Etappe %d)." % completed_stage
        )

    _expect(route.rest_pack_count == 10, "Die Popup-Prüfung muss zehn echte Vergaben erzeugen.")
    _expect(
        route._run_save_rest_pack_reward_popup_queue == expected_stages,
        "Für 5/15/.../95 muss jeweils genau ein eigenes Vergabe-Fenster in der Warteschlange stehen."
    )
    _expect(
        route._run_save_rest_pack_reward_popup_pending,
        "Nach einer echten Vergabe muss das Rastpaket-Fenster zur Anzeige vorgemerkt sein."
    )

    var queued_before_duplicate: int = route._run_save_rest_pack_reward_popup_queue.size()
    _expect(
        not route._award_rest_pack_for_completed_stage(25),
        "Eine bereits vergütete Etappe darf weder Paket noch zweites Fenster erzeugen."
    )
    _expect(
        route._run_save_rest_pack_reward_popup_queue.size() == queued_before_duplicate,
        "Ein doppelter Meilenstein-Aufruf darf kein zweites Vergabe-Fenster einreihen."
    )
    route.free()


func _test_use_heals_team_and_cannot_be_wasted() -> void:
    var route = RouteScript.new()
    # Prevent the explicit production autosave in _use_rest_pack() from touching
    # the real run slot during this isolated regression test.
    route._run_save_finished = true
    route.rest_pack_count = 2
    route.team = [
        {"name": "Pikachu", "hp": 7, "max_hp": 31, "major_status": "paralysis"},
        {"name": "Bisasam", "hp": 0, "max_hp": 36, "major_status": "poison"}
    ]

    _expect(route._team_needs_rest_pack(), "Ein verletztes/statuskrankes Team muss ein Rastpaket benutzen dürfen.")
    route._use_rest_pack()

    _expect(route.rest_pack_count == 1, "Eine erfolgreiche Rast muss exakt ein Paket verbrauchen.")
    _expect(int(route.team[0].get("hp", 0)) == 31, "Rastpaket muss das erste Pokémon vollständig heilen.")
    _expect(int(route.team[1].get("hp", 0)) == 36, "Rastpaket muss auch ein kampfunfähiges Teammitglied vollständig heilen.")
    _expect(str(route.team[0].get("major_status", "x")).is_empty(), "Rastpaket muss den vorhandenen Major-Status über die zentrale Heilung entfernen.")
    _expect(str(route.team[1].get("major_status", "x")).is_empty(), "Rastpaket muss Statusprobleme im gesamten Team entfernen.")
    _expect(not route._team_needs_rest_pack(), "Nach vollständiger Heilung darf kein weiterer Heilbedarf bestehen.")

    route._use_rest_pack()
    _expect(route.rest_pack_count == 1, "Ein vollständig gesundes Team darf kein Rastpaket verschwenden.")
    route.free()


func _test_save_restore_keeps_count_and_claims() -> void:
    var manager = RunSaveManagerScript.new()
    manager.save_path = TEST_SAVE_PATH

    var route = RouteScript.new()
    route.stage = 16
    route.team = [{"name": "Evoli", "hp": 22, "max_hp": 30, "major_status": ""}]
    route.rest_pack_count = 2
    route.rest_pack_claimed_stages = [5, 15]

    _expect(manager.save_route(route, "stage_checkpoint"), "RunSaveManager muss den Rastpaket-Zustand speichern können.")

    var restored = RouteScript.new()
    restored.stage = 1
    restored.team = [{"name": "Platzhalter", "hp": 1, "max_hp": 1}]
    restored.rest_pack_count = 0
    restored.rest_pack_claimed_stages = []

    _expect(manager.restore_route(restored), "Rastpaket-Spielstand muss wiederhergestellt werden können.")
    _expect(restored.rest_pack_count == 2, "Gestapelter Rastpaket-Bestand muss Save/Load überleben.")
    _expect(restored.rest_pack_claimed_stages == [5, 15], "Bereits ausgezahlte Meilensteine müssen Save/Load überleben.")
    _expect(
        restored._run_save_rest_pack_reward_popup_queue.is_empty(),
        "Transiente Vergabe-Fenster dürfen nicht im Spielstand gespeichert werden."
    )

    manager.clear_run_save()
    route.free()
    restored.free()
    manager.free()


func _test_compact_rest_pack_footer_ui_state() -> void:
    var route = RouteScript.new()
    route._build_ui()
    route._build_rest_pack_ui()
    route._refresh_rest_pack_ui()

    _expect(route._rest_pack_panel != null, "Rastpaket-Box muss aufgebaut werden.")
    _expect(route._rest_pack_count_label != null, "Rastpaket-Box braucht eine sichtbare Bestandsanzeige.")
    _expect(route._rest_pack_use_button != null, "Rastpaket-Box braucht einen Heil-Button.")

    if route._rest_pack_count_label != null:
        _expect(route._rest_pack_count_label.text.contains("×0"), "Rastpaket-Anzeige muss auch bei Bestand 0 sichtbar bleiben.")
        _expect(
            route._rest_pack_count_label.tooltip_text.contains("gesamtes Team vollständig"),
            "Der Tooltip muss den vollständigen Team-Heileffekt erklären statt nur den Bestand zu wiederholen."
        )
        _expect(
            route._rest_pack_count_label.tooltip_text.contains("Statusprobleme"),
            "Der Tooltip muss auch die Entfernung von Statusproblemen erklären."
        )

    if route._rest_pack_use_button != null:
        _expect(route._rest_pack_use_button.disabled, "HEILEN muss bei Bestand 0 deaktiviert sein.")
        _expect(route._rest_pack_use_button.text == "HEILEN", "Der kompakte Rastpaket-Button soll klar als HEILEN beschriftet sein.")
        _expect(route._rest_pack_use_button.custom_minimum_size.y <= 22.0, "Der Heil-Button darf nicht wieder zu einem großen Block anwachsen.")

    if route._rest_pack_panel != null and route.team_box != null:
        var team_scroll: Node = route.team_box.get_parent()
        var team_content: Node = team_scroll.get_parent() if team_scroll != null else null
        var team_panel: Node = team_content.get_parent() if team_content != null else null
        var columns: Node = team_panel.get_parent() if team_panel != null else null
        var outer: Node = columns.get_parent() if columns != null else null
        var footer: Node = route._rest_pack_panel.get_parent()

        _expect(
            footer != team_content,
            "Rastpaket darf nicht mehr im dynamischen TEAM-Inhalt zwischen den Pokémonkarten liegen."
        )
        _expect(
            footer is HBoxContainer and footer.get_parent() == outer,
            "Rastpaket muss in der separaten Fußzeile unterhalb der Hauptspalten liegen."
        )
        if footer != null and columns != null:
            _expect(
                footer.get_index() > columns.get_index(),
                "Rastpaket-Fußzeile muss vertikal unter dem TEAM-Bereich liegen."
            )
        _expect(
            route._rest_pack_panel.custom_minimum_size.y <= 28.0,
            "Rastpaket-Anzeige muss kompakt bleiben und darf keine Teamkartenhöhe verbrauchen."
        )

    route.rest_pack_count = 1
    route.team = [{"name": "Schiggy", "hp": 4, "max_hp": 25, "major_status": ""}]
    route._refresh_rest_pack_ui()
    if route._rest_pack_use_button != null:
        _expect(not route._rest_pack_use_button.disabled, "HEILEN muss mit Paket und verletztem Team aktiv sein.")

    route.team[0]["hp"] = 25
    route._refresh_rest_pack_ui()
    if route._rest_pack_use_button != null:
        _expect(route._rest_pack_use_button.disabled, "HEILEN muss bei vollständig gesundem Team deaktiviert sein.")

    route.free()


func _remove_test_save() -> void:
    if FileAccess.file_exists(TEST_SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
