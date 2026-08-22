extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_bulbasaur_family_tm_final.gd")

const BULBASAUR_TMS: Array[String] = [
    "take_down","charm","protect","acid_spray","trailblaze","facade","magical_leaf",
    "venoshock","endure","sunny_day","bullet_seed","false_swipe","body_slam",
    "sleep_talk","seed_bomb","grass_knot","rest","swords_dance","substitute",
    "giga_drain","energy_ball","helping_hand","grassy_terrain","grass_pledge",
    "sludge_bomb","leaf_storm","solar_beam","toxic","knock_off","weather_ball",
    "grassy_glide","double_edge","curse"
]
const IVYSAUR_TMS: Array[String] = [
    "take_down","charm","protect","acid_spray","trailblaze","facade","magical_leaf",
    "venoshock","endure","sunny_day","bullet_seed","false_swipe","body_slam",
    "sleep_talk","seed_bomb","grass_knot","rest","swords_dance","substitute",
    "giga_drain","energy_ball","helping_hand","grassy_terrain","grass_pledge",
    "sludge_bomb","leaf_storm","solar_beam","roar","toxic","knock_off","weather_ball",
    "grassy_glide","double_edge","curse"
]
const VENUSAUR_TMS: Array[String] = [
    "take_down","charm","scary_face","protect","acid_spray","trailblaze","facade",
    "bulldoze","magical_leaf","venoshock","endure","sunny_day","bullet_seed",
    "false_swipe","body_slam","sleep_talk","seed_bomb","grass_knot","poison_jab",
    "stomping_tantrum","rest","swords_dance","substitute","giga_drain","energy_ball",
    "amnesia","helping_hand","earth_power","grassy_terrain","grass_pledge","sludge_bomb",
    "earthquake","giga_impact","frenzy_plant","leaf_storm","hyper_beam","solar_beam",
    "roar","toxic","knock_off","weather_ball","grassy_glide","double_edge","curse"
]

const NEW_MOVE_IDS: Array[String] = [
    "false_swipe","body_slam","leaf_storm","toxic","knock_off","weather_ball",
    "grassy_glide","curse","bulldoze","stomping_tantrum","amnesia","earth_power",
    "earthquake","frenzy_plant"
]


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    _assert_inventory(lab, "bulbasaur", BULBASAUR_TMS, 33)
    _assert_inventory(lab, "ivysaur", IVYSAUR_TMS, 34)
    _assert_inventory(lab, "venusaur", VENUSAUR_TMS, 44)

    for move_id: String in NEW_MOVE_IDS:
        var move: Dictionary = lab._move_data(move_id)
        assert(not move.is_empty(), "Neue Familien-TM fehlt: " + move_id)
        var runtime_value: Variant = move.get("runtime", {})
        assert(runtime_value is Dictionary, "Runtime-Block fehlt: " + move_id)
        assert(bool((runtime_value as Dictionary).get("runtime_supported", false)), "Runtime nicht aktiv: " + move_id)
        assert(bool((runtime_value as Dictionary).get("contract_validated", false)), "V4-Vertrag nicht validiert: " + move_id)
        assert(not str(move.get("emoji", "")).is_empty(), "Emoji fehlt: " + move_id)
        assert(not lab._compact_effect_summary(move).is_empty(), "Spielertext fehlt: " + move_id)

    var glide: Dictionary = lab._move_data("grassy_glide")
    assert(int(glide.get("priority", -1)) == 0, "Grasrutsche darf keine normale Priorität erhalten.")
    assert(not bool(glide.get("opening", true)), "Grasrutsche darf nicht als Runde-0-Attacke gelten.")

    var knock_off: Dictionary = lab._move_data("knock_off")
    var knock_summary: String = lab._compact_effect_summary(knock_off).to_lower()
    assert(not knock_summary.contains("item"), "Abschlag darf im Spielertext kein Item-System voraussetzen.")
    assert(knock_summary.contains("temporären attributseffekt"), "Abschlag muss die Timeflow-Ersatzmechanik erklären.")

    var roar: Dictionary = lab._move_data("roar")
    assert(bool((roar.get("runtime", {}) as Dictionary).get("runtime_supported", false)), "Brüller muss vollständig aktiv sein.")
    assert(str((roar.get("mechanics", []) as Array)[0].get("kind", "")) == "db_atb_pause", "Brüller muss die zentrale ATB-Pause verwenden.")

    var manifest: Dictionary = _read_json("res://data/gen1_database_manifest_v3.json")
    assert(int(manifest.get("move_count", 0)) == 221, "Kanonisches Manifest muss 221 eindeutige Attacken enthalten.")
    assert((manifest.get("move_files", []) as Array).has("res://data/gen1_moves_runtime_v3_bulbasaur_tms.json"), "Das bisherige Bisasam-TM-Paket muss kanonisch im Manifest liegen.")
    assert((manifest.get("move_files", []) as Array).has("res://data/gen1_moves_runtime_v3_10_bulbasaur_family_tms.json"), "Das neue Familien-TM-Paket fehlt im Manifest.")

    print("Bisasam-Familie TM inventory/runtime test: PASS")
    lab.queue_free()
    quit(0)


func _assert_inventory(lab, species_id: String, expected: Array[String], expected_count: int) -> void:
    var available: Array = lab._lab_available_tm_moves(species_id)
    assert(available.size() == expected_count, "%s muss exakt %d Nicht-Tera-TMs besitzen, gefunden: %d" % [species_id, expected_count, available.size()])
    assert(not available.has("tera_blast"), "Tera-Ausbruch darf nicht in der TM-Liste vorkommen: " + species_id)
    for move_id: String in expected:
        assert(available.has(move_id), "%s: TM fehlt: %s" % [species_id, move_id])
        assert(lab._runtime_has_move(move_id), "%s: TM besitzt keine aktive Runtime: %s" % [species_id, move_id])


func _read_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
