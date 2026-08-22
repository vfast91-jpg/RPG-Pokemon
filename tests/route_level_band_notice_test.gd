extends SceneTree

const RouteScript = preload("res://scripts/demo_route_team_panel_fit.gd")

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    root.add_child(route)

    var expected_notices := {
        6: 7,
        11: 15,
        21: 23,
        31: 31,
        41: 39,
        51: 47,
        61: 55,
        71: 63,
        81: 71
    }

    for stage_value: Variant in expected_notices.keys():
        var stage: int = int(stage_value)
        var expected_level: int = int(expected_notices[stage])
        var notice: String = route._route_level_notice_for_stage(stage)
        _check(notice.contains("Neues Levelniveau"), "Etappe %d muss einen Levelniveau-Hinweis anzeigen." % stage)
        _check(notice.contains("Lv.%d" % expected_level), "Etappe %d muss Basisniveau Lv.%d nennen." % [stage, expected_level])

    for stage: int in [1, 2, 5, 7, 10, 12, 20, 22, 30, 40, 50, 60, 70, 80, 90]:
        _check(
            route._route_level_notice_for_stage(stage).is_empty(),
            "Etappe %d darf keinen Niveau-Hinweis anzeigen." % stage
        )

    route.queue_free()

    if failures == 0:
        print("Route level band notice test: PASS")
        quit(0)
    else:
        push_error("Route level band notice test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
