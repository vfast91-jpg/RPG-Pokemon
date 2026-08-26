extends SceneTree

const StatusAggroBattle = preload("res://scripts/battle_demo_status_aggro_integrity_v1.gd")


func _initialize() -> void:
    var battle = StatusAggroBattle.new()
    _test_major_status_scaling(battle)
    _test_duration_status_scaling(battle)
    _test_confusion_extension_only(battle)
    _test_no_effect_means_no_aggro(battle)
    _test_active_stack_contains_integrity_layer()
    battle.free()
    print("Status Aggro integrity test: PASS")
    quit(0)


func _base_target() -> Dictionary:
    return {
        "max_hp": 200,
        "speed": 80.0,
        "major_status": "",
        "paralyzed": false,
        "confused_turns": 0,
        "db_sleep_actions": 0,
        "zf_freeze_actions": 0,
        "tf_bad_poison_stage": 0
    }


func _test_major_status_scaling(battle) -> void:
    var burn_target: Dictionary = _base_target()
    var burn_before: Dictionary = battle._status_aggro_snapshot(burn_target)
    burn_target["major_status"] = "burn"
    assert(is_equal_approx(
        battle._status_aggro_for_transition(burn_target, "burn", burn_before),
        20.0
    ), "Verbrennung muss 10 % der Ziel-Max-KP als Anwendungs-Aggro erzeugen.")

    var poison_target: Dictionary = _base_target()
    var poison_before: Dictionary = battle._status_aggro_snapshot(poison_target)
    poison_target["major_status"] = "poison"
    assert(is_equal_approx(
        battle._status_aggro_for_transition(poison_target, "poison", poison_before),
        20.0
    ), "Vergiftung muss 10 % der Ziel-Max-KP als Anwendungs-Aggro erzeugen.")

    var toxic_target: Dictionary = _base_target()
    var toxic_before: Dictionary = battle._status_aggro_snapshot(toxic_target)
    toxic_target["major_status"] = "bad_poison"
    toxic_target["tf_bad_poison_stage"] = 1
    assert(is_equal_approx(
        battle._status_aggro_for_transition(toxic_target, "bad_poison", toxic_before),
        20.0
    ), "Schwere Vergiftung muss die zentrale Status-Anwendungs-Aggro verwenden.")

    var paralysis_target: Dictionary = _base_target()
    var paralysis_before: Dictionary = battle._status_aggro_snapshot(paralysis_target)
    paralysis_target["major_status"] = "paralysis"
    paralysis_target["paralyzed"] = true
    assert(is_equal_approx(
        battle._status_aggro_for_transition(
            paralysis_target,
            "paralysis",
            paralysis_before
        ),
        60.0
    ), "Paralyse muss 50 % Tempoverlust + 10 % Ziel-Max-KP werten.")


func _test_duration_status_scaling(battle) -> void:
    var sleep_target: Dictionary = _base_target()
    var sleep_before: Dictionary = battle._status_aggro_snapshot(sleep_target)
    sleep_target["major_status"] = "sleep"
    sleep_target["db_sleep_actions"] = 2
    assert(is_equal_approx(
        battle._status_aggro_for_transition(sleep_target, "sleep", sleep_before),
        40.0
    ), "Schlaf muss pro tatsächlich neuer Schlaf-Aktion 10 % Max-KP werten.")

    var freeze_target: Dictionary = _base_target()
    var freeze_before: Dictionary = battle._status_aggro_snapshot(freeze_target)
    freeze_target["major_status"] = "freeze"
    freeze_target["zf_freeze_actions"] = 3
    assert(is_equal_approx(
        battle._status_aggro_for_transition(freeze_target, "freeze", freeze_before),
        60.0
    ), "Gefroren muss seine tatsächlich verlorenen Aktionsmöglichkeiten werten.")


func _test_confusion_extension_only(battle) -> void:
    var target: Dictionary = _base_target()
    target["confused_turns"] = 1
    var before: Dictionary = battle._status_aggro_snapshot(target)
    target["confused_turns"] = 3
    assert(is_equal_approx(
        battle._status_aggro_for_transition(target, "confusion", before),
        24.0
    ), "Zwei neue Verwirrungs-Aktionen müssen 2 × 6 % Max-KP werten.")

    var no_extension_before: Dictionary = battle._status_aggro_snapshot(target)
    assert(is_zero_approx(
        battle._status_aggro_for_transition(
            target,
            "confusion",
            no_extension_before
        )
    ), "Unveränderte Verwirrung darf keine neue Wirkungs-Aggro erzeugen.")


func _test_no_effect_means_no_aggro(battle) -> void:
    var target: Dictionary = _base_target()
    target["major_status"] = "burn"
    var before: Dictionary = battle._status_aggro_snapshot(target)
    assert(is_zero_approx(
        battle._status_aggro_for_transition(target, "burn", before)
    ), "Bereits bestehende Verbrennung darf keine neue Wirkungs-Aggro erzeugen.")


func _test_active_stack_contains_integrity_layer() -> void:
    var source: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_zf_payday_v1.gd"
    )
    assert(
        source.begins_with(
            "extends \"res://scripts/battle_demo_status_aggro_integrity_v1.gd\""
        ),
        "Die Status-Aggro-Integritätsschicht ist nicht im aktiven Vererbungsstack."
    )

    var active_stack = load("res://scripts/battle_demo_stage50_mirror_v1.gd")
    assert(active_stack != null, "Der finale aktive Kampfstack muss ladbar bleiben.")
