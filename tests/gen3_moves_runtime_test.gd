extends SceneTree

const MoveContract = preload("res://scripts/battle/move_contract.gd")
const PACK_V1_PATH: String = "res://data/gen3_moves_runtime_v1.json"
const PACK_V2_PATH: String = "res://data/gen3_moves_runtime_v2.json"
const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"

const V1_IDS: Array[String] = [
    "leafage", "aqua_cutter", "sacred_sword", "force_palm", "aurora_veil"
]

const V2_IDS: Array[String] = [
    "autotomize", "doom_desire", "dragon_ascent", "entrainment", "feint_attack",
    "frost_breath", "grudge", "luster_purge", "metal_burst", "mind_reader",
    "mist_ball", "noble_roar", "origin_pulse", "power_trip", "precipice_blades",
    "psycho_boost", "simple_beam", "spiky_shield", "tail_glow", "teeter_dance",
    "water_spout"
]

var failures: int = 0


func _initialize() -> void:
    _check_pack(PACK_V1_PATH, V1_IDS, 5, "Gen-3-V1")
    _check_pack(PACK_V2_PATH, V2_IDS, 21, "Gen-3-V2")

    var v2: Dictionary = _read_json(PACK_V2_PATH)
    var v2_moves_value: Variant = v2.get("moves", {})
    var v2_moves: Dictionary = v2_moves_value if v2_moves_value is Dictionary else {}

    for move_id: String in ["entrainment", "simple_beam"]:
        var move_value: Variant = v2_moves.get(move_id, {})
        _check(move_value is Dictionary, move_id + ": Definition fehlt.")
        if move_value is Dictionary:
            var move: Dictionary = move_value as Dictionary
            _check(
                str(move.get("target", "")) == "enemy_highest_aggro",
                move_id + ": zentraler Zielvertrag muss enemy_highest_aggro bleiben."
            )
            var runtime_value: Variant = move.get("runtime", {})
            var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
            _check(
                bool(runtime.get("manual_target_support", false)),
                move_id + ": manuelle Verbündeten-Zielwahl fehlt."
            )
            _check(
                str(runtime.get("manual_target_mode", "")) == "enemy_highest_aggro_or_chosen_ally",
                move_id + ": manueller Zielmodus ist falsch."
            )

    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    var move_files_value: Variant = manifest.get("move_files", [])
    var move_files: Array = move_files_value if move_files_value is Array else []
    _check(move_files.has(PACK_V1_PATH), "Gen-3-V1-Paket fehlt im Laufzeitmanifest.")
    _check(move_files.has(PACK_V2_PATH), "Gen-3-V2-Paket fehlt im Laufzeitmanifest.")
    _check(int(manifest.get("move_count", 0)) == 340, "Manifest move_count muss 340 sein.")

    if failures == 0:
        print("Gen-3 moves 1-26 contract test: PASS")
        quit(0)
    else:
        push_error("Gen-3 moves 1-26 contract test: %d Fehler" % failures)
        quit(1)


func _check_pack(path: String, expected_ids: Array[String], expected_count: int, label: String) -> void:
    var pack: Dictionary = _read_json(path)
    var moves_value: Variant = pack.get("moves", {})
    _check(moves_value is Dictionary, label + " besitzt kein moves-Dictionary.")
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}
    _check(moves.size() == expected_count, label + " muss genau " + str(expected_count) + " Attacken enthalten.")

    var report: Dictionary = MoveContract.validate_pack(moves, true)
    var errors_value: Variant = report.get("errors", [])
    var errors: Array = errors_value if errors_value is Array else []
    _check(errors.is_empty(), label + " verletzt den strikten Vertrag: " + _join(errors))

    for move_id: String in expected_ids:
        _check(moves.has(move_id), label + " Attacke fehlt: " + move_id)


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


func _join(values: Array) -> String:
    var parts := PackedStringArray()
    for value: Variant in values:
        parts.append(str(value))
    return " | ".join(parts)
