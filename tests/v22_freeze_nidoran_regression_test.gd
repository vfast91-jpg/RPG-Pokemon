extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_stockpile_infobox_v1.gd")

var failures: int = 0

func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    _test_freeze_budget_range(battle)
    _test_freeze_budget_consumption(battle)
    _test_flatter_substitute_gate(battle)
    battle.free()
    if failures == 0:
        print("V22 Freeze/Nidoran regression test: PASS")
        quit(0)
    push_error("V22 Freeze/Nidoran regression test: %d Fehler" % failures)
    quit(1)

func _test_freeze_budget_range(battle) -> void:
    for _index: int in range(100):
        var rolled: int = battle._zf_roll_freeze_actions()
        _check(rolled >= 1 and rolled <= 3, "Freeze-Budget muss zwischen 1 und 3 liegen.")

func _test_freeze_budget_consumption(battle) -> void:
    var frozen_actor: Dictionary = {"zf_freeze_actions": 3}
    _check(battle._zf_consume_freeze_action_budget(frozen_actor) == 2, "Freeze-Budget 3 -> 2 fehlt.")
    _check(battle._zf_consume_freeze_action_budget(frozen_actor) == 1, "Freeze-Budget 2 -> 1 fehlt.")
    _check(battle._zf_consume_freeze_action_budget(frozen_actor) == 0, "Freeze-Budget 1 -> 0 fehlt.")

func _test_flatter_substitute_gate(battle) -> void:
    var actor: Dictionary = {"id": "actor_test", "side": "player", "special": 100.0}
    var target: Dictionary = {
        "id": "target_test",
        "side": "enemy",
        "action_serial": 0,
        "db_substitute_hp": 20,
        "nido_status_effectiveness_modifiers": []
    }
    battle._nido_apply_status_effectiveness_bonus(actor, target)
    var modifiers_value: Variant = target.get("nido_status_effectiveness_modifiers", [])
    var modifiers: Array = modifiers_value if modifiers_value is Array else []
    _check(modifiers.is_empty(), "Schmeichlers Bonus darf Delegator nicht durchdringen.")

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
