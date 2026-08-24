extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_stockpile_infobox_v1.gd")
const GAP_IDS: Array[String] = [
    "mega_kick", "axe_kick", "mega_punch", "quick_guard", "rock_climb",
    "soft_boiled", "last_resort", "healing_wish", "tickle", "heal_block"
]

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()
    var moves_value: Variant = battle.data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}
    var canonical_value: Variant = battle._canonical_pack.get("moves", {})
    var canonical: Dictionary = canonical_value if canonical_value is Dictionary else {}

    for move_id: String in GAP_IDS:
        _check(moves.has(move_id), "Runtime-ID fehlt: " + move_id)
        _check(canonical.has(move_id), "Canonical-ID fehlt: " + move_id)
        if moves.has(move_id):
            var move: Dictionary = moves[move_id]
            var runtime_value: Variant = move.get("runtime", {})
            var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
            _check(bool(runtime.get("runtime_supported", false)), move_id + ": runtime_supported fehlt")
            _check(not (move.get("mechanics", []) as Array).is_empty(), move_id + ": mechanics fehlen")
            _check(battle._v22_move_has_executable_path(move), move_id + ": kein finaler Runtime-Pfad")

    _test_data_contracts(moves)
    _test_last_resort_gate(battle)
    _test_connected_hit_substitute_rule(battle)
    _test_soft_boiled_curve(battle)
    _test_heal_block_no_refresh(battle)
    _test_healing_wish_effect_gate(battle)
    _test_quick_guard_block_and_break(battle)

    battle.free()
    if failures == 0:
        print("V22 canonical gap fill test: PASS")
        quit(0)
    push_error("V22 canonical gap fill test: %d Fehler" % failures)
    quit(1)


func _test_data_contracts(moves: Dictionary) -> void:
    var mega_kick: Dictionary = moves.get("mega_kick", {})
    _check(int(mega_kick.get("power", 0)) == 120, "Megakick: Stärke muss 120 sein")
    _check(is_equal_approx(float(mega_kick.get("accuracy", 0.0)), 75.0), "Megakick: Genauigkeit muss 75 sein")

    var axe_kick: Dictionary = moves.get("axe_kick", {})
    _check(int(axe_kick.get("power", 0)) == 120, "Fersenkick: Stärke muss 120 sein")
    _check(is_equal_approx(float(axe_kick.get("accuracy", 0.0)), 90.0), "Fersenkick: Genauigkeit muss 90 sein")
    _check(is_equal_approx(float(_runtime(axe_kick).get("v22_gap_crash_on_full_failure_fraction", 0.0)), 0.50), "Fersenkick: 50-Prozent-Fehlschlagskosten fehlen")

    var quick_guard: Dictionary = moves.get("quick_guard", {})
    _check(int(quick_guard.get("priority", 0)) == 3, "Rapidschutz: Priorität muss +3 sein")
    _check(bool(quick_guard.get("opening", false)), "Rapidschutz: Runde-0-Freigabe fehlt")
    _check(int(quick_guard.get("ap", 0)) == 8, "Rapidschutz: Timeflow-AP müssen 8 sein")
    _check(str(quick_guard.get("target", "")) == "all_allies", "Rapidschutz: falsche Zielregel")

    var rock_climb: Dictionary = moves.get("rock_climb", {})
    _check(int(rock_climb.get("power", 0)) == 90, "Kraxler: Stärke muss 90 sein")
    _check(_mechanic_float(rock_climb, "v22_gap_confusion_on_connected_hit", "chance") == 0.20, "Kraxler: 20-Prozent-Verwirrung fehlt")

    var soft_boiled: Dictionary = moves.get("soft_boiled", {})
    _check(str(soft_boiled.get("target", "")) == "self", "Weichei: falsche Zielregel")

    var last_resort: Dictionary = moves.get("last_resort", {})
    _check(int(last_resort.get("power", 0)) == 140, "Zuflucht: Stärke muss 140 sein")

    var healing_wish: Dictionary = moves.get("healing_wish", {})
    _check(str(healing_wish.get("target", "")) == "single_ally", "Heilopfer: muss einen anderen Verbündeten wählen")

    var tickle: Dictionary = moves.get("tickle", {})
    _check(str(tickle.get("name", "")) == "Spaßkanone", "Spaßkanone: Projektname driftet")

    var heal_block: Dictionary = moves.get("heal_block", {})
    _check(str(heal_block.get("target", "")) == "all_enemies", "Heilblockade: muss alle Gegner treffen")
    _check(bool(heal_block.get("area", false)), "Heilblockade: area=true fehlt")
    _check(bool(_runtime(heal_block).get("v22_per_target_accuracy", false)), "Heilblockade: getrennte Zielauflösung fehlt")


func _test_last_resort_gate(battle) -> void:
    var actor: Dictionary = {
        "moves": ["last_resort", "mega_punch", "mega_kick", "rock_climb"],
        "v22_gap_distinct_moves_used": []
    }
    _check(not battle._v22_gap_last_resort_ready(actor), "Zuflucht darf vor anderen Attacken nicht bereit sein")
    actor["v22_gap_distinct_moves_used"] = ["mega_punch", "mega_kick"]
    _check(not battle._v22_gap_last_resort_ready(actor), "Zuflucht verlangt bei drei verfügbaren anderen Attacken drei verschiedene Einsätze")
    actor["v22_gap_distinct_moves_used"] = ["mega_punch", "mega_kick", "rock_climb"]
    _check(battle._v22_gap_last_resort_ready(actor), "Zuflucht wird nach drei verschiedenen anderen Attacken nicht freigegeben")

    var short_actor: Dictionary = {
        "moves": ["last_resort", "mega_punch"],
        "v22_gap_distinct_moves_used": ["mega_punch"]
    }
    _check(battle._v22_gap_last_resort_ready(short_actor), "Zuflucht muss bei nur einer anderen verfügbaren Attacke nach deren Einsatz bereit sein")

    var alone_actor: Dictionary = {
        "moves": ["last_resort"],
        "v22_gap_distinct_moves_used": []
    }
    _check(not battle._v22_gap_last_resort_ready(alone_actor), "Zuflucht darf ohne andere verfügbare Attacke nie bereit sein")


func _test_connected_hit_substitute_rule(battle) -> void:
    var actor: Dictionary = {"id": "actor", "side": "player", "alive": true}
    var target: Dictionary = {
        "id": "target", "side": "enemy", "alive": true,
        "hp": 100, "max_hp": 100, "db_substitute_hp": 0,
        "major_status": "", "confused_turns": 0
    }
    battle._v22_gap_target_snapshots = {
        "target": {"target": target, "hp": 100, "substitute_hp": 25}
    }
    _check(battle._v22_gap_any_connected_target(), "Delegator-Schaden muss als verbundener Treffer zählen")
    var effect: float = battle._v22_gap_confusion_on_connected_hit(
        actor, target, {"chance": 1.0}
    )
    _check(is_zero_approx(effect), "Sekundärverwirrung darf nicht durch einen beim Treffer zerstörten Delegator gehen")
    _check(int(target.get("confused_turns", 0)) == 0, "Delegator hat Verwirrung nicht blockiert")


func _test_soft_boiled_curve(battle) -> void:
    var actor: Dictionary = {
        "id": "egg", "side": "player", "alive": true,
        "hp": 40, "max_hp": 100, "special": 75.0,
        "action_serial": 0, "f40_heal_block_expires_before_serial": 0
    }
    var aggro: float = battle._v22_gap_soft_boiled(actor)
    _check(int(actor.get("hp", 0)) == 90, "Weichei: Status 75 muss 50 Prozent Max-KP anfordern")
    _check(is_equal_approx(aggro, 50.0), "Weichei: Aggro muss den tatsächlich geheilten KP entsprechen")

    actor["hp"] = 95
    aggro = battle._v22_gap_soft_boiled(actor)
    _check(int(actor.get("hp", 0)) == 100, "Weichei: Überheilung wurde nicht gekappt")
    _check(is_equal_approx(aggro, 5.0), "Weichei: Überheilung darf keine Aggro erzeugen")


func _test_heal_block_no_refresh(battle) -> void:
    var actor: Dictionary = {"id": "blocker", "side": "player", "alive": true}
    var target: Dictionary = {
        "id": "blocked", "side": "enemy", "alive": true,
        "hp": 100, "max_hp": 100, "action_serial": 4,
        "f40_heal_block_expires_before_serial": 0,
        "protective_guard": false, "db_substitute_hp": 0,
        "db_status_immunities": []
    }
    var first: float = battle._v22_gap_heal_block(actor, target, {"duration_actions": 3})
    _check(int(target.get("f40_heal_block_expires_before_serial", 0)) == 7, "Heilblockade: exakt drei eigene Zielaktionen fehlen")
    _check(first > 0.0, "Heilblockade: tatsächliche Neuaktivierung muss Effekt-Aggro erzeugen")
    var second: float = battle._v22_gap_heal_block(actor, target, {"duration_actions": 3})
    _check(int(target.get("f40_heal_block_expires_before_serial", 0)) == 7, "Heilblockade darf nicht refreshen")
    _check(is_zero_approx(second), "Heilblockade: bereits aktive Sperre darf keine neue Effekt-Aggro erzeugen")


func _test_healing_wish_effect_gate(battle) -> void:
    var actor: Dictionary = {
        "id": "wish", "side": "player", "alive": true,
        "hp": 100, "max_hp": 100, "special": 75.0
    }
    var target: Dictionary = {
        "id": "ally", "side": "player", "alive": true,
        "hp": 25, "max_hp": 100, "major_status": "poison",
        "paralyzed": false, "db_sleep_actions": 0,
        "action_serial": 0, "f40_heal_block_expires_before_serial": 0
    }
    battle._v22_gap_healing_wish_succeeded = false
    var effect: float = battle._v22_gap_healing_wish(actor, target)
    _check(int(target.get("hp", 0)) == 100, "Heilopfer: Status 75 muss durch 2R bis zu 100 Prozent Max-KP heilen")
    _check(str(target.get("major_status", "x")).is_empty(), "Heilopfer: primärer Status wurde nicht entfernt")
    _check(battle._v22_gap_healing_wish_succeeded, "Heilopfer: tatsächliche Wirkung markiert Selbst-KO nicht")
    _check(effect > 75.0, "Heilopfer: Statusentfernung muss zusätzlich zur tatsächlichen Heilung Support-Aggro erzeugen")

    target["hp"] = 100
    target["major_status"] = ""
    battle._v22_gap_healing_wish_succeeded = false
    effect = battle._v22_gap_healing_wish(actor, target)
    _check(is_zero_approx(effect), "Heilopfer: wirkungsloser Einsatz darf keine Effekt-Aggro erzeugen")
    _check(not battle._v22_gap_healing_wish_succeeded, "Heilopfer: wirkungsloser Einsatz darf keinen Selbst-KO markieren")


func _test_quick_guard_block_and_break(battle) -> void:
    var guard_user: Dictionary = {
        "id": "guard", "side": "player", "alive": true, "aggro": 0.0
    }
    var protected: Dictionary = {
        "id": "protected", "side": "player", "alive": true,
        "hp": 100, "max_hp": 100
    }
    var enemy: Dictionary = {"id": "enemy", "side": "enemy", "alive": true}
    battle.combatants = [guard_user, protected, enemy]
    battle.opening_phase_active = true
    battle._v22_gap_quick_guard_by_side = {
        "player": {"source_id": "guard"}
    }

    var priority_move: Dictionary = {
        "id": "priority_test", "priority": 1,
        "mechanics": [{"kind": "damage"}]
    }
    _check(battle._v22_gap_quick_guard_blocks(enemy, protected, priority_move), "Rapidschutz blockiert gegnerische Prioritätsattacke nicht")

    var normal_move: Dictionary = {
        "id": "normal_test", "priority": 0,
        "mechanics": [{"kind": "damage"}]
    }
    _check(not battle._v22_gap_quick_guard_blocks(enemy, protected, normal_move), "Rapidschutz darf normale Attacken nicht blockieren")

    var breaker: Dictionary = {
        "id": "guard_breaker", "priority": 1,
        "mechanics": [{"kind": "db_break_protect"}]
    }
    _check(not battle._v22_gap_quick_guard_blocks(enemy, protected, breaker), "Schutzbrecher darf nicht von Rapidschutz blockiert werden")
    _check(not battle._v22_gap_quick_guard_by_side.has("player"), "Schutzbrecher hat Rapidschutz nicht entfernt")
    battle.opening_phase_active = false


func _runtime(move: Dictionary) -> Dictionary:
    var value: Variant = move.get("runtime", {})
    return value if value is Dictionary else {}


func _mechanic_float(move: Dictionary, kind: String, key: String) -> float:
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return -1.0
    for mechanic_value: Variant in mechanics_value:
        if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == kind:
            return float((mechanic_value as Dictionary).get(key, -1.0))
    return -1.0


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error("V22 gap test: " + message)
