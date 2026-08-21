extends SceneTree

const RouteScript = preload("res://scripts/demo_route_xp_progress_bonus.gd")

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    var members: Array = [
        {"name": "Testmon A", "level": 5, "xp": 2, "hp": 20, "max_hp": 20},
        {"name": "Testmon B", "level": 5, "xp": 80, "hp": 20, "max_hp": 20},
        {"name": "Testmon C", "level": 2, "xp": 40, "hp": 20, "max_hp": 20},
        {"name": "Testmon KO", "level": 5, "xp": 2, "hp": 0, "max_hp": 20}
    ]

    var messages: Array[String] = route._apply_next_level_progress_bonus(members, 0.25)

    # Lv.5 requires 125 EP for the next level. 25% = 31.25, rounded to 31.
    # Both Lv.5 Pokémon must therefore receive exactly +31 EP regardless of
    # whether their current progress is 2 EP or 80 EP.
    _check(int((members[0] as Dictionary).get("xp", 0)) == 33, "25%-Bonus wurde bei 2 aktuellen EP falsch berechnet.")
    _check(int((members[1] as Dictionary).get("xp", 0)) == 111, "25%-Bonus hängt fälschlich vom aktuellen EP-Stand ab.")

    # Lv.2 requires 80 EP. 25% of the full requirement is exactly 20 EP.
    _check(int((members[2] as Dictionary).get("xp", 0)) == 60, "25%-Bonus nutzt nicht die vollständige EP-Anforderung des Levels.")

    # Fainted Pokémon receive no normal route XP and therefore no route bonus.
    _check(int((members[3] as Dictionary).get("xp", 0)) == 2, "Kampfunfähiges Pokémon erhielt fälschlich Bonus-EP.")
    _check(messages.size() == 3, "Bonus-Zusammenfassung enthält eine falsche Anzahl kampffähiger Pokémon.")

    route.free()

    if failures == 0:
        print("Route XP progress bonus test: PASS")
        quit(0)
    else:
        push_error("Route XP progress bonus test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
