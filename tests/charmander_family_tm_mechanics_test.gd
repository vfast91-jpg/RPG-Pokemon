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
    _assert_semi_invulnerable_aggro_targeting(lab)
    _assert_charge_entry_clears_aggro(lab)
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
    assert(moves.size() == 233, "Manifest und Runtime müssen mit dem Rattfratz-Paket 233 Attacken enthalten.")
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
    assert(int(lab._move_data("acrobatics").get("power", 0)) == 90, "Akrobatik muss als verlässliche itemfreie Attacke auf Stärke 90 begrenzt sein.")
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

func _assert_semi_invulnerable_aggro_targeting(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player",0,{"species_id":"charmander","level":30})
    var hidden: Dictionary = lab._make_combatant("enemy",0,{"species_id":"pikachu","level":30})
    var visible: Dictionary = lab._make_combatant("enemy",1,{"species_id":"pikachu","level":30})
    hidden["aggro"] = 100.0
    visible["aggro"] = 20.0
    lab.player_team = [actor]
    lab.enemy_team = [hidden,visible]
    lab.combatants = [actor,hidden,visible]

    lab._tf_set_state(hidden,"airborne_fly",true)
    lab._semi_targeting_move_id = "tackle"
    var normal_targets: Array = lab._targets(actor,"enemy_highest_aggro")
    assert(normal_targets.size() == 1 and str((normal_targets[0] as Dictionary).get("id", "")) == str(visible.get("id", "")), "Normale Attacken müssen ein fliegendes Aggro-Ziel überspringen.")

    lab._semi_targeting_move_id = "gust"
    var gust_targets: Array = lab._targets(actor,"enemy_highest_aggro")
    assert(gust_targets.size() == 1 and str((gust_targets[0] as Dictionary).get("id", "")) == str(hidden.get("id", "")), "Windstoß muss ein Fliegen-Ziel weiterhin auswählen dürfen.")

    lab._tf_set_state(hidden,"airborne_fly",false)
    lab._tf_set_state(hidden,"underground",true)
    lab._semi_targeting_move_id = "tackle"
    normal_targets = lab._targets(actor,"enemy_highest_aggro")
    assert(normal_targets.size() == 1 and str((normal_targets[0] as Dictionary).get("id", "")) == str(visible.get("id", "")), "Normale Attacken müssen ein unterirdisches Aggro-Ziel überspringen.")

    lab._semi_targeting_move_id = "earthquake"
    var quake_targets: Array = lab._targets(actor,"enemy_highest_aggro")
    assert(quake_targets.size() == 1 and str((quake_targets[0] as Dictionary).get("id", "")) == str(hidden.get("id", "")), "Erdbeben muss ein unterirdisches Ziel weiterhin auswählen dürfen.")
    lab._semi_targeting_move_id = ""

func _assert_charge_entry_clears_aggro(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player",0,{"species_id":"charizard","level":40})
    var target: Dictionary = lab._make_combatant("enemy",0,{"species_id":"pikachu","level":40})
    lab.player_team = [actor]
    lab.enemy_team = [target]
    lab.combatants = [actor,target]

    actor["aggro"] = 88.0
    lab._execute_move(actor,"fly")
    assert(str(actor.get("db_charge_move", "")) == "fly", "Fliegen muss nach der ersten Aktion als Ladeangriff gespeichert sein.")
    assert(lab._tf_has_state(actor,"airborne_fly"), "Fliegen muss nach der ersten Aktion den Luftzustand setzen.")
    assert(is_equal_approx(float(actor.get("aggro", -1.0)),0.0), "Fliegen muss beim Hochfliegen die eigene Aggro auf 0 setzen.")

    lab._tf_set_state(actor,"airborne_fly",false)
    actor["db_charge_move"] = ""
    actor["db_charge_target_id"] = ""
    actor["db_charge_firing"] = false
    actor["aggro"] = 77.0
    lab._execute_move(actor,"dig")
    assert(str(actor.get("db_charge_move", "")) == "dig", "Schaufler muss nach der ersten Aktion als Ladeangriff gespeichert sein.")
    assert(lab._tf_has_state(actor,"underground"), "Schaufler muss nach der ersten Aktion den Untergrundzustand setzen.")
    assert(is_equal_approx(float(actor.get("aggro", -1.0)),0.0), "Schaufler muss beim Eingraben die eigene Aggro auf 0 setzen.")

func _assert_fling_uses_status(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player",0,{"species_id":"charmander","level":30})
    var target: Dictionary = lab._make_combatant("enemy",0,{"species_id":"pikachu","level":30})
    actor["attack"] = 1.0
    actor["special"] = 120.0
    target["defense"] = 70.0
    actor["types"] = ["dark"]
    target["types"] = ["normal"]
    seed(4242)
    lab._cf_active_move_id = "fling"
    var fling_damage: int = lab._damage(actor,target,70,"dark","physical")
    lab._cf_active_move_id = ""
    seed(4242)
    var normal_damage: int = lab._damage(actor,target,70,"dark","physical")
    assert(fling_damage > normal_damage, "Schleuder muss den Statuswert statt Angriff verwenden.")

func _assert_pledge_helpers(lab) -> void:
    assert(lab._cf_pledge_combo_kind("grass","fire") == "fire_field")
    assert(lab._cf_pledge_combo_kind("fire","water") == "rainbow")
    assert(lab._cf_pledge_combo_kind("grass","water").is_empty(), "Die Schiggy-Erweiterung darf die Glumanda-Basisklasse nicht rückwirkend verändern.")

func _assert_dragon_cheer(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player",0,{"species_id":"charizard","level":50})
    var normal_ally: Dictionary = lab._make_combatant("player",1,{"species_id":"pikachu","level":50})
    var dragon_ally: Dictionary = lab._make_combatant("player",2,{"species_id":"charizard","level":50})
    dragon_ally["types"] = ["dragon"]
    lab.player_team = [actor,normal_ally,dragon_ally]
    lab.combatants = [actor,normal_ally,dragon_ally]
    assert(lab._cf_apply_dragon_cheer(actor))
    assert(int(normal_ally.get("cf_dragon_cheer_stage",0)) == 1)
    assert(int(dragon_ally.get("cf_dragon_cheer_stage",0)) == 2)

func _assert_focus_punch_interrupt(lab) -> void:
    var target: Dictionary = lab._make_combatant("player",0,{"species_id":"charmander","level":30})
    target["cf_focus_punch_active"] = true
    target["db_charge_move"] = "focus_punch"
    target["hp"] = 90
    lab._cf_finalize_focus_interrupt(target,100)
    assert(not bool(target.get("cf_focus_punch_active",true)))
    assert(str(target.get("db_charge_move","")) == "")

func _assert_sandstorm_definition(lab) -> void:
    assert(lab.battle_weather.has_weather("sandstorm"))
    var definition: Dictionary = lab.battle_weather.definition("sandstorm")
    assert(is_equal_approx(float(definition.get("duration_seconds",0.0)),50.0))
    assert(str(definition.get("duration_mode","")) == "active_battle_time")
    assert(lab._cf_sandstorm_immune({"types":["rock"]}))
    assert(not lab._cf_sandstorm_immune({"types":["normal"]}))

func _assert_swift_spread_exception(lab) -> void:
    lab._cf_spread_move_id = "swift"
    assert(is_equal_approx(lab._timeflow_spread_damage_scale(4),1.0))
    lab._cf_spread_move_id = "rock_slide"
    assert(is_equal_approx(lab._timeflow_spread_damage_scale(2),0.75))
    lab._cf_spread_move_id = ""
