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

    _assert_close(type_system.get_same_type_damage_multiplier("electric", ["electric"]), 1.5, "Elektro-Pokémon mit Elektro-Attacke erhält STAB")
    _assert_close(type_system.get_same_type_damage_multiplier("normal", ["electric"]), 1.0, "Fremder Attackentyp erhält keinen STAB")
    _assert_close(type_system.get_same_type_status_multiplier("electric", ["electric"]), 1.5, "Skalierbare Elektro-Statuswirkung erhält STAB")
    _assert_close(type_system.apply_attack_damage(100.0, "electric", ["electric"], ["water"]), 300.0, "STAB und Typeneffektivität werden gemeinsam angewendet")
    _assert_close(type_system.apply_to_status_strength(20.0, "electric", ["electric"]), 30.0, "STAB verstärkt skalierbare Statusstärke")
    _assert_close(type_system.apply_to_status_strength(20.0, "normal", ["electric"]), 20.0, "Ohne Typgleichheit bleibt Statusstärke unverändert")

    var attack_result: Dictionary = type_system.evaluate_attack("electric", ["electric"], ["water"])
    _assert_close(float(attack_result["effectiveness_multiplier"]), 2.0, "Evaluate: Typeneffektivität")
    _assert_close(float(attack_result["same_type_multiplier"]), 1.5, "Evaluate: STAB")
    _assert_close(float(attack_result["combined_damage_multiplier"]), 3.0, "Evaluate: kombinierter Schadensmultiplikator")
    assert(bool(attack_result["has_same_type_bonus"]), "Evaluate muss den aktiven Typenbonus markieren.")

    var pikachu_result: Dictionary = type_system.evaluate("electric", ["electric"])
    assert(pikachu_result["feedback_key"] == "resisted", "Pikachu-Spiegelkampf muss resisted melden.")
    assert(pikachu_result["feedback_text"] == "Nicht sehr effektiv.", "Pikachu-Spiegelkampf muss sichtbares Effektivitätsfeedback liefern.")

    print("TypeSystem smoke tests: OK")
    quit(0)

func _assert_close(actual: float, expected: float, label: String) -> void:
    assert(is_equal_approx(actual, expected), "%s: erwartet %s, erhalten %s" % [label, expected, actual])
