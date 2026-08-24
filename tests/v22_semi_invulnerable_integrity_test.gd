extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_v22_semi_invulnerable_integrity_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()

    _test_smack_down_cancels_air_charge(battle)
    _test_bounce_uses_shared_air_contract(battle)
    _test_phantom_force_slot_contract(battle)

    battle.free()
    if failures == 0:
        print("V22 semi-invulnerable integrity test: PASS")
        quit(0)
    push_error("V22 semi-invulnerable integrity test: %d Fehler" % failures)
    quit(1)


func _test_smack_down_cancels_air_charge(battle) -> void:
    for move_id: String in ["fly", "bounce"]:
        var target: Dictionary = {
            "db_charge_move": move_id,
            "db_charge_target_id": "old_target",
            "db_charge_firing": true,
            "v22_charge_target_side": "enemy",
            "v22_charge_target_index": 1,
            "v22_charge_target_original_id": "old_target"
        }
        _check(battle._v22_cancel_air_charge(target), "Katapult muss " + move_id + " abbrechen.")
        _check(str(target.get("db_charge_move", "x")).is_empty(), move_id + ": Charge blieb aktiv.")
        _check(str(target.get("db_charge_target_id", "x")).is_empty(), move_id + ": Legacy-Ziel blieb gespeichert.")
        _check(not bool(target.get("db_charge_firing", true)), move_id + ": db_charge_firing blieb aktiv.")
        _check(not target.has("v22_charge_target_side"), move_id + ": V22-Zielseite blieb gespeichert.")
        _check(not target.has("v22_charge_target_index"), move_id + ": V22-Zielposition blieb gespeichert.")
        _check(not target.has("v22_charge_target_original_id"), move_id + ": V22-Originalziel blieb gespeichert.")

    var dig_target: Dictionary = {"db_charge_move": "dig", "db_charge_target_id": "target"}
    _check(not battle._v22_cancel_air_charge(dig_target), "Katapult darf Schaufler nicht abbrechen.")
    _check(str(dig_target.get("db_charge_move", "")) == "dig", "Schaufler wurde versehentlich gelöscht.")


func _test_bounce_uses_shared_air_contract(battle) -> void:
    var move: Dictionary = battle._move_data("bounce")
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    _check(bool(runtime.get("charge_then_fire", false)), "Sprungfeder muss zweiphasig sein.")
    _check(str(runtime.get("timeflow_charge_state", "")) == "airborne_fly", "Sprungfeder nutzt nicht den zentralen Luftzustand.")

    var target: Dictionary = {"id":"air_target", "side":"enemy", "index":0, "alive":true}
    battle._tf_set_state(target, "airborne_fly", true)
    for move_id: String in ["gust", "twister", "thunder", "hurricane", "smack_down"]:
        _check(battle._cf_target_reachable_by_move(target, move_id), move_id + " muss ein Sprungfeder-Luftziel erreichen.")
    _check(not battle._cf_target_reachable_by_move(target, "tackle"), "Normale Attacken dürfen Sprungfeder nicht erreichen.")


func _test_phantom_force_slot_contract(battle) -> void:
    var move: Dictionary = battle._move_data("phantom_force")
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    _check(bool(runtime.get("charge_then_fire", false)), "Phantomkraft muss zweiphasig sein.")
    _check(str(runtime.get("timeflow_charge_state", "")) == "phantom_hidden", "Phantomkraft: phantom_hidden fehlt.")
    _check(bool(runtime.get("f30_break_protect_on_fire", false)), "Phantomkraft: Schutzschild-Durchbruch fehlt.")

    var actor: Dictionary = {"id":"actor", "side":"player", "index":0, "alive":true}
    var replacement: Dictionary = {"id":"replacement", "side":"enemy", "index":1, "alive":true}
    battle.combatants = [actor, replacement]
    var targets: Array = battle._v22_locked_slot_targets(actor, "phantom_force", "enemy", 1)
    _check(targets.size() == 1 and targets[0] == replacement, "Phantomkraft muss den aktuellen Bewohner des gespeicherten Zielplatzes treffen.")

    replacement["alive"] = false
    targets = battle._v22_locked_slot_targets(actor, "phantom_force", "enemy", 1)
    _check(targets.is_empty(), "Phantomkraft darf bei leerem gespeicherten Platz nicht retargeten.")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
