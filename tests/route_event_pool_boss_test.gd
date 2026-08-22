extends SceneTree

const RouteScript = preload("res://scripts/demo_route_events_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    route.team = [
        {"species_id": "a", "level": 18, "hp": 20, "max_hp": 20},
        {"species_id": "b", "level": 15, "hp": 20, "max_hp": 20}
    ]

    var expected_events: Array[String] = [
        route.EVENT_HEAL,
        route.EVENT_CATCH,
        route.EVENT_TM,
        route.EVENT_TRAINING,
        route.EVENT_RARE
    ]
    _check(route.ACTIVE_ROUTE_EVENTS.size() == 5, "Der aktive Wegpool muss genau fünf Ereignisse enthalten.")
    for kind: String in expected_events:
        _check(route.ACTIVE_ROUTE_EVENTS.has(kind), "Aktiver Wegpool fehlt: %s" % kind)
    _check(not route.ACTIVE_ROUTE_EVENTS.has(route.EVENT_DIRECT), "Direkter Pfad darf nicht mehr im aktiven Wegpool sein.")
    _check(not route.ACTIVE_ROUTE_EVENTS.has(route.EVENT_DANGEROUS), "Gefährlicher Pfad darf nicht mehr im aktiven Wegpool sein.")

    var seen: Dictionary = {}
    for _sample: int in range(160):
        var choices: Array[Dictionary] = route._choices_for_stage(25)
        _check(choices.size() == 3, "Jede Etappe muss genau drei Wegoptionen anbieten.")

        var kinds: Array[String] = []
        for choice: Dictionary in choices:
            var kind: String = str(choice.get("kind", ""))
            _check(expected_events.has(kind), "Ungültiges/entferntes Wegereignis wurde angeboten: %s" % kind)
            _check(not kinds.has(kind), "Eine Wegauswahl darf kein Ereignis doppelt enthalten: %s" % kind)
            kinds.append(kind)
            seen[kind] = true

        _check(not kinds.has(route.EVENT_DIRECT), "Direkter Pfad wurde trotz Entfernung ausgewürfelt.")
        _check(not kinds.has(route.EVENT_DANGEROUS), "Gefährlicher Pfad wurde trotz Entfernung ausgewürfelt.")

    # With a shuffled five-item pool every event must be reachable in any of the
    # three positions. 160 samples makes a missing event effectively a logic
    # error rather than a balancing expectation.
    for kind: String in expected_events:
        _check(bool(seen.get(kind, false)), "Wegereignis wurde in der Zufallsauswahl nie erreicht: %s" % kind)

    _check(route._boss_level() == 23, "Boss bei höchstem eigenen Pokémon Lv.18 muss Lv.23 sein.")
    _check(is_equal_approx(route.BOSS_HP_MULTIPLIER, 2.0), "Boss muss weiterhin den doppelten KP-Pool besitzen.")
    _check(route._route_stage_xp(10) == 316, "Boss und normale Kämpfe müssen dieselbe halbierte Etappen-EP-Quelle verwenden.")

    route.team = [{"species_id": "cap", "level": 100, "hp": 1, "max_hp": 1}]
    _check(route._boss_level() == 100, "Bosslevel darf Lv.100 nicht überschreiten.")

    var fund_choice: Dictionary = route._active_event_choice(route.EVENT_TM, 20)
    _check(str(fund_choice.get("label", "")).contains("Fundstelle"), "Item-Ereignis muss Fundstelle heißen.")
    _check(not str(fund_choice.get("hint", "")).contains("+25%"), "Fundstelle darf keine alte +25%-EP-Alternative bewerben.")

    var boss_choice: Dictionary = route._active_event_choice(route.EVENT_RARE, 20)
    _check(str(boss_choice.get("label", "")).contains("Besondere Begegnung"), "Bossereignis muss als Besondere Begegnung erscheinen.")
    _check(str(boss_choice.get("hint", "")).contains("normale Etappen-EP"), "Boss-Hinweis muss normale statt doppelte EP ankündigen.")
    _check(not str(boss_choice.get("hint", "")).contains("doppelte Etappen-EP"), "Boss-Hinweis darf keinen alten 2×-EP-Bonus enthalten.")

    route.free()

    if failures == 0:
        print("Route event pool and boss test: PASS")
        quit(0)
    else:
        push_error("Route event pool and boss test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
