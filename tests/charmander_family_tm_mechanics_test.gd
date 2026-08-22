extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_charmander_family.gd")
const CHARMANER_FAMILY_MOVE_IDS: Array[String] = [
    "metal_claw","swift","rock_tomb","flame_charge","fling","dragon_tail","dig","brick_break","shadow_claw","fire_punch",
    "rock_slide","dragon_dance","will_o_wisp","dragon_pulse","fire_blast","fire_pledge","outrage","overheat","focus_blast","focus_punch",
    "temper_flare","breaking_swipe","acrobatics","air_cutter","sandstorm","fly","blast_burn","heat_crash","scorching_sands","dragon_cheer"
]

func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)
    _assert_inventory_and_contract(lab)
    _assert_gate1_ap_corrections(lab)
    _assert_charmander_tm031_compatibility(lab)
    _assert_weight_system(lab)
    _assert_semi_invulnerable_states(lab)
    _assert_fling_uses_status(lab)
    _assert_pledge_helpers(lab)
    _assert_dragon_cheer(lab)
    _assert_focus_punch_interrupt(lab)
    _assert_sandstorm_definition(lab)
    _assert_swift_spread_exception(lab)
    print("Glumanda-Familie TM mechanics test: PASS")
    lab.queue_free()
    quit(0)

func _assert_inventory_and_contract(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    assert(moves.size() == 221, "Manifest und Runtime müssen nach dem Raupy-Paket 221 Attacken enthalten.")
    for move_id: String in CHARMANER_FAMILY_MOVE_IDS:
        assert(moves.has(move_id), "Glumanda-Familienattacke fehlt: " + move_id)
        var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss runtime_supported sein.")
        assert(bool(runtime.get("strict_contract", false)), move_id + " muss den V4-Vertrag verwenden.")
        assert(bool(runtime.get("contract_validated", false)), move_id + " muss den MoveContract bestehen.")

func _assert_gate1_ap_corrections(lab) -> void:
    assert(int(lab._move_data("focus_punch").get("ap", 0)) == 5, "Power-Punch muss RPG-AP 5 haben.")
    assert(int(lab._move_data("scorching_sands").get("ap", 0)) == 7, "Brandsand muss RPG-AP 7 haben.")
    assert(int(lab._move_data("acrobatics").get("ap", 0)) == 7, "Akrobatik nutzt bewusst RPG-AP 7.")
    assert(int(lab._move_data("fling").get("power", 0)) == 70, "Schleuder muss feste Stärke 70 haben.")

func _assert_charmander_tm031_compatibility(lab) -> void:
    var species: Dictionary = lab._canonical_pack.get("species", {})
    var charmander_tms: Dictionary = ((species.get("charmander", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {})
    var charmeleon_tms: Dictionary = ((species.get("charmeleon", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {})
    var charizard_tms: Dictionary = ((species.get("charizard", {}) as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {})
    assert(str(charmander_tms.get("TM031", "")) == "metal_claw", "Nur Glumanda muss TM031 Metallklaue lernen können.")
    assert(not charmeleon_tms.has("TM031"), "Glutexo darf TM031 nicht lernen.")
    assert(not charizard_tms.has("TM031"), "Glurak darf TM031 nicht lernen.")

func _assert_weight_system(lab) -> void:
    assert(is_equal_approx(float(lab._cf_weights_kg.get("charmander", 0.0)), 8.5), "Glumanda-Gewicht fehlt.")
    assert(is_equal_approx(float(lab._cf_weights_kg.get("charizard", 0.0)), 90.5), "Glurak-Gewicht fehlt.")
    assert(lab._cf_heat_crash_power(100.0, 60.0) == 40)
    assert(lab._cf_heat_crash_power(100.0, 50.0) == 60)
    assert(lab._cf_heat_crash_power(100.0, 33.0) == 80)
    assert(lab._cf_heat_crash_power(100.0, 25.0) == 100)
    assert(lab._cf_heat_crash_power(100.0, 20.0) == 120)

func _assert_semi_invulnerable_states(lab) -> void:
    var target: Dictionary = lab._make_combatant("enemy",0,{"species_id":"pikachu","level":20})
    lab._tf_set_state(target,"underground",true)
    assert(lab._cf_target_reachable_by_move(target,"earthquake"), "Erdbeben muss unterirdische Ziele treffen.")
    assert(not lab._cf_target_reachable_by_move(target,"flamethrower"), "Normale Attacken dürfen unterirdisch nicht treffen.")
    lab._tf_set_state(target,"underground",false)
    lab._tf_set_state(target,"airborne_fly",true)
    assert(lab._cf_target_reachable_by_move(target,"gust"))
    assert(lab._cf_target_reachable_by_move(target,"twister"))
    assert(lab._cf_target_reachable_by_move(target,"thunder"))
    assert(lab._cf_target_reachable_by_move(target,"hurricane"))
    assert(not lab._cf_target_reachable_by_move(target,"tackle"))

func _assert_fling_uses_status(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player",0,{"species_id":"charmander","level":30})
    var target: Dictionary = lab._make_combatant("enemy",0,{"species_id":"pikachu","level":30})
    actor["attack"] = 1.0
    actor["special"] = 120.0
    target["defense"] = 70.0
    lab._cf_active_move_id = "fling"
    var high_status_damage: int = lab._damage(actor,target,70,"dark","physical")
    actor["special"] = 10.0
    var low_status_damage: int = lab._damage(actor,target,70,"dark","physical")
    lab._cf_active_move_id = ""
    assert(high_status_damage > low_status_damage, "Schleuder muss Status statt Angriff verwenden.")

func _assert_pledge_helpers(lab) -> void:
    assert(lab._cf_pledge_combo_kind("grass","fire") == "sea_of_fire")
    assert(lab._cf_pledge_combo_kind("fire","grass") == "sea_of_fire")
    assert(lab._cf_pledge_combo_kind("grass","water") == "swamp")
    assert(lab._cf_pledge_combo_kind("water","grass") == "swamp")
    assert(lab._cf_pledge_combo_kind("fire","water") == "rainbow")
    assert(lab._cf_pledge_combo_kind("water","fire") == "rainbow")

func _assert_dragon_cheer(lab) -> void:
    var normal: Dictionary = {"types":["fire"]}
    var dragon: Dictionary = {"types":["dragon"]}
    assert(lab._cf_dragon_cheer_stage(normal) == 1)
    assert(lab._cf_dragon_cheer_stage(dragon) == 2)

func _assert_focus_punch_interrupt(lab) -> void:
    var actor: Dictionary = {"cf_focus_punch_pending":true,"cf_focus_punch_interrupted":false}
    lab._cf_mark_focus_punch_interrupted(actor,10)
    assert(bool(actor.get("cf_focus_punch_interrupted",false)), "Direkter Schaden muss Power-Punch unterbrechen.")

func _assert_sandstorm_definition(lab) -> void:
    assert(is_equal_approx(lab.CF_SANDSTORM_DURATION_SECONDS,50.0))
    assert(is_equal_approx(lab.CF_SANDSTORM_PULSE_SECONDS,10.0))
    assert(is_equal_approx(lab.CF_SANDSTORM_DAMAGE_FRACTION,1.0/16.0))

func _assert_swift_spread_exception(lab) -> void:
    var move: Dictionary = lab._move_data("swift")
    assert(str(move.get("target","")) == "all_enemies", "Sternschauer muss alle Gegner treffen.")
    assert(move.get("accuracy",1) == null, "Sternschauer muss ohne normale Genauigkeitsprüfung treffen.")
