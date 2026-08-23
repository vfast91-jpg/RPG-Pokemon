extends SceneTree

const MOVE_PACKS: Array[String] = [
    "res://data/gen1_moves_runtime_v3_26_1_abra_to_doduo.json",
    "res://data/gen1_moves_runtime_v3_26_2_abra_to_doduo.json",
    "res://data/gen1_moves_runtime_v3_26_3_abra_to_doduo.json",
    "res://data/gen1_moves_runtime_v3_26_4_abra_to_doduo.json"
]

const EXPECTED_MOVE_IDS: Array[String] = [
    "teleport", "psycho_cut", "recover", "dream_eater", "power_up_punch",
    "vital_throw", "bullet_punch", "detect", "heavy_slam", "dual_chop",
    "storm_throw", "leaf_blade", "reflect_type", "acid_armor", "rock_polish",
    "rock_throw", "self_destruct", "explosion", "hard_press", "stomp",
    "smart_strike", "mystical_fire", "ally_switch", "yawn", "headbutt",
    "slack_off", "psychic_terrain", "scald", "snowscape", "trick_room",
    "chilly_reception", "heal_pulse", "magnet_rise", "steel_beam", "metal_sound",
    "magnetic_flux", "mirror_coat", "lock_on", "zap_cannon", "supercell_slam",
    "revenge", "brutal_swing", "acupressure", "throat_chop"
]

func _init() -> void:
    var failures: Array[String] = []
    var merged: Dictionary = {}

    for path: String in MOVE_PACKS:
        if not FileAccess.file_exists(path):
            failures.append("Fehlendes Datenpaket: " + path)
            continue
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not (parsed is Dictionary):
            failures.append("Ungültiges JSON: " + path)
            continue
        var moves_value: Variant = (parsed as Dictionary).get("moves", {})
        if not (moves_value is Dictionary):
            failures.append("moves-Dictionary fehlt: " + path)
            continue
        for move_id_value: Variant in (moves_value as Dictionary).keys():
            var move_id: String = str(move_id_value)
            if merged.has(move_id):
                failures.append("Doppelte Attacken-ID im Block: " + move_id)
            merged[move_id] = (moves_value as Dictionary).get(move_id_value)

    if merged.size() != EXPECTED_MOVE_IDS.size():
        failures.append(
            "Attackenanzahl falsch: erwartet %d, gefunden %d"
            % [EXPECTED_MOVE_IDS.size(), merged.size()]
        )

    for move_id: String in EXPECTED_MOVE_IDS:
        if not merged.has(move_id):
            failures.append("Attacke fehlt: " + move_id)
            continue
        var move_value: Variant = merged.get(move_id, {})
        if not (move_value is Dictionary):
            failures.append("Attacke ist kein Dictionary: " + move_id)
            continue
        var runtime_value: Variant = (move_value as Dictionary).get("runtime", {})
        if runtime_value is Dictionary and not bool((runtime_value as Dictionary).get("runtime_supported", true)):
            failures.append("Attacke ist nicht runtime-fähig: " + move_id)

    _assert_field(merged, "supercell_slam", "emoji", "⚡", failures)
    _assert_field(merged, "throat_chop", "name", "Halsabschneider", failures)
    _assert_field(merged, "teleport", "target", "self", failures)
    _assert_field(merged, "heal_pulse", "target", "single_ally", failures)
    _assert_field(merged, "snowscape", "target", "global_battlefield", failures)

    var weather_path: String = "res://data/rules/weather_rules.json"
    var weather_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(weather_path))
    if not (weather_value is Dictionary):
        failures.append("weather_rules.json ist ungültig")
    else:
        var weathers_value: Variant = (weather_value as Dictionary).get("weathers", {})
        var snow_value: Variant = (
            (weathers_value as Dictionary).get("snow", {})
            if weathers_value is Dictionary else {}
        )
        if not (snow_value is Dictionary):
            failures.append("Zentrales Wetter Schnee fehlt")
        elif not is_equal_approx(float((snow_value as Dictionary).get("duration_seconds", 0.0)), 50.0):
            failures.append("Schnee muss 50 Sekunden aktive Kampfzeit dauern")

    var main_scene: String = FileAccess.get_file_as_string("res://main.tscn")
    if not main_scene.contains("res://scripts/battle_demo_ad_final_v1.gd"):
        failures.append("main.tscn aktiviert den finalen Abra-bis-Dodu-Runtime-Layer nicht")

    var final_runtime: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_ad_final_v1.gd"
    )
    if not final_runtime.contains("return _cleffa_gravity_is_active()"):
        failures.append("Magnetflug nutzt nicht die zentrale Erdanziehung")
    if not final_runtime.contains("_database_move_was_attempted"):
        failures.append("Finaler Selbstkosten-/Selbst-K.O.-Aktionsguard fehlt")
    if not final_runtime.contains("_combined_timed_modifier(candidate, \"atb_cycle_mod\")"):
        failures.append("Bizarroraum berücksichtigt temporäre Geschwindigkeitsmodifikatoren nicht")

    if failures.is_empty():
        print("Abra->Dodu/Dodri Attackenblock: OK (44 Definitionen inkl. Halsabschneider-Korrektur)")
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
