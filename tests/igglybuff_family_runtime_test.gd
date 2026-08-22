extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_igglybuff_family.gd")
const MOVE_PATH: String = "res://data/gen1_moves_runtime_v3_24_igglybuff_family.json"

var failures: int = 0


func _initialize() -> void:
    var move_pack: Dictionary = _read_json(MOVE_PATH)
    var moves_value: Variant = move_pack.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}
    var battle = CurrentBattleScript.new()
    battle.data = {"moves": moves.duplicate(true), "species": {}}

    _test_covet(battle, moves.get("covet", {}))
    _test_round_chain(battle, moves.get("round", {}))
    _test_mimic(battle)
    _test_expanding_force(battle, moves.get("expanding_force", {}))
    _test_psychic_noise(battle, moves.get("psychic_noise", {}))

    battle.free()

    if failures == 0:
        print("Fluffeluff/Pummeluff/Knuddeluff runtime behavior test: PASS")
        quit(0)
    else:
        push_error("Fluffeluff/Pummeluff/Knuddeluff runtime behavior test: %d Fehler" % failures)
        quit(1)


func _test_covet(battle, move: Dictionary) -> void:
    var actor: Dictionary = {
        "id": "covet_actor", "side": "player", "hp": 40, "max_hp": 100,
        "aggro": 5.0, "iggly_heal_block_actions": 0
    }
    battle._iggly_apply_covet_heal(actor, 40, move)
    _check_equal_int(int(actor.get("hp", 0)), 60, "Bezirzer muss 50 % von 40 tatsächlichem Schaden heilen.")
    _check_equal_float(float(actor.get("aggro", 0.0)), 25.0, "Bezirzer muss tatsächliche Heilung als Aggro addieren.")

    actor["hp"] = 40
    actor["aggro"] = 5.0
    actor["iggly_heal_block_actions"] = 2
    battle._iggly_apply_covet_heal(actor, 40, move)
    _check_equal_int(int(actor.get("hp", 0)), 40, "Bezirzer darf unter Heilsperre nicht heilen.")
    _check_equal_float(float(actor.get("aggro", 0.0)), 5.0, "Blockierte Bezirzer-Heilung darf keine Heilungs-Aggro erzeugen.")


func _test_round_chain(battle, move: Dictionary) -> void:
    var actor: Dictionary = {"id": "round_a", "side": "player", "iggly_last_team_move": ""}
    var ally: Dictionary = {"id": "round_b", "side": "player", "iggly_last_team_move": ""}
    battle.player_team = [actor, ally]

    battle._iggly_record_team_move(actor, "round")
    _check(str(actor.get("iggly_last_team_move", "")) == "round", "Kanon muss für den Anwender als letzte Teamaktion registriert werden.")
    _check(str(ally.get("iggly_last_team_move", "")) == "round", "Kanon-Kette muss teamweit weitergegeben werden.")
    _check_equal_int(int(move.get("power", 0)), 60, "Erste Kanon muss Stärke 60 besitzen.")
    var runtime: Dictionary = move.get("runtime", {})
    _check_equal_int(int(runtime.get("chained_power", 0)), 120, "Direkt folgende Kanon muss Stärke 120 verwenden.")

    battle._iggly_record_team_move(ally, "pound")
    _check(str(actor.get("iggly_last_team_move", "")) == "pound", "Eine andere Teamaktion muss die Kanon-Kette beenden.")
    _check(str(ally.get("iggly_last_team_move", "")) == "pound", "Kanon-Kettenbruch muss für das ganze Team gelten.")


func _test_mimic(battle) -> void:
    var actor: Dictionary = {
        "id": "mimic_actor", "side": "player", "aggro": 0.0,
        "iggly_mimic_copy_id": ""
    }
    var target: Dictionary = {"id": "mimic_target", "side": "enemy", "db_last_move": "covet"}

    _check(battle._iggly_mimic_move_is_eligible("covet"), "Bezirzer muss für Mimikry kopierbar sein.")
    _check(not battle._iggly_mimic_move_is_eligible("mimic"), "Mimikry darf sich nicht selbst kopieren.")
    _check(not battle._iggly_mimic_move_is_eligible("copycat"), "Imitator darf von Mimikry nicht kopiert werden.")
    _check(not battle._iggly_mimic_move_is_eligible("metronome"), "Metronom darf von Mimikry nicht kopiert werden.")
    _check(not battle._iggly_mimic_move_is_eligible("sleep_talk"), "Schlafrede darf von Mimikry nicht kopiert werden.")

    battle._iggly_apply_mimic(actor, [target])
    _check(str(actor.get("iggly_mimic_copy_id", "")) == "covet", "Mimikry muss die letzte kopierbare Zielattacke speichern.")
    var replaced: Array = battle._iggly_moves_with_mimic_replacement(actor, ["mimic", "round"])
    _check(replaced.has("covet"), "Die kopierte Attacke muss Mimikry in der Kampfauswahl ersetzen.")
    _check(not replaced.has("mimic"), "Mimikry darf nach erfolgreichem Kopieren nicht zusätzlich auswählbar bleiben.")
    _check(replaced.has("round"), "Andere bekannte Attacken dürfen beim Mimikry-Ersatz nicht verschwinden.")

    actor["iggly_mimic_copy_id"] = ""
    target["db_last_move"] = "copycat"
    battle._iggly_apply_mimic(actor, [target])
    _check(str(actor.get("iggly_mimic_copy_id", "")).is_empty(), "Mimikry muss bei nicht kopierbarer Zielattacke fehlschlagen.")


func _test_expanding_force(battle, move: Dictionary) -> void:
    _check_equal_int(int(move.get("power", 0)), 80, "Flächenmacht muss ohne Psychofeld Stärke 80 besitzen.")
    _check(str(move.get("target", "")) == "enemy_highest_aggro", "Flächenmacht muss ohne Psychofeld ein Einzelziel mit höchster Aggro wählen.")
    _check(not bool(move.get("area", false)), "Flächenmacht darf ohne Psychofeld keine Flächenattacke sein.")
    var runtime: Dictionary = move.get("runtime", {})
    _check_equal_int(int(runtime.get("psychic_terrain_power", 0)), 120, "Flächenmacht muss auf Psychofeld Stärke 120 verwenden.")
    _check(bool(runtime.get("central_area_damage_scaling", false)), "Flächenmacht muss im Psychofeld die zentrale Flächenskalierung verwenden.")

    battle.set_meta("timeflow_terrain", "")
    _check(not battle._iggly_psychic_terrain_is_active(), "Flächenmacht darf ohne Psychofeld keinen Feldbonus erkennen.")
    battle.set_meta("timeflow_terrain", "psychic")
    _check(battle._iggly_psychic_terrain_is_active(), "Flächenmacht muss aktives Psychofeld erkennen.")
    var grounded_actor: Dictionary = {"types": ["normal", "fairy"], "tf_states": {}}
    _check(battle._cleffa_is_grounded(grounded_actor), "Ein normales bodengebundenes Pokémon muss den Psychofeld-Bonus erhalten können.")
    battle.set_meta("timeflow_terrain", "")


func _test_psychic_noise(battle, move: Dictionary) -> void:
    var actor: Dictionary = {"id": "noise_actor", "side": "player", "aggro": 0.0}
    var target: Dictionary = {
        "id": "noise_target", "side": "enemy", "hp": 80, "max_hp": 100,
        "aggro": 0.0, "iggly_heal_block_actions": 0
    }
    battle.combatants = [actor, target]
    var hp_before: Dictionary = {"noise_target": 100}

    battle._iggly_apply_psychic_noise(actor, [target], hp_before, move)
    _check_equal_int(int(target.get("iggly_heal_block_actions", 0)), 3, "Psycholärm muss nach erfolgreichem Treffer drei eigene Aktionen Heilsperre setzen.")
    _check_equal_float(float(actor.get("aggro", 0.0)), 3.0, "Psycholärm muss für die angewandte Heilsperre taktische Aggro erzeugen.")

    actor["aggro"] = 3.0
    battle._iggly_apply_psychic_noise(actor, [target], hp_before, move)
    _check_equal_int(int(target.get("iggly_heal_block_actions", 0)), 3, "Psycholärm darf eine aktive Heilsperre nicht erneuern.")
    _check_equal_float(float(actor.get("aggro", 0.0)), 3.0, "Nicht erneuerte Heilsperre darf keine zusätzliche Status-Aggro erzeugen.")

    target["hp"] = 95
    battle._iggly_revert_blocked_healing(actor, {"noise_actor": 100, "noise_target": 80}, float(actor.get("aggro", 0.0)))
    _check_equal_int(int(target.get("hp", 0)), 80, "Psycholärm-Heilsperre muss KP-Wiederherstellung rückgängig machen.")

    battle._iggly_consume_heal_block_action(target)
    _check_equal_int(int(target.get("iggly_heal_block_actions", 0)), 2, "Nach einer eigenen Aktion müssen zwei Heilsperren-Aktionen übrig bleiben.")
    battle._iggly_consume_heal_block_action(target)
    battle._iggly_consume_heal_block_action(target)
    _check_equal_int(int(target.get("iggly_heal_block_actions", 0)), 0, "Heilsperre muss nach drei eigenen Aktionen enden.")

    target["iggly_heal_block_actions"] = 2
    var tokens: Array[String] = battle._status_tokens(target)
    _check(tokens.has("🔊 HEILSPERRE 2"), "Aktive Psycholärm-Heilsperre muss in der Statusanzeige sichtbar sein.")

    var miss_target: Dictionary = {"id": "miss_target", "hp": 100, "iggly_heal_block_actions": 0}
    battle._iggly_apply_psychic_noise(actor, [miss_target], {"miss_target": 100}, move)
    _check_equal_int(int(miss_target.get("iggly_heal_block_actions", 0)), 0, "Ohne tatsächlichen Schaden darf Psycholärm keine Heilsperre setzen.")


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        _fail("Datei fehlt: " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        _fail("JSON konnte nicht gelesen werden: " + path)
        return {}
    return parsed as Dictionary


func _check(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _check_equal_int(actual: int, expected: int, message: String) -> void:
    if actual != expected:
        _fail(message + " Erwartet %d, erhalten %d." % [expected, actual])


func _check_equal_float(actual: float, expected: float, message: String) -> void:
    if not is_equal_approx(actual, expected):
        _fail(message + " Erwartet %.2f, erhalten %.2f." % [expected, actual])


func _fail(message: String) -> void:
    failures += 1
    push_error(message)
