extends SceneTree

const MetaProgressionScript = preload("res://scripts/meta_progression.gd")
const TEST_SAVE_PATH: String = "user://meta_progression_test.json"


func _initialize() -> void:
    _remove_test_save()

    var progression = MetaProgressionScript.new()
    progression.save_path = TEST_SAVE_PATH
    progression.load_progress()

    assert(progression.get_caught_species_ids().is_empty(), "Neuer Meta-Speicher muss ohne gefangene Spezies starten.")
    assert(not progression.is_caught("pikachu"), "Pikachu darf vor einem Fang nicht als gefangen gelten.")

    assert(progression.record_seen("pikachu"), "Erstsichtung muss registriert werden.")
    assert(progression.is_seen("pikachu"), "Gesichtete Spezies muss im Pokedex sichtbar sein.")
    assert(not progression.is_caught("pikachu"), "Nur gesehen ist nicht automatisch gefangen.")

    assert(progression.record_caught("pikachu"), "Erstfang muss registriert werden.")
    assert(progression.is_caught("pikachu"), "Gefangene Spezies muss dauerhaft markiert sein.")
    assert(progression.get_unlocked_run_start_species_ids() == ["pikachu"], "Gefangene Spezies muss fuer spaetere Run-Starts freigeschaltet sein.")

    var reloaded = MetaProgressionScript.new()
    reloaded.save_path = TEST_SAVE_PATH
    reloaded.load_progress()
    assert(reloaded.is_caught("pikachu"), "Pokedex-Fortschritt muss einen Neustart ueberleben.")

    reloaded.record_caught("bulbasaur")
    assert(reloaded.get_caught_species_ids() == ["bulbasaur", "pikachu"], "Mehrere gefangene Spezies muessen stabil gespeichert werden.")

    _remove_test_save()
    print("Meta progression tests: OK")
    quit(0)


func _remove_test_save() -> void:
    if FileAccess.file_exists(TEST_SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
