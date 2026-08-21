extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_charmander_family.gd")

const CHARMANER_FAMILY_MOVE_IDS: Array[String] = [
    "metal_claw", "swift", "rock_tomb", "flame_charge", "fling",
    "dragon_tail", "dig", "brick_break", "shadow_claw", "fire_punch",
    "rock_slide", "dragon_dance", "will_o_wisp", "dragon_pulse", "fire_blast",
    "fire_pledge", "outrage", "overheat", "focus_blast", "focus_punch",
    "temper_flare", "breaking_swipe", "acrobatics", "air_cutter", "sandstorm",
    "fly", "blast_burn", "heat_crash", "scorching_sands", "dragon_cheer"
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
    var moves_value: Variant = lab.data.get("moves", {})
    assert(moves_value is Dictionary, "Runtime braucht ein moves-Dictionary.")
    var moves: Dictionary = moves_value
    assert(moves.size() == 189, "Manifest und Runtime müssen nach dem Glumanda-Paket 189 Attacken enthalten.")

    for move_id: String in CHARMANER_FAMILY_MOVE_IDS:
        assert(moves.has(move_id), "Neue Glumanda-Familienattacke fehlt: " + move_id)
        var move: Dictionary = moves[move_id]
        var runtime_value: Variant = move.get("runtime", {})
        assert(runtime_value is Dictionary, move_id + " braucht runtime-Daten.")
        var runtime: Dictionary = runtime_value
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss runtime_supported sein.")
        assert(bool(runtime.get("strict_contract", false)), move_id + " muss den V4-Vertrag verwenden.")
        assert(bool(runtime.get("contract_validated", false)), move_id + " muss den MoveContract bestehen.")


func _assert_gate1_ap_corrections(lab) -> void:
    assert(int(lab._move_data("focus_punch").get("ap", 0)) == 5, "Power-Punch muss RPG-AP 5 haben.")
    assert(int(lab._move_data("scorching_sands").get("ap", 0)) == 7, "Brandsand muss RPG-AP 7 haben.")
    assert(int(lab._move_data("acrobatics").get("ap", 0)) == 7, "Akrobatik nutzt bewusst RPG-AP 7.")
    assert(int(lab._move_data("fling").get("power", 0)) == 70, "Schleuder muss feste Stärke 70 haben.")


func _assert_charmander_tm031_compatibility(lab) -> void:
    var species_value: Variant = lab._canonical_pack.get("species", {})
    assert(species_value is Dictionary, "Kanonischer Spezies-Pool fehlt.")
    var species: Dictionary = species_value
    var charmander: Dictionary = species.get("charmander", {})
    var charmeleon: Dictionary = species.get("charmeleon", {})
    var charizard: Dictionary = species.get("charizard", {})

    var charmander_learnset: Dictionary = charmander.get("learnset", {})
    var charmeleon_learnset: Dictionary = charmeleon.get("learnset", {})
    var charizard_learnset: Dictionary = charizard.get("learnset", {})
    var charmander_tms: Dictionary = charmander_learnset.get("tm_hm", {})
    var charmeleon_tms: Dictionary = charmeleon_learnset.get("tm_hm", {})
    var charizard_tms: Dictionary = charizard_learnset.get("tm_hm", {})

    assert(str(charmander_tms.get("TM031", "")) == "metal_claw", "Nur Glumanda muss TM031 Metallklaue lernen können.")
    assert(not charmeleon_tms.has("TM031"), "Glutexo darf in Gen 9 TM031 Metallklaue nicht lernen.")
    assert(not charizard_tms.has("TM031"), "Glurak darf in Gen 9 TM031 Metallklaue nicht lernen.")


func _assert_weight_system(lab) -> void:
    assert(is_equal_approx(float(lab._cf_weights_kg.get("charmander", 0.0)), 8.5), "Glumanda-Gewicht fehlt.")
    assert(is_equal_approx(float(lab._cf_weights_kg.get("charizard", 0.0)), 90.5), "Glurak-Gewicht fehlt.")
    assert(lab._cf_heat_crash_power(100.0, 60.0) == 40, "Brandstempel >50 % muss Stärke 40 sein.")
    assert(lab._cf_heat_crash_power(100.0, 50.0) == 60, "Brandstempel bei 50 % muss Stärke 60 sein.")
    assert(lab._cf_heat_crash_power(100.0, 33.0) == 80, "Brandstempel bis 1/3 muss Stärke 80 sein.")
    assert(lab._cf_heat_crash_power(100.0, 25.0) == 100, "Brandstempel bei 25 % muss Stärke 100 sein.")
    assert(lab._cf_heat_crash_power(100.0, 20.0) == 120, "Brandstempel bei 20 % muss Stärke 120 sein.")


func _assert_semi_invulnerable_states(lab) -> void:
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"pikachu","level":20})
    lab._tf_set_state(target, "underground", true)
    assert(lab._cf_target_reachable_by_move(target, "earthquake"), "Erdbeben muss unterirdische Ziele treffen.")
    assert(not lab._cf_target_reachable_by_move(target, "flamethrower"), "Normale Attacken dürfen unterirdisch nicht treffen.")

    lab._tf_set_state(target, "underground", false)
    lab._tf_set_state(target, "airborne_fly", true)
    assert(lab._cf_target_reachable_by_move(target, "gust"), "Windstoß muss fliegende Ziele treffen.")
    assert(lab._cf_target_reachable_by_move(target, "twister"), "Windhose muss fliegende Ziele treffen.")
    assert(lab._cf_target_reachable_by_move(target, "thunder"), "Donner muss fliegende Ziele treffen.")
    assert(lab._cf_target_reachable_by_move(target, "hurricane"), "Orkan muss fliegende Ziele treffen.")
    assert(not lab._cf_target_reachable_by_move(target, "tackle"), "Normale Attacken dürfen Fliegen-Ziele nicht treffen.")


func _assert_fling_uses_status(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id":"charmander","level":30})
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"pikachu","level":30})
    actor["attack"] = 1.0
    actor["special"] = 120.0
    target["defense"] = 70.0
    actor["types"] = ["dark"]
    target["types"] = ["normal"]
    lab.combatants = [actor, target]

    seed(4242)
    lab._cf_active_move_id = "fling"
    var fling_damage: int = lab._damage(actor, target, 70, "dark", "physical")
    lab._cf_active_move_id = ""

    seed(4242)
    var normal_damage: int = lab._damage(actor, target, 70, "dark", "physical")
    assert(fling_damage > normal_damage, "Schleuder muss für Schaden den Statuswert statt des niedrigen Angriffs verwenden.")


func _assert_pledge_helpers(lab) -> void:
    assert(lab._cf_pledge_combo_kind("grass", "fire") == "fire_field", "Pflanze+Feuer muss Feuermeer ergeben.")
    assert(lab._cf_pledge_combo_kind("fire", "grass") == "fire_field", "Feuer+Pflanze muss Feuermeer ergeben.")
    assert(lab._cf_pledge_combo_kind("fire", "water") == "rainbow", "Feuer+Wasser muss Regenbogen ergeben.")
    assert(lab._cf_pledge_combo_kind("water", "fire") == "rainbow", "Wasser+Feuer muss Regenbogen ergeben.")
    assert(lab._cf_pledge_combo_kind("grass", "water").is_empty(), "Nicht freigegebene Säulenkombo darf hier keinen Effekt erfinden.")


func _assert_dragon_cheer(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id":"charizard","level":50})
    var normal_ally: Dictionary = lab._make_combatant("player", 1, {"species_id":"pikachu","level":50})
    var dragon_ally: Dictionary = lab._make_combatant("player", 2, {"species_id":"charizard","level":50})
    dragon_ally["types"] = ["dragon"]
    lab.player_team = [actor, normal_ally, dragon_ally]
    lab.combatants = [actor, normal_ally, dragon_ally]

    assert(lab._cf_apply_dragon_cheer(actor), "Drachenjubel muss mit gültigen Verbündeten erfolgreich sein.")
    assert(int(actor.get("cf_dragon_cheer_actions", 0)) == 0, "Drachenjubel darf den Anwender nicht buffen.")
    assert(int(normal_ally.get("cf_dragon_cheer_stage", 0)) == 1, "Normaler Verbündeter braucht +1 Volltrefferstufe.")
    assert(int(dragon_ally.get("cf_dragon_cheer_stage", 0)) == 2, "Drachen-Verbündeter braucht +2 Volltrefferstufen.")
    assert(not lab._cf_dragon_cheer_eligible(normal_ally), "Aktiver Drachenjubel darf nicht erneuert werden.")


func _assert_focus_punch_interrupt(lab) -> void:
    var target: Dictionary = lab._make_combatant("player", 0, {"species_id":"charmander","level":30})
    target["cf_focus_punch_active"] = true
    target["db_charge_move"] = "focus_punch"
    target["db_charge_target_id"] = "enemy:0"
    target["hp"] = 90
    lab._cf_finalize_focus_interrupt(target, 100)
    assert(not bool(target.get("cf_focus_punch_active", true)), "Direkter KP-Schaden muss Power-Punch-Fokus beenden.")
    assert(str(target.get("db_charge_move", "")) == "", "Unterbrochener Power-Punch darf nicht mehr automatisch feuern.")

    target["cf_focus_punch_active"] = true
    target["db_charge_move"] = "focus_punch"
    target["hp"] = 100
    lab._cf_finalize_focus_interrupt(target, 100)
    assert(bool(target.get("cf_focus_punch_active", false)), "Ohne echten KP-Verlust muss Power-Punch fokussiert bleiben.")


func _assert_sandstorm_definition(lab) -> void:
    assert(lab.battle_weather.has_weather("sandstorm"), "Zentrales Wettersystem muss Sandsturm kennen.")
    var definition: Dictionary = lab.battle_weather.definition("sandstorm")
    assert(is_equal_approx(float(definition.get("duration_seconds", 0.0)), 50.0), "Sandsturm muss 50 Sekunden aktive Kampfzeit dauern.")
    assert(str(definition.get("duration_mode", "")) == "active_battle_time", "Sandsturm muss die zentrale aktive Kampfzeit verwenden.")

    var rock_target: Dictionary = {"types":["rock"]}
    var ground_target: Dictionary = {"types":["ground"]}
    var steel_target: Dictionary = {"types":["steel"]}
    var normal_target: Dictionary = {"types":["normal"]}
    assert(lab._cf_sandstorm_immune(rock_target), "Gestein muss gegen Sandsturm-Pulse immun sein.")
    assert(lab._cf_sandstorm_immune(ground_target), "Boden muss gegen Sandsturm-Pulse immun sein.")
    assert(lab._cf_sandstorm_immune(steel_target), "Stahl muss gegen Sandsturm-Pulse immun sein.")
    assert(not lab._cf_sandstorm_immune(normal_target), "Normal darf nicht gegen Sandsturm-Pulse immun sein.")


func _assert_swift_spread_exception(lab) -> void:
    lab._cf_spread_move_id = "swift"
    assert(is_equal_approx(lab._timeflow_spread_damage_scale(4), 1.0), "Sternschauer muss volle Stärke pro Ziel behalten.")
    lab._cf_spread_move_id = "rock_slide"
    assert(is_equal_approx(lab._timeflow_spread_damage_scale(2), 0.75), "Andere Flächenattacken behalten die zentrale Spread-Skalierung.")
    lab._cf_spread_move_id = ""
