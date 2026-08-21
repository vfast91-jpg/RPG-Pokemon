extends SceneTree

const CombatLabTmScript = preload("res://scripts/battle_demo_lab_tm_toggle.gd")

const EXPECTED_BULBASAUR_TMS: Array[String] = [
    "take_down", "charm", "protect", "trailblaze", "facade", "magical_leaf",
    "endure", "sunny_day", "bullet_seed", "sleep_talk", "seed_bomb",
    "grass_knot", "rest", "substitute", "giga_drain", "energy_ball",
    "helping_hand", "grassy_terrain", "grass_pledge", "sludge_bomb",
    "solar_beam"
]

const NEW_MOVE_NAMES: Dictionary = {
    "trailblaze": "Wegbereiter",
    "magical_leaf": "Zauberblatt",
    "bullet_seed": "Kugelsaat",
    "giga_drain": "Gigasauger",
    "energy_ball": "Energieball",
    "facade": "Fassade",
    "endure": "Ausdauer",
    "rest": "Erholung",
    "sleep_talk": "Schlafrede",
    "substitute": "Delegator",
    "grass_knot": "Strauchler",
    "helping_hand": "Rechte Hand",
    "grassy_terrain": "Grasfeld",
    "grass_pledge": "Pflanzensäulen"
}


func _initialize() -> void:
    var lab = CombatLabTmScript.new()
    root.add_child(lab)

    assert(lab.lab_all_tms_toggle != null, "TM-Testcheckbox fehlt.")
    lab.lab_all_tms_toggle.button_pressed = true

    var available: Array = lab._lab_available_tm_moves("bulbasaur")
    assert(available.size() == 21, "Bisasam muss exakt 21 Nicht-Tera-TMs im Kampflabor erhalten.")
    for move_id: String in EXPECTED_BULBASAUR_TMS:
        assert(available.has(move_id), "Bisasam-TM fehlt: " + move_id)
    assert(not available.has("tera_blast"), "Tera-Ausbruch darf im Kampflabor nicht existieren.")

    var combatant: Dictionary = lab._make_combatant(
        "player", 0, {"species_id": "bulbasaur", "level": 5}
    )
    var combatant_moves: Array = combatant.get("moves", [])
    for move_id: String in EXPECTED_BULBASAUR_TMS:
        assert(combatant_moves.has(move_id), "Aktiviertes Bisasam erhält TM nicht: " + move_id)

    assert(is_equal_approx(float(combatant.get("db_weight_kg", 0.0)), 6.9), "Bisasams Gewichtsdaten fehlen.")

    for move_id_value: Variant in NEW_MOVE_NAMES.keys():
        var move_id: String = str(move_id_value)
        var move: Dictionary = lab._move_data(move_id)
        assert(not move.is_empty(), "Runtime-Attacke fehlt: " + move_id)
        assert(str(move.get("name", "")) == str(NEW_MOVE_NAMES[move_id]), "Deutscher Name falsch: " + move_id)
        var runtime_value: Variant = move.get("runtime", {})
        assert(runtime_value is Dictionary and bool((runtime_value as Dictionary).get("runtime_supported", false)), "Runtime nicht aktiv: " + move_id)

    # The runtime purge is global: no loaded species may still advertise Tera Blast.
    var species_value: Variant = lab.data.get("species", {})
    if species_value is Dictionary:
        for entry_value: Variant in (species_value as Dictionary).values():
            if not (entry_value is Dictionary):
                continue
            var learnset_value: Variant = (entry_value as Dictionary).get("source_learnset", {})
            if not (learnset_value is Dictionary):
                continue
            var tm_value: Variant = (learnset_value as Dictionary).get("tm_hm", {})
            if tm_value is Dictionary:
                assert(not (tm_value as Dictionary).values().has("tera_blast"), "Tera-Ausbruch blieb in einer Runtime-TM-Liste zurück.")

    var endure: Dictionary = lab._move_data("endure")
    assert(str((endure.get("mechanics", []) as Array)[0].get("kind", "")) == "bulba_endure", "Ausdauer-Runtime fehlt.")
    var substitute: Dictionary = lab._move_data("substitute")
    assert(str((substitute.get("mechanics", []) as Array)[0].get("kind", "")) == "bulba_substitute", "Delegator-Runtime fehlt.")
    assert(str(substitute.get("emoji", "")) == "🧸", "Delegator muss das Teddybär-Emoji verwenden.")

    print("Bulbasaur TM runtime test: PASS")
    lab.queue_free()
    quit(0)
