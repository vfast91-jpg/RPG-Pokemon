extends SceneTree

const CentralBattle = preload("res://scripts/battle_demo_status_stage_scaling_v1.gd")
const STATUS_CURVE: float = 75.0


func _initialize() -> void:
    _test_one_stage_speed_softcap()
    _test_suicune_like_regression_case()
    _test_positive_two_stage_weight_is_preserved()
    _test_speed_reduction_direction()
    _test_active_main_runtime_uses_fixed_conversion()
    print("Status speed soft-cap regression test: PASS")
    quit(0)


func _ratio(status_value: float) -> float:
    var status: float = maxf(0.0, status_value)
    if status <= 0.0:
        return 0.0
    return status / (STATUS_CURVE + status)


func _effective_speed_from_cycle(cycle_multiplier: float) -> float:
    return 1.0 / maxf(0.0001, cycle_multiplier)


func _speed_cycle(
    battle: Node,
    status_value: float,
    signed_stages: float
) -> float:
    var actor: Dictionary = {"special": status_value, "types": []}
    return float(battle.call(
        "_status_modifier_multiplier",
        actor,
        {"multiplier_from_special": signed_stages},
        "atb_cycle_mod",
        false,
        false
    ))


func _test_one_stage_speed_softcap() -> void:
    var battle: Node = CentralBattle.new()
    for status_value: float in [0.0, 25.0, 75.0, 150.0, 300.0, 100000.0]:
        var ratio: float = _ratio(status_value)
        var cycle: float = _speed_cycle(battle, status_value, -1.0)
        var effective_speed: float = _effective_speed_from_cycle(cycle)
        var expected_speed: float = 1.0 + ratio

        assert(
            absf(effective_speed - expected_speed) < 0.00001,
            "1x Speed-Buff muss exakt 1+R ergeben."
        )
        if status_value > 0.0:
            assert(
                effective_speed < 2.0,
                "1x Speed-Buff darf bei endlichem Status niemals +100% erreichen/überschreiten."
            )
    battle.free()


func _test_suicune_like_regression_case() -> void:
    # Status 124 entspricht R ~= 0.623. Der alte cycle=(1-R)-Pfad ergab daraus
    # effektiv ca. x2.65 bzw. +165%. Korrekt ist x1.623 bzw. rund +62%.
    var battle: Node = CentralBattle.new()
    var status_value: float = 124.0
    var ratio: float = _ratio(status_value)
    var cycle: float = _speed_cycle(battle, status_value, -1.0)
    var effective_speed: float = _effective_speed_from_cycle(cycle)

    assert(absf(effective_speed - (1.0 + ratio)) < 0.00001)
    assert(effective_speed > 1.62 and effective_speed < 1.63)
    assert(effective_speed < 2.0)
    battle.free()


func _test_positive_two_stage_weight_is_preserved() -> void:
    # Existing globale Regel: ein positiver +2-Stufen-Buff wird als 1.25xR
    # übersetzt. Der Speed-Fix darf diese Balanceentscheidung nicht verändern.
    var battle: Node = CentralBattle.new()
    var status_value: float = 75.0
    var ratio: float = _ratio(status_value)
    var cycle: float = _speed_cycle(battle, status_value, -2.0)
    var effective_speed: float = _effective_speed_from_cycle(cycle)
    var expected_speed: float = 1.0 + 1.25 * ratio

    assert(absf(effective_speed - expected_speed) < 0.00001)
    battle.free()


func _test_speed_reduction_direction() -> void:
    # Positive atb_cycle_mod bedeutet Verlangsamung: Zyklus wird länger und die
    # effektive Geschwindigkeit sinkt auf 1/(1+R). Dieser bestehende Pfad bleibt.
    var battle: Node = CentralBattle.new()
    var status_value: float = 75.0
    var ratio: float = _ratio(status_value)
    var cycle: float = _speed_cycle(battle, status_value, 1.0)
    var effective_speed: float = _effective_speed_from_cycle(cycle)

    assert(absf(cycle - (1.0 + ratio)) < 0.00001)
    assert(absf(effective_speed - (1.0 / (1.0 + ratio))) < 0.00001)
    assert(effective_speed < 1.0)
    battle.free()


func _test_active_main_runtime_uses_fixed_conversion() -> void:
    # Teste nicht nur die zentrale Zwischenschicht. Lade exakt die BattleDemo-
    # Runtime, die main.tscn aktuell verwendet, damit ein spaeteres Override den
    # Fix nicht unbemerkt wieder aushebeln kann.
    var main_text: String = FileAccess.get_file_as_string("res://main.tscn")
    var battle_resource_regex := RegEx.new()
    assert(
        battle_resource_regex.compile(
            "ext_resource type=\"Script\" path=\"([^\"]+)\" id=\"2_battle\""
        ) == OK
    )
    var match_result: RegExMatch = battle_resource_regex.search(main_text)
    assert(match_result != null, "main.tscn muss eine aktive BattleDemo-Runtime besitzen.")

    var active_battle_path: String = match_result.get_string(1)
    var active_script: Script = load(active_battle_path) as Script
    assert(active_script != null, "Aktive BattleDemo-Runtime muss ladbar sein.")

    var cursor: Script = active_script
    var scaling_layer_found: bool = false
    while cursor != null:
        if cursor.resource_path.ends_with("battle_demo_status_stage_scaling_v1.gd"):
            scaling_layer_found = true
            break
        cursor = cursor.get_base_script()
    assert(
        scaling_layer_found,
        "Aktive main-Runtime muss die globale Status-Stufenskalierung enthalten."
    )

    var final_runtime: Node = active_script.new() as Node
    assert(final_runtime != null)

    var status_value: float = 124.0
    var expected_speed: float = 1.0 + _ratio(status_value)
    var cycle: float = _speed_cycle(final_runtime, status_value, -1.0)
    var runtime_speed: float = float(final_runtime.call(
        "_speed_multiplier_from_cycle",
        cycle
    ))

    assert(
        absf(runtime_speed - expected_speed) < 0.00001,
        "Finale main-Runtime muss denselben begrenzten Speed-Buff anzeigen und anwenden."
    )
    assert(runtime_speed < 2.0)
    final_runtime.free()
