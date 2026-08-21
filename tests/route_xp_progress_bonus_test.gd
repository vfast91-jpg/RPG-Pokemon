extends SceneTree

const RouteScript = preload("res://scripts/demo_route_species_xp.gd")

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    route._load_progression_data()

    # Medium Fast is the neutral route reference.
    _check(route._xp_needed_for_curve("medium_fast", 5) == 91, "Medium Fast Lv.5 -> 6 muss 91 EP benötigen.")
    _check(route._xp_needed_for_curve("medium_fast", 10) == 331, "Medium Fast Lv.10 -> 11 muss 331 EP benötigen.")
    _check(route._xp_needed_for_curve("medium_fast", 20) == 1261, "Medium Fast Lv.20 -> 21 muss 1261 EP benötigen.")

    # Species curves come from the canonical spreadsheet-derived progression map.
    _check(route._growth_curve_for_species("bulbasaur") == "medium_slow", "Bisasam nutzt nicht Medium Slow.")
    _check(route._growth_curve_for_species("charmander") == "medium_slow", "Glumanda nutzt nicht Medium Slow.")
    _check(route._growth_curve_for_species("pikachu") == "medium_fast", "Pikachu nutzt nicht Medium Fast.")
    _check(route._growth_curve_for_species("pichu") == "medium_fast", "Pichu nutzt nicht Medium Fast.")

    _check(
        route._xp_needed_for_member({"species_id": "bulbasaur", "level": 5}) == 44,
        "Bisasams individuelle Lv.5-EP-Anforderung ist falsch."
    )
    _check(
        route._xp_needed_for_member({"species_id": "pikachu", "level": 5}) == 91,
        "Pikachus individuelle Lv.5-EP-Anforderung ist falsch."
    )

    # A normal stage reward is independent of the defeated opponent and tracks
    # the Medium-Fast reference level: Lv.5 on stage 1, Lv.14 on stage 10, etc.
    _check(route._route_stage_xp(1) == 91, "Etappe 1 muss 91 Basis-EP geben.")
    _check(route._route_stage_xp(10) == 631, "Etappe 10 muss 631 Basis-EP geben.")
    _check(route._route_stage_xp(90) == 26791, "Etappe 90 muss 26791 Basis-EP geben.")

    var members: Array = [
        {"species_id": "pikachu", "name": "Pikachu A", "level": 5, "xp": 2, "hp": 20, "max_hp": 20},
        {"species_id": "pikachu", "name": "Pikachu B", "level": 5, "xp": 80, "hp": 20, "max_hp": 20},
        {"species_id": "bulbasaur", "name": "Bisasam", "level": 5, "xp": 10, "hp": 20, "max_hp": 20},
        {"species_id": "pikachu", "name": "Pikachu KO", "level": 5, "xp": 2, "hp": 0, "max_hp": 20}
    ]

    var messages: Array[String] = route._apply_next_level_progress_bonus(members, 0.25)

    # 25% bonuses use each Pokemon's OWN complete next-level requirement.
    # Pikachu: 25% of 91 = 22.75 -> 23. Bisasam: 25% of 44 = 11.
    _check(int((members[0] as Dictionary).get("xp", 0)) == 25, "Pikachu-Bonus aus individueller EP-Kurve ist falsch.")
    _check(int((members[1] as Dictionary).get("xp", 0)) == 103, "Pikachu-Bonus hängt fälschlich vom aktuellen EP-Stand ab.")
    _check(int((members[2] as Dictionary).get("xp", 0)) == 21, "Bisasam-Bonus nutzt nicht Medium Slow.")
    _check(int((members[3] as Dictionary).get("xp", 0)) == 2, "Kampfunfähiges Pokémon erhielt fälschlich Bonus-EP.")
    _check(messages.size() == 3, "Bonus-Zusammenfassung enthält eine falsche Anzahl kampffähiger Pokémon.")

    route.free()

    if failures == 0:
        print("Route species XP curve test: PASS")
        quit(0)
    else:
        push_error("Route species XP curve test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
