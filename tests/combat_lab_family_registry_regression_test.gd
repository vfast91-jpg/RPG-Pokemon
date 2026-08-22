extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_lab_family_refresh_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()

    var expected_roots: Array[String] = ["cleffa", "vulpix", "igglybuff"]
    for family_id: String in expected_roots:
        _check(
            battle.species_ids.has(family_id),
            "Die aktive Familienwurzel fehlt nach dem Laden: " + family_id
        )
        _check(
            battle.lab_species_ids.has(family_id),
            "Das Kampflabor muss die Familie auswählbar machen: " + family_id
        )

    _check(
        battle.lab_species_ids == battle.species_ids,
        "Die Kampflabor-Familienliste muss nach allen Familien-Layern dem aktuellen Root-Register entsprechen."
    )

    battle.free()

    if failures == 0:
        print("Combat lab family registry regression test: PASS")
        quit(0)
    else:
        push_error("Combat lab family registry regression test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
