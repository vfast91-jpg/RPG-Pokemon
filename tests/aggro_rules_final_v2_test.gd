extends SceneTree

const Rules = preload("res://scripts/battle/aggro_rules.gd")
const ActiveBattle = preload("res://scripts/battle_demo_aggro_rules_final_v2.gd")


func _initialize() -> void:
    var level_50: Dictionary = {"level": 50}
    assert(is_equal_approx(Rules.level_basis(level_50), 100.0))
    assert(is_equal_approx(Rules.status_application(level_50, "burn"), 75.0))
    assert(is_equal_approx(Rules.status_application(level_50, "poison"), 60.0))
    assert(is_equal_approx(Rules.status_application(level_50, "bad_poison"), 90.0))
    assert(is_equal_approx(Rules.status_application(level_50, "sleep", 2), 100.0))
    assert(is_equal_approx(Rules.status_application(level_50, "confusion", 3), 75.0))
    assert(is_equal_approx(Rules.status_cleanse(level_50, "sleep", 2), 50.0))
    assert(is_equal_approx(Rules.direct_atb_removal(level_50, 40.0), 40.0))
    assert(is_equal_approx(Rules.partial_control(level_50, 4), 50.0))
    assert(is_equal_approx(Rules.utility_effect(level_50), 25.0))

    assert(is_equal_approx(Rules.spread_multiplier(1), 1.0))
    assert(is_equal_approx(Rules.spread_multiplier(2), 0.75))
    assert(is_equal_approx(Rules.spread_multiplier(3), 0.60))
    assert(is_equal_approx(Rules.spread_multiplier(4), 0.50))

    var defense_after: Array = [{
        "kind": "incoming_damage_mod",
        "multiplier": 1.5,
        "expires_after_action": 3
    }]
    assert(is_equal_approx(
        Rules.modifier_transition(level_50, 0, [], defense_after, true),
        50.0
    ))

    var attack_after: Array = [{
        "kind": "outgoing_damage_mod",
        "multiplier": 1.5,
        "expires_after_action": 3
    }]
    assert(is_equal_approx(
        Rules.modifier_transition(level_50, 0, [], attack_after, true),
        75.0
    ))
    assert(is_zero_approx(
        Rules.modifier_transition(level_50, 0, [], attack_after, false)
    ), "Ein gegnerischer Buff darf dem Anwender keine Wirkungs-Aggro geben.")

    var immunity_after: Array = [{
        "status": "major_status",
        "expires_after_action": 3
    }]
    assert(is_equal_approx(
        Rules.status_protection_transition(level_50, 0, [], immunity_after),
        75.0
    ))

    var active_stack = load("res://scripts/battle_demo_aggro_rules_final_v2.gd")
    assert(active_stack != null, "Die finale Aggro-Schicht muss ladbar sein.")
    var main_scene_text: String = FileAccess.get_file_as_string("res://main.tscn")
    assert(main_scene_text.contains("battle_demo_aggro_rules_final_v2.gd"))

    for level: int in [5, 10, 25, 50, 70, 100]:
        var target: Dictionary = {"level": level}
        assert(Rules.status_application(target, "poison") > 0.0)
        assert(Rules.status_application(target, "sleep", 3) <= Rules.level_basis(target) * 1.5)

    _assert_stun_spore_miss_has_no_aggro()
    _assert_unchanged_paralysis_has_no_aggro()

    print("Final Aggro rules v2 test: PASS")
    quit(0)


func _assert_stun_spore_miss_has_no_aggro() -> void:
    var battle = ActiveBattle.new()
    root.add_child(battle)
    var actor: Dictionary = battle._make_combatant(
        "player", 0, {"species_id":"tangela", "level":25}
    )
    var target: Dictionary = battle._make_combatant(
        "enemy", 0, {"species_id":"pichu", "level":25}
    )
    actor["max_hp"] = 5000
    actor["hp"] = 5000
    target["max_hp"] = 5000
    target["hp"] = 5000
    actor["aggro"] = 137.25
    target["aggro"] = 211.5
    _install_teams(battle, [actor], [target])

    var moves: Dictionary = battle.data.get("moves", {})
    var original: Dictionary = (moves.get("stun_spore", {}) as Dictionary).duplicate(true)
    assert(not original.is_empty(), "Stachelspore fehlt in den aktiven Attackendaten.")
    var forced_miss: Dictionary = original.duplicate(true)
    forced_miss["accuracy"] = 0.0
    moves["stun_spore"] = forced_miss
    battle.data["moves"] = moves

    var actor_aggro_before: float = float(actor.get("aggro", 0.0))
    var target_aggro_before: float = float(target.get("aggro", 0.0))
    battle._execute_move(actor, "stun_spore")

    assert(is_equal_approx(float(actor.get("aggro", 0.0)), actor_aggro_before),
        "Eine verfehlte Stachelspore darf dem Anwender keine Aggro geben.")
    assert(is_equal_approx(float(target.get("aggro", 0.0)), target_aggro_before),
        "Eine verfehlte Stachelspore darf die Ziel-Aggro nicht halbieren.")
    assert(not bool(target.get("paralyzed", false)),
        "Eine verfehlte Stachelspore darf keine Paralyse anwenden.")
    assert(str(actor.get("tf_last_move_outcome", "")) == "miss",
        "Der vollständige Angriffspfad muss Stachelspore als Fehlschlag erkennen.")

    moves["stun_spore"] = original
    battle.data["moves"] = moves
    battle.queue_free()


func _assert_unchanged_paralysis_has_no_aggro() -> void:
    var battle = ActiveBattle.new()
    root.add_child(battle)
    var actor: Dictionary = battle._make_combatant(
        "player", 0, {"species_id":"tangela", "level":25}
    )
    var target: Dictionary = battle._make_combatant(
        "enemy", 0, {"species_id":"pichu", "level":25}
    )
    target["paralyzed"] = true
    _install_teams(battle, [actor], [target])

    var gained: float = battle._effect(
        actor,
        target,
        {"kind":"status", "status":"paralysis", "chance":1.0}
    )
    assert(is_zero_approx(gained),
        "Eine wirkungslose erneute Paralyse darf keine Wirkungs-Aggro geben.")
    battle.queue_free()


func _install_teams(battle, players: Array, enemies: Array) -> void:
    battle.player_team = players
    battle.enemy_team = enemies
    battle.combatants = players + enemies
    battle.battle_active = true
    battle.paused = false
    battle.selected_actor = {}
