extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_atb_pause_power_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = BattleScript.new()
    battle._load_data()

    _check_move_contracts(battle)
    _check_pause_fraction(battle, 25.0, 0.50)
    _check_pause_fraction(battle, 50.0, 0.80)
    _check_pause_fraction(battle, 75.0, 1.00)
    _check_pause_fraction(battle, 150.0, 4.0 / 3.0)

    battle.free()
    if failures == 0:
        print("ATB pause power regression test: PASS")
        quit(0)
    push_error("ATB pause power regression test: %d Fehler" % failures)
    quit(1)


func _check_move_contracts(battle) -> void:
    var moves_value: Variant = battle.data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}
    for move_id: String in ["whirlwind", "roar", "dragon_tail"]:
        var move_value: Variant = moves.get(move_id, {})
        _check(move_value is Dictionary, move_id + ": Attacke fehlt.")
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        _check(battle._move_uses_db_atb_pause(move), move_id + ": db_atb_pause fehlt.")
        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        _check(
            is_equal_approx(float(runtime.get("timeflow_atb_pause_multiplier", 0.0)), 2.0),
            move_id + ": ATB-Pausen-Multiplikator muss 2,0 sein."
        )
        _check(
            bool(runtime.get("timeflow_atb_pause_uncapped", false)),
            move_id + ": ATB-Pause muss ohne 100%-Deckel markiert sein."
        )


func _check_pause_fraction(battle, status_value: float, expected_fraction: float) -> void:
    var actor: Dictionary = {
        "id": "pause_actor",
        "side": "player",
        "alive": true,
        "special": status_value
    }
    var target: Dictionary = {
        "id": "pause_target",
        "side": "enemy",
        "alive": true,
        "hp": 100,
        "max_hp": 100,
        "speed": 50.0,
        "cycle": 1.0,
        "atb": 50.0,
        "aggro": 0.0,
        "action_serial": 0,
        "timed_modifiers": [],
        "db_atb_pause_remaining_seconds": 0.0
    }

    var normal_cycle: float = battle._target_full_atb_cycle_seconds(target)
    battle._v22_active_move_id = "dragon_tail"
    battle._effect(actor, target, {"kind": "db_atb_pause"})
    battle._v22_active_move_id = ""

    var actual_pause: float = float(target.get("db_atb_pause_remaining_seconds", 0.0))
    var actual_fraction: float = actual_pause / maxf(0.0001, normal_cycle)
    _check(
        is_equal_approx(actual_fraction, expected_fraction),
        "Status %.0f: erwartet %.3f Zielzyklen Pause, erhalten %.3f."
        % [status_value, expected_fraction, actual_fraction]
    )


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
