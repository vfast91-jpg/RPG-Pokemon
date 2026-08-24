extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_v22_sequence_hit_integrity_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = BattleScript.new()
    battle._load_data()

    var moves_value: Variant = battle.data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}

    _test_forced_sequence_contracts(moves)
    _test_substitute_counts_as_direct_hit(battle)
    _test_multi_hit_first_phase_survives_substitute(battle)
    _test_uproar_execution_semantics(battle)
    _test_interruption_has_no_completion_confusion(battle)
    _test_belch_remains_intentionally_locked(moves)

    battle.free()
    if failures == 0:
        print("V22 sequence hit integrity test: PASS")
        quit(0)
    push_error("V22 sequence hit integrity test: %d Fehler" % failures)
    quit(1)


func _test_forced_sequence_contracts(moves: Dictionary) -> void:
    var petal_dance: Dictionary = _forced_sequence(_move(moves, "petal_dance"))
    _check(
        int(petal_dance.get("min", 0)) == 2
        and int(petal_dance.get("max", 0)) == 3
        and bool(petal_dance.get("confuse_after", false)),
        "Blättertanz muss 2–3 Aktionen dauern und nur nach Abschluss verwirren."
    )

    var thrash: Dictionary = _forced_sequence(_move(moves, "thrash"))
    _check(
        int(thrash.get("min", 0)) == 2
        and int(thrash.get("max", 0)) == 3
        and bool(thrash.get("confuse_after", false)),
        "Fuchtler muss 2–3 Aktionen dauern und nur nach Abschluss verwirren."
    )

    var uproar: Dictionary = _forced_sequence(_move(moves, "uproar"))
    _check(
        int(uproar.get("min", 0)) == 3
        and int(uproar.get("max", 0)) == 3
        and not bool(uproar.get("confuse_after", false)),
        "Aufruhr muss exakt 3 Aktionen ohne Abschlussverwirrung dauern."
    )

    var rollout_move: Dictionary = _move(moves, "rollout")
    var rollout: Dictionary = _forced_sequence(rollout_move)
    _check(
        int(rollout.get("min", 0)) == 5 and int(rollout.get("max", 0)) == 5,
        "Walzer muss maximal fünf erzwungene Serienaktionen vorsehen."
    )
    _check(
        _runtime(rollout_move).get("consecutive_power_chain", [])
        == [30, 60, 120, 240, 480],
        "Walzer muss die V22-Stärkenfolge 30/60/120/240/480 verwenden."
    )


func _test_substitute_counts_as_direct_hit(battle) -> void:
    var target: Dictionary = {
        "id": "sub_target",
        "hp": 100,
        "alive": true,
        "db_substitute_hp": 15
    }
    battle._v22_direct_hit_probe_move_id = "double_kick"
    battle._v22_direct_hit_snapshot = {
        "sub_target": {
            "target": target,
            "hp": 100,
            "substitute_hp": 25
        }
    }
    var base_snapshot: Dictionary = {
        "sub_target": {
            "target": target,
            "hp": 100,
            "alive": true
        }
    }

    _check(
        battle._database_any_target_damaged(base_snapshot),
        "Mehrfachtreffer müssen Delegator-KP-Verlust als erfolgreichen ersten Treffer erkennen."
    )

    battle._v22_direct_hit_probe_move_id = "rollout"
    _check(
        battle._v22_any_opponent_lost_hp({"side": "player"}, {}),
        "Walzer muss einen Treffer auf Delegator als erfolgreichen Serien-Schritt zählen."
    )


func _test_multi_hit_first_phase_survives_substitute(battle) -> void:
    var target: Dictionary = {
        "id": "multi_sub_target",
        "hp": 100,
        "alive": true,
        "db_substitute_hp": 15
    }
    battle._v22_direct_hit_probe_move_id = "double_kick"
    battle._v22_direct_hit_snapshot = {
        "multi_sub_target": {
            "target": target,
            "hp": 100,
            "substitute_hp": 25
        }
    }
    var original_snapshots: Dictionary = {
        "multi_sub_target": {
            "target": target,
            "hp": 100,
            "alive": true
        }
    }

    var adjusted: Dictionary = battle._v22_adjust_multi_hit_first_hit_snapshots(
        original_snapshots
    )
    var adjusted_entry: Dictionary = adjusted.get("multi_sub_target", {})
    _check(
        int(adjusted_entry.get("hp", 0)) == 110,
        "10 Delegator-Schaden müssen den Multi-Hit-Launcher wie 10 Treffer-Schaden weiterlaufen lassen."
    )
    _check(
        int(target.get("hp", 0)) == 100,
        "Die Delegator-Anpassung darf niemals echte Pokémon-KP verändern."
    )


func _test_uproar_execution_semantics(battle) -> void:
    battle._v22_direct_hit_probe_move_id = "uproar"
    battle._v22_direct_hit_snapshot = {}
    _check(
        battle._v22_any_opponent_lost_hp({"side": "player"}, {}),
        "Ausgeführter Aufruhr darf nicht allein wegen 0 KP-Schaden als Sequenzabbruch gelten."
    )


func _test_interruption_has_no_completion_confusion(battle) -> void:
    for move_id: String in ["petal_dance", "thrash"]:
        var actor: Dictionary = {
            "db_forced_move_id": move_id,
            "db_forced_actions_left": 2,
            "confused_turns": 0
        }
        battle._database_interrupt_forced_sequence(actor)
        _check(
            str(actor.get("db_forced_move_id", "")) == ""
            and int(actor.get("db_forced_actions_left", -1)) == 0,
            move_id + ": Unterbrechung muss den Move-Lock vollständig löschen."
        )
        _check(
            int(actor.get("confused_turns", 0)) == 0,
            move_id + ": vorzeitige Unterbrechung darf keine Abschlussverwirrung erzeugen."
        )


func _test_belch_remains_intentionally_locked(moves: Dictionary) -> void:
    var belch: Dictionary = _move(moves, "belch")
    _check(
        not bool(_runtime(belch).get("runtime_supported", true)),
        "Rülpser muss bis zur Beerenverbrauchs-Runtime bewusst gesperrt bleiben."
    )


func _move(moves: Dictionary, move_id: String) -> Dictionary:
    var value: Variant = moves.get(move_id, {})
    return value as Dictionary if value is Dictionary else {}


func _runtime(move: Dictionary) -> Dictionary:
    var value: Variant = move.get("runtime", {})
    return value as Dictionary if value is Dictionary else {}


func _forced_sequence(move: Dictionary) -> Dictionary:
    var value: Variant = _runtime(move).get("forced_sequence", {})
    return value as Dictionary if value is Dictionary else {}


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error("V22 SEQUENCE TEST: " + message)
