extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_miss_recovery.gd")


func _initialize() -> void:
    var battle = BattleScript.new()
    battle._load_data()

    var moves_value: Variant = battle.data.get("moves", {})
    assert(moves_value is Dictionary, "Kampfdaten müssen ein moves-Dictionary enthalten.")
    var move_value: Variant = (moves_value as Dictionary).get("sweet_scent", {})
    assert(move_value is Dictionary, "Lockduft muss in den kanonischen Kampfdaten existieren.")
    var move: Dictionary = move_value

    assert(str(move.get("name", "")) == "Lockduft", "sweet_scent muss als Lockduft angezeigt werden.")
    assert(str(move.get("target", "")) == "all_enemies", "Lockduft muss alle Gegner als Ziel haben.")
    assert(bool(move.get("area", false)), "Lockduft muss als Flächenattacke markiert sein.")

    var mechanics_value: Variant = move.get("mechanics", [])
    assert(mechanics_value is Array and not (mechanics_value as Array).is_empty(), "Lockduft braucht eine Mechanik.")
    var mechanic_value: Variant = (mechanics_value as Array)[0]
    assert(mechanic_value is Dictionary, "Lockdufts Mechanik muss ein Dictionary sein.")
    var mechanic: Dictionary = mechanic_value
    assert(str(mechanic.get("kind", "")) == "db_incoming_accuracy", "Lockduft muss die eingehende Trefferchance verändern.")

    var actor: Dictionary = _combatant("player:0", "player", "Bisaflor", 120.0)
    var enemy_a: Dictionary = _combatant("enemy:0", "enemy", "Turtok A", 80.0)
    var enemy_b: Dictionary = _combatant("enemy:1", "enemy", "Turtok B", 80.0)
    var enemy_c: Dictionary = _combatant("enemy:2", "enemy", "Turtok C", 80.0)

    battle.player_team = [actor]
    battle.enemy_team = [enemy_a, enemy_b, enemy_c]
    battle.combatants = [actor, enemy_a, enemy_b, enemy_c]

    var resolved_targets: Array = battle._targets(actor, str(move.get("target", "")))
    assert(resolved_targets.size() == 3, "Lockduft muss alle drei lebenden Gegner auflösen, nicht nur das Aggro-Ziel.")

    battle._database_active_move = move
    for target_value: Variant in resolved_targets:
        assert(target_value is Dictionary, "Jedes Lockduft-Ziel muss ein Combatant-Dictionary sein.")
        battle._effect(actor, target_value as Dictionary, mechanic)
    battle._database_active_move = {}

    for target: Dictionary in [enemy_a, enemy_b, enemy_c]:
        assert(float(target.get("db_incoming_accuracy_mult", 1.0)) > 1.0, "Jeder Gegner muss durch Lockduft leichter treffbar werden.")
        assert(int(target.get("db_incoming_accuracy_expires", 0)) == 3, "Lockduft muss bei jedem Gegner drei eigene Aktionen halten.")

        var tokens: Array[String] = battle._status_tokens(target)
        var has_readable_token: bool = false
        for token: String in tokens:
            if token.contains("TREFFER") and token.contains("%") and token.contains("Akt."):
                has_readable_token = true
            assert(not token.contains("1A"), "Die alte kryptische 1A-Anzeige darf nicht mehr erscheinen.")
        assert(has_readable_token, "Jeder betroffene Gegner braucht eine verständliche Lockduft-Anzeige auf der Statuskarte.")

        var detail: String = battle._detail_info(target)
        assert(detail.contains("Lockduft:"), "Lockduft muss im i-Detailfenster unter den aktiven Effekten erscheinen.")
        assert(detail.contains("eigene Aktionen"), "Das i-Detailfenster muss die verbleibende Dauer verständlich erklären.")
        assert(not detail.contains("Keine aktiven Veränderungen"), "Ein von Lockduft betroffenes Pokémon darf nicht gleichzeitig 'Keine aktiven Veränderungen' anzeigen.")

    battle.free()
    print("Lockduft regression test: OK")
    quit(0)


func _combatant(id: String, side: String, name: String, special: float) -> Dictionary:
    return {
        "id": id,
        "side": side,
        "name": name,
        "species_id": name.to_lower(),
        "level": 70,
        "alive": true,
        "hp": 190,
        "max_hp": 190,
        "attack": 120,
        "defense": 170,
        "special": special,
        "speed": 110,
        "aggro": 100.0,
        "atb": 0.0,
        "cycle": 1.0,
        "next_cycle": 1.0,
        "attack_mult": 1.0,
        "defense_mult": 1.0,
        "accuracy_mult": 1.0,
        "types": ["water"],
        "moves": [],
        "action_serial": 0,
        "timed_modifiers": [],
        "db_status_immunities": [],
        "db_incoming_accuracy_mult": 1.0,
        "db_incoming_accuracy_expires": 0,
        "db_incoming_accuracy_source": ""
    }
