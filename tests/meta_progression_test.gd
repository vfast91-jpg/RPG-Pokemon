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

    _test_branching_family_roots(progression)

    assert(progression.record_seen("pikachu"), "Erstsichtung muss registriert werden.")
    assert(progression.is_seen("pikachu"), "Gesichtete Spezies muss im Pokedex sichtbar sein.")
    assert(not progression.is_caught("pikachu"), "Nur gesehen ist nicht automatisch gefangen.")

    assert(progression.record_caught("pikachu"), "Erstfang muss registriert werden.")
    assert(progression.is_caught("pikachu"), "Gefangene Spezies muss dauerhaft markiert sein.")
    assert(progression.get_unlocked_run_start_species_ids() == ["pikachu"], "Eine gefangene Basisform muss fuer spaetere Run-Starts freigeschaltet sein.")

    # Kernregel: Eine gefangene Entwicklungsstufe schaltet die Linie frei,
    # fuer neue Low-Level-Runs aber die niedrigste Form.
    assert(progression.get_evolution_family_base_species_id("pidgeotto") == "pidgey", "Tauboga muss zur Taubsi-Linie aufgeloest werden.")
    assert(progression.get_evolution_family_base_species_id("pidgeot") == "pidgey", "Tauboss muss ebenfalls zur Taubsi-Linie aufgeloest werden.")
    assert(progression.record_caught("pidgeotto"), "Der Fang von Tauboga muss registriert werden.")
    assert(progression.is_caught("pidgeotto"), "Die konkret gefangene Form darf fuer den Pokedex erhalten bleiben.")
    assert(not progression.is_caught("pidgey"), "Taubsi darf nicht faelschlich als konkret gefangen markiert werden.")
    assert(progression.is_evolution_family_unlocked("pidgey"), "Der Fang von Tauboga muss die Taubsi-Linie freischalten.")
    assert(progression.is_evolution_family_unlocked("pidgeot"), "Alle Formen derselben Linie muessen denselben Familien-Unlock sehen.")
    assert(progression.get_unlocked_run_start_species_ids() == ["pidgey", "pikachu"], "Der Run-Start-Pool muss Taubsi statt Tauboga enthalten.")

    var reloaded = MetaProgressionScript.new()
    reloaded.save_path = TEST_SAVE_PATH
    reloaded.load_progress()
    assert(reloaded.is_caught("pikachu"), "Pokedex-Fortschritt muss einen Neustart ueberleben.")
    assert(reloaded.is_caught("pidgeotto"), "Die konkret gefangene Entwicklungsstufe muss gespeichert bleiben.")
    assert(reloaded.get_unlocked_run_start_species_ids() == ["pidgey", "pikachu"], "Der Familien-Unlock muss einen Neustart ueberleben.")

    reloaded.record_caught("bulbasaur")
    assert(reloaded.get_caught_species_ids() == ["bulbasaur", "pidgeotto", "pikachu"], "Mehrere gefangene Spezies muessen stabil gespeichert werden.")
    assert(reloaded.get_unlocked_run_start_species_ids() == ["bulbasaur", "pidgey", "pikachu"], "Run-Starts muessen ueber Entwicklungslinien auf Basisformen aufgeloest werden.")

    _remove_test_save()
    print("Meta progression tests: OK")
    quit(0)


func _test_branching_family_roots(progression) -> void:
    var original_rules: Dictionary = progression._evolution_rules.duplicate(true)
    progression._evolution_rules = {
        "level_evolutions": {
            "branch_base": {
                "choices": [
                    {"target": "branch_a", "level": 20},
                    {"target": "branch_b", "level": 20},
                    {"target": "branch_c", "level": 20}
                ]
            }
        }
    }

    assert(
        progression.get_evolution_family_base_species_id("branch_a") == "branch_base",
        "Erster Zweig muss zur gemeinsamen Basisform zurückauflösen."
    )
    assert(
        progression.get_evolution_family_base_species_id("branch_b") == "branch_base",
        "Zweiter Zweig muss zur gemeinsamen Basisform zurückauflösen."
    )
    assert(
        progression.get_evolution_family_base_species_id("branch_c") == "branch_base",
        "Dritter Zweig muss zur gemeinsamen Basisform zurückauflösen."
    )

    progression._evolution_rules = original_rules


func _remove_test_save() -> void:
    if FileAccess.file_exists(TEST_SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
