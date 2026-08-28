extends SceneTree

const RouteScript = preload("res://scripts/demo_route_gen3_legendary_endgame_v1.gd")
const BossRules = preload("res://scripts/route_boss_rules.gd")

const DEOXYS_FORMS: Array[String] = [
    "deoxys",
    "deoxys-attack",
    "deoxys-defense",
    "deoxys-speed"
]

var failures: int = 0


class FakeBattleDemo:
    extends Node

    var available_species: Array[String] = []

    func route_species_is_available(species_id: String) -> bool:
        return available_species.has(species_id)


func _initialize() -> void:
    var lower_pool: Array[String] = BossRules.legendary_pool_species_ids("bst_580")
    var expected_lower: Array[String] = [
        "articuno", "zapdos", "moltres",
        "raikou", "entei", "suicune",
        "regirock", "regice", "registeel",
        "latias", "latios", "deoxys"
    ]
    _check(lower_pool.size() == expected_lower.size(), "Untere Legendärenklasse hat eine falsche Größe.")
    for species_id: String in expected_lower:
        _check(lower_pool.has(species_id), "Untere Legendärenklasse fehlt: %s" % species_id)

    for deoxys_form: String in ["deoxys-attack", "deoxys-defense", "deoxys-speed"]:
        _check(
            not lower_pool.has(deoxys_form),
            "Deoxys-Form %s darf kein eigenes Los im Legendärenpool besitzen." % deoxys_form
        )

    var upper_pool: Array[String] = BossRules.legendary_pool_species_ids("bst_680")
    var expected_upper: Array[String] = [
        "mewtwo", "lugia", "ho-oh", "kyogre", "groudon", "rayquaza"
    ]
    _check(upper_pool.size() == expected_upper.size(), "Obere Legendärenklasse hat eine falsche Größe.")
    for species_id: String in expected_upper:
        _check(upper_pool.has(species_id), "Obere Legendärenklasse fehlt: %s" % species_id)

    var gen3_legendary_policy_ids: Array[String] = [
        "regirock", "regice", "registeel", "latias", "latios",
        "kyogre", "groudon", "rayquaza", "jirachi",
        "deoxys", "deoxys-attack", "deoxys-defense", "deoxys-speed"
    ]
    for species_id: String in gen3_legendary_policy_ids:
        _check(
            BossRules.is_legendary_species(species_id),
            "Gen-3-Legendäres muss aus normalen Kampfpools ausgeschlossen sein: %s" % species_id
        )

    var route = RouteScript.new()
    var battle_demo = FakeBattleDemo.new()
    route.battle_demo = battle_demo

    # With exactly one Deoxys form available, the first draw can only select the
    # single top-level Deoxys slot and the second draw must resolve that form.
    # Testing all four forms this way is deterministic and avoids flaky RNG tests.
    for form_id: String in DEOXYS_FORMS:
        battle_demo.available_species = [form_id]
        route._endgame_pool_picks.clear()
        var resolved_form: String = route._pick_available_legendary_pool_species("bst_580", false)
        _check(
            resolved_form == form_id,
            "Deoxys-Zweitziehung löst Form %s nicht korrekt auf." % form_id
        )

    # Uniqueness is recorded against the one pool entry 'deoxys', not against
    # whichever of the four forms the secondary draw returned.
    battle_demo.available_species = DEOXYS_FORMS.duplicate()
    route._endgame_pool_picks.clear()
    var first_pick: String = route._pick_available_legendary_pool_species("bst_580", true)
    _check(DEOXYS_FORMS.has(first_pick), "Deoxys-Hauptlos muss eine der vier Formen auflösen.")

    var used_value: Variant = route._endgame_pool_picks.get("bst_580", [])
    _check(
        used_value is Array and (used_value as Array).has("deoxys"),
        "Deoxys muss für die Einzigartigkeit als ein gemeinsames Hauptlos gespeichert werden."
    )
    _check(
        route._pick_available_legendary_pool_species("bst_580", true).is_empty(),
        "Nach einem Deoxys-Kampf darf keine zweite Deoxys-Form als separates Los folgen."
    )

    route.free()
    battle_demo.free()

    if failures == 0:
        print("Gen-3 legendary endgame regression test: PASS")
        quit(0)
    else:
        push_error("Gen-3 legendary endgame regression test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
