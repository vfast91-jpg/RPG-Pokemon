extends SceneTree

# Source-level contract guard for the active route save architecture. The project
# has a deep inheritance stack; this test protects the exact boundaries that were
# previously regressed by pre-battle/timer saves and by the invisible path box.

const RUN_SAVE_LAYER: String = "res://scripts/demo_route_run_save_v1.gd"
const LANDSCAPE_LAYER: String = "res://scripts/demo_route_landscape_choice_v1.gd"
const ENDGAME_LAYER: String = "res://scripts/demo_route_gen3_legendary_endgame_v1.gd"
const CAMPFIRE_LAYER: String = "res://scripts/demo_route_campfire_v1.gd"
const BATTLE_LAYER: String = "res://scripts/battle_demo_boss_residual_hp_fix_v1.gd"


func _initialize() -> void:
    var run_save_source: String = FileAccess.get_file_as_string(RUN_SAVE_LAYER)
    assert(not run_save_source.is_empty(), "Aktiver Run-Save-Layer muss lesbar sein.")
    assert(
        run_save_source.contains("const CANONICAL_STAGE_CHECKPOINT: String = \"stage_start\""),
        "Neue Runs müssen einen eindeutigen Etappenstart-Checkpoint verwenden."
    )
    assert(
        run_save_source.contains("RunSaveManager.save_route(self, CANONICAL_STAGE_CHECKPOINT)"),
        "Der einzige neue Save-Write muss den kanonischen Etappenstart schreiben."
    )
    assert(
        not run_save_source.contains("const AUTOSAVE_SECONDS")
        and not run_save_source.contains("_install_autosave_timer")
        and not run_save_source.contains("_on_autosave_timer_timeout"),
        "Der alte 4-Sekunden-Autosave darf nicht mehr existieren."
    )
    assert(
        not run_save_source.contains("_autosave_run(\"before_battle\")")
        and not run_save_source.contains("_autosave_run(\"application_close\")")
        and not run_save_source.contains("_autosave_run(\"main_menu\")"),
        "Kampfstart, App-Schließen und Hauptmenü dürfen keinen neuen Checkpoint schreiben."
    )
    assert(
        run_save_source.contains("func _autosave_run(_checkpoint: String = \"autosave\") -> void:")
        and run_save_source.contains("Compatibility shim for older feature layers"),
        "Alte Feature-Layer brauchen einen harmlosen No-op statt eines versteckten Mid-Stage-Saves."
    )
    assert(
        run_save_source.contains("path_box.visible = true")
        and run_save_source.contains("original invisible-next-stage softlock"),
        "Jeder echte Etappenaufbau muss die Routenauswahl explizit wieder sichtbar machen."
    )
    assert(
        run_save_source.contains("RunSaveManager.saved_version()")
        and run_save_source.contains("_restore_legacy_checkpoint"),
        "V1-Spielstände müssen weiterhin einmalig geladen werden können."
    )
    assert(
        run_save_source.contains("canonical_stage_choice_stage")
        and run_save_source.contains("canonical_stage_choices"),
        "Bereits erzeugte normale Routenangebote müssen Teil des Etappenstart-Saves sein."
    )
    assert(
        run_save_source.contains("_clear_run_save_feedback()\n    super._start_stage_battle()")
        and run_save_source.contains("_clear_run_save_feedback()\n    super._start_special_battle"),
        "Speicherfeedback muss vor normalen und besonderen Kämpfen verschwinden."
    )
    assert(
        run_save_source.contains("💾 Spielstand gespeichert")
        and run_save_source.contains("⚠ Spielstand konnte nicht gespeichert werden"),
        "Erfolg und Fehler müssen ausschließlich auf der Routenoberfläche klar rückgemeldet werden."
    )

    var landscape_source: String = FileAccess.get_file_as_string(LANDSCAPE_LAYER)
    assert(not landscape_source.is_empty(), "Landschafts-Layer muss lesbar sein.")
    assert(
        landscape_source.contains("Nach deiner Landschaftswahl wird dein Spielstand gespeichert"),
        "Die Landschaftsauswahl muss den kommenden Speicherpunkt vorher erklären."
    )
    assert(
        landscape_source.contains("call(\"_commit_canonical_stage_start\", true)"),
        "Etappen 2-95 müssen erst nach bestätigter Landschaft gespeichert werden."
    )
    assert(
        landscape_source.contains("path_box.visible = true"),
        "Die Landschafts-/Routenansicht muss einen zuvor versteckten path_box reparieren."
    )

    var endgame_source: String = FileAccess.get_file_as_string(ENDGAME_LAYER)
    assert(not endgame_source.is_empty(), "Gen-3-Endgame-Layer muss lesbar sein.")
    assert(
        endgame_source.contains("canonical_endgame_target_stage")
        and endgame_source.contains("canonical_endgame_target_species_id")
        and endgame_source.contains("func _prepare_canonical_endgame_target() -> bool:"),
        "Der konkrete Superboss muss vor dem Endgame-Etappenstart-Save feststehen."
    )

    var campfire_source: String = FileAccess.get_file_as_string(CAMPFIRE_LAYER)
    assert(not campfire_source.is_empty(), "Lagerfeuer-Layer muss lesbar sein.")
    assert(
        not campfire_source.contains("_autosave_run(\"team_change\")"),
        "Das Lagerfeuer darf keinen zusätzlichen Mid-Stage-Checkpoint erzeugen."
    )

    var battle_source: String = FileAccess.get_file_as_string(BATTLE_LAYER)
    assert(not battle_source.is_empty(), "Aktiver Battle-Layer muss lesbar sein.")
    assert(
        not battle_source.contains("Letzter Speicherpunkt")
        and not battle_source.contains("Spielstand gespeichert")
        and not battle_source.contains("Fortschritt gespeichert"),
        "Im Kampf darf keinerlei Speicherhinweis eingeblendet werden."
    )

    print("Canonical route save regression checks: OK")
    quit(0)
