extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_boss_residual_hp_fix_v1.gd")


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    var normal := {
        "max_hp": 160,
        "hp": 160,
        "alive": true,
        "boss": false,
        "damage_since_last_action": false
    }
    var two_bar_boss := {
        "max_hp": 320,
        "hp": 320,
        "alive": true,
        "boss": true,
        "boss_base_max_hp": 160,
        "boss_hp_multiplier": 2.0,
        "damage_since_last_action": false
    }
    var four_bar_boss := {
        "max_hp": 640,
        "hp": 640,
        "alive": true,
        "boss": true,
        "boss_base_max_hp": 160,
        "boss_hp_multiplier": 4.0,
        "damage_since_last_action": false
    }
    var legacy_boss := {
        "max_hp": 640,
        "hp": 640,
        "alive": true,
        "boss": true,
        "boss_hp_multiplier": 4.0,
        "damage_since_last_action": false
    }

    assert(lab._residual_damage_max_hp(normal) == 160, "Normale Pokémon müssen ihre normalen Max-KP verwenden.")
    assert(lab._residual_damage_max_hp(two_bar_boss) == 160, "2x-Bosse müssen für Dauerschaden die unmultiplizierten Max-KP verwenden.")
    assert(lab._residual_damage_max_hp(four_bar_boss) == 160, "4x-Endgame-Bosse müssen für Dauerschaden die unmultiplizierten Max-KP verwenden.")
    assert(lab._residual_damage_max_hp(legacy_boss) == 160, "Expliziter Boss-Multiplikator muss als kompatibler Fallback funktionieren.")

    var normal_tick: int = lab._deal_periodic_damage(normal, 1.0 / 8.0, "TEST")
    var two_bar_tick: int = lab._deal_periodic_damage(two_bar_boss, 1.0 / 8.0, "TEST")
    var four_bar_tick: int = lab._deal_periodic_damage(four_bar_boss, 1.0 / 8.0, "TEST")
    assert(normal_tick == 20, "1/8 von 160 muss 20 Schaden verursachen.")
    assert(two_bar_tick == normal_tick, "Binding/Gift-Ticks dürfen durch 2x Boss-KP nicht verdoppelt werden.")
    assert(four_bar_tick == normal_tick, "Binding/Gift-Ticks dürfen durch 4x Boss-KP nicht vervierfacht werden.")

    two_bar_boss["tf_bad_poison_stage"] = 3
    four_bar_boss["tf_bad_poison_stage"] = 3
    var toxic_two: int = lab._tf_tick_bad_poison(two_bar_boss)
    var toxic_four: int = lab._tf_tick_bad_poison(four_bar_boss)
    assert(toxic_two == 30, "Schweres Gift Stufe 3 muss 3/16 der Basis-Max-KP verursachen.")
    assert(toxic_four == toxic_two, "Schweres Gift muss bei 2x- und 4x-Bossen denselben absoluten Tick haben.")

    two_bar_boss["tf_curse_effect"] = {"source_id": "missing-test-source"}
    four_bar_boss["tf_curse_effect"] = {"source_id": "missing-test-source"}
    var curse_two: int = lab._tf_tick_curse(two_bar_boss)
    var curse_four: int = lab._tf_tick_curse(four_bar_boss)
    assert(curse_two == 40, "Geist-Fluch muss 1/4 der Basis-Max-KP verursachen.")
    assert(curse_four == curse_two, "Geist-Fluch muss bei 2x- und 4x-Bossen denselben absoluten Tick haben.")

    print("Boss residual HP scaling tests: PASS")
    lab.queue_free()
    quit(0)
