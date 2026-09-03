extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_lab_family_refresh_v1.gd")
const AreaStatusRules = preload("res://scripts/battle/area_status_rules.gd")


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    _assert_multiplier_table()
    _assert_neutral_modifier_math()
    _assert_runtime_target_counting(lab)

    print("Central numerical area status scaling test: PASS")
    lab.queue_free()
    quit(0)


func _assert_multiplier_table() -> void:
    assert(is_equal_approx(AreaStatusRules.effect_multiplier(0), 1.0), "0 Ziele duerfen keinen Flaechenabzug erzeugen.")
    assert(is_equal_approx(AreaStatusRules.effect_multiplier(1), 1.0), "1 Ziel muss 100 % Statusstaerke erhalten.")
    assert(is_equal_approx(AreaStatusRules.effect_multiplier(2), 0.75), "2 Ziele muessen je 75 % Statusstaerke erhalten.")
    assert(is_equal_approx(AreaStatusRules.effect_multiplier(3), 0.60), "3 Ziele muessen je 60 % Statusstaerke erhalten.")
    assert(is_equal_approx(AreaStatusRules.effect_multiplier(4), 0.50), "4 Ziele muessen je 50 % Statusstaerke erhalten.")
    assert(is_equal_approx(AreaStatusRules.effect_multiplier(8), 0.50), "4+ Ziele muessen bei 50 % gedeckelt bleiben.")

    assert(AreaStatusRules.target_rule_uses_scaling("all_allies"), "Alle Verbündeten muessen die zentrale Flaechenregel verwenden.")
    assert(AreaStatusRules.target_rule_uses_scaling("all_enemies"), "Alle Gegner muessen die zentrale Flaechenregel verwenden.")
    assert(not AreaStatusRules.target_rule_uses_scaling("enemy_highest_aggro"), "Einzelziele duerfen keinen Flaechenabzug erhalten.")


func _assert_neutral_modifier_math() -> void:
    assert(is_equal_approx(AreaStatusRules.scale_special_coefficient(1.0, 4), 0.50), "Positive Statuskoeffizienten muessen bei 4 Zielen halbiert werden.")
    assert(is_equal_approx(AreaStatusRules.scale_special_coefficient(-1.0, 4), -0.50), "Negative Statuskoeffizienten muessen bei 4 Zielen betragsmaessig halbiert werden.")

    assert(is_equal_approx(AreaStatusRules.scale_modifier_multiplier(1.80, 4), 1.40), "Ein 80-%-Buff muss bei 4 Zielen zu einem 40-%-Buff werden.")
    assert(is_equal_approx(AreaStatusRules.scale_modifier_multiplier(0.60, 4), 0.80), "Ein 40-%-Debuff muss bei 4 Zielen zu einem 20-%-Debuff werden und darf sich nicht umkehren.")
    assert(is_equal_approx(AreaStatusRules.scale_modifier_multiplier(1.80, 2), 1.60), "Ein 80-%-Buff muss bei 2 Zielen zu einem 60-%-Buff werden.")


func _assert_runtime_target_counting(lab) -> void:
    var actor: Dictionary = {"id":"player_0", "side":"player", "alive":true}
    var ally_b: Dictionary = {"id":"player_1", "side":"player", "alive":true}
    var ally_c: Dictionary = {"id":"player_2", "side":"player", "alive":true}
    var ally_d: Dictionary = {"id":"player_3", "side":"player", "alive":true}
    var enemy_a: Dictionary = {"id":"enemy_0", "side":"enemy", "alive":true}
    var enemy_b: Dictionary = {"id":"enemy_1", "side":"enemy", "alive":true}
    var enemy_c: Dictionary = {"id":"enemy_2", "side":"enemy", "alive":true}
    var enemy_d: Dictionary = {"id":"enemy_3", "side":"enemy", "alive":true}
    lab.combatants = [actor, ally_b, ally_c, ally_d, enemy_a, enemy_b, enemy_c, enemy_d]

    assert(lab._area_status_target_count(actor, "all_allies", "player") == 4, "Teamweiter Buff muss 4 lebende eigene Ziele zaehlen.")
    assert(lab._area_status_target_count(actor, "all_enemies", "enemy") == 4, "Teamweiter Debuff muss 4 lebende Gegner zaehlen.")

    enemy_d["alive"] = false
    assert(lab._area_status_target_count(actor, "all_enemies", "enemy") == 3, "Ein K.O.-Gegner darf nicht in die Status-Flaechenstaerke eingehen.")
    enemy_c["alive"] = false
    assert(lab._area_status_target_count(actor, "all_enemies", "enemy") == 2, "Zwei lebende Gegner muessen als zwei Statusziele zaehlen.")
    enemy_b["alive"] = false
    assert(lab._area_status_target_count(actor, "all_enemies", "enemy") == 1, "Ein lebender Gegner muss volle Statusstaerke behalten.")
