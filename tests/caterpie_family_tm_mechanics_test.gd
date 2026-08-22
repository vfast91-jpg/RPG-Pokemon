extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_caterpie_family.gd")
const NEW_MOVE_IDS: Array[String] = [
    "thief", "snore", "attract", "u_turn", "echoed_voice", "draining_kiss",
    "psychic", "baton_pass", "shadow_ball", "skill_swap", "pollen_puff"
]
const CORRECTED_MOVE_IDS: Array[String] = [
    "electroweb", "iron_defense", "synthesis", "roost"
]

func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)
    _assert_inventory(lab)
    _assert_species_tm_counts(lab)
    _assert_shared_contracts(lab)
    _assert_healing(lab)
    _assert_attract_curve(lab)
    _assert_echoed_voice(lab)
    _assert_modifier_rebasing(lab)
    _assert_pollen_puff_heal(lab)
    print("Raupy-Familie TM mechanics test: PASS")
    lab.queue_free()
    quit(0)

func _assert_inventory(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    assert(moves.size() == 221, "Runtime muss nach dem Raupy-Paket 221 Attacken enthalten.")
    for move_id: String in NEW_MOVE_IDS + CORRECTED_MOVE_IDS:
        assert(moves.has(move_id), "Raupy-Familienattacke fehlt: " + move_id)
        var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss runtime_supported sein.")
        assert(bool(runtime.get("strict_contract", false)), move_id + " muss strict_contract sein.")
        assert(bool(runtime.get("contract_validated", false)), move_id + " muss den MoveContract bestehen.")

func _assert_species_tm_counts(lab) -> void:
    var species: Dictionary = lab._canonical_pack.get("species", {})
    for pair: Array in [["caterpie",1],["metapod",2],["butterfree",33]]:
        var mon: Dictionary = species.get(str(pair[0]), {})
        var learnset: Dictionary = mon.get("learnset", {})
        var tms: Dictionary = learnset.get("tm_hm", {})
        assert(tms.size() == int(pair[1]), str(pair[0]) + " hat falsche TM/TR-Anzahl.")
    var butterfree: Dictionary = species.get("butterfree", {})
    var butterfree_tms: Dictionary = (butterfree.get("learnset", {}) as Dictionary).get("tm_hm", {})
    for tm_id: String in ["TM034","TM039","TM040","TM056","TM074","TM076","TM078","TM082","TM087","TM095"]:
        assert(butterfree_tms.has(tm_id), "Smettbo-Korrektur fehlt: " + tm_id)

func _assert_shared_contracts(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    var u_turn_runtime: Dictionary = (moves["u_turn"] as Dictionary).get("runtime", {})
    var flip_turn_runtime: Dictionary = (moves["flip_turn"] as Dictionary).get("runtime", {})
    assert(bool(u_turn_runtime.get("timeflow_aggro_reset_on_hit", false)), "Kehrtwende braucht den Aggro-Reset-Vertrag.")
    assert(bool(flip_turn_runtime.get("timeflow_aggro_reset_on_hit", false)), "Rollwende muss denselben Aggro-Reset-Vertrag behalten.")

    var psychic_mechanics: Array = (moves["psychic"] as Dictionary).get("mechanics", [])
    var shadow_mechanics: Array = (moves["shadow_ball"] as Dictionary).get("mechanics", [])
    assert(is_equal_approx(float((psychic_mechanics[1] as Dictionary).get("chance", 0.0)), 0.10), "Psychokinese braucht 10 % Debuff-Chance.")
    assert(is_equal_approx(float((shadow_mechanics[1] as Dictionary).get("chance", 0.0)), 0.20), "Spukball braucht 20 % Debuff-Chance.")

func _assert_healing(lab) -> void:
    var actor: Dictionary = {"max_hp":200,"hp":80,"aggro":0.0}
    var healed: float = lab._cfam_heal_fraction_max_hp(actor, 0.5)
    assert(int(actor.get("hp", 0)) == 180, "50-%-Heilung muss bei 200 Max-KP genau 100 KP heilen.")
    assert(is_equal_approx(healed, 100.0), "Heilroutine muss tatsächlich geheilte KP zurückgeben.")

    var synthesis: Dictionary = lab.data.get("moves", {}).get("synthesis", {})
    var synthesis_mechanics: Array = synthesis.get("mechanics", [])
    assert(is_equal_approx(float((synthesis_mechanics[0] as Dictionary).get("fraction_max_hp", 0.0)), 0.5), "Synthese muss feste 50 % Max-KP verwenden.")
    assert(not bool((synthesis.get("status_scaling", {}) as Dictionary).get("uses_statuswert", true)), "Synthese darf nicht mit Statuswert skalieren.")

    var roost: Dictionary = lab.data.get("moves", {}).get("roost", {})
    var roost_mechanics: Array = roost.get("mechanics", [])
    assert(is_equal_approx(float((roost_mechanics[0] as Dictionary).get("fraction_max_hp", 0.0)), 0.5), "Ruheort muss feste 50 % Max-KP verwenden.")
    assert(not bool((roost.get("status_scaling", {}) as Dictionary).get("uses_statuswert", true)), "Ruheort darf nicht mit Statuswert skalieren.")

func _assert_attract_curve(lab) -> void:
    assert(is_equal_approx(lab._status_ratio(75.0), 0.5), "Status 75 muss bei Anziehung 50 % ergeben.")
    assert(is_equal_approx(lab._status_ratio(300.0), 0.8), "Status 300 muss bei Anziehung 80 % ergeben.")
    assert(lab._status_ratio(300.0) > 0.5, "Anziehung darf über 50 % steigen.")
    assert(lab._status_ratio(1000000.0) < 1.0, "Anziehung darf bei endlichem Status niemals 100 % erreichen.")

func _assert_echoed_voice(lab) -> void:
    assert(lab._cfam_echo_index("player") == 0, "Widerhall muss bei Stärke 40 starten.")
    var actor: Dictionary = {"side":"player"}
    lab._cfam_echo_used_index = 0
    lab._cfam_after_team_action(actor, true)
    assert(lab._cfam_echo_index("player") == 1, "Nach erstem Widerhall muss Stärke 80 folgen.")
    lab._cfam_after_team_action(actor, false)
    lab._cfam_after_team_action(actor, false)
    assert(lab._cfam_echo_index("player") == 1, "Nach zwei fremden Teamaktionen muss die Kette noch aktiv sein.")
    lab._cfam_after_team_action(actor, false)
    assert(lab._cfam_echo_index("player") == 0, "Nach drei Teamaktionen ohne Widerhall muss die Kette zurückgesetzt sein.")

func _assert_modifier_rebasing(lab) -> void:
    var source: Dictionary = {
        "action_serial":5,
        "timed_modifiers":[
            {"kind":"outgoing_damage_mod","multiplier":1.4,"expires_after_action":7,"source_move":"Test+","source_actor":"A"},
            {"kind":"incoming_damage_mod","multiplier":0.7,"expires_after_action":6,"source_move":"Test-","source_actor":"B"}
        ]
    }
    var target: Dictionary = {"action_serial":11,"timed_modifiers":[]}
    var moved: Array = lab._cfam_rebase_modifier_set(source, target)
    assert(moved.size() == 2, "Stafette/Wertewechsel müssen positive und negative Attributseffekte übernehmen.")
    assert(int((moved[0] as Dictionary).get("expires_after_action", 0)) == 13, "Zwei verbleibende Aktionen müssen beim Ziel erhalten bleiben.")
    assert(int((moved[1] as Dictionary).get("expires_after_action", 0)) == 12, "Eine verbleibende Aktion muss beim Ziel erhalten bleiben.")

func _assert_pollen_puff_heal(lab) -> void:
    var actor: Dictionary = {"id":"player_0","side":"player","aggro":10.0}
    var ally: Dictionary = {"id":"player_1","side":"player","alive":true,"max_hp":200,"hp":50}
    var snapshots: Dictionary = {"player_1":{"target":ally,"hp":50,"substitute_hp":0,"protective_guard":false}}
    var success: bool = lab._cfam_finish_pollen_puff(actor, snapshots)
    assert(success, "Pollenknödel muss auf einen Verbündeten heilend aufgelöst werden.")
    assert(int(ally.get("hp", 0)) == 150, "Pollenknödel muss 50 % Max-KP heilen.")
    assert(is_equal_approx(float(actor.get("aggro", 0.0)), 110.0), "Pollenknödel-Aggro muss den tatsächlich geheilten KP entsprechen.")
