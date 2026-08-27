extends SceneTree

const Rules = preload("res://scripts/battle/endure_rules.gd")


func _initialize() -> void:
    var target: Dictionary = {
        "hp": 10,
        "action_serial": 4,
        "db_endure_expires_after_action": 7
    }

    var nonlethal_damage: int = Rules.cap_damage(target, 6)
    assert(nonlethal_damage == 6, "Ausdauer darf nicht-tödlichen Schaden nicht verändern.")
    assert(Rules.is_active(target), "Ausdauer muss nach nicht-tödlichem Schaden weiterlaufen.")

    var rescued_damage: int = Rules.cap_damage(target, 20)
    assert(rescued_damage == 9, "Die erste tödliche Feindattacke muss genau 1 KP übrig lassen.")
    assert(not Rules.is_active(target), "Ausdauer muss nach der ersten Rettung sofort enden.")

    var later_damage: int = Rules.cap_damage(target, 20)
    assert(later_damage == 20, "Nach dem Verbrauch darf Ausdauer keinen weiteren Treffer abfangen.")

    print("Ausdauer-Verbrauchsregel: PASS")
    quit(0)
