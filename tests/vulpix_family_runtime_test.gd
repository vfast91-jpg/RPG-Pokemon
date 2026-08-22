extends SceneTree

const CurrentBattleScript = preload("res://scripts/battle_demo_vulpix_family.gd")
const SPECIES_PATH: String = "res://data/gen1_species_v3_vulpix_family_v1.json"
const MOVE_PATH: String = "res://data/gen1_moves_runtime_v3_23_vulpix_family.json"

var failures: int = 0


func _initialize() -> void:
    var species_pack: Dictionary = _read_json(SPECIES_PATH)
    var move_pack: Dictionary = _read_json(MOVE_PATH)
    var species_value: Variant = species_pack.get("species", {})
    var moves_value: Variant = move_pack.get("moves", {})
    var species: Dictionary = species_value if species_value is Dictionary else {}
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}

    _check(species.has("vulpix"), "Vulpix fehlt im Speziespaket.")
    _check(species.has("ninetales"), "Vulnona fehlt im Speziespaket.")
    _check_equal_int(moves.size(), 7, "Das Vulpix-Attackenpaket muss exakt sieben neue Attacken enthalten.")

    var vulpix_value: Variant = species.get("vulpix", {})
    var ninetales_value: Variant = species.get("ninetales", {})
    var vulpix: Dictionary = vulpix_value if vulpix_value is Dictionary else {}
    var ninetales: Dictionary = ninetales_value if ninetales_value is Dictionary else {}

    _check_equal_int(int(vulpix.get("pokedex_number", 0)), 37, "Vulpix hat die falsche Pokédexnummer.")
    _check_equal_int(int(ninetales.get("pokedex_number", 0)), 38, "Vulnona hat die falsche Pokédexnummer.")

    var evolution_value: Variant = vulpix.get("evolution", {})
    var evolution: Dictionary = evolution_value if evolution_value is Dictionary else {}
    _check_equal_int(int(evolution.get("evolution_level", 0)), 30, "Vulpix muss sich auf Level 30 entwickeln.")
    _check(bool(evolution.get("mandatory", false)), "Vulpix-Entwicklung muss verpflichtend sein.")
    _check(str(evolution.get("evolves_into", "")) == "ninetales", "Vulpix entwickelt sich nicht zu Vulnona.")

    var vulpix_learnset_value: Variant = vulpix.get("learnset", {})
    var vulpix_learnset: Dictionary = vulpix_learnset_value if vulpix_learnset_value is Dictionary else {}
    var vulpix_level_up_value: Variant = vulpix_learnset.get("level_up", {})
    var vulpix_level_up: Dictionary = vulpix_level_up_value if vulpix_level_up_value is Dictionary else {}
    var vulpix_tm_value: Variant = vulpix_learnset.get("tm_hm", {})
    var vulpix_tm: Dictionary = vulpix_tm_value if vulpix_tm_value is Dictionary else {}
    _check(vulpix_level_up.has("28"), "Vulpix muss auf Level 28 Sondersensor lernen.")
    _check(not vulpix_level_up.has("32"), "Vulpix darf wegen Pflichtentwicklung keine reguläre Level-32-Attacke besitzen.")
    _check_equal_int(vulpix_tm.size(), 40, "Vulpix-TM-Liste muss 40 Einträge enthalten.")

    var ninetales_learnset_value: Variant = ninetales.get("learnset", {})
    var ninetales_learnset: Dictionary = ninetales_learnset_value if ninetales_learnset_value is Dictionary else {}
    var evolution_moves_value: Variant = ninetales_learnset.get("evolution_moves", [])
    var evolution_moves: Array = evolution_moves_value if evolution_moves_value is Array else []
    for move_id: String in [
        "flamethrower", "fire_spin", "fire_blast", "safeguard",
        "imprison", "nasty_plot", "inferno"
    ]:
        _check(evolution_moves.has(move_id), "Vulnona-Entwicklungsattacke fehlt: " + move_id)
    _check_equal_int(evolution_moves.size(), 7, "Vulnona muss genau sieben Auto-Entwicklungsattacken besitzen.")
    var ninetales_tm_value: Variant = ninetales_learnset.get("tm_hm", {})
    var ninetales_tm: Dictionary = ninetales_tm_value if ninetales_tm_value is Dictionary else {}
    _check_equal_int(ninetales_tm.size(), 50, "Vulnona-TM-Liste muss 50 Einträge enthalten.")

    for move_id: String in [
        "disable", "incinerate", "confuse_ray", "extrasensory",
        "hex", "foul_play", "burning_jealousy"
    ]:
        _check(moves.has(move_id), "Neue Attacke fehlt: " + move_id)
        var move_value: Variant = moves.get(move_id, {})
        var move: Dictionary = move_value if move_value is Dictionary else {}
        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        _check(bool(runtime.get("runtime_supported", false)), move_id + " ist nicht als runtime_supported markiert.")

    var incinerate_value: Variant = moves.get("incinerate", {})
    var jealousy_value: Variant = moves.get("burning_jealousy", {})
    var hex_value: Variant = moves.get("hex", {})
    var foul_value: Variant = moves.get("foul_play", {})
    var incinerate: Dictionary = incinerate_value if incinerate_value is Dictionary else {}
    var jealousy: Dictionary = jealousy_value if jealousy_value is Dictionary else {}
    var hex_move: Dictionary = hex_value if hex_value is Dictionary else {}
    var foul_move: Dictionary = foul_value if foul_value is Dictionary else {}
    _check(bool(incinerate.get("area", false)), "Einäschern muss eine Flächenattacke sein.")
    _check(bool(jealousy.get("area", false)), "Neidflammen muss eine Flächenattacke sein.")
    _check_equal_int(int(hex_move.get("power", 0)), 65, "Bürde-Basisstärke ist falsch.")
    _check_equal_int(int(foul_move.get("power", 0)), 95, "Schmarotzer-Stärke ist falsch.")

    _check(FileAccess.file_exists("res://assets/monsters/Vulpix.png"), "Vulpix-Sprite fehlt.")
    _check(FileAccess.file_exists("res://assets/monsters/Vulnona.png"), "Vulnona-Sprite fehlt.")
    _check(
        FileAccess.get_file_as_string("res://main.tscn").contains("battle_demo_vulpix_family.gd"),
        "main.tscn verwendet den Vulpix-Runtime-Layer nicht."
    )

    var battle = CurrentBattleScript.new()

    _check_equal_float(battle._timeflow_spread_damage_scale(1), 1.0, "Flächenskalierung für 1 Ziel ist falsch.")
    _check_equal_float(battle._timeflow_spread_damage_scale(2), 0.75, "Flächenskalierung für 2 Ziele ist falsch.")
    _check_equal_float(battle._timeflow_spread_damage_scale(3), 0.60, "Flächenskalierung für 3 Ziele ist falsch.")
    _check_equal_float(battle._timeflow_spread_damage_scale(4), 0.50, "Flächenskalierung für 4+ Ziele ist falsch.")

    var disabled: Dictionary = {
        "action_serial": 0,
        "vulpix_disabled_move_id": "tackle",
        "vulpix_disable_until_action": 4
    }
    _check(battle._vulpix_disable_is_active(disabled), "Aussetzer ist zu früh inaktiv.")
    disabled["action_serial"] = 3
    _check(battle._vulpix_disable_is_active(disabled), "Aussetzer muss während der vierten gesperrten Aktionswahl noch aktiv sein.")
    disabled["action_serial"] = 4
    _check(not battle._vulpix_disable_is_active(disabled), "Aussetzer läuft nicht nach vier eigenen Aktionen aus.")

    _check(battle._vulpix_has_major_status({"major_status": "burn"}), "Bürde erkennt Verbrennung nicht.")
    _check(battle._vulpix_has_major_status({"major_status": "sleep"}), "Bürde erkennt Schlaf nicht.")
    _check(not battle._vulpix_has_major_status({"major_status": "", "confused_turns": 3}), "Bürde darf Verwirrung nicht als Hauptstatus zählen.")

    var actor_modifiers: Array = [
        {"kind": "outgoing_damage_mod", "multiplier": 1.8},
        {"kind": "accuracy_mod", "multiplier": 1.2}
    ]
    var foul_target: Dictionary = {
        "timed_modifiers": [{"kind": "outgoing_damage_mod", "multiplier": 1.35}]
    }
    var foul_modifiers: Array = battle._vulpix_foul_play_modifiers(actor_modifiers, foul_target)
    _check(
        _modifier_has(foul_modifiers, "outgoing_damage_mod", 1.35),
        "Schmarotzer übernimmt den Angriffsmodifier des Ziels nicht."
    )
    _check(
        not _modifier_has(foul_modifiers, "outgoing_damage_mod", 1.8),
        "Schmarotzer verwendet fälschlich den Angriffsmodifier des Anwenders."
    )

    battle.free()

    if failures == 0:
        print("Vulpix/Vulnona runtime integration test: PASS")
        quit(0)
    else:
        push_error("Vulpix/Vulnona runtime integration test: %d Fehler" % failures)
        quit(1)


func _modifier_has(modifiers: Array, kind: String, multiplier: float) -> bool:
    for value: Variant in modifiers:
        if value is Dictionary:
            var modifier: Dictionary = value
            if (
                str(modifier.get("kind", "")) == kind
                and is_equal_approx(float(modifier.get("multiplier", 0.0)), multiplier)
            ):
                return true
    return false


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        _fail("Datei fehlt: " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        _fail("JSON konnte nicht gelesen werden: " + path)
        return {}
    return parsed as Dictionary


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
