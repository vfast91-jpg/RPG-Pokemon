extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_v22_playability_gate_v1.gd")
const V22MoveCatalog = preload("res://scripts/battle/v22_move_catalog.gd")

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

const MULTI_HIT_CONTRACTS: Dictionary = {
    "fury_attack": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "pin_missile": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "bullet_seed": {"min": 2, "max": 5, "weights": [7, 7, 3, 3]},
    "scale_shot": {"min": 2, "max": 5, "weights": [7, 7, 3, 3]},
    "fury_swipes": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "double_kick": {"min": 2, "max": 2, "weights": [1]},
    "dual_wingbeat": {"min": 2, "max": 2, "weights": [1]},
    "double_hit": {"min": 2, "max": 2, "weights": [1]},
    "rock_blast": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "dual_chop": {"min": 2, "max": 2, "weights": [1]},
    "icicle_spear": {"min": 2, "max": 5, "weights": [3, 3, 1, 1]},
    "triple_axel": {"min": 3, "max": 3, "weights": [1]},
    "bonemerang": {"min": 2, "max": 2, "weights": [1]},
    "triple_kick": {"min": 3, "max": 3, "weights": [1]}
}

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()

    var moves_value: Variant = battle.data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}

    _check_equal_int(V22MoveCatalog.count(), 479, "Der kanonische V22-Katalog muss genau 479 Attacken enthalten.")
    _check(
        moves.size() >= V22MoveCatalog.count(),
        "Finaler Runtime-Bestand ist kleiner als der kanonische V22-Katalog."
    )

    for move_id: String in V22MoveCatalog.IDS:
        _check(moves.has(move_id), "Kanonische V22-Attacke fehlt: " + move_id)
        if not moves.has(move_id):
            continue
        var move_value: Variant = moves.get(move_id, {})
        _check(move_value is Dictionary, move_id + ": Attackendefinition ist kein Dictionary.")
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        _check(
            bool(runtime.get("runtime_supported", true)),
            move_id + ": finale Runtime ist als nicht unterstützt markiert."
        )
        _check(
            battle._v22_move_has_executable_path(move),
            move_id + ": besitzt weder mechanics noch Runtime-Spezialpfad."
        )

    _test_rock_slide(battle, moves)
    _test_per_target_accuracy(moves)
    _test_special_targets(moves)
    _test_confirmed_drift_fixes(moves)
    _test_flinch_catalog(moves)
    _test_sequence_contracts(moves)

    battle.free()

    if failures == 0:
        print("V22 final attack runtime regression test: PASS")
        quit(0)
    else:
        push_error("V22 final attack runtime regression test: %d Fehler" % failures)
        quit(1)


func _test_rock_slide(battle, moves: Dictionary) -> void:
    var move: Dictionary = _move(moves, "rock_slide")
    _check_equal_int(int(move.get("power", 0)), 75, "Steinhagel muss Stärke 75 besitzen.")
    _check_equal_float(float(move.get("accuracy", 0.0)), 90.0, "Steinhagel muss Genauigkeit 90 besitzen.")
    _check(str(move.get("target", "")) == "all_enemies", "Steinhagel muss alle Gegner treffen.")
    _check(bool(move.get("area", false)), "Steinhagel muss eine Flächenattacke sein.")

    var mechanics_value: Variant = move.get("mechanics", [])
    _check(mechanics_value is Array, "Steinhagel-Legacy-effects wurden nicht nach mechanics normalisiert.")
    var has_damage: bool = false
    var has_flinch: bool = false
    if mechanics_value is Array:
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

    var runtime: Dictionary = _runtime(move)
    _check(bool(runtime.get("v22_per_target_accuracy", false)), "Steinhagel muss Genauigkeit pro Ziel auflösen.")
    _check(_status_aggro(move), "Steinhagel muss Zurückschrecken als Status-Aggro werten.")

    # Regression gegen die alte konkrete Datenform, die den Fehler ausgelöst hat:
    # amount=0.25 darf niemals mehr zu einem partiellen Rückwurf führen.
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
        var move: Dictionary = _move(moves, move_id)
        _check(
            bool(_runtime(move).get("v22_per_target_accuracy", false)),
            move_id + ": getrennte Genauigkeitsprüfung pro Ziel ist nicht aktiv."
        )


func _test_special_targets(moves: Dictionary) -> void:
    for move_id: String in ["switcheroo", "transform", "conversion_2"]:
        var move: Dictionary = _move(moves, move_id)
        _check(str(move.get("target", "")) == "single_enemy", move_id + ": muss freie Gegnerwahl verwenden.")
        _check(bool(_runtime(move).get("requires_enemy_selection", false)), move_id + ": Zielauswahl-UI fehlt.")

    for move_id: String in ["self_destruct", "explosion", "brutal_swing"]:
        var move: Dictionary = _move(moves, move_id)
        _check(str(move.get("target", "")) == "all_others", move_id + ": muss alle anderen aktiven Pokémon treffen.")
        _check(bool(move.get("area", false)), move_id + ": all_others benötigt area=true.")

    for move_id: String in ["self_destruct", "explosion"]:
        var runtime: Dictionary = _runtime(_move(moves, move_id))
        _check(bool(runtime.get("v22_unconditional_self_ko", false)), move_id + ": V22-Selbst-K.O. fehlt.")
        _check(not bool(runtime.get("f40_self_ko_on_any_damage", false)), move_id + ": alter schadensabhängiger Selbst-K.O.-Pfad ist noch aktiv.")

    for move_id: String in ["swagger", "flatter"]:
        var move: Dictionary = _move(moves, move_id)
        _check(
            str(move.get("target", "")) == "enemy_highest_aggro_or_single_ally",
            move_id + ": muss Gegner mit höchster Aggro ODER gewählten Verbündeten erlauben."
        )

    _check(
        str(_move(moves, "dragon_cheer").get("target", "")) == "all_allies_except_self",
        "Drachenjubel muss alle Verbündeten außer dem Anwender betreffen."
    )


func _test_confirmed_drift_fixes(moves: Dictionary) -> void:
    var psychic_noise: Dictionary = _move(moves, "psychic_noise")
    var found_noise_block: bool = false
    var mechanics_value: Variant = psychic_noise.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
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

    _check(
        _status_aggro(_move(moves, "blaze_kick")),
        "Feuerfeger muss eine neu angewandte Verbrennung als Status-Aggro werten."
    )


func _test_flinch_catalog(moves: Dictionary) -> void:
    for move_id: String in FLINCH_IDS:
        _check(moves.has(move_id), "V22-Zurückschreckattacke fehlt: " + move_id)


func _test_sequence_contracts(moves: Dictionary) -> void:
    for move_id_value: Variant in MULTI_HIT_CONTRACTS.keys():
        var move_id: String = str(move_id_value)
        var expected_value: Variant = MULTI_HIT_CONTRACTS.get(move_id, {})
        var expected: Dictionary = expected_value if expected_value is Dictionary else {}
        var runtime: Dictionary = _runtime(_move(moves, move_id))
        var spec_value: Variant = runtime.get("multi_hit", {})
        _check(spec_value is Dictionary, move_id + ": Multi-Hit-Vertrag fehlt.")
        if not (spec_value is Dictionary):
            continue
        var spec: Dictionary = spec_value
        _check_equal_int(int(spec.get("min", 0)), int(expected.get("min", 0)), move_id + ": falsche Mindesttrefferzahl.")
        _check_equal_int(int(spec.get("max", 0)), int(expected.get("max", 0)), move_id + ": falsche Höchsttrefferzahl.")
        _check(
            spec.get("weights", []) == expected.get("weights", []),
            move_id + ": falsche V22-Trefferverteilung."
        )
        _check(
            bool(spec.get("v22_target_aggro_once", false)),
            move_id + ": Ziel-Aggro darf über Folgetreffer nicht mehrfach halbiert werden."
        )

    var uproar_sequence: Dictionary = _forced_sequence(_move(moves, "uproar"))
    _check_equal_int(int(uproar_sequence.get("min", 0)), 3, "Aufruhr muss exakt drei Aktionen dauern.")
    _check_equal_int(int(uproar_sequence.get("max", 0)), 3, "Aufruhr muss exakt drei Aktionen dauern.")
    _check(not bool(uproar_sequence.get("confuse_after", false)), "Aufruhr darf nach V22 keine automatische Verwirrung erzwingen.")

    var rollout: Dictionary = _move(moves, "rollout")
    var rollout_sequence: Dictionary = _forced_sequence(rollout)
    _check_equal_int(int(rollout_sequence.get("min", 0)), 5, "Walzer muss bis zu fünf eigene Aktionen vorsehen.")
    _check_equal_int(int(rollout_sequence.get("max", 0)), 5, "Walzer muss bis zu fünf eigene Aktionen vorsehen.")
    _check(
        _runtime(rollout).get("consecutive_power_chain", []) == [30, 60, 120, 240, 480],
        "Walzer muss die V22-Stärkenfolge 30/60/120/240/480 verwenden."
    )

    # Meteor Beam is intentionally NOT a generic charge_then_fire move. Its
    # Cleffa-family handler re-evaluates highest Aggro on phase 2.
    _check(
        not bool(_runtime(_move(moves, "meteor_beam")).get("charge_then_fire", false)),
        "Meteorstrahl darf nicht in den generischen Ziel-Lock fallen."
    )
    _check(
        bool(_runtime(_move(moves, "meteor_beam")).get("timeflow_meteor_beam", false)),
        "Meteorstrahl braucht seinen zweiphasigen Spezialpfad."
    )

    _check(
        bool(_runtime(_move(moves, "future_sight")).get("timeflow_future_sight", false)),
        "Seher braucht seinen verzögerten Positions-/Slot-Pfad."
    )


func _forced_sequence(move: Dictionary) -> Dictionary:
    var value: Variant = _runtime(move).get("forced_sequence", {})
    return value if value is Dictionary else {}


func _move(moves: Dictionary, move_id: String) -> Dictionary:
    var value: Variant = moves.get(move_id, {})
    if not (value is Dictionary):
        _fail(move_id + ": Attackendefinition fehlt.")
        return {}
    return value as Dictionary


func _runtime(move: Dictionary) -> Dictionary:
    var value: Variant = move.get("runtime", {})
    return value if value is Dictionary else {}


func _status_aggro(move: Dictionary) -> bool:
    var value: Variant = move.get("aggro", {})
    if not (value is Dictionary):
        return false
    var aggro: Dictionary = value
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
