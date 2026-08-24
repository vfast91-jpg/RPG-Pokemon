extends SceneTree

const StageScaling = preload("res://scripts/battle/status_stage_scaling.gd")
const ActiveBattle = preload("res://scripts/battle_demo_status_stage_scaling_v1.gd")


func _initialize() -> void:
    _test_global_positive_stage_translation()
    _test_status_60_defense_values()
    _test_stockpile_uses_one_persistent_modifier()
    print("Status stage scaling regression test: PASS")
    quit(0)


func _test_global_positive_stage_translation() -> void:
    assert(is_equal_approx(
        StageScaling.effective_positive_stage_weight("outgoing_damage_mod", 1.0),
        1.0
    ))
    assert(is_equal_approx(
        StageScaling.effective_positive_stage_weight("outgoing_damage_mod", 2.0),
        1.25
    ))
    assert(is_equal_approx(
        StageScaling.effective_positive_stage_weight("incoming_damage_mod", -2.0),
        1.25
    ))
    assert(is_equal_approx(
        StageScaling.effective_positive_stage_weight("atb_cycle_mod", -2.0),
        1.25
    ))

    # The new rule is deliberately for positive +2-stage boosts. Existing -2
    # debuffs are not silently redesigned by this change.
    assert(is_equal_approx(
        StageScaling.effective_positive_stage_weight("outgoing_damage_mod", -2.0),
        2.0
    ))


func _test_status_60_defense_values() -> void:
    var battle = ActiveBattle.new()
    var actor: Dictionary = {"special": 60.0, "types": []}
    var ratio: float = 60.0 / 135.0

    var one_stage: float = battle._status_modifier_multiplier(
        actor,
        {"multiplier_from_special": -1.0},
        "incoming_damage_mod",
        false,
        false
    )
    var two_stage: float = battle._status_modifier_multiplier(
        actor,
        {"multiplier_from_special": -2.0},
        "incoming_damage_mod",
        false,
        false
    )

    assert(is_equal_approx(one_stage, 1.0 + ratio))
    assert(is_equal_approx(two_stage, 1.0 + 1.25 * ratio))
    assert(absf((two_stage - 1.0) * 100.0 - 55.5555556) < 0.001)
    battle.free()


func _test_stockpile_uses_one_persistent_modifier() -> void:
    var battle = ActiveBattle.new()
    var actor: Dictionary = {
        "special": 60.0,
        "types": [],
        "db_stockpile": 0,
        "db_stockpile_defense_multiplier": 1.0,
        "timed_modifiers": []
    }
    var mechanic: Dictionary = {"kind": "db_stockpile", "max": 3}
    var ratio: float = 60.0 / 135.0
    var per_stack_bonus: float = 1.25 * ratio

    battle._effect(actor, actor, mechanic)
    assert(int(actor.get("db_stockpile", 0)) == 1)
    assert(is_equal_approx(
        float(actor.get("db_stockpile_defense_multiplier", 0.0)),
        1.0 + per_stack_bonus
    ))
    assert((actor.get("timed_modifiers", []) as Array).is_empty())

    battle._effect(actor, actor, mechanic)
    assert(int(actor.get("db_stockpile", 0)) == 2)
    assert(is_equal_approx(
        float(actor.get("db_stockpile_defense_multiplier", 0.0)),
        1.0 + 2.0 * per_stack_bonus
    ))

    battle._effect(actor, actor, mechanic)
    assert(int(actor.get("db_stockpile", 0)) == 3)
    var expected_three: float = 1.0 + 3.0 * per_stack_bonus
    assert(is_equal_approx(
        float(actor.get("db_stockpile_defense_multiplier", 0.0)),
        expected_three
    ))
    assert(is_equal_approx(
        battle._combined_timed_modifier(actor, "incoming_damage_mod"),
        expected_three
    ))

    battle._clear_global_stockpile_defense(actor)
    assert(is_equal_approx(
        float(actor.get("db_stockpile_defense_multiplier", 0.0)),
        1.0
    ))
    battle.free()
