extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_v22_effective_speed_integrity_v1.gd")
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
const V22_INTENTIONALLY_LOCKED_IDS: Array[String] = ["belch"]
const MULTI_HIT_CONTRACTS: Dictionary = {
    "fury_attack": [2, 5, [3, 3, 1, 1]],
    "pin_missile": [2, 5, [3, 3, 1, 1]],
    "bullet_seed": [2, 5, [7, 7, 3, 3]],
    "scale_shot": [2, 5, [7, 7, 3, 3]],
    "fury_swipes": [2, 5, [3, 3, 1, 1]],
    "double_kick": [2, 2, [1]],
    "dual_wingbeat": [2, 2, [1]],
    "double_hit": [2, 2, [1]],
    "rock_blast": [2, 5, [3, 3, 1, 1]],
    "dual_chop": [2, 2, [1]],
    "icicle_spear": [2, 5, [3, 3, 1, 1]],
    "triple_axel": [3, 3, [1]],
    "bonemerang": [2, 2, [1]],
    "triple_kick": [3, 3, [1]]
}

var failures: int = 0


func _initialize() -> void:
    var battle = CurrentBattleScript.new()
    battle._load_data()
    var moves_value: Variant = battle.data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}

    _check(V22MoveCatalog.count() == 479, "V22-Katalog muss genau 479 Attacken enthalten.")
    _check(moves.size() >= 479, "Finaler Runtime-Bestand ist kleiner als der V22-Katalog.")
    for move_id: String in V22MoveCatalog.IDS:
        _check(moves.has(move_id), "Kanonische V22-Attacke fehlt: " + move_id)
        if not moves.has(move_id):
            continue
        var move: Dictionary = _move(moves, move_id)
        var supported: bool = bool(_runtime(move).get("runtime_supported", true))
        if V22_INTENTIONALLY_LOCKED_IDS.has(move_id):
            _check(not supported, move_id + ": V22-Zukunftssperre wurde versehentlich aufgehoben.")
        else:
            _check(supported, move_id + ": runtime_supported=false")
        _check(battle._v22_move_has_executable_path(move), move_id + ": kein ausführbarer Runtime-Pfad")

    _test_rock_slide(battle, moves)
    _test_per_target_accuracy(moves)
    _test_targets(moves)
    _test_confirmed_drift(moves)
    _test_flinch_catalog(moves)
    _test_sequences(moves)
    _test_charge_and_delay_paths(moves)
    _test_runtime_completion(battle, moves)
    _test_critical_support(battle, moves)
    _test_effective_speed_power(battle, moves)
    _test_intentional_locks(moves)

    battle.free()
    if failures == 0:
        print("V22 final attack runtime regression test: PASS")
        quit(0)
    push_error("V22 final attack runtime regression test: %d Fehler" % failures)
    quit(1)


func _test_rock_slide(battle, moves: Dictionary) -> void:
    var move: Dictionary = _move(moves, "rock_slide")
    _check(int(move.get("power", 0)) == 75, "Steinhagel: Stärke muss 75 sein.")
    _check(is_equal_approx(float(move.get("accuracy", 0.0)), 90.0), "Steinhagel: Genauigkeit muss 90 sein.")
    _check(str(move.get("target", "")) == "all_enemies", "Steinhagel: falsches Ziel.")
    _check(bool(move.get("area", false)), "Steinhagel: area=true fehlt.")
    _check(_has_mechanic(move, "damage"), "Steinhagel: Schadensmechanik fehlt.")
    _check(
        _has_any_mechanic(move, ["atb_knockback", "zf_flinch", "f40_flinch_on_damage", "f64_flinch_on_damage"]),
        "Steinhagel: Zurückschreckmechanik fehlt."
    )
    _check(bool(_runtime(move).get("v22_per_target_accuracy", false)), "Steinhagel: Genauigkeit nicht pro Ziel.")
    _check(_status_aggro(move), "Steinhagel: Status-Aggro fehlt.")

    var actor: Dictionary = {"id": "rock_actor", "side": "player"}
    var target: Dictionary = {"id": "rock_target", "side": "enemy", "hp": 90, "max_hp": 100, "atb": 67.0, "alive": true}
    battle._v22_active_move_id = "rock_slide"
    battle._zf_hp_before = {"rock_target": 100}
    battle._effect(actor, target, {"kind": "atb_knockback", "chance": 1.0, "amount": 0.25})
    _check(is_equal_approx(float(target.get("atb", -1.0)), 0.0), "Steinhagel darf keinen alten 25-%-Knockback verwenden.")
    battle._v22_active_move_id = ""
    battle._zf_hp_before.clear()


func _test_per_target_accuracy(moves: Dictionary) -> void:
    for move_id: String in PER_TARGET_ACCURACY_IDS:
        _check(
            bool(_runtime(_move(moves, move_id)).get("v22_per_target_accuracy", false)),
            move_id + ": getrennte Genauigkeitsprüfung pro Ziel fehlt."
        )


func _test_targets(moves: Dictionary) -> void:
    for move_id: String in ["switcheroo", "transform", "conversion_2"]:
        var move: Dictionary = _move(moves, move_id)
        _check(str(move.get("target", "")) == "single_enemy", move_id + ": muss freie Gegnerwahl verwenden.")
        _check(bool(_runtime(move).get("requires_enemy_selection", false)), move_id + ": Zielauswahl-UI fehlt.")
    for move_id: String in ["self_destruct", "explosion", "brutal_swing"]:
        var move: Dictionary = _move(moves, move_id)
        _check(str(move.get("target", "")) == "all_others", move_id + ": muss alle anderen treffen.")
        _check(bool(move.get("area", false)), move_id + ": area=true fehlt.")
    for move_id: String in ["self_destruct", "explosion"]:
        var runtime: Dictionary = _runtime(_move(moves, move_id))
        _check(bool(runtime.get("v22_unconditional_self_ko", false)), move_id + ": bedingungsloser Selbst-K.O. fehlt.")
        _check(not bool(runtime.get("f40_self_ko_on_any_damage", false)), move_id + ": alter schadensabhängiger Selbst-K.O. ist noch aktiv.")
    for move_id: String in ["swagger", "flatter"]:
        _check(
            str(_move(moves, move_id).get("target", "")) == "enemy_highest_aggro_or_single_ally",
            move_id + ": Hybrid-Zielregel fehlt."
        )
    _check(str(_move(moves, "dragon_cheer").get("target", "")) == "all_allies_except_self", "Drachenjubel: falsche Zielregel.")


func _test_confirmed_drift(moves: Dictionary) -> void:
    var psychic_noise: Dictionary = _move(moves, "psychic_noise")
    var noise_mechanic: Dictionary = _find_mechanic(psychic_noise, "f40_heal_block_on_damage")
    _check(not noise_mechanic.is_empty(), "Psycholärm: Heilsperre fehlt.")
    if not noise_mechanic.is_empty():
        _check(int(noise_mechanic.get("duration_actions", 0)) == 3, "Psycholärm: Heilsperre muss 3 Aktionen dauern.")
        _check(not bool(noise_mechanic.get("refresh", true)), "Psycholärm: Heilsperre darf nicht refreshen.")
    _check(_status_aggro(psychic_noise), "Psycholärm: Status-Aggro fehlt.")
    _check(_status_aggro(_move(moves, "blaze_kick")), "Feuerfeger: Verbrennung muss Status-Aggro erzeugen.")


func _test_flinch_catalog(moves: Dictionary) -> void:
    for move_id: String in FLINCH_IDS:
        _check(moves.has(move_id), "V22-Zurückschreckattacke fehlt: " + move_id)


func _test_sequences(moves: Dictionary) -> void:
    for move_id_value: Variant in MULTI_HIT_CONTRACTS.keys():
        var move_id: String = str(move_id_value)
        var expected: Array = MULTI_HIT_CONTRACTS[move_id]
        var spec_value: Variant = _runtime(_move(moves, move_id)).get("multi_hit", {})
        _check(spec_value is Dictionary, move_id + ": Multi-Hit-Vertrag fehlt.")
        if not (spec_value is Dictionary):
            continue
        var spec: Dictionary = spec_value
        _check(int(spec.get("min", 0)) == int(expected[0]), move_id + ": falsche Mindesttrefferzahl.")
        _check(int(spec.get("max", 0)) == int(expected[1]), move_id + ": falsche Höchsttrefferzahl.")
        _check(spec.get("weights", []) == expected[2], move_id + ": falsche Trefferverteilung.")
        _check(bool(spec.get("v22_target_aggro_once", false)), move_id + ": Ziel-Aggro darf nicht mehrfach halbiert werden.")

    var uproar: Dictionary = _forced_sequence(_move(moves, "uproar"))
    _check(int(uproar.get("min", 0)) == 3 and int(uproar.get("max", 0)) == 3, "Aufruhr muss exakt 3 Aktionen dauern.")
    _check(not bool(uproar.get("confuse_after", false)), "Aufruhr darf keine automatische Abschlussverwirrung erzwingen.")

    var rollout: Dictionary = _move(moves, "rollout")
    var rollout_sequence: Dictionary = _forced_sequence(rollout)
    _check(int(rollout_sequence.get("min", 0)) == 5 and int(rollout_sequence.get("max", 0)) == 5, "Walzer muss bis zu 5 Aktionen vorsehen.")
    _check(_runtime(rollout).get("consecutive_power_chain", []) == [30, 60, 120, 240, 480], "Walzer: falsche Stärkenfolge.")


func _test_charge_and_delay_paths(moves: Dictionary) -> void:
    _check(not bool(_runtime(_move(moves, "meteor_beam")).get("charge_then_fire", false)), "Meteorstrahl darf nicht in den generischen Ziel-Lock fallen.")
    _check(bool(_runtime(_move(moves, "meteor_beam")).get("timeflow_meteor_beam", false)), "Meteorstrahl: Spezialpfad fehlt.")
    _check(bool(_runtime(_move(moves, "future_sight")).get("timeflow_future_sight", false)), "Seher: verzögerter Slot-Pfad fehlt.")


func _test_runtime_completion(battle, moves: Dictionary) -> void:
    for move_id: String in ["whirlwind", "roar"]:
        var move: Dictionary = _move(moves, move_id)
        _check(bool(_runtime(move).get("runtime_supported", false)), move_id + ": muss final spielbar sein.")
        _check(_has_mechanic(move, "db_atb_pause"), move_id + ": zentrale ATB-Pause fehlt.")
        _check(str(move.get("target", "")) == "enemy_highest_aggro", move_id + ": falsche Zielregel.")
        _check(_status_aggro(move), move_id + ": Status-Aggro fehlt.")
    _check(is_equal_approx(float(_move(moves, "whirlwind").get("accuracy", 0.0)), 100.0), "Wirbelwind muss Genauigkeit 100 haben.")
    _check(_move(moves, "roar").get("accuracy", 1) == null, "Brüller muss ohne normale Genauigkeitsprüfung auskommen.")

    var ingrain: Dictionary = _move(moves, "ingrain")
    _check(bool(_runtime(ingrain).get("runtime_supported", false)), "Verwurzler muss final spielbar sein.")
    _check(bool(_runtime(ingrain).get("v22_persistent_ingrain", false)), "Verwurzler: permanenter Runtime-Pfad fehlt.")
    _check(_has_mechanic(ingrain, "v22_ingrain"), "Verwurzler: Aktivierungsmechanik fehlt.")
    _check(str(ingrain.get("target", "")) == "self", "Verwurzler muss auf den Anwender zielen.")

    var rooted: Dictionary = {
        "id": "rooted_target", "side": "enemy", "alive": true,
        "hp": 50, "max_hp": 100, "special": 75.0, "speed": 50.0,
        "cycle": 1.0, "atb": 80.0, "aggro": 0.0, "action_serial": 1,
        "timed_modifiers": [], "db_atb_pause_remaining_seconds": 0.0
    }
    battle._v22_apply_ingrain(rooted)
    _check(bool(rooted.get("v22_ingrain_active", false)), "Verwurzler aktiviert rooted nicht.")
    battle._v22_trigger_ingrain_after_action(rooted)
    _check(int(rooted.get("hp", 0)) == 56, "Verwurzler-Heilung bei Status 75 muss 6 KP auf 100 Max-KP ergeben.")
    _check(is_equal_approx(float(rooted.get("aggro", 0.0)), 6.0), "Verwurzler-Aggro muss exakt der tatsächlichen Heilung entsprechen.")
    battle._v22_trigger_ingrain_after_action(rooted)
    _check(int(rooted.get("hp", 0)) == 56, "Verwurzler darf pro Aktionsserial nur einmal heilen.")

    var source: Dictionary = {"id": "pause_source", "side": "player", "alive": true, "special": 75.0}
    battle._v22_active_move_id = "whirlwind"
    battle._effect(source, rooted, {"kind": "db_atb_pause"})
    _check(is_equal_approx(float(rooted.get("db_atb_pause_remaining_seconds", 0.0)), 0.0), "Rooted muss Wirbelwind blockieren.")

    battle._v22_active_move_id = "dragon_tail"
    battle._effect(source, rooted, {"kind": "db_atb_pause"})
    _check(float(rooted.get("db_atb_pause_remaining_seconds", 0.0)) > 0.0, "Rooted darf Drachenruten-Pause nicht blockieren.")
    battle._v22_active_move_id = ""


func _test_critical_support(battle, moves: Dictionary) -> void:
    var focus_energy: Dictionary = _move(moves, "focus_energy")
    _check(_has_mechanic(focus_energy, "critical_focus"), "Energiefokus: critical_focus fehlt.")
    _check(
        is_equal_approx(float(battle._status_percent(75.0)), 50.0),
        "Energiefokus muss bei Status 75 +50 Prozentpunkte liefern, nicht den alten +25-Cap."
    )

    var dragon_cheer_active: Dictionary = {
        "cf_dragon_cheer_actions": 3,
        "db_focus_energy_bonus_pp": 0.0,
        "critical_focus_bonus": 0.0
    }
    _check(
        battle._v22_focus_energy_blocked_by_dragon_cheer(dragon_cheer_active),
        "Aktives Drachenjubel muss Energiefokus blockieren."
    )

    var focus_energy_active: Dictionary = {
        "cf_dragon_cheer_actions": 0,
        "db_focus_energy_bonus_pp": 50.0,
        "critical_focus_bonus": 0.5
    }
    _check(
        not battle._cf_dragon_cheer_eligible(focus_energy_active),
        "Aktiver Energiefokus muss Drachenjubel blockieren."
    )


func _test_effective_speed_power(battle, moves: Dictionary) -> void:
    var electro_ball: Dictionary = _move(moves, "electro_ball")
    var runtime: Dictionary = _runtime(electro_ball)
    _check(bool(runtime.get("runtime_supported", false)), "Elektroball muss spielbar sein.")
    _check(bool(runtime.get("timeflow_effective_speed_power", false)), "Elektroball: effektiver-Tempo-Pfad fehlt.")
    _check(runtime.get("power_tiers", []) == [40, 60, 80, 120, 150], "Elektroball: falsche V22-Stärkestufen.")

    var actor: Dictionary = {
        "speed": 100.0, "paralyzed": false, "cycle": 7.0, "atb": 0.0,
        "timed_modifiers": []
    }
    var target: Dictionary = {
        "speed": 50.0, "paralyzed": false, "cycle": 1.0, "atb": 99.0,
        "timed_modifiers": [], "db_atb_pause_remaining_seconds": 99.0
    }
    _check(
        battle._pika_electro_ball_power(actor, target) == 80,
        "Elektroball: Tempo 100 gegen 50 muss Verhältnis 2x und Stärke 80 ergeben."
    )

    actor["speed"] = 200.0
    _check(battle._pika_electro_ball_power(actor, target) == 150, "Elektroball: >=4x muss Stärke 150 ergeben.")
    actor["speed"] = 40.0
    _check(battle._pika_electro_ball_power(actor, target) == 40, "Elektroball: <1x muss Stärke 40 ergeben.")

    actor["speed"] = 100.0
    actor["paralyzed"] = true
    _check(
        battle._pika_electro_ball_power(actor, target) == 60,
        "Elektroball: Paralyse muss die wirksame Geschwindigkeit halbieren."
    )

    actor["paralyzed"] = false
    actor["speed"] = 50.0
    actor["timed_modifiers"] = [
        {"kind": "atb_cycle_mod", "multiplier": 0.5}
    ]
    _check(
        battle._pika_electro_ball_power(actor, target) == 80,
        "Elektroball: echte Tempo-Modifikatoren müssen in das Verhältnis eingehen."
    )


func _test_intentional_locks(moves: Dictionary) -> void:
    var belch: Dictionary = _move(moves, "belch")
    _check(not bool(_runtime(belch).get("runtime_supported", true)), "Rülpser darf vor der Beerenmechanik nicht regulär freigeschaltet sein.")
    _check(_has_mechanic(belch, "damage"), "Rülpser: zukünftiger Schadenspfad muss erhalten bleiben.")
    var rules: String = str(belch.get("special_rules", ""))
    _check(
        rules.contains("Beerenmechanik") or rules.contains("requires_berry_consumed"),
        "Rülpser: V22-Beerenabhängigkeit ist nicht dokumentiert."
    )


func _move(moves: Dictionary, move_id: String) -> Dictionary:
    var value: Variant = moves.get(move_id, {})
    return value as Dictionary if value is Dictionary else {}


func _runtime(move: Dictionary) -> Dictionary:
    var value: Variant = move.get("runtime", {})
    return value as Dictionary if value is Dictionary else {}


func _forced_sequence(move: Dictionary) -> Dictionary:
    var value: Variant = _runtime(move).get("forced_sequence", {})
    return value as Dictionary if value is Dictionary else {}


func _find_mechanic(move: Dictionary, kind: String) -> Dictionary:
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for value: Variant in mechanics_value:
            if value is Dictionary and str((value as Dictionary).get("kind", "")) == kind:
                return value as Dictionary
    return {}


func _has_mechanic(move: Dictionary, kind: String) -> bool:
    return not _find_mechanic(move, kind).is_empty()


func _has_any_mechanic(move: Dictionary, kinds: Array[String]) -> bool:
    for kind: String in kinds:
        if _has_mechanic(move, kind):
            return true
    return false


func _status_aggro(move: Dictionary) -> bool:
    var value: Variant = move.get("aggro", {})
    if not (value is Dictionary):
        return false
    var aggro: Dictionary = value
    return bool(aggro.get("status", aggro.get("from_status", false)))


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error("V22 TEST: " + message)
