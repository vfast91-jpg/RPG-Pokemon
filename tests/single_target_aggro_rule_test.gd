extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_lab_family_refresh_v1.gd")
const SingleTargetAggroRules = preload("res://scripts/battle/single_target_aggro_rules.gd")


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    _assert_rule_contract()
    _assert_status_single_target_halves(lab)
    _assert_damage_single_target_halves_once(lab)
    _assert_status_miss_does_not_halve(lab)
    _assert_spread_damage_does_not_halve(lab, 1)
    _assert_spread_damage_does_not_halve(lab, 2)

    print("Central single-target Aggro rule test: PASS")
    lab.queue_free()
    quit(0)


func _assert_rule_contract() -> void:
    var actor: Dictionary = {"id":"player_0", "side":"player"}
    var enemy: Dictionary = {"id":"enemy_0", "side":"enemy", "aggro":100.0}
    var ally: Dictionary = {"id":"player_1", "side":"player", "aggro":100.0}
    var single_status: Dictionary = {
        "category":"status", "power":null,
        "target":"enemy_highest_aggro", "area":false,
        "mechanics":[{"kind":"status", "status":"confusion"}]
    }
    var spread_damage: Dictionary = {
        "category":"special", "power":60,
        "target":"all_enemies", "area":true,
        "mechanics":[{"kind":"damage"}]
    }

    assert(
        SingleTargetAggroRules.should_reduce(
            single_status, actor, enemy, true, "success", false
        ),
        "Erfolgreiche gegnerische Einzelziel-Statusattacken muessen Aggro halbieren."
    )
    assert(
        not SingleTargetAggroRules.should_reduce(
            single_status, actor, ally, true, "success", false
        ),
        "Verbuendete Einzelziele duerfen keine Ziel-Aggro-Halbierung ausloesen."
    )
    assert(
        not SingleTargetAggroRules.should_reduce(
            single_status, actor, enemy, true, "miss", true
        ),
        "Verfehlte Einzelzielattacken duerfen Aggro nicht halbieren."
    )
    assert(
        SingleTargetAggroRules.is_spread_move(spread_damage, "all_enemies"),
        "Eine Flaechenattacke bleibt strukturell Flaeche, unabhaengig von der Zahl lebender Ziele."
    )


func _assert_status_single_target_halves(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var target: Dictionary = _combatant(lab, "enemy", 0)
    target["aggro"] = 120.0
    _install_teams(lab, [actor], [target])

    var original: Dictionary = _force_accuracy(lab, "sweet_kiss", null)
    lab._execute_move(actor, "sweet_kiss")
    _restore_move(lab, "sweet_kiss", original)

    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 60.0),
        "Bitterkuss muss als erfolgreiche reine Einzelziel-Statusattacke die Ziel-Aggro halbieren."
    )


func _assert_damage_single_target_halves_once(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var target: Dictionary = _combatant(lab, "enemy", 0)
    target["aggro"] = 120.0
    _install_teams(lab, [actor], [target])

    var original: Dictionary = _force_accuracy(lab, "thunder_shock", null)
    lab._execute_move(actor, "thunder_shock")
    _restore_move(lab, "thunder_shock", original)

    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 60.0),
        "Einzelziel-Schaden darf die Ziel-Aggro genau einmal halbieren, nicht doppelt."
    )


func _assert_status_miss_does_not_halve(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var target: Dictionary = _combatant(lab, "enemy", 0)
    target["aggro"] = 120.0
    _install_teams(lab, [actor], [target])

    var original: Dictionary = _force_accuracy(lab, "sweet_kiss", 0.0)
    lab._execute_move(actor, "sweet_kiss")
    _restore_move(lab, "sweet_kiss", original)

    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 120.0),
        "Ein verfehlter Bitterkuss darf die Ziel-Aggro nicht halbieren."
    )


func _assert_spread_damage_does_not_halve(lab, enemy_count: int) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var enemies: Array = []
    for index: int in range(enemy_count):
        var target: Dictionary = _combatant(lab, "enemy", index)
        target["aggro"] = 120.0 + float(index * 20)
        enemies.append(target)
    _install_teams(lab, [actor], enemies)

    var expected: Dictionary = {}
    for target_value: Variant in enemies:
        var target: Dictionary = target_value
        expected[str(target.get("id", ""))] = float(target.get("aggro", 0.0))

    var original: Dictionary = _force_accuracy(lab, "swift", null)
    lab._execute_move(actor, "swift")
    _restore_move(lab, "swift", original)

    for target_value: Variant in enemies:
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        assert(
            is_equal_approx(
                float(target.get("aggro", 0.0)),
                float(expected.get(target_id, -1.0))
            ),
            "Flaechenschaden darf Ziel-Aggro nicht halbieren; das gilt auch bei nur einem lebenden Ziel."
        )


func _combatant(lab, side: String, index: int) -> Dictionary:
    var combatant: Dictionary = lab._make_combatant(
        side,
        index,
        {"species_id":"pichu", "level":10}
    )
    # Keep integration targets comfortably alive so _check_end() cannot turn
    # an Aggro assertion into a battle-end side effect.
    combatant["max_hp"] = 5000
    combatant["hp"] = 5000
    combatant["aggro"] = 100.0
    return combatant


func _install_teams(lab, players: Array, enemies: Array) -> void:
    lab.player_team = players
    lab.enemy_team = enemies
    lab.combatants = players + enemies
    lab.battle_active = true
    lab.paused = false
    lab.selected_actor = {}


func _force_accuracy(lab, move_id: String, accuracy: Variant) -> Dictionary:
    var moves_value: Variant = lab.data.get("moves", {})
    assert(moves_value is Dictionary, "Aktive Attackendaten fehlen.")
    var moves: Dictionary = moves_value
    var original: Dictionary = (moves.get(move_id, {}) as Dictionary).duplicate(true)
    assert(not original.is_empty(), "Testattacke fehlt: " + move_id)
    var patched: Dictionary = original.duplicate(true)
    patched["accuracy"] = accuracy
    moves[move_id] = patched
    lab.data["moves"] = moves
    return original


func _restore_move(lab, move_id: String, original: Dictionary) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    moves[move_id] = original
    lab.data["moves"] = moves
