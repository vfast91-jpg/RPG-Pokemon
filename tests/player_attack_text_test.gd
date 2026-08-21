extends SceneTree

const AttackTextScript = preload("res://scripts/battle_demo_attack_text_final.gd")
const CurrentBattleScript = preload("res://scripts/battle_demo_player_effect_labels.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = AttackTextScript.new()

    _check_equal(
        lab._final_attack_text("eingehender Schaden ×1.25"),
        "Verteidigung −20%",
        "Eingehender Schadensmultiplikator wird nicht als Verteidigungsprozent angezeigt."
    )
    _check_equal(
        lab._final_attack_text("eingehender Schaden ×1,25"),
        "Verteidigung −20%",
        "Dezimal-Komma beim Verteidigungstext wird nicht korrekt umgerechnet."
    )
    _check_equal(
        lab._final_attack_text("Gesamt Angriff: ×1.44"),
        "Gesamt Angriff: +44%",
        "Gestapelter Angriff wird noch als Multiplikator angezeigt."
    )
    _check_equal(
        lab._final_attack_text("Gesamt Verteidigung: ×0.80"),
        "Gesamt Verteidigung: −20%",
        "Gestapelte Verteidigung wird noch als Multiplikator angezeigt."
    )
    _check_equal(
        lab._final_attack_text("Ladezeit der Aktionsleiste ×2,10"),
        "Ladezeit der Aktionsleiste +110%",
        "Aktionsleisten-Ladezeit wird noch als Multiplikator angezeigt."
    )
    _check_equal(
        lab._final_attack_text("Ladezeit der Aktionsleiste ×0,90"),
        "Ladezeit der Aktionsleiste −10%",
        "Verkürzte Aktionsleisten-Ladezeit wird nicht als Prozentwert angezeigt."
    )
    _check_equal(
        lab._modifier_detail_text("incoming_damage_mod", 0.80),
        "Verteidigung −20%",
        "Einzelner Verteidigungs-Debuff verwendet nicht den Attribut-Prozenttext."
    )
    _check_equal(
        lab._modifier_detail_text("outgoing_damage_mod", 1.25),
        "Angriff +25%",
        "Einzelner Angriffs-Buff verwendet nicht den Attribut-Prozenttext."
    )

    lab.free()

    var current_lab = CurrentBattleScript.new()
    _check_equal(
        current_lab._compact_effect_summary({
            "id": "petal_dance",
            "name": "Blättertanz",
            "mechanics": [{"kind": "damage"}],
            "runtime": {
                "forced_sequence": {"min": 2, "max": 3, "confuse_after": true}
            }
        }),
        "direkter Schaden · 2–3 eigene Aktionen: Attacke wird automatisch fortgesetzt · danach Verwirrung",
        "Blättertanz erklärt die erzwungene 2–3-Aktionen-Sequenz nicht in der Attackeninfo."
    )

    _check_equal(
        current_lab._target_name("enemy_field"),
        "gegnerische Feldseite",
        "Das Datenbank-Ziel enemy_field wird noch technisch/englisch angezeigt."
    )

    var toxic_spikes_summary: String = current_lab._compact_effect_summary({
        "id": "toxic_spikes",
        "name": "Giftspitzen",
        "mechanics": [{"kind": "db_toxic_spikes", "max_layers": 2}]
    })
    _check(
        toxic_spikes_summary.contains("Giftspitzen: 1 Lage pro Einsatz (max. 2)"),
        "Giftspitzen erklärt die Feldgefahr nicht in Spielersprache."
    )
    _check(
        not toxic_spikes_summary.to_lower().contains("db toxic spikes")
        and not toxic_spikes_summary.to_lower().contains("db_toxic_spikes"),
        "Giftspitzen zeigt noch den internen Mechaniknamen an."
    )

    var focus_summary: String = current_lab._compact_effect_summary({
        "id": "laser_focus",
        "name": "Konzentration",
        "mechanics": [{"kind": "db_guaranteed_crit"}]
    })
    _check(
        focus_summary.contains("Volltreffer garantiert"),
        "Konzentration erklärt den garantierten Volltreffer nicht."
    )
    _check(
        not focus_summary.to_lower().contains("db guaranteed crit")
        and not focus_summary.to_lower().contains("db_guaranteed_crit"),
        "Konzentration zeigt noch den internen Mechaniknamen an."
    )

    var endeavor_summary: String = current_lab._compact_effect_summary({
        "id": "endeavor",
        "name": "Notsituation",
        "type": "normal",
        "target": "enemy_highest_aggro",
        "mechanics": [{"kind": "db_equalize_hp"}]
    })
    _check(
        endeavor_summary.contains("Schaden: positive KP-Differenz (Ziel-KP − eigene KP)"),
        "Notsituation erklärt den variablen KP-Schaden nicht."
    )
    _check(
        not endeavor_summary.to_lower().contains("db equalize hp")
        and not endeavor_summary.to_lower().contains("db_equalize_hp"),
        "Notsituation zeigt noch den internen Mechaniknamen an."
    )

    var feint_summary: String = current_lab._compact_effect_summary({
        "id": "feint",
        "mechanics": [{"kind": "damage"}, {"kind": "db_break_protect"}]
    })
    _check(
        feint_summary.contains("Schutzschild") and feint_summary.contains("trifft trotzdem"),
        "Offenlegung erklärt Schutzschildbruch und anschließenden Treffer nicht vollständig."
    )

    var safeguard_summary: String = current_lab._compact_effect_summary({
        "id": "safeguard",
        "mechanics": [{"kind": "db_team_immunity", "duration_actions": 3}]
    })
    _check(
        safeguard_summary.contains("3 eigene Aktionen")
        and safeguard_summary.contains("neuen Hauptstatuszuständen")
        and safeguard_summary.contains("vorhandene Status bleiben")
        and safeguard_summary.contains("Reserve nicht betroffen"),
        "Bodyguard erklärt Dauer, Schutzumfang und Grenzen nicht vollständig."
    )

    var rage_powder_summary: String = current_lab._compact_effect_summary({
        "id": "rage_powder",
        "mechanics": [{"kind": "db_redirect", "duration_actions": 3}]
    })
    _check(
        rage_powder_summary.contains("Einzelzielattacken")
        and rage_powder_summary.contains("Aggro-Zielregel")
        and rage_powder_summary.contains("Flächenattacken nicht")
        and rage_powder_summary.contains("endet bei K.O."),
        "Wutpulver erklärt Umlenkung, Aggro-Ausnahme, Flächen-Ausnahme und Ende nicht vollständig."
    )

    var bug_bite_summary: String = current_lab._compact_effect_summary({
        "id": "bug_bite",
        "power": 60,
        "mechanics": [{"kind": "damage"}, {"kind": "db_berry_interaction"}]
    })
    _check(
        bug_bite_summary.contains("Beereninteraktion ist noch nicht aktiv")
        and bug_bite_summary.contains("Itemsystem fehlt")
        and bug_bite_summary.contains("Stärke-60-Schadensattacke"),
        "Käferbiss verschweigt den aktuell noch nicht aktiven Beeren-Effekt."
    )

    for summary: String in [feint_summary, safeguard_summary, rage_powder_summary, bug_bite_summary]:
        _check(
            not summary.to_lower().contains("db_")
            and not summary.to_lower().contains("db "),
            "Eine der geprüften Attacken zeigt weiterhin interne db-Bezeichner an."
        )

    current_lab.free()

    if failures == 0:
        print("Player attack text test: PASS")
        quit(0)
    else:
        push_error("Player attack text test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)


func _check_equal(actual: String, expected: String, message: String) -> void:
    if actual == expected:
        return
    failures += 1
    push_error(message + " Erwartet: '%s', erhalten: '%s'" % [expected, actual])
