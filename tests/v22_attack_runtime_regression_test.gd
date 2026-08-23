extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_v22_consistency_v1.gd")
const EXPECTED_MOVE_COUNT: int = 479

const PER_TARGET_ACCURACY_IDS: Array[String] = [
    "string_shot", "razor_leaf", "heat_wave", "electroweb", "hurricane",
    "rock_slide", "air_cutter", "icy_wind", "blizzard", "muddy_water",
    "snarl", "poison_gas"
]

const FLINCH_IDS: Array[String] = [
    "bite", "fire_fang", "air_slash", "twister", "ice_fang",
    "thunder_fang", "rock_slide", "zen_headbutt", "dark_pulse", "snore",
    "iron_head", "extrasensory", "sky_attack", "astonish", "waterfall",
    "stomp", "headbutt", "icicle_crash", "mountain_gale", "dragon_rush"
]

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()

    var moves_value: Variant = battle.data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}

    _check(
        moves.size() >= EXPECTED_MOVE_COUNT,
        "Finaler V22-Runtime-Bestand enthält nur %d statt mindestens %d Attacken."
        % [moves.size(), EXPECTED_MOVE_COUNT]
    )

    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        _check(move_value is Dictionary, move_id + ": Attackendefinition ist kein Dictionary.")
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        var mechanics_value: Variant = move.get("mechanics", [])
        _check(
            mechanics_value is Array and not (mechanics_value as Array).is_empty(),
            move_id + ": finale Runtime besitzt keine ausführbare mechanics-Liste."
        )
        var runtime_value: Variant = move.get("runtime", {})
        if runtime_value is Dictionary:
            _check(
                bool((runtime_value as Dictionary).get("runtime_supported", true)),
                move_id + ": finale Runtime ist als nicht unterstützt markiert."
            )

    _test_rock_slide(battle, moves)
    _test_per_target_accuracy(moves)
    _test_special_targets(moves)
    _test_confirmed_v22_drift_fixes(moves)
    _test_canonical_flinch_runtime(battle)

    battle.free()

    if failures == 0:
        print("V22 final attack runtime regression test: PASS")
        quit(0)
    else:
        push_error("V22 final attack runtime regression test: %d Fehler" % failures)
        quit(1)


func _test_rock_slide(battle, moves: Dictionary) -> void:
    var move_value: Variant = moves.get("rock_slide", {})
    _check(move_value is Dictionary, "Steinhagel fehlt im finalen Runtime-Bestand.")
    if not (move_value is Dictionary):
        return
    var move: Dictionary = move_value
    _check_equal_int(int(move.get("power", 0)), 75, "Steinhagel muss Stärke 75 besitzen.")
    _check_equal_float(float(move.get("accuracy", 0.0)), 90.0, "Steinhagel muss Genauigkeit 90 besitzen.")
    _check(str(move.get("target", "")) == "all_enemies", "Steinhagel muss alle Gegner treffen.")
    _check(bool(move.get("area", false)), "Steinhagel muss eine Flächenattacke sein.")

    var mechanics_value: Variant = move.get("mechanics", [])
    _check(mechanics_value is Array, "Steinhagel-Legacy-effects wurden nicht nach mechanics normalisiert.")
    if mechanics_value is Array:
        var has_damage: bool = false
        var has_flinch: bool = false
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            var kind: String = str((mechanic_value as Dictionary).get("kind", ""))
            has_damage = has_damage or kind == "damage"
            has_flinch = has_flinch or kind in [
                "atb_knockback", "zf_flinch", "f40_flinch_on_damage", "f64_flinch_on_damage"
            ]
        _check(has_damage, "Steinhagel besitzt nach finaler Normalisierung keine Schadensmechanik.")
        _check(has_flinch, "Steinhagel besitzt nach finaler Normalisierung keine Zurückschreckmechanik.")

    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    _check(bool(runtime.get("v22_per_target_accuracy", false)), "Steinhagel muss Genauigkeit pro Ziel auflösen.")

    var aggro_value: Variant = move.get("aggro", {})
    var aggro: Dictionary = aggro_value if aggro_value is Dictionary else {}
    _check(
        bool(aggro.get("from_status", aggro.get("status", false))),
        "Steinhagel muss erfolgreiche Zurückschreckwirkung als Status-Aggro werten."
    )

    # Exact runtime regression for the old amount=0.25 representation.
    var actor: Dictionary = {"id": "rock_actor", "side": "player"}
    var target: Dictionary = {
        "id": "rock_target", "side": "enemy", "hp": 90, "max_hp": 100,
        "atb": 67.0, "alive": true
    }
    battle._v22_active_move_id = "rock_slide"
    battle._zf_hp_before = {"rock_target": 100}
    battle._effect(
        actor,
        target,
        {"kind": "atb_knockback", "chance": 1.0, "amount": 0.25}
    )
    _check_equal_float(
        float(target.get("atb", -1.0)),
        0.0,
        "Steinhagel darf den alten 25-%-Knockback nicht mehr verwenden."
    )
    battle._v22_active_move_id = ""
    battle._zf_hp_before.clear()


func _test_per_target_accuracy(moves: Dictionary) -> void:
    for move_id: String in PER_TARGET_ACCURACY_IDS:
        var move_value: Variant = moves.get(move_id, {})
        _check(move_value is Dictionary, move_id + ": V22-Flächenattacke fehlt.")
        if not (move_value is Dictionary):
            continue
        var runtime_value: Variant = (move_value as Dictionary).get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        _check(
            bool(runtime.get("v22_per_target_accuracy", false)),
            move_id + ": getrennte Genauigkeitsprüfung pro Ziel ist nicht aktiv."
        )


func _test_special_targets(moves: Dictionary) -> void:
    for move_id: String in ["switcheroo", "transform", "conversion_2"]:
        var move: Dictionary = _move(moves, move_id)
        _check(str(move.get("target", "")) == "single_enemy", move_id + ": muss freie Gegnerwahl verwenden.")
        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        _check(bool(runtime.get("requires_enemy_selection", false)), move_id + ": Zielauswahl-UI fehlt.")

    for move_id: String in ["self_destruct", "explosion", "brutal_swing"]:
        var move: Dictionary = _move(moves, move_id)
        _check(str(move.get("target", "")) == "all_others", move_id + ": muss alle anderen aktiven Pokémon treffen.")
        _check(bool(move.get("area", false)), move_id + ": all_others benötigt area=true.")

    for move_id: String in ["self_destruct", "explosion"]:
        var move: Dictionary = _move(moves, move_id)
        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        _check(bool(runtime.get("v22_unconditional_self_ko", false)), move_id + ": V22-Selbst-K.O. fehlt.")
        _check(not bool(runtime.get("f40_self_ko_on_any_damage", false)), move_id + ": alter schadensabhängiger Selbst-K.O.-Pfad ist noch aktiv.")


func _test_confirmed_v22_drift_fixes(moves: Dictionary) -> void:
    var psychic_noise: Dictionary = _move(moves, "psychic_noise")
    var noise_mechanics_value: Variant = psychic_noise.get("mechanics", [])
    var found_noise_block: bool = false
    if noise_mechanics_value is Array:
        for mechanic_value: Variant in noise_mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            var mechanic: Dictionary = mechanic_value
            if str(mechanic.get("kind", "")) != "f40_heal_block_on_damage":
                continue
            found_noise_block = true
            _check_equal_int(int(mechanic.get("duration_actions", 0)), 3, "Psycholärm-Heilsperre muss drei Zielaktionen dauern.")
            _check(not bool(mechanic.get("refresh", true)), "Psycholärm darf aktive Heilsperre nicht erneuern.")
    _check(found_noise_block, "Psycholärm besitzt keine Heilsperrenmechanik.")
    _check(_status_aggro(psychic_noise), "Psycholärm muss Status-Aggro aktivieren.")

    var blaze_kick: Dictionary = _move(moves, "blaze_kick")
    _check(_status_aggro(blaze_kick), "Feuerfeger muss eine neu angewandte Verbrennung als Status-Aggro werten.")


func _test_canonical_flinch_runtime(battle) -> void:
    # All known V22 flinch IDs must at least exist in the final runtime. Legacy
    # mechanic kinds are allowed in data because the final layer redirects them
    # centrally, but no legacy amount may influence the result.
    var moves: Dictionary = battle.data.get("moves", {})
    for move_id: String in FLINCH_IDS:
        _check(moves.has(move_id), "V22-Zurückschreckattacke fehlt: " + move_id)


func _move(moves: Dictionary, move_id: String) -> Dictionary:
    var value: Variant = moves.get(move_id, {})
    if not (value is Dictionary):
        _fail(move_id + ": Attackendefinition fehlt.")
        return {}
    return value as Dictionary


func _status_aggro(move: Dictionary) -> bool:
    var aggro_value: Variant = move.get("aggro", {})
    if not (aggro_value is Dictionary):
        return false
    var aggro: Dictionary = aggro_value
    return bool(aggro.get("from_status", aggro.get("status", false)))


func _check(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _check_equal_int(actual: int, expected: int, message: String) -> void:
    if actual != expected:
        _fail(message + " Erwartet %d, erhalten %d." % [expected, actual])


func _check_equal_float(actual: float, expected: float, message: String) -> void:
    if not is_equal_approx(actual, expected):
        _fail(message + " Erwartet %.2f, erhalten %.2f." % [expected, actual])


func _fail(message: String) -> void:
    failures += 1
    push_error(message)
