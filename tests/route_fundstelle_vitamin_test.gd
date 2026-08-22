extends SceneTree

const RouteScript = preload("res://scripts/demo_route_fundstelle_v1.gd")
const BattleScript = preload("res://scripts/battle_demo_route_vitamins_v1.gd")

class FakeBattleDemo:
    extends Node

    func route_stat_snapshot(_species_id: String, level: int) -> Dictionary:
        return {
            "max_hp": 30 + level,
            "attack": 10 + level,
            "defense": 11 + level,
            "special": 12 + level,
            "speed": 13 + level
        }


var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    var fake_battle := FakeBattleDemo.new()
    root.add_child(fake_battle)
    route.battle_demo = fake_battle

    _check(route.VITAMIN_BONUS_PER_USE == 1, "Ein Vitamin muss +1 permanenten Wertpunkt geben.")
    _check(route.VITAMIN_STAT_CAP == 10, "Vitamin-Cap muss +10 pro Attribut und Pokémon sein.")

    var early: Dictionary = route._healing_item_for_stage(1)
    var mid_a: Dictionary = route._healing_item_for_stage(21)
    var mid_b: Dictionary = route._healing_item_for_stage(41)
    var late: Dictionary = route._healing_item_for_stage(61)
    _check(str(early.get("name", "")) == "Trank" and int(early.get("amount", 0)) == 20, "Etappe 1-20 muss Trank +20 KP anbieten.")
    _check(str(mid_a.get("name", "")) == "Supertrank" and int(mid_a.get("amount", 0)) == 50, "Etappe 21-40 muss Supertrank +50 KP anbieten.")
    _check(str(mid_b.get("name", "")) == "Hypertrank" and int(mid_b.get("amount", 0)) == 120, "Etappe 41-60 muss Hypertrank +120 KP anbieten.")
    _check(str(late.get("name", "")) == "Top-Trank" and int(late.get("amount", 0)) < 0, "Ab Etappe 61 muss Top-Trank volle KP herstellen.")

    var member: Dictionary = {
        "species_id": "test",
        "level": 10,
        "hp": 35,
        "max_hp": 40,
        "vitamin_bonuses": {
            "hp": 2,
            "attack": 3,
            "defense": 4,
            "special": 5,
            "speed": 6
        }
    }
    var stats: Dictionary = route._route_member_stats(member)
    _check(int(stats.get("max_hp", 0)) == 42, "Zink-Bonus muss in der Team-Detailansicht auf Max-KP addiert werden.")
    _check(int(stats.get("attack", 0)) == 23, "Protein-Bonus muss in der Team-Detailansicht auf Angriff addiert werden.")
    _check(int(stats.get("defense", 0)) == 25, "Eisen-Bonus muss in der Team-Detailansicht auf Verteidigung addiert werden.")
    _check(int(stats.get("special", 0)) == 27, "Kalzium-Bonus muss in der Team-Detailansicht auf Status addiert werden.")
    _check(int(stats.get("speed", 0)) == 29, "Carbon-Bonus muss in der Team-Detailansicht auf Initiative addiert werden.")

    var malformed: Dictionary = {
        "vitamin_bonuses": {"hp": -5, "attack": 99}
    }
    var normalized: Dictionary = route._vitamin_bonuses_for_member(malformed)
    _check(int(normalized.get("hp", -1)) == 0, "Negative Vitaminboni müssen auf 0 begrenzt werden.")
    _check(int(normalized.get("attack", -1)) == 10, "Vitaminboni über dem Cap müssen auf 10 begrenzt werden.")
    _check(int(normalized.get("defense", -1)) == 0, "Fehlende Vitaminwerte müssen als 0 behandelt werden.")

    # HP-vitamin repair after a level/evolution must keep the amount of damage,
    # not accidentally erase the permanent bonus or fully heal the Pokémon.
    route.team = [{
        "species_id": "test",
        "level": 12,
        "hp": 37,
        "max_hp": 44,
        "vitamin_bonuses": {"hp": 2}
    }]
    route._repair_member_hp_vitamin(0, 7, true)
    var repaired: Dictionary = route.team[0]
    _check(int(repaired.get("max_hp", 0)) == 44, "Lv.12 Basis-Max-KP 42 +2 Zink müssen 44 Max-KP ergeben.")
    _check(int(repaired.get("hp", 0)) == 37, "HP-Reparatur muss 7 bestehende Schadenspunkte erhalten.")

    route.team = [{
        "species_id": "test",
        "level": 12,
        "hp": 0,
        "max_hp": 44,
        "vitamin_bonuses": {"hp": 2}
    }]
    route._repair_member_hp_vitamin(0, 44, false)
    _check(int((route.team[0] as Dictionary).get("hp", -1)) == 0, "Zink darf ein kampfunfähiges Pokémon bei Level-Up/Entwicklung nicht wiederbeleben.")

    # Battle layer: individual bonuses must alter route combatants only through
    # the carried route state; canonical base stats themselves remain untouched.
    var battle = BattleScript.new()
    var combatant: Dictionary = {
        "max_hp": 50,
        "hp": 50,
        "attack": 30,
        "defense": 31,
        "special": 32,
        "speed": 33,
        "alive": true
    }
    var state: Dictionary = {
        "hp": 47,
        "major_status": "",
        "vitamin_bonuses": {
            "hp": 2,
            "attack": 3,
            "defense": 4,
            "special": 5,
            "speed": 6
        }
    }
    battle._route_apply_state(combatant, state)
    _check(int(combatant.get("max_hp", 0)) == 52, "Zink muss im Route-Kampf +2 Max-KP geben.")
    _check(int(combatant.get("hp", 0)) == 47, "Gespeicherte aktuelle KP müssen beim Kampfeintritt erhalten bleiben.")
    _check(int(combatant.get("attack", 0)) == 33, "Protein muss im Route-Kampf Angriff erhöhen.")
    _check(int(combatant.get("defense", 0)) == 35, "Eisen muss im Route-Kampf Verteidigung erhöhen.")
    _check(int(combatant.get("special", 0)) == 37, "Kalzium muss im Route-Kampf Status erhöhen.")
    _check(int(combatant.get("speed", 0)) == 39, "Carbon muss im Route-Kampf Initiative erhöhen.")

    battle.free()
    fake_battle.queue_free()
    route.free()

    if failures == 0:
        print("Route Fundstelle vitamin test: PASS")
        quit(0)
    else:
        push_error("Route Fundstelle vitamin test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
