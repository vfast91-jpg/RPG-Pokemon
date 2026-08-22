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
    _assert_taunt_aggro_and_ai_filter(lab)
    _assert_shock_wave(lab)
    _assert_charge_beam_refresh(lab)
    _assert_strength(lab)
    _assert_active_runtime_chain()
    print("Rattfratz/Rattikarl TM mechanics test: PASS")
    lab.queue_free()
    quit(0)


func _assert_inventory_and_contracts(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    assert(moves.size() == 233, "Runtime muss nach dem Rattfratz-Paket 233 Attacken enthalten.")
    assert(MoveRegistry.is_known_effect("db_block_move_category"), "Die zentrale Attackenart-Sperre muss registriert sein.")
    for move_id: String in NEW_MOVE_IDS:
        assert(moves.has(move_id), "Rattfratz-Familien-TM fehlt: " + move_id)
        var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss runtime_supported sein.")
        assert(bool(runtime.get("strict_contract", false)), move_id + " muss strict_contract sein.")
        assert(bool(runtime.get("contract_validated", false)), move_id + " muss den MoveContract bestehen.")


func _assert_family_tm_lists(lab) -> void:
    var species: Dictionary = lab._canonical_pack.get("species", {})
    var rattata: Dictionary = species.get("rattata", {})
    var raticate: Dictionary = species.get("raticate", {})
    var rattata_tms: Dictionary = (rattata.get("learnset", {}) as Dictionary).get("tm_hm", {})
    var raticate_tms: Dictionary = (raticate.get("learnset", {}) as Dictionary).get("tm_hm", {})

    assert(rattata_tms.size() == 29, "Rattfratz muss exakt 29 Nicht-Tera-TMs besitzen.")
    assert(raticate_tms.size() == 34, "Rattikarl muss exakt 34 Nicht-Tera-TMs besitzen.")
    assert(not rattata_tms.values().has("tera_blast") and not raticate_tms.values().has("tera_blast"), "Die Familie darf Tera-Ausbruch nicht enthalten.")
    assert(str(rattata_tms.get("TM012", "")) == "taunt")
    assert(str(rattata_tms.get("TM034", "")) == "shock_wave")
    assert(str(rattata_tms.get("TM057", "")) == "charge_beam")
    assert(str(raticate_tms.get("TM096", "")) == "strength")


func _assert_taunt_category_lock(lab) -> void:
    var taunt: Dictionary = lab._move_data("taunt")
    assert(str(taunt.get("type", "")) == "dark")
    assert(str(taunt.get("category", "")) == "status")
    assert(int(taunt.get("accuracy", 0)) == 100)
    assert(int(taunt.get("original_pp", 0)) == 20)
    assert(int(taunt.get("ap", 0)) == 5)

    var mechanics: Array = taunt.get("mechanics", [])
    assert(mechanics.size() == 1)
    var mechanic: Dictionary = mechanics[0]
    assert(str(mechanic.get("kind", "")) == "db_block_move_category")
    assert(str(mechanic.get("category", "")) == "status")
    assert(int(mechanic.get("duration_actions", 0)) == 3)

    var target: Dictionary = {"action_serial":0}
    MoveCategoryLock.apply(target, "status", 3)
    assert(MoveCategoryLock.blocks(target, "status"), "Verhöhner muss Statusattacken sperren.")
    assert(not MoveCategoryLock.blocks(target, "physical"), "Verhöhner darf Schadensattacken nicht sperren.")
    assert(MoveCategoryLock.remaining_actions(target, "status") == 3)
    target["action_serial"] = 1
    assert(MoveCategoryLock.remaining_actions(target, "status") == 2)
    target["action_serial"] = 2
    assert(MoveCategoryLock.remaining_actions(target, "status") == 1)
    target["action_serial"] = 3
    assert(not MoveCategoryLock.blocks(target, "status"), "Verhöhner muss nach drei eigenen Aktionen enden.")

    target["action_serial"] = 5
    MoveCategoryLock.apply(target, "status", 3)
    MoveCategoryLock.apply(target, "status", 3)
    var locks: Dictionary = target.get(MoveCategoryLock.STATE_KEY, {})
    assert(locks.size() == 1, "Erneuter Verhöhner darf nicht stapeln.")
    assert(MoveCategoryLock.remaining_actions(target, "status") == 3, "Erneuter Verhöhner muss auf drei Aktionen auffrischen.")


func _assert_taunt_aggro_and_ai_filter(lab) -> void:
    var taunt: Dictionary = lab._move_data("taunt")
    var mechanic: Dictionary = (taunt.get("mechanics", []) as Array)[0]
    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id":"rattata", "level":20})
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"raticate", "level":20})
    lab.player_team = [actor]
    lab.enemy_team = [target]
    lab.combatants = [actor, target]

    var expected_one_action_aggro: float = float(target.get("max_hp", 1)) * 0.10
    var first_aggro: float = lab._effect(actor, target, mechanic)
    assert(is_equal_approx(first_aggro, expected_one_action_aggro * 3.0), "Erstes Verhöhner muss genau drei neu erzeugte Sperr-Aktionen als Status-Aggro bewerten.")
    assert(MoveCategoryLock.remaining_actions(target, "status") == 3)

    var same_action_refresh_aggro: float = lab._effect(actor, target, mechanic)
    assert(is_zero_approx(same_action_refresh_aggro), "Identisches Auffrischen ohne zusätzliche Wirkungsdauer darf keine künstliche Zusatz-Aggro erzeugen.")

    target["action_serial"] = 1
    var one_action_refresh_aggro: float = lab._effect(actor, target, mechanic)
    assert(is_equal_approx(one_action_refresh_aggro, expected_one_action_aggro), "Nach einer verbrauchten Zielaktion darf Auffrischen nur die tatsächlich neu hinzugewonnene Aktion bewerten.")

    target["moves"] = ["taunt", "strength"]
    var allowed: Array = lab._rattata_allowed_moves(target)
    assert(allowed.size() == 1 and str(allowed[0]) == "strength", "Die KI muss unter Verhöhner Statusattacken filtern und Schadensattacken behalten.")
    target["moves"] = ["taunt"]
    assert(lab._rattata_allowed_moves(target).is_empty(), "Hat die KI unter Verhöhner nur Statusattacken, muss der Filter leer sein; der Laufzeitpfad fällt dann auf Warten zurück.")


func _assert_shock_wave(lab) -> void:
    var move: Dictionary = lab._move_data("shock_wave")
    assert(str(move.get("type", "")) == "electric")
    assert(str(move.get("category", "")) == "special")
    assert(int(move.get("power", 0)) == 60)
    assert(move.get("accuracy", 1) == null, "Schockwelle muss die zentrale Immer-Treffer-Regel über accuracy=null verwenden.")
    assert(int(move.get("original_pp", 0)) == 20)
    assert(int(move.get("ap", 0)) == 5)
    assert(not bool(move.get("contact", true)))

    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"pikachu", "level":20})
    lab._tf_set_state(target, "underground", true)
    assert(not lab._cf_target_reachable_by_move(target, "shock_wave"), "Schockwelle darf echte Unverwundbarkeit durch Schaufler nicht umgehen.")
    lab._tf_set_state(target, "underground", false)
    lab._tf_set_state(target, "airborne_fly", true)
    assert(not lab._cf_target_reachable_by_move(target, "shock_wave"), "Schockwelle darf echte Unverwundbarkeit durch Fliegen nicht umgehen.")


func _assert_charge_beam_refresh(lab) -> void:
    var move: Dictionary = lab._move_data("charge_beam")
    assert(int(move.get("power", 0)) == 50)
    assert(int(move.get("accuracy", 0)) == 90)
    assert(int(move.get("original_pp", 0)) == 10)
    assert(int(move.get("ap", 0)) == 7)
    var runtime: Dictionary = move.get("runtime", {})
    assert(is_equal_approx(float(runtime.get("timeflow_self_attack_buff_chance", 0.0)), 0.70))
    assert(is_equal_approx(float(runtime.get("timeflow_self_attack_buff_weight", 0.0)), 1.0))

    var actor: Dictionary = {
        "id":"player_0","side":"player","alive":true,"special":75,
        "types":["normal"],"action_serial":0,"timed_modifiers":[],"aggro":0.0
    }
    lab._cf_apply_self_modifier(actor, "outgoing_damage_mod", 1.0, "electric", "Ladestrahl")
    var modifiers: Array = actor.get("timed_modifiers", [])
    assert(modifiers.size() == 1, "Ladestrahl muss einen zentralen Angriffsmodifier erzeugen.")
    assert(is_equal_approx(float((modifiers[0] as Dictionary).get("multiplier", 0.0)), 1.5), "Statuswert 75 muss bei 1×-Skalierung +50 % Angriff ergeben.")
    assert(int((modifiers[0] as Dictionary).get("expires_after_action", -1)) == 3)

    actor["action_serial"] = 1
    lab._cf_apply_self_modifier(actor, "outgoing_damage_mod", 1.0, "electric", "Ladestrahl")
    modifiers = actor.get("timed_modifiers", [])
    assert(modifiers.size() == 1, "Ladestrahl muss auffrischen statt zu stapeln.")
    assert(int((modifiers[0] as Dictionary).get("expires_after_action", -1)) == 4, "Auffrischen muss wieder drei eigene Aktionen geben.")


func _assert_strength(lab) -> void:
    var move: Dictionary = lab._move_data("strength")
    assert(str(move.get("type", "")) == "normal")
    assert(str(move.get("category", "")) == "physical")
    assert(int(move.get("power", 0)) == 80)
    assert(int(move.get("accuracy", 0)) == 100)
    assert(int(move.get("original_pp", 0)) == 15)
    assert(int(move.get("ap", 0)) == 6)
    assert(bool(move.get("contact", false)))
    var mechanics: Array = move.get("mechanics", [])
    assert(mechanics.size() == 1 and str((mechanics[0] as Dictionary).get("kind", "")) == "damage")


func _assert_active_runtime_chain() -> void:
    var route_guard_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_route_result_guard.gd")
    assert(route_guard_text.contains("res://scripts/battle_demo_rattata_family.gd"), "Die Hauptkampf-Runtime muss die Rattfratz-Familienschicht tatsächlich laden.")
