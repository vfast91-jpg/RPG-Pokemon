extends SceneTree

const RunSaveManagerScript = preload("res://scripts/run_save_manager.gd")
const TEST_SAVE_PATH: String = "user://timeflow_run_save_test.dat"


class DummyRoute:
    extends Node

    # Deliberately normal runtime members, not @export variables. This is the
    # exact category that the old PROPERTY_USAGE_STORAGE bug skipped.
    var stage: int = 18
    var team: Array = [{
        "species_id": "zapdos",
        "name": "Zapdos",
        "level": 18,
        "hp": 63,
        "max_hp": 70,
        "xp": 17,
        "moves": ["thundershock", "peck"]
    }]
    var storage: Array = [{"species_id": "pikachu", "level": 11}]
    var pending_capture: Dictionary = {}
    var stage_xp_multiplier: float = 1.0
    var last_route_message: String = "Etappe 17 geschafft"
    var current_landscape_id: String = "forest"
    var _tf_landscape_prepared_stage: int = 18
    var canonical_stage_choice_stage: int = 18
    var canonical_stage_choices: Array = [
        {"kind": "heal", "label": "Heilquelle"},
        {"kind": "battle", "label": "Direkter Pfad"},
        {"kind": "catch", "label": "Fangwiese"}
    ]
    var canonical_endgame_target_stage: int = 0
    var canonical_endgame_target_species_id: String = ""
    var canonical_endgame_target_level: int = 0

    # Internal presentation state must never become part of the persistent run.
    var _run_save_transient_value: String = "not persistent"


func _initialize() -> void:
    _remove_test_files()

    var manager = RunSaveManagerScript.new()
    manager.save_path = TEST_SAVE_PATH

    var route := DummyRoute.new()
    assert(
        manager.save_route(route, "stage_start"),
        "Der kanonische Etappenstart muss gespeichert werden können."
    )
    assert(FileAccess.file_exists(TEST_SAVE_PATH), "Run-Save-Datei muss tatsächlich angelegt werden.")
    assert(manager.has_run_save(), "Ein gerade geschriebener Run-Save muss als vorhanden erkannt werden.")
    assert(manager.saved_version() == 2, "Neue Run-Saves müssen Format V2 verwenden.")
    assert(manager.saved_stage() == 18, "Gespeicherte Etappe muss erhalten bleiben.")
    assert(manager.saved_checkpoint() == "stage_start", "Der neue Checkpoint muss stage_start heißen.")

    var payload: Dictionary = manager.load_run_save()
    var state: Dictionary = payload.get("state", {}) as Dictionary
    assert(int(state.get("stage", 0)) == 18, "Snapshot muss die Etappe enthalten.")
    assert(str(state.get("current_landscape_id", "")) == "forest", "Gewählte Landschaft muss gespeichert werden.")
    assert(int(state.get("_tf_landscape_prepared_stage", 0)) == 18, "Vorbereitete Landschaftsetappe muss erhalten bleiben.")
    assert(int(state.get("canonical_stage_choice_stage", 0)) == 18, "Fixierte Routenangebote müssen zur Etappe gehören.")
    assert(
        state.get("canonical_stage_choices", []) is Array
        and (state.get("canonical_stage_choices", []) as Array).size() == 3,
        "Die drei bereits erzeugten Routenangebote müssen im Etappenstart liegen."
    )
    assert(
        not state.has("_run_save_transient_value"),
        "Interne Save-/UI-Hilfswerte mit _run_save_-Präfix dürfen nicht persistiert werden."
    )

    route.stage = 99
    route.team.clear()
    route.storage.clear()
    route.current_landscape_id = "meadow"
    route._tf_landscape_prepared_stage = 1
    route.canonical_stage_choice_stage = 0
    route.canonical_stage_choices.clear()

    assert(manager.restore_route(route), "Gespeicherter Run muss wiederhergestellt werden können.")
    assert(route.stage == 18, "Restore muss die gespeicherte Etappe zurücksetzen.")
    assert(route.team.size() == 1, "Restore muss das gespeicherte Team zurückbringen.")
    assert(str((route.team[0] as Dictionary).get("species_id", "")) == "zapdos", "Restore muss das gespeicherte Pokémon zurückbringen.")
    assert(route.storage.size() == 1, "Restore muss auch das Lager zurückbringen.")
    assert(route.current_landscape_id == "forest", "Restore muss die gewählte Landschaft zurückbringen.")
    assert(route._tf_landscape_prepared_stage == 18, "Restore darf nicht erneut zur Landschaftsauswahl springen.")
    assert(route.canonical_stage_choices.size() == 3, "Restore muss dieselben Routenangebote zurückbringen.")

    # Existing V1 saves are intentionally still accepted. They are not rewritten
    # by the manager merely because they were loaded; the route layer converts
    # them only at its next legitimate stage-start boundary.
    manager.clear_run_save()
    _write_legacy_v1_save()
    assert(manager.has_run_save(), "Ein gültiger V1-Spielstand muss weiterhin erkannt werden.")
    assert(manager.saved_version() == 1, "Legacy-Version muss als V1 erkennbar bleiben.")
    assert(manager.saved_checkpoint() == "before_battle", "Legacy-Checkpoint muss lesbar bleiben.")

    route.stage = 1
    route.team = [{"species_id": "pikachu", "level": 5}]
    route.current_landscape_id = "meadow"
    assert(manager.restore_route(route), "V1-Spielstand muss einmalig wiederhergestellt werden können.")
    assert(route.stage == 7, "Legacy-Restore muss seine gespeicherte Etappe erhalten.")
    assert(str((route.team[0] as Dictionary).get("species_id", "")) == "raichu", "Legacy-Team muss wiederhergestellt werden.")

    manager.clear_run_save()
    assert(not FileAccess.file_exists(TEST_SAVE_PATH), "clear_run_save muss die Test-Save-Datei löschen.")
    assert(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "clear_run_save muss temporäre Dateien löschen.")
    assert(not FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "clear_run_save muss Sicherungsdateien löschen.")

    route.queue_free()
    manager.queue_free()
    print("Run save manager tests: OK")
    quit(0)


func _write_legacy_v1_save() -> void:
    var legacy_payload: Dictionary = {
        "version": 1,
        "kind": "adventure_route",
        "checkpoint": "before_battle",
        "stage": 7,
        "saved_at": 1,
        "state": {
            "stage": 7,
            "team": [{"species_id": "raichu", "name": "Raichu", "level": 14, "hp": 41, "max_hp": 41}],
            "storage": [],
            "current_landscape_id": "canyon"
        }
    }
    var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
    assert(file != null, "Legacy-Testsave muss geschrieben werden können.")
    file.store_var(legacy_payload, false)
    file.flush()
    file.close()


func _remove_test_files() -> void:
    for path: String in [TEST_SAVE_PATH, TEST_SAVE_PATH + ".tmp", TEST_SAVE_PATH + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
