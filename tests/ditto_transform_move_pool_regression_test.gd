extends SceneTree

const ActiveBattle = preload("res://scripts/battle_demo_ditto_move_pool_guard_v1.gd")


func _initialize() -> void:
    var battle = ActiveBattle.new()

    _assert_stale_original_pool_is_repaired(battle)
    _assert_empty_pool_is_repaired(battle)
    _assert_valid_transformed_pool_is_preserved(battle)
    _assert_untransformed_ditto_is_untouched(battle)

    battle.free()
    print("Ditto Transform move-pool regression test: PASS")
    quit(0)


func _assert_stale_original_pool_is_repaired(battle) -> void:
    var target: Dictionary = {
        "id": "player_0",
        "side": "player",
        "alive": true,
        "moves": ["tackle", "growl", "quick_attack"],
    }
    var ditto: Dictionary = {
        "id": "enemy_0",
        "side": "enemy",
        "alive": true,
        "species_id": "ditto",
        "f64_transformed": true,
        "f64_transform_target_id": "player_0",
        "f64_transform_original_moves": ["transform"],
        "moves": ["transform"],
    }
    battle.combatants = [ditto, target]

    assert(
        battle._ditto_repair_transformed_move_pool(ditto),
        "Ein verwandeltes Ditto muss repariert werden, wenn sein Move-Pool wieder auf Wandler zurueckfaellt."
    )
    assert(
        ditto.get("moves", []) == target.get("moves", []),
        "Nach der Reparatur muss Ditto den kompletten aktuellen Ziel-Move-Pool besitzen."
    )
    assert(
        target.get("moves", []) == ["tackle", "growl", "quick_attack"],
        "Die Reparatur darf den Move-Pool des Ziel-Pokemon nicht veraendern."
    )


func _assert_empty_pool_is_repaired(battle) -> void:
    var target: Dictionary = {
        "id": "player_1",
        "side": "player",
        "alive": true,
        "moves": ["water_gun", "withdraw"],
    }
    var ditto: Dictionary = {
        "id": "enemy_1",
        "side": "enemy",
        "alive": true,
        "species_id": "ditto",
        "f64_transformed": true,
        "f64_transform_target_id": "player_1",
        "f64_transform_original_moves": ["transform"],
        "moves": [],
    }
    battle.combatants = [ditto, target]

    assert(
        battle._ditto_repair_transformed_move_pool(ditto),
        "Ein durch Wandler geleerter Move-Pool muss ebenfalls repariert werden."
    )
    assert(
        ditto.get("moves", []) == ["water_gun", "withdraw"],
        "Ein leerer verwandelter Move-Pool muss aus dem Ziel wiederhergestellt werden."
    )


func _assert_valid_transformed_pool_is_preserved(battle) -> void:
    var target: Dictionary = {
        "id": "player_2",
        "side": "player",
        "alive": true,
        "moves": ["ember", "smokescreen"],
    }
    var ditto: Dictionary = {
        "id": "enemy_2",
        "side": "enemy",
        "alive": true,
        "species_id": "ditto",
        "f64_transformed": true,
        "f64_transform_target_id": "player_2",
        "f64_transform_original_moves": ["transform"],
        "moves": ["ember", "mimic"],
    }
    battle.combatants = [ditto, target]

    assert(
        not battle._ditto_repair_transformed_move_pool(ditto),
        "Ein bereits gueltiger kampflokaler Transform-Move-Pool darf nicht zwangsweise ueberschrieben werden."
    )
    assert(
        ditto.get("moves", []) == ["ember", "mimic"],
        "Legitime spaetere kampflokale Move-Aenderungen muessen erhalten bleiben."
    )


func _assert_untransformed_ditto_is_untouched(battle) -> void:
    var target: Dictionary = {
        "id": "player_3",
        "side": "player",
        "alive": true,
        "moves": ["vine_whip", "growth"],
    }
    var ditto: Dictionary = {
        "id": "enemy_3",
        "side": "enemy",
        "alive": true,
        "species_id": "ditto",
        "f64_transformed": false,
        "f64_transform_target_id": "player_3",
        "f64_transform_original_moves": ["transform"],
        "moves": ["transform"],
    }
    battle.combatants = [ditto, target]

    assert(
        not battle._ditto_repair_transformed_move_pool(ditto),
        "Ein noch nicht verwandeltes Ditto darf niemals durch den Guard veraendert werden."
    )
    assert(
        ditto.get("moves", []) == ["transform"],
        "Vor Wandler muss Ditto weiterhin nur seinen echten Move-Pool besitzen."
    )
