extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_lab_family_refresh_v1.gd")
const SingleTargetAggroRules = preload("res://scripts/battle/single_target_aggro_rules.gd")


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    _assert_rule_contract()
    _assert_active_move_classification(lab)
    _assert_status_single_target_halves(lab)
    _assert_damage_single_target_halves_once(lab)
    _assert_status_miss_does_not_halve(lab)
    _assert_failed_disable_does_not_halve(lab)
    _assert_mimic_does_not_halve_target(lab)
    _assert_night_shade_halves_once(lab)
    _assert_night_shade_immunity_does_not_halve(lab)
    _assert_future_sight_cast_and_impact(lab)
    _assert_payback_retaliation_halves_once(lab)
    _assert_spread_damage_does_not_halve(lab, 1)
    _assert_spread_damage_does_not_halve(lab, 2)
    _assert_all_others_spread_preserves_ally_aggro(lab)

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
    var spread_status: Dictionary = {
        "category":"status", "power":null,
        "target":"all_enemies", "area":true,
        "mechanics":[{"kind":"accuracy_mod"}]
    }
    var custom_damage: Dictionary = {
        "category":"special", "power":null,
        "target":"enemy_highest_aggro", "area":false,
        "mechanics":[], "aggro":{"from_damage":true}
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
    assert(
        not SingleTargetAggroRules.should_reduce(
            spread_status, actor, enemy, true, "success", false, "all_enemies"
        ),
        "Auch reine Flaechen-Statusattacken duerfen keine Ziel-Aggro halbieren."
    )
    assert(
        SingleTargetAggroRules.is_damage_resolution_move(custom_damage),
        "Custom-Schaden mit Aggro.from_damage muss als Schadensaufloesung erkannt werden."
    )


func _assert_active_move_classification(lab) -> void:
    var moves_value: Variant = lab.data.get("moves", {})
    assert(moves_value is Dictionary, "Aktive Attackendaten fehlen.")
    var moves: Dictionary = moves_value
    var audited_spread: int = 0

    for move_id_value: Variant in moves.keys():
        var move_value: Variant = moves.get(move_id_value, {})
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        var target_rule: String = str(move.get("target", ""))
        var structurally_spread: bool = (
            bool(move.get("area", false))
            or target_rule.begins_with("all_")
            or target_rule in ["field", "battlefield", "all_active", "all_others"]
        )
        if not structurally_spread:
            continue
        audited_spread += 1
        assert(
            SingleTargetAggroRules.is_spread_move(move, target_rule),
            "Aktive Flaechenattacke wird von der zentralen Aggro-Regel nicht als Flaeche erkannt: "
            + str(move_id_value)
        )

    assert(audited_spread > 0, "Der aktive Move-Audit hat keine Flaechenattacken gefunden.")


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


func _assert_failed_disable_does_not_halve(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var target: Dictionary = _combatant(lab, "enemy", 0)
    target["aggro"] = 120.0
    target["vulpix_last_successful_move_id"] = ""
    _install_teams(lab, [actor], [target])

    var original: Dictionary = _force_accuracy(lab, "disable", null)
    lab._execute_move(actor, "disable")
    _restore_move(lab, "disable", original)

    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 120.0),
        "Wirkungslos gescheiterter Aussetzer darf die Ziel-Aggro nicht halbieren."
    )


func _assert_mimic_does_not_halve_target(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var target: Dictionary = _combatant(lab, "enemy", 0)
    target["aggro"] = 120.0
    target["db_last_move"] = "thunder_shock"
    _install_teams(lab, [actor], [target])

    var original: Dictionary = _force_accuracy(lab, "mimic", null)
    lab._execute_move(actor, "mimic")
    _restore_move(lab, "mimic", original)

    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 120.0),
        "Mimikry veraendert nur den Anwender und darf deshalb keine Ziel-Aggro halbieren."
    )


func _assert_night_shade_halves_once(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var target: Dictionary = _combatant(lab, "enemy", 0)
    target["aggro"] = 120.0
    target["types"] = ["electric"]
    _install_teams(lab, [actor], [target])

    var hp_before: int = int(target.get("hp", 0))
    var original: Dictionary = _force_accuracy(lab, "night_shade", null)
    lab._execute_move(actor, "night_shade")
    _restore_move(lab, "night_shade", original)

    assert(int(target.get("hp", 0)) < hp_before, "Nachtnebel muss im Test tatsaechlich Schaden verursachen.")
    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 60.0),
        "Custom-Einzelzielschaden Nachtnebel darf Aggro genau einmal halbieren."
    )


func _assert_night_shade_immunity_does_not_halve(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var target: Dictionary = _combatant(lab, "enemy", 0)
    target["aggro"] = 120.0
    target["types"] = ["normal"]
    _install_teams(lab, [actor], [target])

    var hp_before: int = int(target.get("hp", 0))
    var original: Dictionary = _force_accuracy(lab, "night_shade", null)
    lab._execute_move(actor, "night_shade")
    _restore_move(lab, "night_shade", original)

    assert(int(target.get("hp", 0)) == hp_before, "Normal-Ziel muss gegen Nachtnebel immun bleiben.")
    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 120.0),
        "Immuner Nachtnebel darf keine Ziel-Aggro halbieren."
    )


func _assert_future_sight_cast_and_impact(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var target: Dictionary = _combatant(lab, "enemy", 0)
    target["aggro"] = 120.0
    target["types"] = ["electric"]
    _install_teams(lab, [actor], [target])
    lab._cleffa_future_sight_events.clear()

    var original: Dictionary = _force_accuracy(lab, "future_sight", null)
    lab._execute_move(actor, "future_sight")
    _restore_move(lab, "future_sight", original)

    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 120.0),
        "Seher darf beim Vorbereiten noch keine Ziel-Aggro halbieren."
    )
    assert(lab._cleffa_future_sight_events.size() == 1, "Seher muss genau ein verzögertes Ereignis planen.")

    var hp_before: int = int(target.get("hp", 0))
    var event: Dictionary = (lab._cleffa_future_sight_events[0] as Dictionary).duplicate(true)
    lab._cleffa_resolve_future_sight(event)

    assert(int(target.get("hp", 0)) < hp_before, "Seher muss beim spaeteren Einschlag Schaden verursachen.")
    assert(
        is_equal_approx(float(target.get("aggro", 0.0)), 60.0),
        "Seher muss die Ziel-Aggro erst beim erfolgreichen Einzelziel-Einschlag halbieren."
    )
    lab._cleffa_future_sight_events.clear()


func _assert_payback_retaliation_halves_once(lab) -> void:
    var defender: Dictionary = _combatant(lab, "player", 0)
    var attacker: Dictionary = _combatant(lab, "enemy", 0)
    attacker["aggro"] = 120.0
    _install_teams(lab, [defender], [attacker])

    lab._bfam_activate_payback(defender)
    var hp_before: int = int(attacker.get("hp", 0))
    var damage: int = lab._bfam_resolve_payback_retaliation(defender, attacker)

    assert(damage > 0 and int(attacker.get("hp", 0)) < hp_before, "Gegenstoss muss im Test treffen.")
    assert(
        is_equal_approx(float(attacker.get("aggro", 0.0)), 60.0),
        "Automatischer Gegenstoss muss dieselbe einmalige Einzelziel-Aggro-Halbierung nutzen."
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


func _assert_all_others_spread_preserves_ally_aggro(lab) -> void:
    var actor: Dictionary = _combatant(lab, "player", 0)
    var ally: Dictionary = _combatant(lab, "player", 1)
    var enemy: Dictionary = _combatant(lab, "enemy", 0)
    ally["aggro"] = 90.0
    enemy["aggro"] = 140.0
    _install_teams(lab, [actor, ally], [enemy])

    var original: Dictionary = _force_accuracy(lab, "earthquake", null)
    lab._execute_move(actor, "earthquake")
    _restore_move(lab, "earthquake", original)

    assert(
        is_equal_approx(float(ally.get("aggro", 0.0)), 90.0),
        "Eine all-others-Flaechenattacke darf auch die Aggro eines getroffenen Verbuendeten nicht halbieren."
    )
    assert(
        is_equal_approx(float(enemy.get("aggro", 0.0)), 140.0),
        "Eine all-others-Flaechenattacke darf die Aggro eines getroffenen Gegners nicht halbieren."
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
