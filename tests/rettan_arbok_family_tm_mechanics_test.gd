extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_rattata_family.gd")
const MoveTagLock = preload("res://scripts/battle/move_tag_lock.gd")
const MoveApOverride = preload("res://scripts/battle/move_ap_override.gd")
const MoveRegistry = preload("res://scripts/battle/move_effect_registry.gd")

const NEW_MOVE_IDS: Array[String] = [
    "poison_tail","snarl","psychic_fangs","leech_life","spite","lash_out",
    "scale_shot","sludge_wave","skitter_smack","pain_split","throat_chop"
]


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)
    _assert_inventory_and_contracts(lab)
    _assert_family_tm_lists(lab)
    _assert_groll(lab)
    _assert_sound_lock(lab)
    _assert_pain_split(lab)
    _assert_leech_life(lab)
    _assert_barrier_break(lab)
    _assert_lash_out_window(lab)
    _assert_scale_shot_and_area_rules(lab)
    _assert_active_runtime_chain()
    print("Rettan/Arbok family TM mechanics test: PASS")
    lab.queue_free()
    quit(0)


func _assert_inventory_and_contracts(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    assert(moves.size() == 244, "Runtime muss nach dem Rettan/Arbok-Paket 244 Attacken enthalten.")
    for kind: String in [
        "db_move_ap_override","db_break_team_barriers","db_drain_from_damage",
        "db_pair_hp_average","db_block_move_tag"
    ]:
        assert(MoveRegistry.is_known_effect(kind), "Zentrale Mechanik fehlt im MoveEffectRegistry: " + kind)

    for move_id: String in NEW_MOVE_IDS:
        assert(moves.has(move_id), "Rettan/Arbok-TM fehlt: " + move_id)
        var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss runtime_supported sein.")
        assert(bool(runtime.get("strict_contract", false)), move_id + " muss strict_contract sein.")
        assert(bool(runtime.get("contract_validated", false)), move_id + " muss den MoveContract bestehen.")


func _assert_family_tm_lists(lab) -> void:
    var species: Dictionary = lab._canonical_pack.get("species", {})
    var ekans: Dictionary = species.get("ekans", {})
    var arbok: Dictionary = species.get("arbok", {})
    var ekans_tms: Dictionary = ((ekans.get("learnset", {}) as Dictionary).get("tm_hm", {}))
    var arbok_tms: Dictionary = ((arbok.get("learnset", {}) as Dictionary).get("tm_hm", {}))

    assert(ekans_tms.size() == 42, "Rettan muss exakt 42 Nicht-Tera-TMs besitzen.")
    assert(arbok_tms.size() == 53, "Arbok muss exakt 53 Nicht-Tera-TMs besitzen.")
    assert(not ekans_tms.values().has("tera_blast") and not arbok_tms.values().has("tera_blast"), "Tera-Ausbruch muss vollständig ausgeschlossen sein.")

    for tm_id: String in ["TM026","TM030","TM063","TM095","TM177","TM199","TM200","TM214","TM219"]:
        assert(ekans_tms.has(tm_id), "Rettan-TM fehlt: " + tm_id)
        assert(arbok_tms.has(tm_id), "Arbok muss Rettans TM ebenfalls besitzen: " + tm_id)
    assert(str(arbok_tms.get("TM202", "")) == "pain_split")
    assert(str(arbok_tms.get("TM221", "")) == "throat_chop")


func _assert_groll(lab) -> void:
    var move: Dictionary = lab._move_data("spite")
    assert(int(move.get("ap", 0)) == 7)
    var mechanic: Dictionary = (move.get("mechanics", []) as Array)[0]
    assert(str(mechanic.get("kind", "")) == "db_move_ap_override")
    assert(int(mechanic.get("ap", 0)) == 8)
    assert(int(mechanic.get("duration_actions", 0)) == 2)

    var target: Dictionary = {"action_serial":0}
    MoveApOverride.apply(target, 8, 2)
    assert(MoveApOverride.effective_ap(target, 2) == 8)
    assert(MoveApOverride.effective_ap(target, 7) == 8)
    assert(MoveApOverride.effective_ap(target, 8) == 8)
    target["action_serial"] = 1
    assert(MoveApOverride.remaining_actions(target) == 1)
    assert(MoveApOverride.effective_ap(target, 3) == 8)
    target["action_serial"] = 2
    assert(MoveApOverride.remaining_actions(target) == 0)
    assert(MoveApOverride.effective_ap(target, 3) == 3, "Nach zwei eigenen Aktionen müssen die normalen RPG-AP zurückkehren.")


func _assert_sound_lock(lab) -> void:
    var snarl: Dictionary = lab._move_data("snarl")
    var screech: Dictionary = lab._move_data("screech")
    var throat_chop: Dictionary = lab._move_data("throat_chop")
    assert(MoveTagLock.move_has_tag(snarl, "sound"), "Standpauke muss zentral als Klangattacke markiert sein.")
    assert(MoveTagLock.move_has_tag(screech, "sound"), "Kreideschrei muss zentral als Klangattacke markiert sein.")

    var mechanic: Dictionary = (throat_chop.get("mechanics", []) as Array)[1]
    assert(str(mechanic.get("kind", "")) == "db_block_move_tag")
    assert(str(mechanic.get("tag", "")) == "sound")
    assert(int(mechanic.get("duration_actions", 0)) == 3)

    var target: Dictionary = {"action_serial":0}
    MoveTagLock.apply(target, "sound", 3)
    assert(MoveTagLock.blocks_move(target, snarl))
    assert(MoveTagLock.blocks_move(target, screech))
    assert(not MoveTagLock.blocks_move(target, lab._move_data("poison_tail")))
    target["action_serial"] = 1
    assert(MoveTagLock.remaining_actions(target, "sound") == 2)
    target["action_serial"] = 2
    assert(MoveTagLock.remaining_actions(target, "sound") == 1)
    target["action_serial"] = 3
    assert(not MoveTagLock.blocks(target, "sound"), "Neck Strike muss nach drei eigenen Aktionen enden.")


func _assert_pain_split(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id":"ekans","level":20})
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"arbok","level":30})
    actor["max_hp"] = 100
    target["max_hp"] = 100
    actor["hp"] = 30
    target["hp"] = 90
    lab.player_team = [actor]
    lab.enemy_team = [target]
    lab.combatants = [actor, target]

    var mechanic: Dictionary = (lab._move_data("pain_split").get("mechanics", []) as Array)[0]
    lab._effect(actor, target, mechanic)
    assert(int(actor.get("hp", 0)) == 60 and int(target.get("hp", 0)) == 60, "Leidteiler muss 30/90 auf 60/60 verteilen.")

    actor["hp"] = 100
    target["hp"] = 40
    lab._effect(actor, target, mechanic)
    assert(int(actor.get("hp", 0)) == 70 and int(target.get("hp", 0)) == 70, "Leidteiler muss auch den Anwender schädigen und das Ziel heilen können.")

    actor["hp"] = 30
    target["hp"] = 90
    target["db_substitute_hp"] = 10
    lab._effect(actor, target, mechanic)
    assert(int(actor.get("hp", 0)) == 30 and int(target.get("hp", 0)) == 90, "Delegator muss Leidteiler blockieren.")


func _assert_leech_life(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id":"ekans","level":20})
    actor["max_hp"] = 100
    actor["hp"] = 20
    actor["tf_family_last_actual_damage"] = 40
    var mechanic: Dictionary = (lab._move_data("leech_life").get("mechanics", []) as Array)[1]
    var aggro: float = lab._effect(actor, {}, mechanic)
    assert(int(actor.get("hp", 0)) == 40, "Blutsauger muss 50 % des tatsächlichen Schadens heilen.")
    assert(is_equal_approx(aggro, 20.0), "Heilungs-Aggro muss nur aus tatsächlich geheilten KP entstehen.")
    actor["hp"] = 95
    actor["tf_family_last_actual_damage"] = 40
    assert(is_equal_approx(lab._effect(actor, {}, mechanic), 5.0))
    assert(int(actor.get("hp", 0)) == 100, "Blutsauger darf nicht über Max-KP heilen.")


func _assert_barrier_break(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id":"ekans","level":20})
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"arbok","level":30})
    var target_two: Dictionary = lab._make_combatant("enemy", 1, {"species_id":"pikachu","level":20})
    target["db_light_screen_reduction"] = 0.25
    target["db_light_screen_source_id"] = "enemy_0"
    target_two["db_light_screen_reduction"] = 0.25
    target_two["db_light_screen_source_id"] = "enemy_0"
    lab.combatants = [actor, target, target_two]

    var mechanic: Dictionary = (lab._move_data("psychic_fangs").get("mechanics", []) as Array)[0]
    lab._effect(actor, target, mechanic)
    assert(is_zero_approx(float(target.get("db_light_screen_reduction", 1.0))))
    assert(is_zero_approx(float(target_two.get("db_light_screen_reduction", 1.0))), "Psychobeißer muss die gegnerische Team-Barriere zentral entfernen.")


func _assert_lash_out_window(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id":"ekans","level":20})
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"arbok","level":30})
    lab.combatants = [actor, target]
    var drop: Dictionary = {"kind":"outgoing_damage_mod","multiplier_from_special":-1.0,"uses_special_percent":true,"duration":"3_actions"}
    lab._effect(target, actor, drop)
    assert(bool(actor.get("tf_attribute_lowered_since_last_action", false)), "Eine echte Attributsenkung muss Frustventil für die nächste eigene Aktion vormerken.")

    var move: Dictionary = lab._move_data("lash_out")
    assert(int(move.get("power", 0)) == 75)
    assert(bool((move.get("runtime", {}) as Dictionary).get("timeflow_double_if_attribute_lowered_since_last_action", false)))


func _assert_scale_shot_and_area_rules(lab) -> void:
    var scale_shot: Dictionary = lab._move_data("scale_shot")
    var runtime: Dictionary = scale_shot.get("runtime", {})
    var multi_hit: Dictionary = runtime.get("multi_hit", {})
    assert(int(multi_hit.get("min", 0)) == 2 and int(multi_hit.get("max", 0)) == 5)
    assert((multi_hit.get("weights", []) as Array) == [7,7,3,3])
    assert(int(scale_shot.get("power", 0)) == 25 and int(scale_shot.get("accuracy", 0)) == 90)

    var sludge_wave: Dictionary = lab._move_data("sludge_wave")
    assert(str(sludge_wave.get("target", "")) == "all_other_active_pokemon")
    assert(int(sludge_wave.get("power", 0)) == 95)
    var poison_runtime: Dictionary = lab._move_data("poison_tail").get("runtime", {})
    assert(bool(poison_runtime.get("high_crit", false)))
    assert(int(lab._move_data("skitter_smack").get("power", 0)) == 70)


func _assert_active_runtime_chain() -> void:
    var rattata_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_rattata_family.gd")
    assert(rattata_text.contains("res://scripts/battle_demo_rettan_arbok_family.gd"), "Die aktive Rattfratz-Schicht muss die Rettan/Arbok-Schicht erben.")
    var route_guard_text: String = FileAccess.get_file_as_string("res://scripts/battle_demo_route_result_guard.gd")
    assert(route_guard_text.contains("res://scripts/battle_demo_rattata_family.gd"), "Die Hauptkampf-Runtime muss weiterhin über den Rattfratz-Layer in die Familienkette führen.")
