extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_squirtle_family.gd")
const NEW_MOVE_IDS: Array[String] = [
    "chilling_water","icy_wind","mud_shot","zen_headbutt","ice_punch",
    "liquidation","surf","ice_spinner","ice_beam","blizzard",
    "water_pledge","gyro_ball","flip_turn","whirlpool","muddy_water",
    "avalanche","body_press","dark_pulse","aura_sphere","hydro_cannon","smack_down"
]

func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)
    _assert_inventory(lab)
    _assert_species_tm_counts(lab)
    _assert_global_flinch(lab)
    _assert_freeze(lab)
    _assert_gyro_ball(lab)
    _assert_body_press(lab)
    _assert_grounded(lab)
    _assert_pledges(lab)
    print("Schiggy-Familie TM mechanics test: PASS")
    lab.queue_free()
    quit(0)

func _assert_inventory(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    assert(moves.size() == 210, "Runtime muss nach dem Schiggy-Paket 210 Attacken enthalten.")
    for move_id: String in NEW_MOVE_IDS:
        assert(moves.has(move_id), "Schiggy-Familienattacke fehlt: " + move_id)
        var runtime: Dictionary = (moves[move_id] as Dictionary).get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss runtime_supported sein.")
        assert(bool(runtime.get("strict_contract", false)), move_id + " muss strict_contract sein.")
        assert(bool(runtime.get("contract_validated", false)), move_id + " muss den MoveContract bestehen.")

func _assert_species_tm_counts(lab) -> void:
    var species: Dictionary = lab._canonical_pack.get("species", {})
    for pair: Array in [["squirtle",35],["wartortle",35],["blastoise",52]]:
        var mon: Dictionary = species.get(str(pair[0]), {})
        var learnset: Dictionary = mon.get("learnset", {})
        var tms: Dictionary = learnset.get("tm_hm", {})
        assert(tms.size() == int(pair[1]), str(pair[0]) + " hat falsche Nicht-Tera-TM-Anzahl.")
    var blastoise: Dictionary = species.get("blastoise", {})
    var blastoise_tms: Dictionary = (blastoise.get("learnset", {}) as Dictionary).get("tm_hm", {})
    for tm_id: String in ["TM046","TM149","TM154","TM158","TM172","TM179"]:
        assert(blastoise_tms.has(tm_id), "Turtok-Korrektur fehlt: " + tm_id)

func _assert_global_flinch(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player",0,{"species_id":"squirtle","level":20})
    var target: Dictionary = lab._make_combatant("enemy",0,{"species_id":"pikachu","level":20})
    target["atb"] = 91.0
    lab.combatants = [actor,target]
    lab._sf_apply_flinch(actor,target,1.0)
    assert(is_equal_approx(float(target.get("atb", -1.0)),0.0), "Zurückschrecken muss die aktuelle ATB-Leiste global auf 0 setzen.")

func _assert_freeze(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player",0,{"species_id":"squirtle","level":20})
    var target: Dictionary = lab._make_combatant("enemy",0,{"species_id":"pikachu","level":20})
    lab.combatants = [actor,target]
    var aggro: float = lab._sf_apply_freeze(actor,target,1.0)
    assert(aggro > 0.0, "Garantiertes Gefrieren muss Status-Aggro erzeugen.")
    assert(str(target.get("major_status", "")) == "freeze", "Gefroren muss ein echter Hauptstatus sein.")
    assert(int(target.get("db_freeze_actions",0)) >= 1 and int(target.get("db_freeze_actions",0)) <= 3, "Gefroren muss 1–3 eigene Aktionsmöglichkeiten dauern.")

func _assert_gyro_ball(lab) -> void:
    var actor: Dictionary = {"speed":25.0,"paralyzed":false,"timed_modifiers":[]}
    var target: Dictionary = {"speed":100.0,"paralyzed":false,"timed_modifiers":[]}
    assert(lab._sf_gyro_ball_power(actor,target) == 101, "Gyroball muss das effektive Geschwindigkeitsverhältnis verwenden.")
    actor["speed"] = 1.0
    target["speed"] = 200.0
    assert(lab._sf_gyro_ball_power(actor,target) == 150, "Gyroball muss bei Stärke 150 gedeckelt sein.")

func _assert_body_press(lab) -> void:
    var actor: Dictionary = {"defense":100.0,"timed_modifiers":[]}
    assert(is_equal_approx(lab._sf_body_press_offense(actor),100.0), "Body Press muss ohne Modifikator die Verteidigung nutzen.")
    actor["timed_modifiers"] = [{"kind":"incoming_damage_mod","multiplier":1.5,"expires_after_action":99}]
    assert(is_equal_approx(lab._sf_body_press_offense(actor),150.0), "Defensivbuff muss Body Press verstärken.")

func _assert_grounded(lab) -> void:
    var target: Dictionary = lab._make_combatant("enemy",0,{"species_id":"charizard","level":40})
    target["types"] = ["fire","flying"]
    target["action_serial"] = 4
    target["sf_grounded_until_action"] = 7
    assert(lab._tf_is_grounded(target), "Katapult muss Flugziele während der Dauer als am Boden behandeln.")
    target["action_serial"] = 7
    assert(not lab._sf_force_grounded_active(target), "Katapult-Bodenzwang muss nach drei Zielaktionen enden.")

func _assert_pledges(lab) -> void:
    assert(lab._cf_pledge_combo_kind("grass","water") == "swamp", "Pflanze+Wasser muss Sumpf ergeben.")
    assert(lab._cf_pledge_combo_kind("water","grass") == "swamp", "Wasser+Pflanze muss Sumpf ergeben.")
    assert(lab._cf_pledge_combo_kind("fire","water") == "rainbow", "Feuer+Wasser muss weiterhin Regenbogen ergeben.")
