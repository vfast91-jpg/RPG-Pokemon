extends SceneTree

const RouteScript = preload("res://scripts/demo_route_milestone_double_boss_v1.gd")

var failures: int = 0


class BattleStub extends Node:
    func route_species_ids_for_level(_level: int) -> Array:
        return ["bulbasaur", "rattata", "caterpie"]


func _initialize() -> void:
    var route = RouteScript.new()
    var battle_stub := BattleStub.new()
    route.battle_demo = battle_stub
    route.team = [
        {"species_id": "bulbasaur", "level": 18, "hp": 30, "max_hp": 30},
        {"species_id": "rattata", "level": 15, "hp": 24, "max_hp": 24}
    ]

    var allowed_species: Array[String] = ["bulbasaur", "rattata", "caterpie"]

    for milestone: int in [20, 40, 60, 80]:
        _check(
            route._is_milestone_double_boss_stage(milestone),
            "Etappe %d muss als Doppelboss-Meilenstein erkannt werden." % milestone
        )

        var pool: Array[String] = route._route_event_pool_for_stage(milestone)
        _check(
            not pool.has(route.EVENT_RARE),
            "Etappe %d darf keine Besondere Begegnung im Wegpool anbieten." % milestone
        )
        _check(
            pool.size() == 4,
            "Etappe %d muss nach Ausschluss der Besonderen Begegnung vier mögliche Wegereignisse besitzen." % milestone
        )

        for _sample: int in range(40):
            var choices: Array[Dictionary] = route._choices_for_stage(milestone)
            _check(choices.size() == 3, "Etappe %d muss weiterhin genau drei Wegoptionen zeigen." % milestone)
            for choice: Dictionary in choices:
                _check(
                    str(choice.get("kind", "")) != route.EVENT_RARE,
                    "Etappe %d hat trotz Doppelboss eine Besondere Begegnung angeboten." % milestone
                )

        var party: Array = route._enemy_party_for_stage(milestone)
        _check(party.size() == 2, "Etappe %d muss genau zwei Bossgegner erzeugen." % milestone)
        for enemy_value: Variant in party:
            _check(enemy_value is Dictionary, "Doppelboss-Gegner muss als Dictionary erzeugt werden.")
            if not (enemy_value is Dictionary):
                continue
            var enemy: Dictionary = enemy_value as Dictionary
            _check(bool(enemy.get("boss", false)), "Beide Gegner auf Etappe %d müssen Bossstatus besitzen." % milestone)
            _check(bool(enemy.get("milestone_double_boss", false)), "Doppelboss-Markierung fehlt auf Etappe %d." % milestone)
            _check(int(enemy.get("level", 0)) == 23, "Boss auf Etappe %d muss bei Teammaximum Lv.18 auf Lv.23 skalieren." % milestone)
            _check(is_equal_approx(float(enemy.get("hp_multiplier", 0.0)), 2.0), "Boss auf Etappe %d muss 2× KP besitzen." % milestone)
            _check(int(enemy.get("hp_bars", 0)) == 2, "Boss auf Etappe %d muss zwei KP-Leisten besitzen." % milestone)
            _check(
                allowed_species.has(str(enemy.get("species_id", ""))),
                "Doppelboss auf Etappe %d muss aus dem gefilterten nicht-legendären Kandidatenpool stammen." % milestone
            )

    for normal_stage: int in [11, 19, 21, 39, 41, 59, 61, 79, 81, 90]:
        _check(
            not route._is_milestone_double_boss_stage(normal_stage),
            "Etappe %d darf nicht fälschlich als Doppelboss-Meilenstein gelten." % normal_stage
        )
        var normal_pool: Array[String] = route._route_event_pool_for_stage(normal_stage)
        _check(
            normal_pool.has(route.EVENT_RARE),
            "Etappe %d muss die Besondere Begegnung weiterhin grundsätzlich erlauben." % normal_stage
        )

    route.free()
    battle_stub.free()

    if failures == 0:
        print("Route milestone double boss test: PASS")
        quit(0)
    else:
        push_error("Route milestone double boss test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
