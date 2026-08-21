extends SceneTree

const MoveContract = preload("res://scripts/battle/move_contract.gd")
const Registry = preload("res://scripts/battle/move_effect_registry.gd")
const Presenter = preload("res://scripts/battle/move_presenter.gd")

const MANIFEST_PATH: String = "res://data/gen1_database_manifest_v3.json"
const EXTRA_MOVE_PACKS: Array[String] = [
    "res://data/gen1_moves_runtime_v3_bulbasaur_tms.json"
]

var failures: int = 0


func _initialize() -> void:
    _test_registry_surface_contract()
    _test_current_move_database()
    _test_strict_v4_contract()
    _test_unknown_mechanic_rejected()
    _test_nested_unknown_mechanic_rejected()
    _test_player_wording_rejected()
    _test_presenter_percentages()

    if failures == 0:
        print("Move contract test: PASS")
        quit(0)
    else:
        push_error("Move contract test: %d Fehler" % failures)
        quit(1)


func _test_registry_surface_contract() -> void:
    var errors: Array[String] = Registry.surface_contract_errors()
    _check(errors.is_empty(), "Effektregister besitzt unvollständige UI-/Runtime-Verträge: " + _join_values(errors))


func _test_current_move_database() -> void:
    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    _check(not manifest.is_empty(), "Attacken-Manifest konnte nicht gelesen werden.")
    var moves: Dictionary = {}

    var move_files_value: Variant = manifest.get("move_files", [])
    if move_files_value is Array:
        for path_value: Variant in move_files_value:
            _merge_moves(moves, _read_json(str(path_value)))

    for path: String in EXTRA_MOVE_PACKS:
        _merge_moves(moves, _read_json(path))

    var report: Dictionary = MoveContract.validate_pack(moves, false)
    _check(int(report.get("moves_checked", 0)) == moves.size(), "Nicht alle aktuellen Attacken wurden geprüft.")
    var errors_value: Variant = report.get("errors", [])
    var errors: Array = errors_value if errors_value is Array else []
    _check(errors.is_empty(), "Aktuelle Attackendaten verletzen den Kompatibilitätsvertrag: " + _join_values(errors))


func _test_strict_v4_contract() -> void:
    var source: Dictionary = {
        "schema_version": 3,
        "id": "contract_test_move",
        "name": "Vertragstest",
        "description": "Senkt den Angriff des Ziels für dessen nächste drei eigene Aktionen.",
        "emoji": "🧪",
        "type": "normal",
        "category": "status",
        "power": null,
        "accuracy": 100,
        "original_pp": 20,
        "rpg_ap": 5,
        "target": "enemy_highest_aggro",
        "area": false,
        "contact": false,
        "priority_reference": 0,
        "opening_phase": false,
        "effects": [
            {
                "kind": "outgoing_damage_mod",
                "multiplier_from_special": -1.0,
                "uses_special_percent": true,
                "duration": "3_actions"
            }
        ],
        "status_scaling": "central_status_curve",
        "aggro": {
            "from_damage": false,
            "from_status": true,
            "from_healing": false
        },
        "special_rules": [],
        "required_behavior_tests": [
            "richtige Stärke",
            "richtige Dauer",
            "korrektes Herunterzählen",
            "Statuskarte",
            "Tooltip"
        ],
        "runtime": {
            "runtime_supported": true,
            "strict_contract": true
        }
    }

    var report: Dictionary = MoveContract.compile_move(source, true)
    var errors_value: Variant = report.get("errors", [])
    var errors: Array = errors_value if errors_value is Array else []
    _check(errors.is_empty(), "Gültige V4-Attacke wurde abgelehnt: " + _join_values(errors))

    var compiled_value: Variant = report.get("move", {})
    var compiled: Dictionary = compiled_value if compiled_value is Dictionary else {}
    _check(int(compiled.get("ap", 0)) == 5, "Compiler übernimmt rpg_ap nicht nach ap.")
    _check(bool(compiled.get("opening", true)) == false, "Compiler übernimmt opening_phase nicht.")
    _check(int(compiled.get("priority", -1)) == 0, "Compiler übernimmt priority_reference nicht.")
    _check(compiled.get("mechanics", null) is Array, "Compiler übernimmt effects nicht nach mechanics.")


func _test_unknown_mechanic_rejected() -> void:
    var move: Dictionary = _minimal_strict_move()
    move["mechanics"] = [{"kind": "totally_unknown_effect"}]
    move["required_behavior_tests"] = ["Runtime"]
    var report: Dictionary = MoveContract.validate_move("unknown_test", move, true)
    _check(not bool(report.get("ok", true)), "Unbekannte Mechanik wurde nicht blockiert.")


func _test_nested_unknown_mechanic_rejected() -> void:
    var move: Dictionary = _minimal_strict_move()
    move["mechanics"] = [{
        "kind": "db_chance_mechanic",
        "chance": 0.25,
        "mechanic": {"kind": "nested_unknown_effect"}
    }]
    move["required_behavior_tests"] = ["Chance", "Runtime"]
    var report: Dictionary = MoveContract.validate_move("nested_unknown_test", move, true)
    _check(not bool(report.get("ok", true)), "Unbekannte verschachtelte Mechanik wurde nicht blockiert.")


func _test_player_wording_rejected() -> void:
    var move: Dictionary = _minimal_strict_move()
    move["description"] = "Der ATB-Zyklus ×0,8 und outgoing_damage_mod werden verändert."
    var report: Dictionary = MoveContract.validate_move("wording_test", move, true)
    _check(not bool(report.get("ok", true)), "Technischer Spielertext wurde nicht blockiert.")


func _test_presenter_percentages() -> void:
    _check(Presenter.modifier_text("outgoing_damage_mod", 1.25) == "Angriff +25 %", "Angriff-Prozentdarstellung falsch.")
    _check(Presenter.modifier_text("incoming_damage_mod", 0.8) == "Verteidigung −20 %", "Verteidigung-Prozentdarstellung falsch.")
    _check(Presenter.modifier_text("accuracy_mod", 0.8) == "Genauigkeit −20 %", "Genauigkeit-Prozentdarstellung falsch.")
    _check(Presenter.modifier_text("atb_cycle_mod", 0.8) == "Geschwindigkeit +25 %", "Geschwindigkeit-Prozentdarstellung falsch.")
    _check(Presenter.modifier_token("incoming_damage_mod", 0.8) == "DEF-", "Statuskarten-Vorzeichen für Verteidigung falsch.")
    _check(Presenter.modifier_token("atb_cycle_mod", 0.8) == "GES+", "Statuskarten-Kürzel für Geschwindigkeit falsch.")


func _minimal_strict_move() -> Dictionary:
    return {
        "id": "minimal",
        "name": "Minimal",
        "description": "Verursacht normalen Schaden.",
        "emoji": "✨",
        "type": "normal",
        "category": "physical",
        "power": 40,
        "accuracy": 100,
        "original_pp": 20,
        "ap": 5,
        "target": "enemy_highest_aggro",
        "area": false,
        "contact": false,
        "priority": 0,
        "opening": false,
        "mechanics": [{"kind": "damage"}],
        "status_scaling": "none",
        "aggro": {
            "from_damage": true,
            "from_status": false,
            "from_healing": false
        },
        "special_rules": [],
        "required_behavior_tests": [],
        "runtime": {
            "runtime_supported": true,
            "strict_contract": true
        }
    }


func _merge_moves(target: Dictionary, pack: Dictionary) -> void:
    var moves_value: Variant = pack.get("moves", {})
    if not (moves_value is Dictionary):
        return
    for move_id_value: Variant in (moves_value as Dictionary).keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
        if move_value is Dictionary:
            target[move_id] = (move_value as Dictionary).duplicate(true)


func _read_json(path: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)


func _join_values(values: Array) -> String:
    var parts := PackedStringArray()
    for value: Variant in values:
        parts.append(str(value))
    return " | ".join(parts)
