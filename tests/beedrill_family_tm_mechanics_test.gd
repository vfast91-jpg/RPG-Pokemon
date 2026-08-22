extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_beedrill_family.gd")
const BIBOR_NEW_MOVES: Array[String] = [
    "payback", "flash", "x_scissor", "swagger", "cut", "defog", "rock_smash"
]

func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)
    _assert_inventory(lab)
    _assert_family_tm_harmonization(lab)
    _assert_simple_move_contracts(lab)
    _assert_payback(lab)
    _assert_swagger_targeting(lab)
    _assert_defog(lab)
    print("Hornliu/Kokuna/Bibor TM mechanics test: PASS")
    lab.queue_free()
    quit(0)


func _assert_inventory(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})
    assert(moves.size() == 233, "Runtime muss mit dem nachfolgenden Rattfratz-Paket 233 Attacken enthalten.")
    for move_id: String in BIBOR_NEW_MOVES:
        assert(moves.has(move_id), "Bibor-TM fehlt: " + move_id)
        var move: Dictionary = moves[move_id]
        var runtime: Dictionary = move.get("runtime", {})
        assert(bool(runtime.get("runtime_supported", false)), move_id + " muss runtime_supported sein.")
        assert(bool(runtime.get("strict_contract", false)), move_id + " muss strict_contract sein.")
        assert(bool(runtime.get("contract_validated", false)), move_id + " muss den MoveContract bestehen.")


func _assert_family_tm_harmonization(lab) -> void:
    var species: Dictionary = lab._canonical_pack.get("species", {})
    for pair: Array in [
        ["caterpie", 1],
        ["weedle", 1],
        ["metapod", 2],
        ["kakuna", 2],
        ["beedrill", 29]
    ]:
        var mon: Dictionary = species.get(str(pair[0]), {})
        var tms: Dictionary = (mon.get("learnset", {}) as Dictionary).get("tm_hm", {})
        assert(tms.size() == int(pair[1]), str(pair[0]) + " hat falsche Maschinen-Anzahl.")

    var weedle_tms: Dictionary = ((species["weedle"] as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {})
    var kakuna_tms: Dictionary = ((species["kakuna"] as Dictionary).get("learnset", {}) as Dictionary).get("tm_hm", {})
    assert(weedle_tms.values().has("electroweb"), "Hornliu muss Elektronetz lernen können.")
    assert(kakuna_tms.values().has("electroweb"), "Kokuna muss Elektronetz lernen können.")
    assert(kakuna_tms.values().has("iron_defense"), "Kokuna muss Eisenabwehr lernen können.")


func _assert_simple_move_contracts(lab) -> void:
    var moves: Dictionary = lab.data.get("moves", {})

    var flash: Dictionary = moves["flash"]
    assert(int(flash.get("accuracy", 0)) == 100)
    var flash_mechanic: Dictionary = (flash.get("mechanics", []) as Array)[0]
    assert(str(flash_mechanic.get("kind", "")) == "accuracy_mod")
    assert(is_equal_approx(float(flash_mechanic.get("multiplier_from_special", 0.0)), -1.0))

    var x_scissor: Dictionary = moves["x_scissor"]
    assert(int(x_scissor.get("power", 0)) == 80 and int(x_scissor.get("accuracy", 0)) == 100)
    assert(bool(x_scissor.get("contact", false)))

    var cut: Dictionary = moves["cut"]
    assert(int(cut.get("power", 0)) == 50 and int(cut.get("accuracy", 0)) == 95)

    var rock_smash: Dictionary = moves["rock_smash"]
    assert(int(rock_smash.get("power", 0)) == 40 and int(rock_smash.get("accuracy", 0)) == 100)
    var rock_mechanics: Array = rock_smash.get("mechanics", [])
    assert(rock_mechanics.size() == 2)
    var chance_mechanic: Dictionary = rock_mechanics[1]
    assert(is_equal_approx(float(chance_mechanic.get("chance", 0.0)), 0.5))


func _assert_payback(lab) -> void:
    var defender: Dictionary = {
        "id":"player_0","side":"player","alive":true,"hp":200,"max_hp":200,
        "level":30,"attack":90,"defense":70,"special":50,"types":["bug","poison"],
        "aggro":20.0,"timed_modifiers":[]
    }
    var attacker: Dictionary = {
        "id":"enemy_0","side":"enemy","alive":true,"hp":250,"max_hp":250,
        "level":30,"attack":85,"defense":70,"special":50,"types":["normal"],
        "aggro":40.0,"timed_modifiers":[]
    }

    lab._bfam_activate_payback(defender)
    assert(int(defender.get("bfam_payback_charges", 0)) == 3, "Gegenstoß muss auf drei Ladungen setzen.")

    var hp_before: int = int(attacker.get("hp", 0))
    var damage: int = lab._bfam_resolve_payback_retaliation(defender, attacker)
    assert(damage > 0 and int(attacker.get("hp", 0)) < hp_before, "Gegenstoß muss Stärke-35-Schaden auslösen.")
    assert(int(defender.get("bfam_payback_charges", 0)) == 2, "Ein Trigger verbraucht genau eine Ladung.")

    lab._bfam_activate_payback(defender)
    assert(int(defender.get("bfam_payback_charges", 0)) == 3, "Erneuter Einsatz muss auf drei auffrischen statt zu stapeln.")

    defender["alive"] = false
    assert(lab._bfam_resolve_payback_retaliation(defender, attacker) == 0, "Kampfunfähiger Anwender darf nicht kontern.")


func _assert_swagger_targeting(lab) -> void:
    var actor: Dictionary = {"id":"player_0","side":"player","alive":true,"aggro":10.0}
    var ally: Dictionary = {"id":"player_1","side":"player","alive":true,"aggro":10.0}
    var enemy_low: Dictionary = {"id":"enemy_0","side":"enemy","alive":true,"aggro":5.0}
    var enemy_high: Dictionary = {"id":"enemy_1","side":"enemy","alive":true,"aggro":30.0}
    lab.player_team = [actor, ally]
    lab.enemy_team = [enemy_low, enemy_high]
    lab.combatants = [actor, ally, enemy_low, enemy_high]

    var choices: Array = lab._bfam_swagger_target_choices(actor)
    var ids: Array[String] = []
    for target_value: Variant in choices:
        ids.append(str((target_value as Dictionary).get("id", "")))
    assert(ids.has("enemy_1"), "Angeberei muss den Gegner mit höchster Aggro anbieten.")
    assert(ids.has("player_1"), "Angeberei muss einen Verbündeten anbieten.")
    assert(not ids.has("player_0"), "Angeberei darf den Anwender nicht selbst anbieten.")
    assert(not ids.has("enemy_0"), "Bei Gegnern bleibt die höchste-Aggro-Regel bestehen.")

    var swagger: Dictionary = lab.data.get("moves", {}).get("swagger", {})
    assert(int(swagger.get("accuracy", 0)) == 85, "Angeberei braucht 85 Genauigkeit.")
    var mechanics: Array = swagger.get("mechanics", [])
    assert(str((mechanics[0] as Dictionary).get("status", "")) == "confusion")
    assert(is_equal_approx(float((mechanics[1] as Dictionary).get("multiplier_from_special", 0.0)), 2.0))


func _assert_defog(lab) -> void:
    var actor: Dictionary = {"id":"player_0","side":"player","alive":true}
    var ally: Dictionary = {
        "id":"player_1","side":"player","alive":true,
        "major_status":"poison","seed_effect":{"source_side":"enemy"},"binding_effect":{"ticks_left":2},
        "protective_guard":true
    }
    var enemy: Dictionary = {
        "id":"enemy_0","side":"enemy","alive":true,
        "db_light_screen_reduction":0.4,
        "db_light_screen_source_id":"enemy_0",
        "db_light_screen_expires_source_action":3,
        "major_status":"burn",
        "seed_effect":{"source_side":"player"},
        "binding_effect":{"ticks_left":2},
        "protective_guard":true,
        "timed_modifiers":[
            {"kind":"incoming_damage_mod","multiplier":1.3,"source_move":"Reflektor","expires_after_action":3},
            {"kind":"incoming_damage_mod","multiplier":1.2,"source_move":"Eisenabwehr","expires_after_action":3}
        ]
    }
    lab.player_team = [actor, ally]
    lab.enemy_team = [enemy]
    lab.combatants = [actor, ally, enemy]

    lab.set_meta("db_toxic_spikes_player", 2)
    lab.set_meta("db_toxic_spikes_enemy", 1)
    lab.set_meta("db_active_terrain", "electric")
    lab._bfam_apply_defog_cleanup(actor)

    assert(int(lab.get_meta("db_toxic_spikes_player", -1)) == 0, "Auflockern muss eigene Eintrittsgefahren entfernen.")
    assert(int(lab.get_meta("db_toxic_spikes_enemy", -1)) == 0, "Auflockern muss gegnerische Eintrittsgefahren entfernen.")
    assert(str(lab.get_meta("db_active_terrain", "x")).is_empty(), "Auflockern muss aktives Terrain entfernen.")
    assert(is_zero_approx(float(enemy.get("db_light_screen_reduction", 1.0))), "Auflockern muss gegnerisches Lichtschild entfernen.")

    var remaining_modifiers: Array = enemy.get("timed_modifiers", [])
    assert(remaining_modifiers.size() == 1, "Auflockern darf nur Team-Barrieren aus den temporären Modifikatoren entfernen.")
    assert(str((remaining_modifiers[0] as Dictionary).get("source_move", "")) == "Eisenabwehr", "Persönliche Verteidigungsbuffs müssen erhalten bleiben.")

    assert(bool(enemy.get("protective_guard", false)), "Auflockern darf Schutzschild nicht entfernen.")
    assert(str(enemy.get("major_status", "")) == "burn", "Auflockern darf Hauptstatus nicht entfernen.")
    assert(not (enemy.get("seed_effect", {}) as Dictionary).is_empty(), "Auflockern darf Egelsamen nicht entfernen.")
    assert(not (enemy.get("binding_effect", {}) as Dictionary).is_empty(), "Auflockern darf Bindung nicht entfernen.")
