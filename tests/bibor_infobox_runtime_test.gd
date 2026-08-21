extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_player_effect_labels.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = BattleScript.new()

    _expect_contains_all(
        lab._compact_effect_summary({
            "id":"fury_attack", "power":15,
            "mechanics":[{"kind":"damage"}],
            "runtime":{"multi_hit":{"min":2,"max":5,"weights":[3,3,1,1]}}
        }),
        ["2–5 Treffer", "Stärke 15 je Treffer", "37,5%", "Genauigkeit einmal", "Volltrefferwurf"],
        "Furienschlag"
    )
    _expect_contains_all(
        lab._compact_effect_summary({
            "id":"pin_missile", "power":25,
            "mechanics":[{"kind":"damage"}],
            "runtime":{"multi_hit":{"min":2,"max":5,"weights":[3,3,1,1]}}
        }),
        ["2–5 Treffer", "Stärke 25 je Treffer", "37,5%", "Genauigkeit einmal", "Volltrefferwurf"],
        "Nadelrakete"
    )
    _expect_contains_all(
        lab._compact_effect_summary({
            "id":"string_shot",
            "mechanics":[{"kind":"atb_cycle_mod","multiplier_from_special":2.0,"duration":"3_actions"}]
        }),
        ["Geschwindigkeit", "alle Gegner", "3 eigene Aktionen", "Genauigkeit pro Ziel separat"],
        "Fadenschuss"
    )
    _expect_contains_all(
        lab._compact_effect_summary({"id":"focus_energy","mechanics":[{"kind":"critical_focus"}]}),
        ["Volltrefferchance", "Statuswert", "Wechsel/Kampfende", "nicht stapelbar"],
        "Energiefokus"
    )
    _expect_contains_all(
        lab._compact_effect_summary({"id":"assurance","mechanics":[{"kind":"damage"}]}),
        ["Stärke 120", "seit seiner letzten eigenen Aktion KP verloren", "Stärke 60"],
        "Gewissheit"
    )
    _expect_contains_all(
        lab._compact_effect_summary({
            "id":"harden",
            "mechanics":[{"kind":"incoming_damage_mod","multiplier_from_special":-1.0,"duration":"3_actions"}]
        }),
        ["Verteidigung", "3 eigene Aktionen"],
        "Härtner"
    )
    _expect_contains_all(
        lab._compact_effect_summary({
            "id":"fury_cutter", "mechanics":[{"kind":"damage"}],
            "runtime":{"consecutive_power_chain":[40,80,160]}
        }),
        ["40 → 80 → 160", "Ziel darf wechseln", "Reset", "Warten"],
        "Zornklinge"
    )
    _expect_contains_all(
        lab._compact_effect_summary({"id":"laser_focus","mechanics":[{"kind":"db_guaranteed_crit"}]}),
        ["Volltreffer garantiert", "Mehrfachtreffern alle Treffer kritisch", "Statusattacke", "Miss", "Fehlschlag", "nicht stapelbar"],
        "Konzentration"
    )
    _expect_contains_all(
        lab._compact_effect_summary({"id":"venoshock","mechanics":[{"kind":"damage"}]}),
        ["Stärke 130", "vergiftete oder schwer vergiftete", "Stärke 65"],
        "Giftschock"
    )
    _expect_contains_all(
        lab._compact_effect_summary({"id":"toxic_spikes","mechanics":[{"kind":"db_toxic_spikes","max_layers":2}]}),
        ["1 Lage: Vergiftung", "2 Lagen: schwere Vergiftung", "geerdeter Gegner", "physische Kontaktattacke", "Gift/Stahl immun", "Turbodreher"],
        "Giftspitzen"
    )
    _expect_contains_all(
        lab._compact_effect_summary({
            "id":"agility",
            "mechanics":[{"kind":"atb_cycle_mod","multiplier_from_special":-2.0,"duration":"3_actions"}]
        }),
        ["Geschwindigkeit", "3 eigene Aktionen"],
        "Agilität"
    )
    _expect_contains_all(
        lab._compact_effect_summary({
            "id":"endeavor", "type":"normal", "target":"enemy_highest_aggro",
            "mechanics":[{"kind":"db_equalize_hp"}]
        }),
        ["positive KP-Differenz", "ignoriert Angriff und Verteidigung", "kein Volltreffer", "Schutz", "Typ-Immunität"],
        "Notsituation"
    )
    _expect_contains_all(
        lab._compact_effect_summary({
            "id":"fell_stinger",
            "mechanics":[
                {"kind":"damage"},
                {"kind":"db_on_ko_modifier","modifier_kind":"outgoing_damage_mod","multiplier_from_special":3.0}
            ]
        }),
        ["nur bei K.O. durch diese Attacke", "Angriff", "3 eigene Aktionen", "indirekter K.O."],
        "Stachelfinale"
    )
    _expect_contains_all(
        lab._compact_effect_summary({"id":"poison_jab","mechanics":[{"kind":"damage"},{"kind":"status","status":"poison","chance":0.3}]}),
        ["30 % Chance auf Vergiftung"],
        "Gifthieb"
    )

    # Notsituation should show the concrete damage in the live preview when a
    # single current target exists, not just a generic mechanic description.
    lab.selected_actor = {
        "id":"player_bibor", "side":"player", "hp":40, "alive":true,
        "types":["bug","poison"], "special":100, "aggro":10.0
    }
    lab.enemy_team = [{
        "id":"enemy_target", "side":"enemy", "hp":100, "alive":true,
        "types":["normal"], "aggro":20.0
    }]
    var endeavor_live: String = lab._compact_effect_summary({
        "id":"endeavor", "type":"normal", "target":"enemy_highest_aggro",
        "mechanics":[{"kind":"db_equalize_hp"}]
    })
    _check(endeavor_live.contains("60 KP"), "Notsituation zeigt den aktuellen Schaden 60 KP nicht an.")

    # Giftspitzen behavior regression: one layer poisons, two layers badly poison.
    lab.selected_actor = {}
    var source: Dictionary = {
        "id":"source_bibor", "side":"player", "alive":true,
        "types":["bug","poison"], "major_status":"", "paralyzed":false,
        "aggro":0.0, "tf_states":{}
    }
    var target: Dictionary = {
        "id":"enemy_contact", "side":"enemy", "alive":true,
        "types":["normal"], "major_status":"", "paralyzed":false,
        "aggro":0.0, "tf_states":{}, "db_status_immunities":[]
    }
    lab.combatants = [source, target]
    lab._effect(source, source, {"kind":"db_toxic_spikes","max_layers":2})
    lab._database_trigger_toxic_spikes_if_defined(target, {"category":"physical","contact":true}, true)
    _check(str(target.get("major_status", "")) == "poison", "Eine Lage Giftspitzen verursacht keine Vergiftung.")

    target["major_status"] = ""
    target["tf_bad_poison_stage"] = 0
    lab._effect(source, source, {"kind":"db_toxic_spikes","max_layers":2})
    lab._database_trigger_toxic_spikes_if_defined(target, {"category":"physical","contact":true}, true)
    _check(str(target.get("major_status", "")) == "bad_poison", "Zwei Lagen Giftspitzen verursachen keine schwere Vergiftung.")
    _check(int(target.get("tf_bad_poison_stage", 0)) == 1, "Schwere Vergiftung durch Giftspitzen startet nicht auf Stufe 1.")

    lab._effect(source, source, {"kind":"db_clear_allied_hazards"})
    _check(int(lab.get_meta("db_toxic_spikes_player", 0)) == 0, "Turbodreher/Feldreinigung entfernt eigene Giftspitzen nicht.")

    lab.free()

    if failures == 0:
        print("Bibor infobox/runtime test: PASS")
        quit(0)
    else:
        push_error("Bibor infobox/runtime test: %d Fehler" % failures)
        quit(1)


func _expect_contains_all(summary: String, needles: Array, move_name: String) -> void:
    for needle_value: Variant in needles:
        var needle: String = str(needle_value)
        _check(summary.contains(needle), move_name + "-Infobox fehlt: " + needle + " | Text: " + summary)
    var lower: String = summary.to_lower()
    _check(not lower.contains("db_"), move_name + " zeigt internen db_-Namen: " + summary)
    _check(not lower.contains("effect_source"), move_name + " zeigt effect_source: " + summary)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
