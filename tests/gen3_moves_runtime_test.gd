extends SceneTree

const MoveContract = preload("res://scripts/battle/move_contract.gd")
const PACK_PATH: String = "res://data/gen3_moves_runtime_v1.json"
const MANIFEST_PATH: String = "res://data/pokemon_database_manifest_v1.json"

var failures: int = 0


func _initialize() -> void:
    var pack: Dictionary = _read_json(PACK_PATH)
    var moves_value: Variant = pack.get("moves", {})
    _check(moves_value is Dictionary, "Gen-3-Paket besitzt kein moves-Dictionary.")
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}
    _check(moves.size() == 5, "Gen-3-Paket muss genau fünf Attacken enthalten.")
    var report: Dictionary = MoveContract.validate_pack(moves, true)
    var errors_value: Variant = report.get("errors", [])
    var errors: Array = errors_value if errors_value is Array else []
    _check(errors.is_empty(), "Gen-3-Attacken verletzen den strikten Vertrag: " + _join(errors))
    for move_id: String in ["leafage", "aqua_cutter", "sacred_sword", "force_palm", "aurora_veil"]:
        _check(moves.has(move_id), "Gen-3-Attacke fehlt: " + move_id)

    var manifest: Dictionary = _read_json(MANIFEST_PATH)
    var move_files_value: Variant = manifest.get("move_files", [])
    var move_files: Array = move_files_value if move_files_value is Array else []
    _check(move_files.has(PACK_PATH), "Gen-3-Paket fehlt im Laufzeitmanifest.")
    _check(int(manifest.get("move_count", 0)) == 319, "Manifest move_count muss 319 sein.")

    if failures == 0:
        print("Gen-3 first five moves test: PASS")
        quit(0)
    else:
        push_error("Gen-3 first five moves test: %d Fehler" % failures)
        quit(1)


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
