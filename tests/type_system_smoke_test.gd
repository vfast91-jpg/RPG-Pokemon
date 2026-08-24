extends SceneTree

const TypeSystemScript = preload("res://scripts/battle/type_system.gd")

func _initialize() -> void:
    var type_system = TypeSystemScript.new()
    root.add_child(type_system)

    _assert_close(type_system.get_multiplier("electric", ["electric"]), 0.5, "Elektro gegen Elektro")
    _assert_close(type_system.get_multiplier("electric", ["water"]), 2.0, "Elektro gegen Wasser")
    _assert_close(type_system.get_multiplier("electric", ["ground"]), 0.25, "Elektro gegen Boden")
    _assert_close(type_system.get_multiplier("normal", ["ghost"]), 0.25, "Normal gegen Geist")
    _assert_close(type_system.get_multiplier("ghost", ["normal"]), 0.25, "Geist gegen Normal")
    _assert_close(type_system.get_multiplier("fire", ["grass", "steel"]), 4.0, "Feuer gegen Pflanze/Stahl")
    _assert_close(type_system.get_multiplier("normal", ["ghost", "rock"]), 0.125, "Normal gegen Geist/Gestein")

    _assert_close(type_system.get_same_type_damage_multiplier("electric", ["electric"]), 1.5, "STAB Elektro")
    _assert_close(type_system.get_same_type_damage_multiplier("normal", ["electric"]), 1.0, "Kein STAB für Normal bei Elektro")
    _assert_close(type_system.get_same_type_status_multiplier("grass", ["grass", "poison"]), 1.5, "Status-STAB bei Dualtyp")

    var electric_mirror: Dictionary = type_system.evaluate_attack("electric", ["electric"], ["electric"])
    _assert_close(float(electric_mirror["same_type_multiplier"]), 1.5, "STAB im Elektro-Spiegel")
    _assert_close(float(electric_mirror["effectiveness_multiplier"]), 0.5, "Resistenz im Elektro-Spiegel")
    _assert_close(float(electric_mirror["combined_damage_multiplier"]), 0.75, "Gesamtmultiplikator im Elektro-Spiegel")

    var pikachu_result: Dictionary = type_system.evaluate("electric", ["electric"])
    assert(pikachu_result["feedback_key"] == "resisted", "Pikachu-Spiegelkampf muss resisted melden.")
    assert(pikachu_result["feedback_text"] == "Nicht sehr effektiv.", "Pikachu-Spiegelkampf muss sichtbares Effektivitätsfeedback liefern.")

    var ground_result: Dictionary = type_system.evaluate("electric", ["ground"])
    assert(ground_result["feedback_key"] == "super_ineffective", "Elektro gegen Boden muss super_ineffective melden.")
    assert(ground_result["feedback_text"] == "Super ineffektiv!", "0,25x muss sichtbares Super-ineffektiv-Feedback liefern.")

    # Regression: Schlecker (Geist) gegen Mauzi (Normal) ist in Timeflow keine
    # Immunität. Diese Kombination muss 0,25x UND explizit Super ineffektiv sein.
    var lick_vs_meowth: Dictionary = type_system.evaluate("ghost", ["normal"])
    _assert_close(float(lick_vs_meowth["multiplier"]), 0.25, "Schlecker gegen Mauzi")
    assert(lick_vs_meowth["feedback_key"] == "super_ineffective", "Geist gegen Normal darf nicht als immun gemeldet werden.")
    assert(lick_vs_meowth["feedback_text"] == "Super ineffektiv!", "Schlecker gegen Mauzi muss Super ineffektiv melden.")
    assert(lick_vs_meowth["feedback_text"] != "Keine Wirkung.", "Schlecker gegen Mauzi darf niemals Keine Wirkung melden.")

    var dual_result: Dictionary = type_system.evaluate("normal", ["ghost", "rock"])
    assert(dual_result["feedback_key"] == "super_ineffective", "0,125x bei Doppeltyp muss ebenfalls super_ineffective melden.")

    for attack_type_value: Variant in type_system._chart.get("types", []):
        var attack_type: String = str(attack_type_value)
        for defender_type_value: Variant in type_system._chart.get("types", []):
            var defender_type: String = str(defender_type_value)
            assert(
                type_system.get_multiplier(attack_type, [defender_type]) > 0.0,
                "%s gegen %s darf in Timeflow keine 0x-Typenimmunität mehr haben." % [attack_type, defender_type]
            )

    print("TypeSystem smoke tests: OK")
    quit(0)

func _assert_close(actual: float, expected: float, label: String) -> void:
    assert(is_equal_approx(actual, expected), "%s: erwartet %s, erhalten %s" % [label, expected, actual])
