extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_lab_family_refresh_v1.gd")
const AreaDamageRules = preload("res://scripts/battle/area_damage_rules.gd")

const EXPECTED_SCALED_AREA_DAMAGE_MOVES: Array[String] = [
    "razor_leaf",
    "petal_blizzard",
    "heat_wave",
    "electroweb",
    "acid",
    "bulldoze",
    "earthquake",
    "rock_slide",
    "breaking_swipe",
    "air_cutter",
    "icy_wind",
    "surf",
    "blizzard",
    "muddy_water",
    "snarl",
    "sludge_wave",
    "dazzling_gleam",
    "hyper_voice",
    "misty_explosion",
    "incinerate",
    "burning_jealousy"
]

const EXPECTED_FULL_POWER_EXCEPTIONS: Array[String] = [
    "swift",
    "disarming_voice"
]

const EXPECTED_CONDITIONAL_AREA_DAMAGE_MOVES: Array[String] = [
    "expanding_force"
]


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    _assert_multiplier_table()
    _assert_current_area_damage_registry(lab)
    _assert_runtime_target_counting(lab)

    print("Central area damage scaling test: PASS")
    lab.queue_free()
    quit(0)


func _assert_multiplier_table() -> void:
    assert(is_equal_approx(AreaDamageRules.damage_multiplier(0), 1.0), "0 Ziele duerfen keinen Spread-Abzug erzeugen.")
    assert(is_equal_approx(AreaDamageRules.damage_multiplier(1), 1.0), "1 Ziel muss 100 % Schaden erhalten.")
    assert(is_equal_approx(AreaDamageRules.damage_multiplier(2), 0.75), "2 Ziele muessen je 75 % Schaden erhalten.")
    assert(is_equal_approx(AreaDamageRules.damage_multiplier(3), 0.60), "3 Ziele muessen je 60 % Schaden erhalten.")
    assert(is_equal_approx(AreaDamageRules.damage_multiplier(4), 0.50), "4 Ziele muessen je 50 % Schaden erhalten.")
    assert(is_equal_approx(AreaDamageRules.damage_multiplier(8), 0.50), "4+ Ziele muessen bei 50 % gedeckelt bleiben.")

    var mislabeled_spread_move: Dictionary = {
        "area": false,
        "target": "all_enemies",
        "runtime": {}
    }
    assert(AreaDamageRules.move_uses_central_scaling(mislabeled_spread_move), "Eine all_*-Mehrzielregel darf die zentrale Formel auch bei fehlerhaftem area-Flag nicht umgehen.")


func _assert_current_area_damage_registry(lab) -> void:
    var moves_value: Variant = lab.data.get("moves", {})
    assert(moves_value is Dictionary, "Aktive Attacken-Datenbank fehlt.")
    var moves: Dictionary = moves_value

    for move_id: String in EXPECTED_SCALED_AREA_DAMAGE_MOVES:
        assert(moves.has(move_id), "Erwartete Flaechenschadensattacke fehlt: " + move_id)
        var move: Dictionary = moves[move_id]
        assert(_is_runtime_area_damage(move), move_id + " muss als aktive Flaechenschadensattacke markiert sein.")
        assert(AreaDamageRules.move_uses_central_scaling(move), move_id + " muss die zentrale Flaechenschadensformel verwenden.")

    for move_id: String in EXPECTED_FULL_POWER_EXCEPTIONS:
        assert(moves.has(move_id), "Erwartete Vollschaden-Ausnahme fehlt: " + move_id)
        var move: Dictionary = moves[move_id]
        assert(_is_runtime_area_damage(move), move_id + " muss eine aktive Flaechenschadensattacke sein.")
        assert(not AreaDamageRules.move_uses_central_scaling(move), move_id + " muss als explizite Vollschaden-Ausnahme markiert bleiben.")

    for move_id: String in EXPECTED_CONDITIONAL_AREA_DAMAGE_MOVES:
        assert(moves.has(move_id), "Erwartete bedingte Flaechenschadensattacke fehlt: " + move_id)
        var move: Dictionary = moves[move_id]
        var runtime_value: Variant = move.get("runtime", {})
        assert(runtime_value is Dictionary, move_id + " braucht einen Runtime-Vertrag.")
        assert(bool((runtime_value as Dictionary).get(AreaDamageRules.CENTRAL_SCALING_RUNTIME_FLAG, false)), move_id + " muss den zentralen Flaechenschadensvertrag tragen.")
        assert(AreaDamageRules.move_uses_central_scaling(move), move_id + " muss auch im Einzelziel-Grundzustand an die zentrale Formel angebunden bleiben.")

    var audited_count: int = 0
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id_value, {})
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        if not _is_runtime_area_damage(move):
            continue
        audited_count += 1

        var runtime_value: Variant = move.get("runtime", {})
        var full_power: bool = (
            runtime_value is Dictionary
            and bool((runtime_value as Dictionary).get(AreaDamageRules.FULL_SPREAD_RUNTIME_FLAG, false))
        )
        if full_power:
            assert(EXPECTED_FULL_POWER_EXCEPTIONS.has(move_id), "Ungepruefte Vollschaden-Ausnahme gefunden: " + move_id)
        else:
            assert(AreaDamageRules.move_uses_central_scaling(move), "Flaechenschadensattacke umgeht die zentrale Formel: " + move_id)

    # Also audit conditional contracts whose base data is still single-target.
    for move_id_value: Variant in moves.keys():
        var move_value: Variant = moves.get(move_id_value, {})
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        var runtime_value: Variant = move.get("runtime", {})
        if not (runtime_value is Dictionary):
            continue
        var runtime: Dictionary = runtime_value
        if not bool(runtime.get(AreaDamageRules.CENTRAL_SCALING_RUNTIME_FLAG, false)):
            continue
        assert(AreaDamageRules.move_uses_central_scaling(move), "Zentraler Flaechenschadensvertrag ist wirkungslos: " + str(move_id_value))

    assert(audited_count >= 23, "Der Flaechenschadens-Audit hat unerwartet wenige aktive Attacken gefunden: " + str(audited_count))


func _assert_runtime_target_counting(lab) -> void:
    var actor: Dictionary = {"id":"player_0", "side":"player", "alive":true, "action_serial":7}
    var enemy_a: Dictionary = {"id":"enemy_0", "side":"enemy", "alive":true}
    var enemy_b: Dictionary = {"id":"enemy_1", "side":"enemy", "alive":true}
    var enemy_c: Dictionary = {"id":"enemy_2", "side":"enemy", "alive":true}
    var enemy_d: Dictionary = {"id":"enemy_3", "side":"enemy", "alive":true}
    lab.combatants = [actor, enemy_a, enemy_b, enemy_c, enemy_d]

    var moves: Dictionary = lab.data.get("moves", {})
    var electroweb: Dictionary = moves.get("electroweb", {})
    assert(is_equal_approx(lab._area_damage_multiplier_for_move(actor, electroweb), 0.50), "Elektronetz muss gegen 4 Gegner auf 50 % skalieren.")

    enemy_d["alive"] = false
    assert(is_equal_approx(lab._area_damage_multiplier_for_move(actor, electroweb), 0.60), "Elektronetz muss gegen 3 lebende Gegner auf 60 % skalieren.")

    enemy_c["alive"] = false
    assert(is_equal_approx(lab._area_damage_multiplier_for_move(actor, electroweb), 0.75), "Elektronetz muss gegen 2 lebende Gegner auf 75 % skalieren.")

    enemy_b["alive"] = false
    assert(is_equal_approx(lab._area_damage_multiplier_for_move(actor, electroweb), 1.0), "Elektronetz muss gegen nur 1 lebenden Gegner vollen Schaden behalten.")

    # Freeze regression: all targets of ONE attack must retain the multiplier
    # established before an earlier target can be KO'd by that same attack.
    enemy_b["alive"] = true
    enemy_c["alive"] = true
    enemy_d["alive"] = true
    lab._area_damage_action_multipliers.clear()
    assert(is_equal_approx(lab._area_damage_multiplier_for_resolution(actor, electroweb), 0.50), "Erster Treffer einer 4-Ziel-Aktion muss 50 % festschreiben.")
    enemy_d["alive"] = false
    assert(is_equal_approx(lab._area_damage_multiplier_for_resolution(actor, electroweb), 0.50), "Ein KO innerhalb derselben Aktion darf den Spread-Multiplikator nicht erhoehen.")
    actor["action_serial"] = 8
    assert(is_equal_approx(lab._area_damage_multiplier_for_resolution(actor, electroweb), 0.60), "Eine neue Aktion muss die aktuelle Zielzahl neu auswerten.")

    enemy_d["alive"] = true
    var swift: Dictionary = moves.get("swift", {})
    assert(is_equal_approx(lab._area_damage_multiplier_for_move(actor, swift), 1.0), "Sternschauer muss seine explizite Vollschaden-Ausnahme behalten.")

    # Flaechenmacht starts as single-target but becomes spread damage on Psychic
    # Terrain. Its data contract must still produce the same central multiplier
    # once the runtime changes the target rule.
    var expanding_force: Dictionary = (moves.get("expanding_force", {}) as Dictionary).duplicate(true)
    expanding_force["target"] = "all_enemies"
    expanding_force["area"] = true
    assert(is_equal_approx(lab._area_damage_multiplier_for_move(actor, expanding_force), 0.50), "Bedingte Flaechenmacht muss gegen 4 Gegner auf 50 % skalieren.")


func _is_runtime_area_damage(move: Dictionary) -> bool:
    var target_rule: String = str(move.get("target", ""))
    if not bool(move.get("area", false)) and not target_rule.begins_with("all_"):
        return false

    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary and (runtime_value as Dictionary).has("runtime_supported"):
        if not bool((runtime_value as Dictionary).get("runtime_supported", true)):
            return false

    if move.get("power", null) != null and str(move.get("category", "")) != "status":
        return true

    for list_key: String in ["mechanics", "effects"]:
        var entries_value: Variant = move.get(list_key, [])
        if not (entries_value is Array):
            continue
        for entry_value: Variant in entries_value:
            if entry_value is Dictionary and str((entry_value as Dictionary).get("kind", "")) == "damage":
                return true
    return false
