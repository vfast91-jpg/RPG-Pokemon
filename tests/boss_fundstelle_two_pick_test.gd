extends SceneTree

const RouteScript = preload("res://scripts/demo_route_boss_reward_two_pick_v1.gd")


func _initialize() -> void:
    # Run after SceneTree has entered its event loop. The assertions themselves
    # previously passed, but quit(0) from _initialize() could leave this very
    # large inherited route script waiting during engine teardown until CI hit
    # its five-minute timeout.
    call_deferred("_run_tests")


func _run_tests() -> void:
    var route = RouteScript.new()

    route.set("_boss_fundstelle_pending", true)
    route.set("_fundstelle_active", true)
    route.set("_boss_fundstelle_choices_remaining", 2)

    assert(
        bool(route.call("_boss_double_reward_is_active")),
        "Boss-Fundstelle muss mit zwei offenen Auswahlen als aktiv gelten."
    )

    var has_second_pick: bool = bool(route.call("_consume_boss_fundstelle_pick", "🧪 Supertrank"))
    assert(has_second_pick, "Nach der ersten Bossbelohnung muss genau eine zweite Auswahl offen bleiben.")
    assert(
        int(route.get("_boss_fundstelle_choices_remaining")) == 1,
        "Der Boss-Fundstellenzaehler muss nach Auswahl 1 von 2 auf 1 stehen."
    )
    assert(
        str(route.get("_boss_fundstelle_last_reward")) == "🧪 Supertrank",
        "Die erste gewaehlte Bossbelohnung muss fuer die UI erhalten bleiben."
    )

    var has_third_pick: bool = bool(route.call("_consume_boss_fundstelle_pick", "✨ Beleber"))
    assert(not has_third_pick, "Nach der zweiten Bossbelohnung darf keine dritte Auswahl offen bleiben.")
    assert(
        int(route.get("_boss_fundstelle_choices_remaining")) == 0,
        "Der Boss-Fundstellenzaehler muss nach Auswahl 2 auf 0 stehen."
    )

    route.set("_boss_fundstelle_choices_remaining", 1)
    route.set("_fundstelle_tm_offers", [
        {"number": "024", "move_id": "thunderbolt", "name": "Donnerblitz"},
        {"number": "006", "move_id": "toxic", "name": "Toxin"},
        {"number": "044", "move_id": "rest", "name": "Erholung"}
    ])
    route.set("_boss_fundstelle_consumed_tm_keys", ["024|thunderbolt"])
    route.call("_remove_consumed_boss_tm_offers")

    var remaining_offers_value: Variant = route.get("_fundstelle_tm_offers")
    assert(remaining_offers_value is Array, "TM-Angebote muessen als Array erhalten bleiben.")
    var remaining_offers: Array = remaining_offers_value as Array
    assert(remaining_offers.size() == 2, "Eine vergebene TM muss exakt einen der drei TM-Slots verbrauchen.")

    for offer_value: Variant in remaining_offers:
        assert(offer_value is Dictionary, "Verbleibende TM-Angebote muessen Dictionaries bleiben.")
        var offer: Dictionary = offer_value as Dictionary
        assert(
            str(route.call("_fundstelle_tm_offer_key", offer)) != "024|thunderbolt",
            "Die bereits vergebene TM darf fuer Auswahl 2 nicht erneut angeboten werden."
        )

    assert(
        str(route.call("_fundstelle_tm_offer_key", remaining_offers[0] as Dictionary))
        != str(route.call("_fundstelle_tm_offer_key", remaining_offers[1] as Dictionary)),
        "Die beiden verbleibenden TM-Angebote muessen ihre eigene Identitaet behalten."
    )

    route.free()
    print("Boss Fundstelle two-pick tests: OK")
    quit(0)
