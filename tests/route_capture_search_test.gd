extends SceneTree

const RouteScript = preload("res://scripts/demo_route_rebalance_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()

    route.team = [
        {"species_id": "a", "level": 18, "hp": 20, "max_hp": 20},
        {"species_id": "b", "level": 15, "hp": 20, "max_hp": 20}
    ]
    route.stage = 40

    _check(route.CAPTURE_SEARCH_MAX == 3, "Eine Fangwiese muss exakt drei Suchen erlauben.")
    _check(route._capture_level_for_stage(40) == 15, "Basis-Fanglevel bei Teammaximum Lv.18 muss Lv.15 sein.")
    _check(route._capture_level_for_search(1) == 15, "Suche 1 muss 100% des Basis-Fanglevels verwenden.")
    _check(route._capture_level_for_search(2) == 11, "Suche 2 muss 75% des Basis-Fanglevels abrunden: 15 -> 11.")
    _check(route._capture_level_for_search(3) == 7, "Suche 3 muss 50% des Basis-Fanglevels abrunden: 15 -> 7.")

    route.team = [{"species_id": "starter", "level": 5, "hp": 20, "max_hp": 20}]
    _check(route._capture_level_for_stage(1) == 2, "Starter Lv.5 muss ein Basis-Fanglevel von Lv.2 erzeugen.")
    _check(route._capture_level_for_search(2) == 1, "Niedrige Fanglevel müssen bei Suche 2 auf mindestens Lv.1 begrenzt werden.")
    _check(route._capture_level_for_search(3) == 1, "Niedrige Fanglevel müssen bei Suche 3 auf mindestens Lv.1 begrenzt werden.")

    route._ensure_encounter_family_data()
    _check(route._family_id_for_species("pikachu") == "pichu", "Pikachu muss zur Pichu-Familie gehören.")
    _check_close(route._family_catch_rate("bulbasaur"), 45.0, 0.000001, "Bisasam-Familien-Fangrate")
    _check_close(route._family_catch_rate("rattata"), 191.0, 0.000001, "Rattfratz-Familien-Fangrate")

    var common_1: float = route._capture_family_weight("rattata", 1)
    var rare_1: float = route._capture_family_weight("bulbasaur", 1)
    var common_2: float = route._capture_family_weight("rattata", 2)
    var rare_2: float = route._capture_family_weight("bulbasaur", 2)
    var common_3: float = route._capture_family_weight("rattata", 3)
    var rare_3: float = route._capture_family_weight("bulbasaur", 3)

    _check_close(rare_1, 45.0, 0.000001, "Suche-1-Gewicht")
    _check_close(rare_2, sqrt(45.0), 0.000001, "Suche-2-Gewicht")
    _check_close(rare_3, sqrt(sqrt(45.0)), 0.000001, "Suche-3-Gewicht")

    var ratio_1: float = common_1 / rare_1
    var ratio_2: float = common_2 / rare_2
    var ratio_3: float = common_3 / rare_3
    _check(ratio_1 > ratio_2 and ratio_2 > ratio_3, "Spätere Suchen müssen den Häufigkeitsvorteil häufig fangbarer Familien schrittweise verkleinern.")
    _check(ratio_3 > 1.0, "Auch Suche 3 darf seltene Familien nicht automatisch wahrscheinlicher als häufige machen.")

    # A declined family should not immediately be offered again when another
    # valid family is available.
    route._capture_seen_families = ["bulbasaur"]
    var forced_new_root: String = route._weighted_capture_root(["bulbasaur", "charmander"], 2)
    _check(forced_new_root == "charmander", "Weitersuchen muss bereits gezeigte Familien vermeiden, solange Alternativen existieren.")

    route.free()

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
