extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_periodic_wait_fix.gd")


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    var source: Dictionary = lab._make_combatant("player", 0, {"species_id":"bulbasaur","level":5})
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"bulbasaur","level":5})
    lab.combatants = [source, target]

    source["alive"] = true
    target["alive"] = true
    target["types"] = ["normal"]
    target["max_hp"] = 160
    target["hp"] = 160

    var status_aggro: float = lab._tf_apply_bad_poison(source, target)
    assert(is_equal_approx(status_aggro, 20.0), "Schwere Vergiftung muss für den Wartetest erfolgreich anwendbar sein.")
    target["tf_curse_effect"] = {"source_id": str(source.get("id", ""))}

    lab.battle_active = true
    lab.paused = true
    lab.selected_actor = target
    lab._choose_wait()

    assert(int(target.get("hp", 0)) == 110, "Warten muss 1/16 schweres Gift und 1/4 Fluch nach der eigenen Aktion auslösen.")
    assert(int(target.get("tf_bad_poison_stage", 0)) == 2, "Warten muss die Stufe der schweren Vergiftung genau einmal erhöhen.")
    assert(str(target.get("tf_last_move_outcome", "")) == "wait", "Warten muss als eigenes Aktionsergebnis gespeichert bleiben.")

    print("Periodic wait effects test: PASS")
    lab.queue_free()
    quit(0)
