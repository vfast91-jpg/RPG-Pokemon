extends SceneTree

const SpotlightRules = preload("res://scripts/battle/spotlight_indicator_rules.gd")


func _initialize() -> void:
    var active := {
        "alive": true,
        "db_redirect_expires": 12
    }
    assert(SpotlightRules.is_active(active, 11), "Spotlight muss bis vor seine Ablaufgrenze sichtbar bleiben.")
    assert(not SpotlightRules.is_active(active, 12), "Spotlight muss exakt an seiner Ablaufgrenze verschwinden.")

    var fainted := {
        "alive": false,
        "db_redirect_expires": 99
    }
    assert(not SpotlightRules.is_active(fainted, 1), "K.O.-Pokémon dürfen keinen Spotlight-Marker behalten.")

    var authoritative_expired_with_legacy_counter := {
        "alive": true,
        "db_redirect_expires": 4,
        "effects": {"redirect_actions": 3}
    }
    assert(
        not SpotlightRules.is_active(authoritative_expired_with_legacy_counter, 4),
        "Ein abgelaufenes aktuelles Redirect-Feld darf nicht durch einen alten Kompatibilitätszähler wieder sichtbar werden."
    )

    var compatibility_only := {
        "alive": true,
        "effects": {"redirect_actions": 2}
    }
    assert(SpotlightRules.is_active(compatibility_only, 50), "Der Redirect-Aktionszähler muss als Fallback unterstützt bleiben.")

    var no_spotlight := {"alive": true}
    assert(not SpotlightRules.is_active(no_spotlight, 0), "Ohne Redirect-Effekt darf kein Spotlight-Marker erscheinen.")

    print("Spotlight indicator rules tests: PASS")
    quit(0)
