extends SceneTree

const RouteScript = preload("res://scripts/demo_route_boss_reward_two_pick_v1.gd")

var failures: int = 0


func _initialize() -> void:
    _test_exactly_two_successful_picks()
    _test_tm_and_vitamin_offers_are_single_use()
    _test_vitamin_application_consumes_offer()
    _test_healing_item_can_be_used_twice()
    _test_revive_can_be_used_twice()
    _test_boss_reward_state_is_save_safe()

    if failures == 0:
        print("Route boss Fundstelle two-pick test: PASS")
        quit(0)
    else:
        push_error("Route boss Fundstelle two-pick test: %d Fehler" % failures)
        quit(1)


func _test_exactly_two_successful_picks() -> void:
    var route = _make_route()
    route._boss_fundstelle_choices_remaining = route.BOSS_FUNDSTELLE_PICK_COUNT

    _check(route.BOSS_FUNDSTELLE_PICK_COUNT == 2, "Boss-Fundstelle muss genau zwei erfolgreiche Belohnungswahlen erlauben.")
    _check(route._consume_boss_fundstelle_pick("Erste Belohnung"), "Nach der ersten Bossbelohnung muss genau eine weitere Wahl offen bleiben.")
    _check(route._boss_fundstelle_choices_remaining == 1, "Nach Wahl 1 muss der Restzähler 1 sein.")
    _check(not route._consume_boss_fundstelle_pick("Zweite Belohnung"), "Nach der zweiten Bossbelohnung darf keine weitere Wahl offen bleiben.")
    _check(route._boss_fundstelle_choices_remaining == 0, "Nach Wahl 2 muss der Restzähler 0 sein.")
    route.free()


func _test_tm_and_vitamin_offers_are_single_use() -> void:
    var route = _make_route()

    var tm_a: Dictionary = {"number": "RPG:a", "move_id": "move_a", "name": "A"}
    var tm_b: Dictionary = {"number": "RPG:b", "move_id": "move_b", "name": "B"}
    var vitamin: Dictionary = {
        "id": "protein",
        "name": "Protein",
        "stat": "attack",
        "label": "Angriff",
        "emoji": "⚔️"
    }

    route._fundstelle_tm_offers.append(tm_a.duplicate(true))
    route._fundstelle_tm_offers.append(tm_b.duplicate(true))
    route._fundstelle_vitamin_offers.append(vitamin.duplicate(true))
    route._boss_fundstelle_consumed_tm_keys.append(route._fundstelle_tm_offer_key(tm_a))
    route._boss_fundstelle_consumed_vitamin_keys.append(route._fundstelle_vitamin_offer_key(vitamin))

    route._remove_consumed_boss_tm_offers()

    _check(route._fundstelle_tm_offers.size() == 1, "Eine verbrauchte TM muss aus derselben Boss-Fundstelle entfernt werden.")
    _check(str((route._fundstelle_tm_offers[0] as Dictionary).get("move_id", "")) == "move_b", "Eine andere, noch nicht verbrauchte TM muss für Wahl 2 verfügbar bleiben.")
    _check(route._fundstelle_vitamin_offers.is_empty(), "Das einmal genommene Vitamin muss für Wahl 2 vollständig aus dem Angebot verschwinden.")
    route.free()


func _test_vitamin_application_consumes_offer() -> void:
    var route = _make_route()
    var vitamin: Dictionary = {
        "id": "protein",
        "name": "Protein",
        "stat": "attack",
        "label": "Angriff",
        "emoji": "⚔️"
    }

    route.team = [{
        "species_id": "test",
        "name": "Testmon",
        "level": 20,
        "hp": 80,
        "max_hp": 100,
        "vitamin_bonuses": {}
    }]
    route._fundstelle_vitamin_offers.append(vitamin.duplicate(true))
    _arm_boss_fundstelle(route)

    route._apply_vitamin(0, vitamin)

    var member: Dictionary = route.team[0]
    var bonuses: Dictionary = member.get("vitamin_bonuses", {})
    _check(int(bonuses.get("attack", 0)) == 1, "Die erste Vitaminwahl muss den Bonus genau einmal anwenden.")
    _check(route._boss_fundstelle_choices_remaining == 1, "Nach dem Vitamin muss genau eine Bosswahl übrig sein.")
    _check(route._boss_fundstelle_consumed_vitamin_keys.has(route._fundstelle_vitamin_offer_key(vitamin)), "Das verwendete Vitamin muss als verbraucht markiert werden.")
    _check(route._fundstelle_vitamin_offers.is_empty(), "Das verwendete Vitamin darf in Wahl 2 nicht erneut angeboten werden.")
    route.free()


func _test_healing_item_can_be_used_twice() -> void:
    var route = _make_route()
    route.team = [{
        "species_id": "test",
        "name": "Testmon",
        "level": 20,
        "hp": 10,
        "max_hp": 100
    }]
    _arm_boss_fundstelle(route)
    var item: Dictionary = route._healing_item_for_stage(route.stage)

    route._apply_healing_item(0, item)
    _check(route._boss_fundstelle_choices_remaining == 1, "Nach dem ersten Heilitem muss eine zweite Bosswahl offen bleiben.")
    _check(route._fundstelle_active, "Nach dem ersten Heilitem muss dieselbe Fundstelle wieder aktiv sein.")

    route._apply_healing_item(0, item)
    _check(route._boss_fundstelle_choices_remaining == 0, "Dasselbe Heilitem muss als zweite Bossbelohnung erneut benutzt werden dürfen.")
    _check(int((route.team[0] as Dictionary).get("hp", 0)) == 50, "Zwei Tränke auf Etappe 20 müssen 10 KP auf 50 KP anheben.")
    route.free()


func _test_revive_can_be_used_twice() -> void:
    var route = _make_route()
    route.team = [
        {"species_id": "a", "name": "A", "level": 20, "hp": 0, "max_hp": 40},
        {"species_id": "b", "name": "B", "level": 20, "hp": 0, "max_hp": 60}
    ]
    _arm_boss_fundstelle(route)

    route._apply_revive(0)
    _check(route._boss_fundstelle_choices_remaining == 1, "Nach dem ersten Beleber muss eine zweite Bosswahl offen bleiben.")
    _check(int((route.team[0] as Dictionary).get("hp", 0)) == 20, "Der erste Beleber muss Pokémon A mit 50 % KP wiederbeleben.")

    route._apply_revive(1)
    _check(route._boss_fundstelle_choices_remaining == 0, "Der Beleber muss als zweite Bossbelohnung erneut benutzt werden dürfen.")
    _check(int((route.team[1] as Dictionary).get("hp", 0)) == 30, "Der zweite Beleber muss Pokémon B mit 50 % KP wiederbeleben.")
    route.free()


func _test_boss_reward_state_is_save_safe() -> void:
    var route = _make_route()
    route._boss_fundstelle_pending = true
    route._boss_fundstelle_choices_remaining = 1
    route._boss_fundstelle_consumed_tm_keys.append("RPG:a|move_a")
    route._boss_fundstelle_consumed_vitamin_keys.append("protein|attack|Protein")

    var state: Dictionary = RunSaveManager._snapshot_script_state(route)
    _check(int(state.get("_boss_fundstelle_choices_remaining", -1)) == 1, "Der verbleibende Bosswahl-Zähler muss im Spielstand landen.")

    var saved_tms_value: Variant = state.get("_boss_fundstelle_consumed_tm_keys", [])
    var saved_tms: Array = saved_tms_value if saved_tms_value is Array else []
    _check(saved_tms.has("RPG:a|move_a"), "Verbrauchte Boss-TMs müssen im Spielstand erhalten bleiben.")

    var saved_vitamins_value: Variant = state.get("_boss_fundstelle_consumed_vitamin_keys", [])
    var saved_vitamins: Array = saved_vitamins_value if saved_vitamins_value is Array else []
    _check(saved_vitamins.has("protein|attack|Protein"), "Das verbrauchte Boss-Vitamin muss im Spielstand erhalten bleiben.")
    route.free()


func _make_route():
    var route = RouteScript.new()
    route.stage = 20
    route.capture_actions = VBoxContainer.new()
    route.continue_button = Button.new()
    route.event_label = RichTextLabel.new()
    route.add_child(route.capture_actions)
    route.add_child(route.continue_button)
    route.add_child(route.event_label)
    return route


func _arm_boss_fundstelle(route) -> void:
    route._boss_fundstelle_pending = true
    route._fundstelle_active = true
    route._boss_fundstelle_choices_remaining = route.BOSS_FUNDSTELLE_PICK_COUNT
    route._boss_fundstelle_last_reward = ""
    route._boss_fundstelle_final_reward_text = ""
    route._boss_fundstelle_consumed_tm_keys.clear()
    route._boss_fundstelle_consumed_vitamin_keys.clear()
    route.continue_button.visible = false


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
