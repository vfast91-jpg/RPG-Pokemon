extends SceneTree

const FlinchRules = preload("res://scripts/battle/flinch_rules.gd")
const MovePresenter = preload("res://scripts/battle/move_presenter.gd")
const CurrentBattleScript = preload("res://scripts/battle_demo_caterpie_family_ui.gd")

const EXPECTED_FLINCH_MOVES: Array[String] = [
    "bite",
    "fire_fang",
    "air_slash",
    "twister",
    "ice_fang",
    "thunder_fang",
    "rock_slide",
    "zen_headbutt",
    "dark_pulse",
    "snore"
]

var failures: int = 0


func _initialize() -> void:
    var target: Dictionary = {"atb": 73.0}
    _check(
        FlinchRules.apply(target, 1.0, 0.99),
        "100%-Zurückschrecken wurde trotz erzwungenem Treffer nicht ausgelöst."
    )
    _check(
        is_zero_approx(float(target.get("atb", -1.0))),
        "Zurückschrecken setzt eine teilweise gefüllte Aktionsleiste nicht auf 0 %."
    )

    var immune_target: Dictionary = {"atb": 73.0}
    _check(
        not FlinchRules.apply(immune_target, 0.0, 0.0),
        "0%-Zurückschrecken darf niemals auslösen."
    )
    _check_equal_float(
        float(immune_target.get("atb", -1.0)),
        73.0,
        "Ein nicht ausgelöstes Zurückschrecken verändert die Aktionsleiste."
    )

    var moves: Dictionary = _load_manifest_moves()
    var found: Array[String] = []
    var battle = CurrentBattleScript.new()

    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        var flinch_mechanics: Array = _collect_flinch_mechanics(move.get("mechanics", []))
        if flinch_mechanics.is_empty():
            continue

        found.append(move_id)

        var infobox: String = battle._compact_effect_summary(move)
        _check(
            infobox.contains("Zurückschrecken")
            and infobox.contains("Aktionsleiste auf 0 %"),
            move_id + ": Infobox erklärt Zurückschrecken nicht als vollständigen ATB-Reset."
        )
        _check(
            not infobox.contains("ATB −")
            and not infobox.contains("Aktionsleiste −")
            and not infobox.contains("-25%")
            and not infobox.contains("−25%"),
            move_id + ": Infobox enthält noch einen alten partiellen ATB-Knockback."
        )

        for mechanic_value: Variant in flinch_mechanics:
            if not (mechanic_value is Dictionary):
                continue
            var mechanic: Dictionary = mechanic_value
            var presenter_text: String = MovePresenter.effect_summary({"mechanics": [mechanic]})
            _check(
                presenter_text.contains("Zurückschrecken")
                and presenter_text.contains("Aktionsleiste auf 0 %"),
                move_id + ": zentraler MovePresenter erklärt den ATB-Reset nicht."
            )

            # Regression against the exact legacy shape that caused Biss:
            # even amount=0.25 must be ignored by the active runtime.
            var forced_legacy: Dictionary = mechanic.duplicate(true)
            forced_legacy["chance"] = 1.0
            forced_legacy["amount"] = 0.25
            var runtime_target: Dictionary = {"atb": 68.0}
            battle._effect({}, runtime_target, forced_legacy)
            _check(
                is_zero_approx(float(runtime_target.get("atb", -1.0))),
                move_id + ": Runtime verwendet noch einen partiellen Knockback statt ATB 0 %."
            )

    battle.free()
    found.sort()

    for expected_move: String in EXPECTED_FLINCH_MOVES:
        _check(
            found.has(expected_move),
            "Erwartete Zurückschrecken-Attacke fehlt im zentralen Audit: " + expected_move
        )

    print("Flinch audit: " + ", ".join(found))

    if failures == 0:
        print("Flinch ATB reset test: PASS")
        quit(0)
    else:
        push_error("Flinch ATB reset test: %d Fehler" % failures)
        quit(1)


func _load_manifest_moves() -> Dictionary:
    var manifest: Dictionary = _read_json("res://data/gen1_database_manifest_v3.json")
    var merged: Dictionary = {}
    var files_value: Variant = manifest.get("move_files", [])
    if not (files_value is Array):
        _fail("Manifest enthält keine move_files-Liste.")
        return merged

    for file_value: Variant in files_value:
        var file_path: String = str(file_value)
        var pack: Dictionary = _read_json(file_path)
        var moves_value: Variant = pack.get("moves", {})
        if not (moves_value is Dictionary):
            _fail(file_path + ": moves fehlt oder ist kein Dictionary.")
            continue
        for move_id_value: Variant in (moves_value as Dictionary).keys():
            var move_id: String = str(move_id_value)
            merged[move_id] = (moves_value as Dictionary).get(move_id)
    return merged


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        _fail("Datei fehlt: " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        _fail("JSON konnte nicht als Dictionary gelesen werden: " + path)
        return {}
    return parsed as Dictionary


func _collect_flinch_mechanics(value: Variant, inherited_chance: float = 1.0) -> Array:
    var result: Array = []

    if value is Array:
        for item: Variant in value:
            result.append_array(_collect_flinch_mechanics(item, inherited_chance))
        return result

    if not (value is Dictionary):
        return result

    var mechanic: Dictionary = value
    var kind: String = str(mechanic.get("kind", ""))
    if kind == "atb_knockback":
        var normalized: Dictionary = mechanic.duplicate(true)
        normalized["chance"] = clampf(
            inherited_chance * float(mechanic.get("chance", 1.0)),
            0.0,
            1.0
        )
        result.append(normalized)
        return result

    if kind == "db_chance_mechanic":
        return _collect_flinch_mechanics(
            mechanic.get("mechanic", {}),
            clampf(
                inherited_chance * float(mechanic.get("chance", 1.0)),
                0.0,
                1.0
            )
        )

    return result


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _fail(message)


func _check_equal_float(actual: float, expected: float, message: String) -> void:
    if is_equal_approx(actual, expected):
        return
    _fail(message + " Erwartet %.2f, erhalten %.2f." % [expected, actual])


func _fail(message: String) -> void:
    failures += 1
    push_error(message)
