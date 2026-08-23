extends SceneTree

const RouteScript = preload("res://scripts/demo_route_rebalance_v1.gd")
const RouteEventsScript = preload("res://scripts/demo_route_events_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()

    route.team = [
        {"species_id": "a", "level": 18, "hp": 20, "max_hp": 20},
        {"species_id": "b", "level": 15, "hp": 20, "max_hp": 20}
    ]
    route.stage = 40

    _check(route.CAPTURE_SEARCH_MAX == 3, "Eine Fangwiese muss exakt drei Suchen erlauben.")
    _check(route.CAPTURE_SEARCH_LEVEL_OFFSETS == [1, 3, 5], "Fangwiese muss die festen Levelabstände -1/-3/-5 verwenden.")
    _check(route._capture_level_for_stage(40) == 17, "Basis-Fanglevel bei Teammaximum Lv.18 muss Lv.17 sein.")
    _check(route._capture_level_for_search(1) == 17, "Suche 1 muss ein Level unter dem höchsten Team-Pokémon liegen.")
    _check(route._capture_level_for_search(2) == 15, "Suche 2 muss drei Level unter dem höchsten Team-Pokémon liegen.")
    _check(route._capture_level_for_search(3) == 13, "Suche 3 muss fünf Level unter dem höchsten Team-Pokémon liegen.")

    route.team = [{"species_id": "starter", "level": 5, "hp": 20, "max_hp": 20}]
    _check(route._capture_level_for_stage(1) == 4, "Starter Lv.5 muss bei Suche 1 ein Fanglevel von Lv.4 erzeugen.")
    _check(route._capture_level_for_search(2) == 2, "Starter Lv.5 muss bei Suche 2 ein Fanglevel von Lv.2 erzeugen.")
    _check(route._capture_level_for_search(3) == 1, "Suche 3 muss bei niedrigen Teamleveln auf mindestens Lv.1 begrenzt werden.")

    route.team = [{"species_id": "starter", "level": 3, "hp": 20, "max_hp": 20}]
    _check(route._capture_level_for_search(1) == 2, "Teammaximum Lv.3 muss bei Suche 1 Lv.2 ergeben.")
    _check(route._capture_level_for_search(2) == 1, "Teammaximum Lv.3 muss bei Suche 2 auf Lv.1 begrenzt werden.")
    _check(route._capture_level_for_search(3) == 1, "Teammaximum Lv.3 muss bei Suche 3 auf Lv.1 begrenzt werden.")

    _check(route.ROUTE_RARITY_MAX_STAGE == 100, "Die Seltenheitskurve muss auf das spätere Maximum von 100 Etappen normiert sein.")
    _check_close(route._route_rarity_progress_for_stage(1), 0.0, 0.000001, "Seltenheitsfortschritt Etappe 1")
    _check_close(route._route_rarity_progress_for_stage(100), 1.0, 0.000001, "Seltenheitsfortschritt Etappe 100")
    _check_close(route._route_rarity_exponent_for_stage(1), 1.0, 0.000001, "Routen-Exponent Etappe 1")
    _check_close(route._route_rarity_exponent_for_stage(100), -1.0, 0.000001, "Routen-Exponent Etappe 100")

    var normalized_25: float = 24.0 / 99.0
    var normalized_75: float = 74.0 / 99.0
    _check(
        route._route_rarity_progress_for_stage(25) < normalized_25,
        "Die weiche Kurve muss im frühen Run unter dem linearen Fortschritt liegen."
    )
    _check(
        route._route_rarity_progress_for_stage(75) > normalized_75,
        "Die weiche Kurve muss im späten Run über dem linearen Fortschritt liegen."
    )

    route._ensure_encounter_family_data()
    _check(route._family_id_for_species("pikachu") == "pichu", "Pikachu muss zur Pichu-Familie gehören.")
    _check_close(route._family_catch_rate("bulbasaur"), 45.0, 0.000001, "Bisasam-Familien-Fangrate")
    _check_close(route._family_catch_rate("rattata"), 191.0, 0.000001, "Rattfratz-Familien-Fangrate")

    # Die Seltenheits-Gambling-Kurve bleibt unverändert; nur die Fanglevel wurden
    # auf die neuen festen Abstände -1/-3/-5 angehoben.
    route.stage = 1
    var common_1: float = route._capture_family_weight("rattata", 1)
    var rare_1: float = route._capture_family_weight("bulbasaur", 1)
    var common_2: float = route._capture_family_weight("rattata", 2)
    var rare_2: float = route._capture_family_weight("bulbasaur", 2)
    var common_3: float = route._capture_family_weight("rattata", 3)
    var rare_3: float = route._capture_family_weight("bulbasaur", 3)

    _check_close(rare_1, 45.0, 0.000001, "Suche-1-Gewicht auf Etappe 1")
    _check_close(rare_2, sqrt(45.0), 0.000001, "Suche-2-Gewicht auf Etappe 1")
    _check_close(rare_3, sqrt(sqrt(45.0)), 0.000001, "Suche-3-Gewicht auf Etappe 1")

    var ratio_1: float = common_1 / rare_1
    var ratio_2: float = common_2 / rare_2
    var ratio_3: float = common_3 / rare_3
    _check(ratio_1 > ratio_2 and ratio_2 > ratio_3, "Spätere Suchen müssen den Häufigkeitsvorteil häufig fangbarer Familien schrittweise verkleinern.")
    _check(ratio_3 > 1.0, "Auf Etappe 1 darf auch Suche 3 seltene Familien nicht automatisch wahrscheinlicher als häufige machen.")

    # Im späten Run muss sich das Verhältnis umkehren. Suche 2/3 verstärken
    # diese Verschiebung zusätzlich, ohne Familien zu garantieren.
    route.stage = 90
    var late_ratio_1: float = (
        route._capture_family_weight("rattata", 1)
        / route._capture_family_weight("bulbasaur", 1)
    )
    var late_ratio_2: float = (
        route._capture_family_weight("rattata", 2)
        / route._capture_family_weight("bulbasaur", 2)
    )
    var late_ratio_3: float = (
        route._capture_family_weight("rattata", 3)
        / route._capture_family_weight("bulbasaur", 3)
    )
    _check(late_ratio_1 < 1.0, "Auf Etappe 90 muss Bisasams Familie bereits wahrscheinlicher als Rattfratz' Familie gewichtet sein.")
    _check(late_ratio_1 > late_ratio_2 and late_ratio_2 > late_ratio_3, "Auf Etappe 90 müssen spätere Suchen den Vorteil seltener Familien weiter verstärken.")

    route.stage = 100
    _check_close(
        route._capture_family_weight("rattata", 1),
        1.0 / 191.0,
        0.000001,
        "Rattfratz-Endgewicht auf Etappe 100"
    )
    _check_close(
        route._capture_family_weight("bulbasaur", 1),
        1.0 / 45.0,
        0.000001,
        "Bisasam-Endgewicht auf Etappe 100"
    )

    # A declined family should not immediately be offered again when another
    # valid family is available.
    route._capture_seen_families = ["bulbasaur"]
    var forced_new_root: String = route._weighted_capture_root(["bulbasaur", "charmander"], 2)
    _check(forced_new_root == "charmander", "Weitersuchen muss bereits gezeigte Familien vermeiden, solange Alternativen existieren.")

    route.free()

    # Normale Gegner und Bosse benutzen dieselbe Etappenkurve wie Suche 1.
    var event_route = RouteEventsScript.new()
    event_route._ensure_encounter_family_data()

    event_route.stage = 1
    var early_common_encounter: float = event_route._encounter_species_weight("rattata")
    var early_rare_encounter: float = event_route._encounter_species_weight("bulbasaur")
    _check(
        early_common_encounter > early_rare_encounter,
        "Auf Etappe 1 müssen häufige Familien bei normalen/Boss-Begegnungen klar bevorzugt sein."
    )

    event_route.stage = 100
    var end_common_encounter: float = event_route._encounter_species_weight("rattata")
    var end_rare_encounter: float = event_route._encounter_species_weight("bulbasaur")
    _check(
        end_rare_encounter > end_common_encounter,
        "Auf Etappe 100 müssen seltene Familien bei normalen/Boss-Begegnungen klar bevorzugt sein."
    )

    event_route.free()

    if failures == 0:
        print("Route capture search test: PASS")
        quit(0)
    else:
        push_error("Route capture search test: %d Fehler" % failures)
        quit(1)


func _check_close(actual: float, expected: float, tolerance: float, label: String) -> void:
    _check(absf(actual - expected) <= tolerance, "%s: erwartet %.6f, erhalten %.6f." % [label, expected, actual])


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
