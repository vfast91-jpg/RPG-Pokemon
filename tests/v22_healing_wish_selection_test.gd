extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_stockpile_infobox_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()

    var actor: Dictionary = {
        "id": "wish_user",
        "side": "player",
        "alive": true,
        "hp": 100,
        "max_hp": 100,
        "special": 75.0
    }
    var ally_a: Dictionary = {
        "id": "ally_a",
        "side": "player",
        "alive": true,
        "hp": 100,
        "max_hp": 100,
        "major_status": "",
        "paralyzed": true,
        "db_sleep_actions": 0,
        "action_serial": 0,
        "f40_heal_block_expires_before_serial": 0
    }
    var ally_b: Dictionary = {
        "id": "ally_b",
        "side": "player",
        "alive": true,
        "hp": 50,
        "max_hp": 100,
        "major_status": "",
        "paralyzed": false,
        "db_sleep_actions": 0,
        "action_serial": 0,
        "f40_heal_block_expires_before_serial": 0
    }
    var enemy: Dictionary = {
        "id": "enemy",
        "side": "enemy",
        "alive": true,
        "hp": 100,
        "max_hp": 100
    }

    battle.combatants = [actor, ally_a, ally_b, enemy]
    battle.player_team = [actor, ally_a, ally_b]
    battle.enemy_team = [enemy]

    battle._v22_gap_healing_wish_selected_id = "ally_b"
    var targets: Array = battle._targets(actor, "single_ally")
    _check(targets.size() == 1, "Heilopfer muss genau den gewählten Verbündeten liefern")
    if targets.size() == 1 and targets[0] is Dictionary:
        _check(str((targets[0] as Dictionary).get("id", "")) == "ally_b", "Heilopfer ignoriert die manuelle Verbündetenwahl")

    battle._v22_gap_healing_wish_succeeded = false
    var effect: float = battle._v22_gap_healing_wish(actor, ally_a)
    _check(not bool(ally_a.get("paralyzed", true)), "Heilopfer muss separat gespeicherte Paralyse entfernen")
    _check(battle._v22_gap_healing_wish_succeeded, "Reine Paralyse-Heilung muss den Heilopfer-Selbst-KO freigeben")
    _check(effect > 0.0, "Reine Paralyse-Heilung muss tatsächliche Support-Aggro erzeugen")

    ally_a["paralyzed"] = true
    battle._v22_gap_healing_wish_succeeded = false
    var self_effect: float = battle._v22_gap_healing_wish(actor, actor)
    _check(is_zero_approx(self_effect), "Heilopfer darf den Anwender nicht als Ziel akzeptieren")
    _check(not battle._v22_gap_healing_wish_succeeded, "Ungültiges Selbstziel darf keinen Selbst-KO markieren")

    battle.free()
    if failures == 0:
        print("V22 Healing Wish selection test: PASS")
        quit(0)
    push_error("V22 Healing Wish selection test: %d Fehler" % failures)
    quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error("V22 Healing Wish test: " + message)
