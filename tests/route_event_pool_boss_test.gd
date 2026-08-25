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
    _check(route.ACTIVE_ROUTE_EVENTS.size() == 5, "Der vollständige aktive Wegpool muss genau fünf Ereignisse enthalten.")
    for kind: String in expected_events:
        _check(route.ACTIVE_ROUTE_EVENTS.has(kind), "Aktiver Wegpool fehlt: %s" % kind)
    _check(not route.ACTIVE_ROUTE_EVENTS.has(route.EVENT_DIRECT), "Direkter Pfad darf nicht mehr im aktiven Wegpool sein.")
    _check(not route.ACTIVE_ROUTE_EVENTS.has(route.EVENT_DANGEROUS), "Gefährlicher Pfad darf nicht mehr im aktiven Wegpool sein.")
    _check(route.FIRST_SPECIAL_ENCOUNTER_STAGE == 10, "Die erste feste Besondere Begegnung muss auf Etappe 10 liegen.")

    # Stages 1-9 are protected: the boss is excluded, but the remaining four
    # events stay fully random and three distinct choices are shown.
    for stage: int in [1, 5, 9]:
        var early_pool: Array[String] = route._route_event_pool_for_stage(stage)
        _check(early_pool.size() == 4, "Etappe %d muss genau vier mögliche Wegereignisse im geschützten Pool haben." % stage)
        _check(not early_pool.has(route.EVENT_RARE), "Etappe %d darf keinen Boss im Wegpool haben." % stage)
        _check(early_pool.has(route.EVENT_HEAL), "Etappe %d muss Heilquelle erlauben." % stage)
        _check(early_pool.has(route.EVENT_CATCH), "Etappe %d muss Fangwiese erlauben." % stage)
        _check(early_pool.has(route.EVENT_TM), "Etappe %d muss Fundstelle erlauben." % stage)
        _check(early_pool.has(route.EVENT_TRAINING), "Etappe %d muss Trainingsplatz erlauben." % stage)

        for _sample: int in range(80):
            var early_choices: Array[Dictionary] = route._choices_for_stage(stage)
            _check(early_choices.size() == 3, "Etappe %d muss genau drei Wegoptionen anbieten." % stage)
            var early_kinds: Array[String] = []
            for choice: Dictionary in early_choices:
                var kind: String = str(choice.get("kind", ""))
                _check(kind != route.EVENT_RARE, "Etappe %d hat trotz Schutzphase eine Besondere Begegnung angeboten." % stage)
                _check(not early_kinds.has(kind), "Etappe %d darf kein Wegereignis doppelt anbieten: %s" % [stage, kind])
                early_kinds.append(kind)

    # Stage 10 is the first fixed special encounter. It must never be replaced
    # by a random route choice and therefore exposes only the boss event.
    var stage10_pool: Array[String] = route._route_event_pool_for_stage(10)
    _check(stage10_pool.size() == 1, "Etappe 10 muss genau ein festes Wegereignis besitzen.")
    _check(stage10_pool[0] == route.EVENT_RARE, "Etappe 10 muss zwingend die Besondere Begegnung verwenden.")

    for _sample: int in range(40):
        var stage10_choices: Array[Dictionary] = route._choices_for_stage(10)
        _check(stage10_choices.size() == 1, "Etappe 10 darf nur eine Wegoption anzeigen.")
        if not stage10_choices.is_empty():
            var stage10_choice: Dictionary = stage10_choices[0]
            _check(str(stage10_choice.get("kind", "")) == route.EVENT_RARE, "Etappe 10 muss immer die Besondere Begegnung anbieten.")
            _check(str(stage10_choice.get("label", "")).contains("Besondere Begegnung"), "Die feste Etappe-10-Option muss als Besondere Begegnung beschriftet sein.")
            _check(str(stage10_choice.get("hint", "")).contains("Level +5"), "Etappe 10 muss die bestehende Bossregel höchstes eigenes Level +5 anzeigen.")

    # Stage 11 switches to the full five-event pool. From there every event,
    # including the boss, must be reachable in the fully random selection.
    var stage11_pool: Array[String] = route._route_event_pool_for_stage(11)
    _check(stage11_pool.size() == 5, "Ab Etappe 11 muss der vollständige Fünferpool aktiv sein.")
    _check(stage11_pool.has(route.EVENT_RARE), "Ab Etappe 11 muss die Besondere Begegnung wieder möglich sein.")

    var seen: Dictionary = {}
    for _sample: int in range(160):
        var choices: Array[Dictionary] = route._choices_for_stage(25)
        _check(choices.size() == 3, "Jede reguläre Etappe ab 11 muss genau drei Wegoptionen anbieten.")

        var kinds: Array[String] = []
        for choice: Dictionary in choices:
            var kind: String = str(choice.get("kind", ""))
            _check(expected_events.has(kind), "Ungültiges/entferntes Wegereignis wurde angeboten: %s" % kind)
            _check(not kinds.has(kind), "Eine Wegauswahl darf kein Ereignis doppelt enthalten: %s" % kind)
            kinds.append(kind)
            seen[kind] = true

        _check(not kinds.has(route.EVENT_DIRECT), "Direkter Pfad wurde trotz Entfernung ausgewürfelt.")
        _check(not kinds.has(route.EVENT_DANGEROUS), "Gefährlicher Pfad wurde trotz Entfernung ausgewürfelt.")

    for kind: String in expected_events:
        _check(bool(seen.get(kind, false)), "Wegereignis wurde ab Etappe 11 in der Zufallsauswahl nie erreicht: %s" % kind)

    # At stage 1, normal enemy species selection still uses the old family
    # catch-rate foundation exactly: higher catch rate = more encounter weight.
    route.stage = 1
    _check_close(route._encounter_species_weight("bulbasaur"), 45.0, 0.000001, "Bisasam-Gegnergewicht Etappe 1")
    _check_close(route._encounter_species_weight("caterpie"), 140.0, 0.000001, "Raupy-Gegnergewicht Etappe 1")
    _check_close(route._encounter_species_weight("rattata"), 191.0, 0.000001, "Rattfratz-Gegnergewicht Etappe 1")
    _check(
        route._encounter_species_weight("rattata") > route._encounter_species_weight("bulbasaur"),
        "Auf Etappe 1 müssen leichter fangbare Familien als normale Gegner häufiger gewichtet sein."
    )

    # At stage 100, the soft route curve must fully invert that relationship.
    route.stage = 100
    _check_close(route._encounter_species_weight("bulbasaur"), 1.0 / 45.0, 0.000001, "Bisasam-Gegnergewicht Etappe 100")
    _check_close(route._encounter_species_weight("rattata"), 1.0 / 191.0, 0.000001, "Rattfratz-Gegnergewicht Etappe 100")
    _check(
        route._encounter_species_weight("bulbasaur") > route._encounter_species_weight("rattata"),
        "Auf Etappe 100 müssen seltene Familien als normale Gegner häufiger gewichtet sein."
    )

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


func _check_close(actual: float, expected: float, tolerance: float, label: String) -> void:
    _check(absf(actual - expected) <= tolerance, "%s: erwartet %.6f, erhalten %.6f." % [label, expected, actual])


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
