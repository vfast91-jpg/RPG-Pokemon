extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_igglybuff_family.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()

    var expected_level_one: Array[String] = ["copycat", "pound", "sing"]
    var level_one_moves: Array = battle.route_moves_for_level("igglybuff", 1)

    _check(not level_one_moves.is_empty(), "Fluffeluff darf auf Level 1 keine leere Attackenliste besitzen.")
    for move_id: String in expected_level_one:
        _check(
            level_one_moves.has(move_id),
            "Fluffeluff Level 1 muss die Startattacke laden: " + move_id
        )
        _check(
            not battle._move_data(move_id).is_empty(),
            "Die Startattacke muss im aktiven Runtime-Register auflösbar sein: " + move_id
        )

    var captured: Dictionary = battle.route_new_member("igglybuff", 1)
    var known_value: Variant = captured.get("known_moves", [])
    var known_moves: Array = known_value if known_value is Array else []
    _check(not known_moves.is_empty(), "Ein frisch gefangenes Level-1-Fluffeluff darf nicht ohne Attacken ins Team kommen.")
    for move_id: String in expected_level_one:
        _check(
            known_moves.has(move_id),
            "Ein frisch gefangenes Level-1-Fluffeluff muss diese Attacke kennen: " + move_id
        )

    var level_four_moves: Array = battle.route_moves_for_level("igglybuff", 4)
    _check(level_four_moves.has("defense_curl"), "Fluffeluff muss ab Level 4 Einigler erhalten.")

    battle.free()

    if failures == 0:
        print("Fluffeluff start-moves regression test: PASS")
        quit(0)
    else:
        push_error("Fluffeluff start-moves regression test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
