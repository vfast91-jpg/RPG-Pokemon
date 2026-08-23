extends SceneTree

const MOVE_PACKS: Array[String] = [
    "res://data/gen1_moves_runtime_v3_27_1_families_21_30.json",
    "res://data/gen1_moves_runtime_v3_27_2_families_21_30.json",
    "res://data/gen1_moves_runtime_v3_27_3_families_21_30.json",
    "res://data/gen1_moves_runtime_v3_27_4_families_21_30.json",
    "res://data/gen1_moves_runtime_v3_27_5_families_21_30.json"
]
const EXPECTED_MOVE_IDS: Array[String] = [
    "aqua_ring", "aurora_beam", "brine", "dive", "ice_shard", "icicle_spear", "sheer_cold", "triple_axel", "poison_gas", "sludge", "minimize", "memento", "razor_shell", "icicle_crash", "lick", "mean_look", "shadow_punch", "destiny_bond", "amnesia", "poltergeist", "phantom_force", "ancient_power", "head_smash", "hammer_arm", "wide_guard", "flail", "slam", "crabhammer", "guillotine", "hail", "counter", "final_gambit", "wood_hammer", "bonemerang", "skull_bash"
]

func _init() -> void:
    var failures: Array[String] = []
    var moves: Dictionary = {}

    for pack_path: String in MOVE_PACKS:
        if not FileAccess.file_exists(pack_path):
            failures.append("Fehlendes Datenpaket: " + pack_path)
            continue
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pack_path))
        if not (parsed is Dictionary):
            failures.append("Ungültiges JSON: " + pack_path)
            continue
        var pack_moves_value: Variant = (parsed as Dictionary).get("moves", {})
        if not (pack_moves_value is Dictionary):
            failures.append("moves-Dictionary fehlt: " + pack_path)
            continue
        for move_id_value: Variant in (pack_moves_value as Dictionary).keys():
            var move_id: String = str(move_id_value)
            if moves.has(move_id):
                failures.append("Doppelte Attacken-ID: " + move_id)
            moves[move_id] = (pack_moves_value as Dictionary).get(move_id_value)

    if moves.size() != EXPECTED_MOVE_IDS.size():
        failures.append(
            "Attackenanzahl falsch: erwartet %d, gefunden %d"
            % [EXPECTED_MOVE_IDS.size(), moves.size()]
        )

    for move_id: String in EXPECTED_MOVE_IDS:
        if not moves.has(move_id):
            failures.append("Attacke fehlt: " + move_id)
            continue
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            failures.append("Attacke ist kein Dictionary: " + move_id)
            continue
        var runtime_value: Variant = (move_value as Dictionary).get("runtime", {})
        if (
            runtime_value is Dictionary
            and not bool((runtime_value as Dictionary).get("runtime_supported", true))
        ):
            failures.append("Attacke ist nicht runtime-fähig: " + move_id)

    _assert_field(moves, "poltergeist", "accuracy", 80, failures)
    _assert_field(moves, "mean_look", "ap", 8, failures)
    _assert_field(moves, "wide_guard", "priority", 3, failures)
    _assert_field(moves, "wide_guard", "opening_only", true, failures)
    _assert_field(moves, "hail", "target", "battlefield", failures)
    _assert_runtime_field(moves, "dive", "timeflow_charge_state", "underwater", failures)
    _assert_runtime_field(moves, "phantom_force", "timeflow_charge_state", "phantom_hidden", failures)
    _assert_runtime_field(moves, "bonemerang", "multi_hit", {"kind":"fixed","count":2}, failures)
    _assert_runtime_field(moves, "skull_bash", "charge_then_fire", true, failures)

    _assert_field(moves, "amnesia", "ap", 5, failures)
    _assert_field(moves, "amnesia", "target", "self", failures)
    _assert_field(moves, "amnesia", "category", "status", failures)
    _assert_first_mechanic_field(
        moves, "amnesia", "kind", "incoming_damage_mod", failures
    )
    _assert_first_mechanic_field(
        moves, "amnesia", "multiplier_from_special", -2.0, failures
    )
    _assert_first_mechanic_field(
        moves, "amnesia", "duration", "3_actions", failures
    )
    _assert_first_mechanic_field(
        moves, "amnesia", "scope", "self", failures
    )

    var weather_value: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/rules/weather_rules.json")
    )
    if not (weather_value is Dictionary):
        failures.append("weather_rules.json ist ungültig")
    else:
        var weathers_value: Variant = (weather_value as Dictionary).get("weathers", {})
        var hail_value: Variant = (
            (weathers_value as Dictionary).get("hail", {})
            if weathers_value is Dictionary else {}
        )
        if not (hail_value is Dictionary):
            failures.append("Zentrales Wetter Hagel fehlt")
        elif not is_equal_approx(float((hail_value as Dictionary).get("duration_seconds", 0.0)), 50.0):
            failures.append("Hagel muss 50 Sekunden aktive Kampfzeit dauern")

    var main_scene: String = FileAccess.get_file_as_string("res://main.tscn")
    if not main_scene.contains("res://scripts/battle_demo_pvp_active_v1.gd"):
        failures.append("main.tscn verwendet nicht den aktiven PvP-Kampfstack")

    var pvp_top: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_pvp_active_v1.gd"
    )
    if not pvp_top.contains('extends "res://scripts/battle_demo_families_41_64_runtime_v1.gd"'):
        failures.append("Aktiver PvP-Stack lädt den Familien-41-64-Runtime-Layer nicht")

    var f64_registry: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_families_41_64_registry_v1.gd"
    )
    if not f64_registry.contains('extends "res://scripts/battle_demo_families_31_40_runtime_v1.gd"'):
        failures.append("Familien-41-64-Stack reicht nicht bis Familien 31-40 zurück")

    var f40_runtime: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_families_31_40_runtime_v1.gd"
    )
    if not f40_runtime.contains('extends "res://scripts/battle_demo_families_21_30_runtime_v1.gd"'):
        failures.append("Aktiver Kampfstack lädt den Familien-21-30-Runtime-Layer nicht")

    var runtime_text: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_families_21_30_runtime_v1.gd"
    )
    var status_text: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_families_21_30_status_support_v1.gd"
    )
    var special_text: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_families_21_30_special_support_v1.gd"
    )
    for required_marker: String in [
        "_f30_enforce_mean_look_locks",
        "_f30_wide_guard_blocks",
        "_f30_hail_pulse",
        "_f30_counter",
        "_f30_final_gambit",
        "phantom_hidden"
    ]:
        if (
            not runtime_text.contains(required_marker)
            and not status_text.contains(required_marker)
            and not special_text.contains(required_marker)
        ):
            failures.append("Runtime-Marker fehlt: " + required_marker)

    if failures.is_empty():
        print(
            "Familien 21-30 Attackenblock V20: OK (%d Definitionen)"
            % EXPECTED_MOVE_IDS.size()
        )
        quit(0)
        return

    for failure: String in failures:
        push_error(failure)
    quit(1)


func _assert_field(
    moves: Dictionary,
    move_id: String,
    key: String,
    expected: Variant,
    failures: Array[String]
) -> void:
    var move_value: Variant = moves.get(move_id, {})
    if not (move_value is Dictionary):
        failures.append("Kann Feld nicht prüfen, Attacke fehlt: " + move_id)
        return
    var actual: Variant = (move_value as Dictionary).get(key, null)
    if actual != expected:
        failures.append(
            "%s.%s: erwartet %s, gefunden %s"
            % [move_id, key, str(expected), str(actual)]
        )


func _assert_runtime_field(
    moves: Dictionary,
    move_id: String,
    key: String,
    expected: Variant,
    failures: Array[String]
) -> void:
    var move_value: Variant = moves.get(move_id, {})
    if not (move_value is Dictionary):
        failures.append("Kann Runtime-Feld nicht prüfen, Attacke fehlt: " + move_id)
        return
    var runtime_value: Variant = (move_value as Dictionary).get("runtime", {})
    if not (runtime_value is Dictionary):
        failures.append("Runtime-Dictionary fehlt: " + move_id)
        return
    var actual: Variant = (runtime_value as Dictionary).get(key, null)
    if actual != expected:
        failures.append(
            "%s.runtime.%s: erwartet %s, gefunden %s"
            % [move_id, key, str(expected), str(actual)]
        )


func _assert_first_mechanic_field(
    moves: Dictionary,
    move_id: String,
    key: String,
    expected: Variant,
    failures: Array[String]
) -> void:
    var move_value: Variant = moves.get(move_id, {})
    if not (move_value is Dictionary):
        failures.append("Kann Mechanik nicht prüfen, Attacke fehlt: " + move_id)
        return
    var mechanics_value: Variant = (move_value as Dictionary).get("mechanics", [])
    if not (mechanics_value is Array) or (mechanics_value as Array).is_empty():
        failures.append("Mechanik fehlt: " + move_id)
        return
    var mechanic_value: Variant = (mechanics_value as Array)[0]
    if not (mechanic_value is Dictionary):
        failures.append("Erste Mechanik ist kein Dictionary: " + move_id)
        return
    var actual: Variant = (mechanic_value as Dictionary).get(key, null)
    if actual != expected:
        failures.append(
            "%s.mechanics[0].%s: erwartet %s, gefunden %s"
            % [move_id, key, str(expected), str(actual)]
        )
