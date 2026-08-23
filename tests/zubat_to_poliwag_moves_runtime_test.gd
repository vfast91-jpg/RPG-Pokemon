extends SceneTree

const PACK_PATHS: Array[String] = [
    "res://data/gen1_moves_runtime_v3_25_1_zubat_to_poliwag.json",
    "res://data/gen1_moves_runtime_v3_25_2_zubat_to_poliwag.json",
    "res://data/gen1_moves_runtime_v3_25_3_zubat_to_poliwag.json",
    "res://data/gen1_moves_runtime_v3_25_4_zubat_to_poliwag.json"
]
const MAIN_SCENE_PATH := "res://main.tscn"
const REGISTRY_SCRIPT_PATH := "res://scripts/battle_demo_zf_registry_v1.gd"
const COMBAT_SCRIPT_PATH := "res://scripts/battle_demo_zf_combat_v1.gd"
const STATUS_SCRIPT_PATH := "res://scripts/battle_demo_zf_status_v1.gd"
const PAYDAY_SCRIPT_PATH := "res://scripts/battle_demo_zf_payday_v1.gd"

const EXPECTED_IDS: Array[String] = [
    "absorb", "hypnosis", "poison_fang", "ominous_wind", "razor_wind",
    "sky_attack", "night_slash", "double_hit", "brave_bird", "mega_drain",
    "solar_blade", "spore", "cross_poison", "aromatherapy", "struggle_bug",
    "pounce", "lunge", "astonish", "rock_blast", "tri_attack", "fissure",
    "fake_out", "pay_day", "switcheroo", "power_gem", "aqua_jet",
    "low_sweep", "soak", "vacuum_wave", "waterfall", "wonder_room",
    "bulk_up", "close_combat", "cross_chop", "rage_fist", "seismic_toss",
    "thrash", "howl", "flame_wheel", "retaliate", "extreme_speed",
    "bubble_beam", "belly_drum", "circle_throw", "dynamic_punch", "coaching",
    "bounce", "perish_song"
]


func _initialize() -> void:
    var moves: Dictionary = {}
    for path: String in PACK_PATHS:
        var pack: Dictionary = _read_json(path)
        assert(not pack.is_empty(), "Attackenpaket fehlt: " + path)
        var entries: Variant = pack.get("moves", {})
        assert(entries is Dictionary, "moves-Dictionary fehlt: " + path)
        for move_id_value: Variant in (entries as Dictionary).keys():
            var move_id: String = str(move_id_value)
            assert(not moves.has(move_id), "Doppelte neue Attacken-ID: " + move_id)
            moves[move_id] = (entries as Dictionary)[move_id_value]

    assert(moves.size() == 48, "Der Zehnerblock muss exakt 48 freigegebene Attacken enthalten.")
    assert(EXPECTED_IDS.size() == 48, "Testliste muss 48 IDs enthalten.")
    for move_id: String in EXPECTED_IDS:
        assert(moves.has(move_id), "Neue Attacke fehlt: " + move_id)
        var move: Dictionary = moves[move_id]
        assert(bool((move.get("runtime", {}) as Dictionary).get("runtime_supported", false)), move_id + ": Runtime muss aktiv sein.")

    assert(int((moves["coaching"] as Dictionary).get("ap", -1)) == 7, "Coaching muss final AP 7 haben.")
    assert(int((moves["howl"] as Dictionary).get("ap", -1)) == 6, "Jauler muss final AP 6 haben.")
    assert(str((moves["coaching"] as Dictionary).get("target", "")) == "single_ally", "Coaching braucht freie Verbündetenwahl.")
    assert(bool(((moves["coaching"] as Dictionary).get("runtime", {}) as Dictionary).get("requires_ally_selection", false)), "Coaching-Zielwahl fehlt.")
    assert(bool(((moves["switcheroo"] as Dictionary).get("runtime", {}) as Dictionary).get("requires_enemy_selection", false)), "Wechseldich braucht freie Gegnerwahl.")
    assert(str((moves["wonder_room"] as Dictionary).get("target", "")) == "battlefield", "Wunderraum muss global sein.")
    assert(is_equal_approx(float(((moves["wonder_room"] as Dictionary).get("runtime", {}) as Dictionary).get("duration_active_seconds", 0.0)), 50.0), "Wunderraum muss 50 Sekunden halten.")

    for move_id: String in ["fake_out", "aqua_jet", "vacuum_wave", "extreme_speed"]:
        var move: Dictionary = moves[move_id]
        assert(bool(move.get("opening", false)), move_id + ": muss Runde 0 erlauben.")
        assert(bool(move.get("opening_only", false)), move_id + ": muss Runde-0-exklusiv sein.")
        assert(int(move.get("ap", 0)) == 8, move_id + ": muss AP 8 haben.")

    var main_scene: String = FileAccess.get_file_as_string(MAIN_SCENE_PATH)
    assert(main_scene.contains("battle_demo_zf_payday_v1.gd"), "main.tscn muss den finalen 48-Attacken-Layer laden.")

    var registry_script: String = FileAccess.get_file_as_string(REGISTRY_SCRIPT_PATH)
    assert(registry_script.contains("battle_demo_remaining_gen1_species_v1.gd"), "Registry muss auf dem vollständigen Gen1-Familien-Layer aufbauen.")
    assert(registry_script.contains("_zf_rebuild_species_runtime_after_move_load"), "Neue Attacken müssen die bestehenden Lernlisten neu auflösen.")

    var combat_script: String = FileAccess.get_file_as_string(COMBAT_SCRIPT_PATH)
    assert(combat_script.contains("_tf_apply_bad_poison"), "Giftzahn muss die zentrale schwere Vergiftung wiederverwenden.")
    assert(combat_script.contains("_zf_drain"), "Drain-Regel fehlt.")
    assert(combat_script.contains("_zf_aggro_swap"), "Wechseldich-Aggrotausch fehlt.")
    assert(combat_script.contains("zf_direct_hits_received"), "Zornesfaust-Trefferzähler fehlt.")

    var status_script: String = FileAccess.get_file_as_string(STATUS_SCRIPT_PATH)
    assert(status_script.contains("ZF_WONDER_ROOM_DURATION_SECONDS"), "Wunderraum-Laufzeit fehlt.")
    assert(status_script.contains("zf_perish_count"), "Abgesang-Countdown fehlt.")
    assert(status_script.contains("ZF_FREEZE_THAW_CHANCE"), "Gefroren-Laufzeitregel fehlt.")

    var payday_script: String = FileAccess.get_file_as_string(PAYDAY_SCRIPT_PATH)
    assert(payday_script.contains("_healing_item_for_stage"), "Zahltag muss denselben Fundstellen-Heilitem-Resolver benutzen.")
    assert(payday_script.contains("_revive_hp_amount"), "Zahltag muss den zentralen Beleber-Wert wiederverwenden.")

    print("Zubat-to-Poliwag attack block passed: 48 runtime moves + final Timeflow corrections.")
    quit(0)


func _read_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    assert(parsed is Dictionary, "JSON konnte nicht gelesen werden: " + path)
    return parsed as Dictionary
