extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_pidgey_family.gd")


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)
    _assert_inventory(lab)
    _assert_family_tm_lists(lab)
    _assert_steel_wing_contract(lab)
    _assert_steel_wing_status_curve(lab)
    _assert_pluck_final(lab)
    print("Taubsi/Tauboga/Tauboss TM mechanics test: PASS")
    lab.queue_free()
    quit(0)


func _assert_inventory(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    assert(moves.size() == 233, "Runtime muss nach dem Rattfratz-Paket 233 Attacken enthalten.")
    assert(moves.has("steel_wing"), "Stahlflügel muss als Runtime-Attacke vorhanden sein.")

    var move: Dictionary = moves["steel_wing"]
    var runtime: Dictionary = move.get("runtime", {})
    assert(bool(runtime.get("runtime_supported", false)), "Stahlflügel muss runtime_supported sein.")
    assert(bool(runtime.get("strict_contract", false)), "Stahlflügel muss strict_contract sein.")
    assert(bool(runtime.get("contract_validated", false)), "Stahlflügel muss den MoveContract bestehen.")


func _assert_family_tm_lists(lab) -> void:
    var species: Dictionary = lab._canonical_pack.get("species", {})
    for pair: Array in [
        ["pidgey", 20],
        ["pidgeotto", 20],
        ["pidgeot", 22]
    ]:
        var mon: Dictionary = species.get(str(pair[0]), {})
        var tms: Dictionary = (mon.get("learnset", {}) as Dictionary).get("tm_hm", {})
        assert(tms.size() == int(pair[1]), str(pair[0]) + " hat falsche Maschinen-Anzahl.")
        assert(str(tms.get("TM047", "")) == "steel_wing", str(pair[0]) + " muss TM047 Stahlflügel lernen können.")


func _assert_steel_wing_contract(lab) -> void:
    var move: Dictionary = lab.data.get("moves", {}).get("steel_wing", {})
    assert(str(move.get("name", "")) == "Stahlflügel")
    assert(str(move.get("type", "")) == "steel")
    assert(str(move.get("category", "")) == "physical")
    assert(int(move.get("power", 0)) == 70)
    assert(int(move.get("accuracy", 0)) == 90)
    assert(int(move.get("original_pp", 0)) == 25)
    assert(int(move.get("rpg_ap", 0)) == 4)
    assert(bool(move.get("contact", false)))

    var scaling: Dictionary = move.get("status_scaling", {})
    assert(bool(scaling.get("uses_statuswert", false)))
    assert(is_equal_approx(float(scaling.get("multiplier", 0.0)), 1.0))
    assert(str(scaling.get("formula", "")) == "R=Status/(75+Status)")

    var runtime: Dictionary = move.get("runtime", {})
    assert(is_equal_approx(float(runtime.get("timeflow_self_defense_buff_chance", 0.0)), 0.10))
    assert(is_equal_approx(float(runtime.get("timeflow_self_defense_buff_weight", 0.0)), 1.0))


func _assert_steel_wing_status_curve(lab) -> void:
    var actor: Dictionary = {
        "id":"player_0",
        "side":"player",
        "alive":true,
        "special":25,
        "types":["normal", "flying"],
        "action_serial":0,
        "timed_modifiers":[],
        "aggro":0.0
    }

    var multiplier: float = lab._cf_status_modifier_for_type(
        actor,
        "incoming_damage_mod",
        -1.0,
        "steel"
    )
    # Status 25 -> R = 25 / (75 + 25) = 0.25. Die zentrale
    # Verteidigungsdarstellung verwendet deshalb den Faktor 1 + R = 1.25.
    assert(is_equal_approx(multiplier, 1.25), "Stahlflügel muss die zentrale 1×-Statuswert-Kurve als Verteidigungsbonus verwenden.")

    lab._cf_apply_self_modifier(actor, "incoming_damage_mod", -1.0, "steel", "Stahlflügel")
    var modifiers: Array = actor.get("timed_modifiers", [])
    assert(modifiers.size() == 1, "Stahlflügel muss genau einen zentralen Verteidigungsmodifier anlegen.")
    var modifier: Dictionary = modifiers[0]
    assert(str(modifier.get("kind", "")) == "incoming_damage_mod")
    assert(is_equal_approx(float(modifier.get("multiplier", 0.0)), 1.25))
    assert(int(modifier.get("expires_after_action", -1)) == 3, "Stahlflügel-Buff muss drei eigene Aktionen halten.")

    assert(is_equal_approx(lab._cf_effect_chance(actor, 0.10), 0.10), "Grundchance von Stahlflügel muss 10 % bleiben.")


func _assert_pluck_final(lab) -> void:
    var move: Dictionary = lab.data.get("moves", {}).get("pluck", {})
    assert(str(move.get("name", "")) == "Pflücker")
    assert(str(move.get("type", "")) == "flying")
    assert(str(move.get("category", "")) == "physical")
    assert(int(move.get("power", 0)) == 60)
    assert(int(move.get("accuracy", 0)) == 100)
    assert(int(move.get("original_pp", 0)) == 20)
    assert(bool(move.get("contact", false)))
    var mechanics: Array = move.get("mechanics", [])
    assert(mechanics.size() == 1 and str((mechanics[0] as Dictionary).get("kind", "")) == "damage", "Pflücker darf keinen Item-/Beerenhook mehr besitzen.")
    var runtime: Dictionary = move.get("runtime", {})
    assert(bool(runtime.get("runtime_supported", false)))
    assert(bool(runtime.get("strict_contract", false)))
    assert(bool(runtime.get("contract_validated", false)))
    assert(not bool(runtime.get("partial", false)), "Pflücker muss im itemfreien Timeflow final sein.")
