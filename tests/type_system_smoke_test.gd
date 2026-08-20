extends SceneTree

const TypeSystemScript = preload("res://scripts/battle/type_system.gd")

func _initialize() -> void:
    var type_system = TypeSystemScript.new()
    root.add_child(type_system)

    _assert_close(type_system.get_multiplier("electric", ["electric"]), 0.5, "Elektro gegen Elektro")
    _assert_close(type_system.get_multiplier("electric", ["water"]), 2.0, "Elektro gegen Wasser")
    _assert_close(type_system.get_multiplier("electric", ["ground"]), 0.0, "Elektro gegen Boden")
    _assert_close(type_system.get_multiplier("normal", ["ghost"]), 0.0, "Normal gegen Geist")
    _assert_close(type_system.get_multiplier("fire", ["grass", "steel"]), 4.0, "Feuer gegen Pflanze/Stahl")

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

    print("TypeSystem smoke tests: OK")
    quit(0)

func _assert_close(actual: float, expected: float, label: String) -> void:
    assert(is_equal_approx(actual, expected), "%s: erwartet %s, erhalten %s" % [label, expected, actual])
