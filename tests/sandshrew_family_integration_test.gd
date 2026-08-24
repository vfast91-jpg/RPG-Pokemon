extends SceneTree

const MoveContractScript = preload("res://scripts/battle/move_contract.gd")
const SandRuntimeScript = preload("res://scripts/battle_demo_database_sandshrew_family.gd")
const SandIntegrityScript = preload("res://scripts/battle_demo_sandshrew_hit_aggro_integrity_v1.gd")

const SPECIES_PACK_PATH: String = "res://data/gen1_species_v3_sandshrew_family_v1.json"
const MOVE_PACK_PATH: String = "res://data/gen1_moves_runtime_v3_19_sandshrew_family_tms.json"
const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v3.json"
const META_PATH: String = "res://data/gen1_database_meta_v3.json"

const REQUIRED_MOVES: Array[String] = [
    "defense_curl","rollout","crush_claw","fury_swipes","sand_tomb",
    "low_kick","spikes","stealth_rock","stone_edge","high_horsepower"
]


func _initialize() -> void:
    _test_species_and_playable_registration()
    _test_move_pack_contracts()
    _test_runtime_helpers()
    _test_hit_followup_and_binding_aggro_integrity()
    _test_active_chain_and_assets()

    print("Sandan/Sandamer family integration test: PASS")
    quit(0)


func _test_species_and_playable_registration() -> void:
    var pack: Dictionary = _read_json(SPECIES_PACK_PATH)
    var species: Dictionary = pack.get("species", {})
    assert(species.has("sandshrew"))
    assert(species.has("sandslash"))

    var sandshrew: Dictionary = species.get("sandshrew", {})
    var sandslash: Dictionary = species.get("sandslash", {})
    var sandshrew_stats: Dictionary = sandshrew.get("base_stats", {})
    var sandslash_stats: Dictionary = sandslash.get("base_stats", {})

    assert(int(sandshrew_stats.get("hp", 0)) == 50)
    assert(int(sandshrew_stats.get("attack", 0)) == 65)
    assert(int(sandshrew_stats.get("defense", 0)) == 75)
    assert(int(sandshrew_stats.get("special", 0)) == 30)
    assert(int(sandshrew_stats.get("speed", 0)) == 40)

    assert(int(sandslash_stats.get("hp", 0)) == 75)
    assert(int(sandslash_stats.get("attack", 0)) == 95)
    assert(int(sandslash_stats.get("defense", 0)) == 110)
    assert(int(sandslash_stats.get("special", 0)) == 30)
    assert(int(sandslash_stats.get("speed", 0)) == 65)

    var evolution: Dictionary = sandshrew.get("evolution", {})
    assert(str(evolution.get("evolves_into", "")) == "sandslash")
    assert(int(evolution.get("evolution_level", 0)) == 22)
    assert(bool(evolution.get("mandatory", false)))

    var sandshrew_learnset: Dictionary = sandshrew.get("learnset", {})
    var sandslash_learnset: Dictionary = sandslash.get("learnset", {})
    assert(((sandshrew_learnset.get("level_up", {}) as Dictionary).get("1", []) as Array).has("defense_curl"))
    assert(((sandshrew_learnset.get("level_up", {}) as Dictionary).get("9", []) as Array).has("rollout"))
    assert((sandslash_learnset.get("evolution_moves", []) as Array).has("crush_claw"))
    assert(((sandslash_learnset.get("level_up", {}) as Dictionary).get("26", []) as Array).has("fury_swipes"))
    assert(((sandshrew_learnset.get("tm_hm", {}) as Dictionary).size()) == 49)
    assert(((sandslash_learnset.get("tm_hm", {}) as Dictionary).size()) == 54)

    var meta: Dictionary = _read_json(META_PATH)
    var route_roots: Array = meta.get("route_roots", [])
    assert(route_roots.has("sandshrew"), "Sandan muss im Kampflabor als Basislinie auswählbar sein.")

    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    assert(int(manifest.get("species_count", 0)) == 30)
    assert(int(manifest.get("move_count", 0)) == 266)
    assert(int(manifest.get("route_root_count", 0)) == 11)


func _test_move_pack_contracts() -> void:
    var pack: Dictionary = _read_json(MOVE_PACK_PATH)
    var moves: Dictionary = pack.get("moves", {})
    assert(moves.size() == 10)

    for move_id: String in REQUIRED_MOVES:
        assert(moves.has(move_id), "Sandan-Familienattacke fehlt: " + move_id)
        var move: Dictionary = moves.get(move_id, {})
        var runtime: Dictionary = move.get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)))
        assert(bool(runtime.get("strict_contract", false)))

        var report: Dictionary = MoveContractScript.validate_move(move_id, move, true)
        if not bool(report.get("ok", false)):
            push_error(move_id + " verletzt den Strict-V4-Vertrag: " + str(report.get("errors", [])))
        assert(bool(report.get("ok", false)))

    var rollout: Dictionary = moves.get("rollout", {})
    assert(int(rollout.get("ap", 0)) == 5)
    assert((rollout.get("runtime", {}) as Dictionary).get("power_chain", []) == [30,60,120,240,480])

    var fury_swipes: Dictionary = moves.get("fury_swipes", {})
    var multi_hit: Dictionary = (fury_swipes.get("runtime", {}) as Dictionary).get("multi_hit", {})
    assert(multi_hit.get("weights", []) == [3,3,1,1])

    var crush_claw: Dictionary = moves.get("crush_claw", {})
    var crush_mechanics: Array = crush_claw.get("mechanics", [])
    assert(crush_mechanics.size() == 2)
    assert(str((crush_mechanics[1] as Dictionary).get("kind", "")) == "db_chance_mechanic")
    assert(is_equal_approx(float((crush_mechanics[1] as Dictionary).get("chance", 0.0)), 0.5))

    var sand_tomb: Dictionary = moves.get("sand_tomb", {})
    var mechanics: Array = sand_tomb.get("mechanics", [])
    assert(mechanics.size() == 2)
    assert(str((mechanics[1] as Dictionary).get("kind", "")) == "binding")
    assert(int((mechanics[1] as Dictionary).get("min_ticks", 0)) == 4)
    assert(int((mechanics[1] as Dictionary).get("max_ticks", 0)) == 5)
    assert(is_equal_approx(float((mechanics[1] as Dictionary).get("damage_fraction", 0.0)), 1.0 / 8.0))

    assert(bool(((moves.get("stone_edge", {}) as Dictionary).get("runtime", {}) as Dictionary).get("high_crit", false)))


func _test_runtime_helpers() -> void:
    var runtime = SandRuntimeScript.new()

    assert(runtime._sand_weight_power(9.9) == 20)
    assert(runtime._sand_weight_power(12.0) == 40)
    assert(runtime._sand_weight_power(29.5) == 60)
    assert(runtime._sand_weight_power(75.0) == 80)
    assert(runtime._sand_weight_power(150.0) == 100)
    assert(runtime._sand_weight_power(200.0) == 120)

    assert(runtime._sand_rollout_power_for_step(0, false) == 30)
    assert(runtime._sand_rollout_power_for_step(1, false) == 60)
    assert(runtime._sand_rollout_power_for_step(4, false) == 480)
    assert(runtime._sand_rollout_power_for_step(0, true) == 60)
    assert(runtime._sand_rollout_power_for_step(4, true) == 960)

    assert(is_equal_approx(runtime._sand_spikes_fraction(1), 1.0 / 8.0))
    assert(is_equal_approx(runtime._sand_spikes_fraction(2), 1.0 / 6.0))
    assert(is_equal_approx(runtime._sand_spikes_fraction(3), 1.0 / 4.0))

    runtime.free()


func _test_hit_followup_and_binding_aggro_integrity() -> void:
    var runtime = SandIntegrityScript.new()

    assert(runtime._sand_followup_requires_connected_hit("crush_claw", "db_chance_mechanic"))
    assert(runtime._sand_followup_requires_connected_hit("sand_tomb", "binding"))
    assert(not runtime._sand_followup_requires_connected_hit("sand_tomb", "damage"))

    var target: Dictionary = {
        "id": "enemy_0",
        "alive": true,
        "hp": 100,
        "max_hp": 100,
        "db_substitute_hp": 0,
        "binding_effect": {},
        "timed_modifiers": []
    }
    runtime._sand_followup_snapshots = {
        "enemy_0": {
            "target": target,
            "hp": 100,
            "substitute_hp": 0
        }
    }

    # Protection/type immunity: no real HP or Delegator-HP loss -> no follow-up.
    assert(not runtime._sand_followup_connected(target))
    runtime._sand_followup_move_id = "crush_claw"
    assert(is_equal_approx(runtime._effect({}, target, {
        "kind": "db_chance_mechanic",
        "chance": 1.0,
        "mechanic": {"kind": "incoming_damage_mod", "multiplier": 1.2}
    }), 0.0))
    assert((target.get("timed_modifiers", []) as Array).is_empty())

    # A normal connected damaging hit unlocks the follow-up.
    target["hp"] = 80
    assert(runtime._sand_followup_connected(target))

    # Damage absorbed by Delegator still counts as a connected hit. The existing
    # central Delegator interceptor is then responsible for blocking the debuff.
    target["hp"] = 100
    target["db_substitute_hp"] = 10
    runtime._sand_followup_snapshots = {
        "enemy_0": {
            "target": target,
            "hp": 100,
            "substitute_hp": 25
        }
    }
    assert(runtime._sand_followup_connected(target))

    # Binding setup no longer awards the inherited flat +4 Aggro. Its real
    # residual damage is credited exactly when the tick happens.
    var actor: Dictionary = {"side": "player", "index": 0, "aggro": 7.0}
    var bind_target: Dictionary = {"alive": true, "binding_effect": {}}
    assert(is_equal_approx(runtime._apply_binding(actor, bind_target, {
        "kind": "binding",
        "min_ticks": 4,
        "max_ticks": 4,
        "damage_fraction": 0.125
    }), 0.0))
    assert(not (bind_target.get("binding_effect", {}) as Dictionary).is_empty())

    assert(runtime._credit_actual_binding_damage_aggro(actor, 100, 88) == 12)
    assert(is_equal_approx(float(actor.get("aggro", 0.0)), 19.0))
    assert(runtime._credit_actual_binding_damage_aggro(actor, 88, 88) == 0)
    assert(is_equal_approx(float(actor.get("aggro", 0.0)), 19.0))

    runtime.free()


func _test_active_chain_and_assets() -> void:
    assert(ResourceLoader.exists("res://assets/monsters/Sandan.png"))
    assert(ResourceLoader.exists("res://assets/monsters/Sandamer.png"))
    assert(ResourceLoader.exists("res://scripts/battle_demo_database_sandshrew_family.gd"))
    assert(ResourceLoader.exists("res://scripts/battle_demo_sandshrew_hit_aggro_integrity_v1.gd"))

    var active_chain: String = FileAccess.get_file_as_string("res://scripts/battle_demo_type_help_button_polish.gd")
    assert(active_chain.contains("res://scripts/battle_demo_database_sandshrew_family.gd"))

    var main_scene: String = FileAccess.get_file_as_string("res://main.tscn")
    assert(main_scene.contains("res://scripts/battle_demo_sandshrew_hit_aggro_integrity_v1.gd"))

    var weights: Dictionary = _read_json("res://data/gen1_species_weights_v1.json").get("weights_kg", {})
    assert(is_equal_approx(float(weights.get("sandshrew", 0.0)), 12.0))
    assert(is_equal_approx(float(weights.get("sandslash", 0.0)), 29.5))


func _read_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
