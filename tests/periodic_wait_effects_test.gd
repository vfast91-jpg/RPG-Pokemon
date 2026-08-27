extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_periodic_wait_fix.gd")


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    assert(is_equal_approx(lab._timeflow_spread_damage_scale(1), 1.0), "Ein Ziel muss 100 % Schaden erhalten.")
    assert(is_equal_approx(lab._timeflow_spread_damage_scale(2), 0.75), "Zwei Ziele müssen je 75 % Schaden erhalten.")
    assert(is_equal_approx(lab._timeflow_spread_damage_scale(3), 0.60), "Drei Ziele müssen je 60 % Schaden erhalten.")
    assert(is_equal_approx(lab._timeflow_spread_damage_scale(4), 0.50), "Vier Ziele müssen je 50 % Schaden erhalten.")
    assert(is_equal_approx(lab._timeflow_spread_damage_scale(7), 0.50), "Bei mehr als vier Zielen darf die Skalierung nicht wieder ansteigen.")

    var hurricane: Dictionary = lab._move_data("hurricane")
    assert(str(hurricane.get("target", "")) == "enemy_highest_aggro", "Orkan muss wieder ein einzelnes gegnerisches Ziel treffen.")
    assert(not bool(hurricane.get("area", true)), "Orkan darf keine Flächenattacke mehr sein.")

    var source: Dictionary = lab._make_combatant("player", 0, {"species_id":"bulbasaur","level":5})
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"bulbasaur","level":5})
    lab.combatants = [source, target]

    source["alive"] = true
    target["alive"] = true
    target["types"] = ["normal"]
    target["max_hp"] = 160
    target["hp"] = 160

    seed(424242)
    var baseline_damage: int = lab._damage(source, target, 80, "normal", "physical")
    lab._timeflow_spread_damage_multiplier = 0.50
    lab._timeflow_spread_damage_target_ids = {str(target.get("id", "")): true}
    seed(424242)
    var spread_damage: int = lab._damage(source, target, 80, "normal", "physical")
    assert(spread_damage == maxi(1, int(round(float(baseline_damage) * 0.50))), "Die globale 50-%-Flächenskalierung muss auf den finalen Schaden angewendet werden.")
    lab._timeflow_spread_damage_multiplier = 1.0
    lab._timeflow_spread_damage_target_ids = {}

    var status_aggro: float = lab._tf_apply_bad_poison(source, target)
    assert(is_equal_approx(status_aggro, 9.0), "Schwere Vergiftung muss für den Wartetest mit Levelbasis anwendbar sein.")
    target["tf_curse_effect"] = {"source_id": str(source.get("id", ""))}

    lab.battle_active = true
    lab.paused = true
    lab.selected_actor = target
    lab._choose_wait()

    assert(int(target.get("hp", 0)) == 110, "Warten muss 1/16 schweres Gift und 1/4 Fluch nach der eigenen Aktion auslösen.")
    assert(int(target.get("tf_bad_poison_stage", 0)) == 2, "Warten muss die Stufe der schweren Vergiftung genau einmal erhöhen.")
    assert(str(target.get("tf_last_move_outcome", "")) == "wait", "Warten muss als eigenes Aktionsergebnis gespeichert bleiben.")

    print("Periodic wait and spread damage tests: PASS")
    lab.queue_free()
    quit(0)
