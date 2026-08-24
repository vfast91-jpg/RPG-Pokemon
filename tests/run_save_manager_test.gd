extends SceneTree

const RunSaveManagerScript = preload("res://scripts/run_save_manager.gd")
const TEST_SAVE_PATH: String = "user://timeflow_run_save_test.dat"


class DummyRoute:
    extends Node

    # Deliberately normal runtime members, not @export variables. This is the
    # exact category that the broken PROPERTY_USAGE_STORAGE filter skipped.
    var stage: int = 3
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
    var stage_xp_multiplier: float = 1.25
    var last_route_message: String = "Etappe 2 geschafft"
    var saved_special_battle_kind: String = ""
    var saved_special_enemy_party: Array = []
    var saved_special_battle_heading: String = ""


func _initialize() -> void:
    _remove_test_save()

    var manager = RunSaveManagerScript.new()
    manager.save_path = TEST_SAVE_PATH

    var route := DummyRoute.new()
    assert(manager.save_route(route, "stage_checkpoint"), "Run-Save muss normale Runtime-Variablen speichern können.")
    assert(FileAccess.file_exists(TEST_SAVE_PATH), "Run-Save-Datei muss tatsächlich angelegt werden.")
    assert(manager.has_run_save(), "Ein gerade geschriebener Run-Save muss als vorhanden erkannt werden.")
    assert(manager.saved_stage() == 3, "Gespeicherte Etappe muss erhalten bleiben.")
    assert(manager.saved_checkpoint() == "stage_checkpoint", "Checkpoint muss erhalten bleiben.")

    var payload: Dictionary = manager.load_run_save()
    var state: Dictionary = payload.get("state", {}) as Dictionary
    assert(int(state.get("stage", 0)) == 3, "Snapshot muss die Etappe enthalten.")
    assert(state.get("team", []) is Array and (state.get("team", []) as Array).size() == 1, "Snapshot muss das Team enthalten.")
    assert(str(((state.get("team", []) as Array)[0] as Dictionary).get("species_id", "")) == "zapdos", "Gefangenes Pokémon muss im Save erhalten bleiben.")

    route.stage = 99
    route.team.clear()
    route.storage.clear()
    route.stage_xp_multiplier = 1.0

    assert(manager.restore_route(route), "Gespeicherter Run muss wiederhergestellt werden können.")
    assert(route.stage == 3, "Restore muss die gespeicherte Etappe zurücksetzen.")
    assert(route.team.size() == 1, "Restore muss das gespeicherte Team zurückbringen.")
    assert(str((route.team[0] as Dictionary).get("species_id", "")) == "zapdos", "Restore muss das gespeicherte Pokémon zurückbringen.")
    assert(route.storage.size() == 1, "Restore muss auch das Lager zurückbringen.")
    assert(is_equal_approx(route.stage_xp_multiplier, 1.25), "Restore muss Run-Multiplikatoren erhalten.")

    manager.clear_run_save()
    assert(not FileAccess.file_exists(TEST_SAVE_PATH), "clear_run_save muss nur die Test-Save-Datei löschen.")

    route.queue_free()
    manager.queue_free()
    print("Run save manager tests: OK")
    quit(0)


func _remove_test_save() -> void:
    if FileAccess.file_exists(TEST_SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
