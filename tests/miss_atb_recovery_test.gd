extends SceneTree

const CombatLabScript = preload("res://scripts/battle_demo_miss_recovery.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = CombatLabScript.new()
    root.add_child(lab)

    var moves_value: Variant = lab.data.get("moves", {})
    _check(moves_value is Dictionary, "Move-Dictionary fehlt im Kampflabor.")
    if not (moves_value is Dictionary):
        _finish(lab)
        return

    var move_id: String = "miss_recovery_regression"
    (moves_value as Dictionary)[move_id] = {
        "id": move_id,
        "name": "Fehlschlagtest",
        "type": "normal",
        "category": "physical",
        "power": 40,
        "accuracy": -1,
        "ap": 8,
        "target": "enemy_highest_aggro",
        "area": false,
        "priority": 0,
        "opening": false,
        "mechanics": [{"kind": "damage"}]
    }

    var actor: Dictionary = lab._make_combatant(
        "player",
        0,
        {"species_id": "pichu", "level": 5}
    )
    actor["next_cycle"] = 1.2
    actor["accuracy_mult"] = 1.0
    actor["confused_turns"] = 0
    actor["alive"] = true

    var normal_cycle: float = lab._ap_cycle(8) * 1.2
    var expected_miss_cycle: float = normal_cycle * 0.75

    lab._execute_move(actor, move_id)

    _check(
        is_equal_approx(float(actor.get("cycle", -1.0)), expected_miss_cycle),
        "Fehlschlag muss die ATB-Erholung auf exakt 75% der normalen AP-Erholung verkürzen."
    )
    _check(
        is_equal_approx(float(actor.get("next_cycle", -1.0)), 1.0),
        "Der gespeicherte next_cycle-Modifikator muss nach der Aktion wie üblich verbraucht sein."
    )
    _check(
        is_equal_approx(float(actor.get("atb", -1.0)), 0.0),
        "Nach einem Fehlschlag muss die ATB-Leiste wie nach einer normalen Aktion bei 0 starten."
    )
    _check(
        lab.log_label != null and lab.log_label.text.contains("verfehlt"),
        "Der Fehlschlag muss weiterhin im Kampftext sichtbar sein."
    )

    _finish(lab)


func _finish(lab: Node) -> void:
    lab.queue_free()
    if failures == 0:
        print("Miss ATB recovery test: PASS")
        quit(0)
    else:
        push_error("Miss ATB recovery test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
