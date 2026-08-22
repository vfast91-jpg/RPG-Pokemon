extends SceneTree

const StartAggroRules = preload("res://scripts/battle/start_aggro_rules.gd")


func _initialize() -> void:
    var weak_species: Dictionary = {
        "base_stats": {"hp": 20, "attack": 20, "defense": 20, "special": 20, "speed": 20}
    }
    var strong_species: Dictionary = {
        "base_stats": {"hp": 60, "attack": 60, "defense": 60, "special": 60, "speed": 60}
    }

    assert(StartAggroRules.base_stat_total(weak_species) == 100)
    assert(StartAggroRules.base_stat_total(strong_species) == 300)

    var weak_level_10: float = StartAggroRules.calculate(weak_species, 10)
    var strong_level_10: float = StartAggroRules.calculate(strong_species, 10)
    var weak_level_20: float = StartAggroRules.calculate(weak_species, 20)

    assert(is_equal_approx(weak_level_10, 35.0), "100 Basiswerte auf Level 10 muessen 35 Start-Aggro ergeben.")
    assert(is_equal_approx(strong_level_10, 45.0), "300 Basiswerte auf Level 10 muessen 45 Start-Aggro ergeben.")
    assert(strong_level_10 > weak_level_10, "Staerkere Spezies muessen bei gleichem Level mehr Start-Aggro haben.")
    assert(weak_level_20 > weak_level_10, "Hoeheres Level muss bei gleicher Spezies mehr Start-Aggro haben.")

    print("Start aggro rules test: PASS")
    quit(0)
