extends SceneTree

const RouteScript = preload("res://scripts/demo_route_team_panel_fit.gd")

const MODIFIERS := {
    1: 5,
    2: 2,
    3: 0,
    4: -2
}

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    root.add_child(route)

    for stage: int in range(1, 21):
        for enemy_count: int in range(1, 5):
            var expected: int = maxi(1, stage + int(MODIFIERS[enemy_count]))
            var actual: int = route._enemy_level_for_encounter(stage, enemy_count)
            _check(
                actual == expected,
                "Etappe %d mit %d Gegnern: erwartet Lv.%d, erhalten Lv.%d."
                % [stage, enemy_count, expected, actual]
            )

    # Concrete regression around the jump that exposed the old balancing flaw.
    _check(route._enemy_level_for_encounter(10, 1) == 15, "Etappe 10 / 1 Gegner muss Lv.15 sein.")
    _check(route._enemy_level_for_encounter(10, 4) == 8, "Etappe 10 / 4 Gegner müssen Lv.8 sein.")
    _check(route._enemy_level_for_encounter(11, 1) == 16, "Etappe 11 / 1 Gegner muss Lv.16 sein.")
    _check(route._enemy_level_for_encounter(11, 4) == 9, "Etappe 11 / 4 Gegner müssen Lv.9 sein.")

    route.queue_free()

    if failures == 0:
        print("Route encounter level curve test: PASS")
        quit(0)
    else:
        push_error("Route encounter level curve test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
