extends SceneTree

const ActiveRouteScript = preload("res://scripts/demo_route_boss_gauntlet_test_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var route = ActiveRouteScript.new()

    _check(
        route._tf_player_facing_text("NEUE DEMO-ROUTE") == "NEUE ROUTE",
        "Der sichtbare Neustart darf nicht mehr NEUE DEMO-ROUTE heißen."
    )
    _check(
        route._tf_player_facing_text("Du hast die Demo-Route geschafft.") == "Du hast die Route geschafft.",
        "Sichtbare Demo-Route-Texte müssen zu Route bereinigt werden."
    )
    _check(
        route._tf_player_facing_text("Für die Demo wird dein Team geheilt.").find("Demo") == -1,
        "Sichtbare Demo-Hinweise dürfen nicht bestehen bleiben."
    )

    _check(
        route.FINAL_VICTORY_TITLE.contains("POKÉMON TIMEFLOW") and route.FINAL_VICTORY_TITLE.contains("🏆"),
        "Der finale Sieg braucht einen klaren feierlichen Timeflow-Titel."
    )
    _check(
        route.FINAL_VICTORY_PROGRESS.contains("100 / 100") and route.FINAL_VICTORY_PROGRESS.contains("ROUTE VOLLENDET"),
        "Der Abschluss muss die vollständig gemeisterte 100-Etappen-Route sichtbar machen."
    )

    var route_source: String = FileAccess.get_file_as_string("res://scripts/demo_route_boss_gauntlet_test_v1.gd")
    _check(
        route_source.contains("AudioManager.play_victory(true)"),
        "Etappe 100 muss den bestehenden Champion-Siegkanal verwenden."
    )
    _check(
        route_source.contains("restart_button.text = \"NEUE ROUTE\""),
        "Der finale Neustartbutton muss NEUE ROUTE heißen."
    )
    _check(
        route_source.contains("FinalVictoryCelebration"),
        "Der finale Sieg braucht eine eigene feierliche Präsentation."
    )
    _check(
        route_source.contains("if not _boss_gauntlet_test_mode"),
        "Der normale Abschluss muss weiterhin vom isolierten Bosskampflauf getrennt bleiben."
    )
    _check(
        route_source.contains("func start_boss_gauntlet_test"),
        "Der Bosskampflauf darf durch Paket 3 nicht entfernt werden."
    )

    var audio_source: String = FileAccess.get_file_as_string("res://scripts/audio_manager.gd")
    _check(
        audio_source.contains("VictoryChampion.mp3"),
        "Der bestehende Champion-Siegtrack muss weiterhin die Audioquelle sein."
    )
    _check(
        audio_source.contains("func play_victory(final_battle := false)"),
        "Paket 3 muss die bestehende Audio-Architektur statt eines neuen Players verwenden."
    )

    route.free()

    if failures == 0:
        print("Final route victory regression test: PASS")
        quit(0)
    else:
        push_error("Final route victory regression test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
