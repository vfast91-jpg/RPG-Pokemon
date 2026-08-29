extends SceneTree

# Lightweight regression guard for the route-resume bug that left the next
# stage internally built but invisible after winning a resumed battle.
#
# This intentionally checks the active leaf scripts: the project uses a deep
# inheritance stack, so these final layers are the contract that must remain in
# place even when lower route/battle implementations change later.

const ROUTE_LAYER: String = "res://scripts/demo_route_clean_stage_header_v1.gd"
const BATTLE_LAYER: String = "res://scripts/battle_demo_boss_residual_hp_fix_v1.gd"


func _initialize() -> void:
    var route_source: String = FileAccess.get_file_as_string(ROUTE_LAYER)
    assert(not route_source.is_empty(), "Aktiver Route-Save-Layer muss lesbar sein.")

    var path_restore_pos: int = route_source.find("path_box.visible = true")
    var inherited_stage_build_pos: int = route_source.find("super._show_stage_choices(message)")
    assert(path_restore_pos >= 0, "Stage-Choices muessen path_box nach Resume wieder sichtbar machen.")
    assert(
        inherited_stage_build_pos > path_restore_pos,
        "path_box muss sichtbar sein, bevor die geerbte Routenauswahl neu aufgebaut wird."
    )
    assert(
        route_source.contains("_tf_refresh_local_scroll_state()"),
        "Nach dem Neuaufbau muss der Route-Viewport aktualisiert werden."
    )
    assert(
        route_source.contains("_run_save_last_write_ok = RunSaveManager.save_route(self, effective_checkpoint)"),
        "Speicherfeedback muss den echten Rueckgabewert von save_route verwenden."
    )
    assert(
        route_source.contains("_autosave_run(\"before_battle\")")
        and route_source.contains("if not _run_save_last_write_ok:"),
        "Ein Kampf darf nach fehlgeschlagenem Sicherheits-Save nicht gestartet werden."
    )
    assert(
        route_source.contains("\"stage_checkpoint\", \"new_adventure\"")
        and route_source.contains("Fortschritt gespeichert"),
        "Der gespeicherte Zustand nach einem abgeschlossenen Kampf muss fuer Spieler erkennbar sein."
    )

    var battle_source: String = FileAccess.get_file_as_string(BATTLE_LAYER)
    assert(not battle_source.is_empty(), "Aktiver Battle-Layer muss lesbar sein.")
    assert(
        battle_source.contains("Letzter Speicherpunkt: vor diesem Kampf")
        and battle_source.contains("beginnt dieser Kampf erneut"),
        "Im Routenkampf muss klar sein, dass eine Unterbrechung den Kampf neu startet."
    )
    assert(
        battle_source.contains("route_mode and battle_active"),
        "Die Kampf-Speicherwarnung darf nur in einem aktiven Routenkampf sichtbar sein."
    )

    print("Route save/resume regression checks: OK")
    quit(0)
