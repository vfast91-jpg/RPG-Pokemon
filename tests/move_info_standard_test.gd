extends SceneTree

const CombatLabScript = preload("res://scripts/battle_demo_move_info_standard_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = CombatLabScript.new()

    var confuse_ray := {
        "id": "confuse_ray",
        "name": "Konfusstrahl",
        "type": "ghost",
        "category": "status",
        "power": null,
        "accuracy": 100,
        "ap": 7,
        "target": "enemy_highest_aggro",
        "area": false,
        "priority": 0,
        "opening": false,
        "mechanics": [
            {"kind": "status", "status": "confusion", "chance": 1.0}
        ]
    }
    var confuse_text: String = lab._standardized_move_info_text(confuse_ray)
    _check(
        confuse_text.contains("Konfusstrahl")
        and confuse_text.contains("Geist")
        and confuse_text.contains("Status")
        and confuse_text.contains("AP 7")
        and confuse_text.contains("Ladezeit 160 % länger"),
        "Konfusstrahl folgt nicht dem standardisierten Kopf mit Typ/Kategorie/AP/Zeitkosten."
    )
    _check(
        confuse_text.contains("Ziel: höchste Aggro")
        and confuse_text.contains("Genauigkeit: 100 %"),
        "Konfusstrahl zeigt Ziel und Genauigkeit nicht im Standardformat."
    )
    _check(
        confuse_text.contains("Wirkung: Verursacht garantiert Verwirrung"),
        "Garantierte Verwirrung wird nicht eindeutig als garantiert beschrieben."
    )
    _check(
        not confuse_text.contains("Stärke:"),
        "Eine reine Statusattacke darf keine erfundene Schadensstärke anzeigen."
    )

    var poison_hit := {
        "id": "poison_test",
        "name": "Gifttest",
        "type": "poison",
        "category": "physical",
        "power": 50,
        "accuracy": 90,
        "ap": 4,
        "target": "enemy_highest_aggro",
        "mechanics": [
            {"kind": "damage"},
            {"kind": "status", "status": "poison", "chance": 0.30}
        ]
    }
    var poison_text: String = lab._standardized_move_info_text(poison_hit)
    _check(
        poison_text.contains("Stärke: 50")
        and poison_text.contains("Genauigkeit: 90 %")
        and poison_text.contains("30 % Chance auf Vergiftung"),
        "Schaden plus prozentualer Zusatzeffekt folgt nicht dem Standardformat."
    )

    var special_move := {
        "id": "rage_powder",
        "name": "Wutpulver",
        "type": "bug",
        "category": "status",
        "power": null,
        "accuracy": null,
        "ap": 5,
        "target": "self",
        "mechanics": [
            {"kind": "db_redirect", "duration_actions": 3}
        ]
    }
    var special_text: String = lab._standardized_move_info_text(special_move)
    _check(
        special_text.contains("Aggro-Zielregel")
        and special_text.contains("Flächenattacken nicht")
        and special_text.contains("endet bei K.O."),
        "Ein Sonderfall wurde vom Standard verschluckt statt vollständig erhalten."
    )
    _check(
        special_text.contains("Genauigkeit: sicher")
        and not special_text.to_lower().contains("db_redirect")
        and not special_text.to_lower().contains("db redirect"),
        "Sonderfälle zeigen noch technische Begriffe oder kein klares Genauigkeitsformat."
    )

    lab.selected_actor = {"accuracy_mult": 0.8, "timed_modifiers": []}
    var accuracy_move: Dictionary = poison_hit.duplicate(true)
    accuracy_move["accuracy"] = 75
    var modified_accuracy_text: String = lab._standardized_move_info_text(accuracy_move)
    _check(
        modified_accuracy_text.contains("Genauigkeit: 60 %"),
        "Aktive Genauigkeitsänderungen werden in der standardisierten Box nicht berücksichtigt."
    )

    lab.free()

    if failures == 0:
        print("Move info standard test: PASS")
        quit(0)
    else:
        push_error("Move info standard test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
