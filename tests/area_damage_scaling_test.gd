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

    assert(audited_count >= 23, "Der Flaechenschadens-Audit hat unerwartet wenige aktive Attacken gefunden: " + str(audited_count))


func _assert_runtime_target_counting(lab) -> void:
    var actor: Dictionary = {"id":"player_0", "side":"player", "alive":true}
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

    enemy_b["alive"] = true
    enemy_c["alive"] = true
    enemy_d["alive"] = true
    var swift: Dictionary = moves.get("swift", {})
    assert(is_equal_approx(lab._area_damage_multiplier_for_move(actor, swift), 1.0), "Sternschauer muss seine explizite Vollschaden-Ausnahme behalten.")


func _is_runtime_area_damage(move: Dictionary) -> bool:
    if not bool(move.get("area", false)):
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
