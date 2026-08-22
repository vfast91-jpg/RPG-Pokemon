extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_rattata_family.gd")
const MoveCategoryLock = preload("res://scripts/battle/move_category_lock.gd")
const MoveRegistry = preload("res://scripts/battle/move_effect_registry.gd")
const NEW_MOVE_IDS: Array[String] = ["taunt", "shock_wave", "charge_beam", "strength"]


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)
    _assert_inventory_and_contracts(lab)
    _assert_family_tm_lists(lab)
    _assert_taunt_category_lock(lab)
    _assert_taunt_ai_filter(lab)
    _assert_shock_wave(lab)
    _assert_charge_beam(lab)
    _assert_strength(lab)
    _assert_active_runtime_chain()
    print("Rattfratz/Rattikarl TM mechanics test: PASS")
    lab.queue_free()
    quit(0)


func _assert_inventory_and_contracts(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    assert(moves.size() == 244, "Runtime muss nach dem Rettan/Arbok-Paket 244 Attacken enthalten.")
    assert(MoveRegistry.is_known_effect("db_block_move_category"))
    for move_id: String in NEW_MOVE_IDS:
        assert(moves.has(move_id), "Rattfratz-Familien-TM fehlt: " + move_id)
        var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)))
        assert(bool(runtime.get("strict_contract", false)))
        assert(bool(runtime.get("contract_validated", false)))


func _assert_family_tm_lists(lab) -> void:
    var species: Dictionary = lab._canonical_pack.get("species", {})
    var rattata_tms: Dictionary = (((species.get("rattata", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    var raticate_tms: Dictionary = (((species.get("raticate", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {}))
    assert(rattata_tms.size() == 29)
    assert(raticate_tms.size() == 34)
    assert(not rattata_tms.values().has("tera_blast") and not raticate_tms.values().has("tera_blast"))
    assert(str(rattata_tms.get("TM012", "")) == "taunt")
    assert(str(rattata_tms.get("TM034", "")) == "shock_wave")
    assert(str(rattata_tms.get("TM057", "")) == "charge_beam")
    assert(str(raticate_tms.get("TM096", "")) == "strength")


func _assert_taunt_category_lock(lab) -> void:
    var taunt: Dictionary = lab._move_data("taunt")
    assert(str(taunt.get("type", "")) == "dark")
    assert(int(taunt.get("ap", 0)) == 5)
    var mechanic: Dictionary = (taunt.get("mechanics", []) as Array)[0]
    assert(str(mechanic.get("kind", "")) == "db_block_move_category")
    assert(int(mechanic.get("duration_actions", 0)) == 3)

    var target: Dictionary = {"action_serial":0}
    MoveCategoryLock.apply(target, "status", 3)
    assert(MoveCategoryLock.blocks(target, "status"))
    assert(not MoveCategoryLock.blocks(target, "physical"))
    target["action_serial"] = 3
    assert(not MoveCategoryLock.blocks(target, "status"))
    target["action_serial"] = 5
    MoveCategoryLock.apply(target, "status", 3)
    MoveCategoryLock.apply(target, "status", 3)
    assert(MoveCategoryLock.remaining_actions(target, "status") == 3)


func _assert_taunt_ai_filter(lab) -> void:
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"raticate", "level":20})
    target["moves"] = ["taunt", "strength"]
    MoveCategoryLock.apply(target, "status", 3)
    var allowed: Array = lab._rattata_allowed_moves(target)
    assert(allowed.size() == 1 and str(allowed[0]) == "strength")


func _assert_shock_wave(lab) -> void:
    var move: Dictionary = lab._move_data("shock_wave")
    assert(int(move.get("power", 0)) == 60)
    assert(move.get("accuracy", 1) == null)
    assert(int(move.get("ap", 0)) == 5)
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"pikachu", "level":20})
    lab._tf_set_state(target, "underground", true)
    assert(not lab._cf_target_reachable_by_move(target, "shock_wave"))
    lab._tf_set_state(target, "underground", false)


func _assert_charge_beam(lab) -> void:
    var move: Dictionary = lab._move_data("charge_beam")
    assert(int(move.get("power", 0)) == 50)
    assert(int(move.get("accuracy", 0)) == 90)
    var runtime: Dictionary = move.get("runtime", {})
    assert(is_equal_approx(float(runtime.get("timeflow_self_attack_buff_chance", 0.0)), 0.70))
    var actor: Dictionary = {
        "id":"player_0","side":"player","alive":true,"special":75,
        "types":["normal"],"action_serial":0,"timed_modifiers":[],"aggro":0.0
    }
    lab._cf_apply_self_modifier(actor, "outgoing_damage_mod", 1.0, "electric", "Ladestrahl")
    var modifiers: Array = actor.get("timed_modifiers", [])
    assert(modifiers.size() == 1)
    assert(is_equal_approx(float((modifiers[0] as Dictionary).get("multiplier", 0.0)), 1.5))


func _assert_strength(lab) -> void:
    var move: Dictionary = lab._move_data("strength")
    assert(str(move.get("type", "")) == "normal")
    assert(str(move.get("category", "")) == "physical")
    assert(int(move.get("power", 0)) == 80)
    assert(int(move.get("accuracy", 0)) == 100)
    assert(int(move.get("ap", 0)) == 6)
    assert(bool(move.get("contact", false)))


func _assert_active_runtime_chain() -> void:
    var route_guard_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_route_result_guard.gd")
    assert(route_guard_text.contains("res://scripts/battle_demo_rattata_family.gd"))
    var rattata_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_rattata_family.gd")
    assert(rattata_text.contains("res://scripts/battle_demo_rettan_arbok_family.gd"), "Rattfratz muss die neue Rettan/Arbok-Schicht mitladen.")
