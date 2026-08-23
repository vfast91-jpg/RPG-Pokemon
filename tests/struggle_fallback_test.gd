extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_struggle_fallback_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()

    var struggle: Dictionary = battle._move_data("struggle")
    _check(not struggle.is_empty(), "Verzweifler muss als System-Fallback geladen werden.")
    _check(str(struggle.get("name", "")) == "Verzweifler", "Der Fallback muss Verzweifler heißen.")
    _check(int(struggle.get("power", 0)) == 50, "Verzweifler muss Stärke 50 besitzen.")
    _check(struggle.get("accuracy", 0) == null, "Verzweifler muss immer treffen.")
    _check(int(struggle.get("ap", 0)) == 4, "Verzweifler muss 4 RPG-AP besitzen.")

    var mechanics_value: Variant = struggle.get("mechanics", [])
    var mechanics: Array = mechanics_value if mechanics_value is Array else []
    var has_damage: bool = false
    var has_recoil: bool = false
    for mechanic_value: Variant in mechanics:
        if not (mechanic_value is Dictionary):
            continue
        var kind: String = str((mechanic_value as Dictionary).get("kind", ""))
        has_damage = has_damage or kind == "damage"
        has_recoil = has_recoil or kind == "recoil"
    _check(has_damage, "Verzweifler benötigt eine normale Schadensmechanik.")
    _check(not has_recoil, "Verzweifler darf in Timeflow ausdrücklich keinen Rückstoß besitzen.")

    _check(
        battle._tf_effective_combat_moves({}, []).size() == 1
        and str(battle._tf_effective_combat_moves({}, [])[0]) == "struggle",
        "Ein Pokémon ohne Attacken muss automatisch Verzweifler erhalten."
    )
    _check(
        battle._tf_effective_combat_moves({}, ["warten", "vorne!"]) == ["struggle"],
        "Warten und Vorne! dürfen den Verzweifler-Fallback nicht verhindern."
    )
    _check(
        battle._tf_effective_combat_moves({}, ["attacke_die_noch_nicht_implementiert_ist"]) == ["struggle"],
        "Nur fehlende/unimplementierte Attacken-IDs müssen ebenfalls Verzweifler auslösen."
    )

    var runtime_moves_value: Variant = battle.data.get("moves", {})
    if runtime_moves_value is Dictionary:
        var runtime_moves: Dictionary = runtime_moves_value
        runtime_moves["deferred_runtime_test"] = {
            "id": "deferred_runtime_test",
            "name": "Später implementierte Attacke",
            "runtime": {"runtime_supported": false}
        }
        runtime_moves["normal_battle_blocked_test"] = {
            "id": "normal_battle_blocked_test",
            "name": "Nicht im normalen Kampf verfügbar",
            "runtime": {"runtime_supported": true, "normal_battle_available": false}
        }
        battle.data["moves"] = runtime_moves

    _check(
        battle._tf_effective_combat_moves({}, ["deferred_runtime_test"]) == ["struggle"],
        "Eine bereits registrierte, aber noch nicht runtime-unterstützte Attacke darf Verzweifler nicht verhindern."
    )
    _check(
        battle._tf_effective_combat_moves({}, ["normal_battle_blocked_test"]) == ["struggle"],
        "Eine im normalen Kampf gesperrte Attacke darf Verzweifler nicht verhindern."
    )

    var regular_move_id: String = ""
    var moves_value: Variant = battle.data.get("moves", {})
    if moves_value is Dictionary:
        for move_id_value: Variant in (moves_value as Dictionary).keys():
            var candidate: String = str(move_id_value)
            if battle._tf_regular_move_available(candidate):
                regular_move_id = candidate
                break
    _check(not regular_move_id.is_empty(), "Der Test benötigt mindestens eine regulär implementierte Attacke.")
    if not regular_move_id.is_empty():
        _check(
            battle._tf_effective_combat_moves({}, [regular_move_id]) == [regular_move_id],
            "Sobald eine reguläre Attacke verfügbar ist, darf Verzweifler nicht angeboten werden."
        )

    battle._tf_struggle_damage_depth = 1
    _check(
        battle._tf_damage_type("normal") == "typeless",
        "Verzweifler-Schaden muss typneutral aufgelöst werden."
    )
    battle._tf_struggle_damage_depth = 0
    _check(
        battle._tf_damage_type("normal") == "normal",
        "Andere Attacken dürfen durch den Fallback ihre Typenauflösung nicht verlieren."
    )

    battle.free()

    if failures == 0:
        print("Struggle fallback test: PASS")
        quit(0)
    else:
        push_error("Struggle fallback test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
