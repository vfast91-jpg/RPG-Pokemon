extends SceneTree

const CombatLabScript = preload("res://scripts/battle_demo_adaptive_family_ui.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = CombatLabScript.new()
    root.add_child(lab)

    var move := {
        "id": "preview_accuracy_test",
        "name": "Testattacke",
        "type": "normal",
        "category": "physical",
        "power": 40,
        "accuracy": 75,
        "ap": 2,
        "target": "enemy_highest_aggro",
        "mechanics": []
    }

    lab.selected_actor = {"accuracy_mult": 1.0}
    lab._preview_move("preview_accuracy_test", move, false)
    _check(
        lab.log_label != null and lab.log_label.text.contains("Genauigkeit: 75%"),
        "Attackenvorschau zeigt die Genauigkeit 75% nicht an."
    )

    lab.selected_actor = {"accuracy_mult": 0.8}
    lab._preview_move("preview_accuracy_test", move, false)
    _check(
        lab.log_label != null and lab.log_label.text.contains("Genauigkeit: 60%"),
        "Attackenvorschau berücksichtigt den aktiven Genauigkeitsmodifikator nicht."
    )

    var always_hit_move: Dictionary = move.duplicate(true)
    always_hit_move["accuracy"] = null
    lab.selected_actor = {"accuracy_mult": 0.5}
    lab._preview_move("preview_accuracy_test", always_hit_move, false)
    _check(
        lab.log_label != null and lab.log_label.text.contains("Genauigkeit: sicher"),
        "Attacken ohne Genauigkeitswurf werden nicht als sicher angezeigt."
    )

    lab.queue_free()

    if failures == 0:
        print("Move preview accuracy test: PASS")
        quit(0)
    else:
        push_error("Move preview accuracy test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
