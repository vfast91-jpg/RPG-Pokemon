extends SceneTree

const DATA_PATH: String = "res://data/combat_lab_data.json"
const KNOWN_KINDS: Array[String] = [
    "damage",
    "status",
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod",
    "atb_knockback",
    "critical_focus",
    "seed",
    "binding",
    "cleanse_self"
]


func _initialize() -> void:
    var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
    assert(file != null, "combat_lab_data.json muss für den Mechanik-Audit existieren.")

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    assert(parsed is Dictionary, "combat_lab_data.json muss gültiges JSON enthalten.")
    var data: Dictionary = parsed
    var moves_value: Variant = data.get("moves", {})
    assert(moves_value is Dictionary, "moves-Dictionary fehlt.")
    var moves: Dictionary = moves_value

    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        assert(move_value is Dictionary, move_id + ": ungültige Attackendefinition")
        var move: Dictionary = move_value
        var mechanics_value: Variant = move.get("mechanics", [])
        assert(mechanics_value is Array, move_id + ": mechanics muss ein Array sein")

        for mechanic_value: Variant in mechanics_value:
            assert(mechanic_value is Dictionary, move_id + ": ungültiger Mechanik-Eintrag")
            var mechanic: Dictionary = mechanic_value
            var kind: String = str(mechanic.get("kind", ""))
            assert(KNOWN_KINDS.has(kind), move_id + ": unbekannte Mechanik " + kind)

    _assert_move_has_kind(moves, "leech_seed", "seed")
    _assert_move_has_kind(moves, "rapid_spin", "cleanse_self")
    _assert_move_has_kind(moves, "focus_energy", "critical_focus")
    _assert_move_has_kind(moves, "bite", "atb_knockback")
    _assert_move_has_kind(moves, "wrap", "binding")
    _assert_status(moves, "ember", "burn")
    _assert_status(moves, "poison_sting", "poison")
    _assert_damage_flag(moves, "assurance", "conditional_double_if_damaged_since_last_action")

    print("Special mechanics data audit: OK")
    quit(0)


func _assert_move_has_kind(moves: Dictionary, move_id: String, kind: String) -> void:
    var move: Dictionary = moves.get(move_id, {})
    assert(not move.is_empty(), move_id + " fehlt")
    for mechanic_value: Variant in move.get("mechanics", []):
        if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == kind:
            return
    assert(false, move_id + " muss Mechanik " + kind + " enthalten")


func _assert_status(moves: Dictionary, move_id: String, status_id: String) -> void:
    var move: Dictionary = moves.get(move_id, {})
    for mechanic_value: Variant in move.get("mechanics", []):
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        if str(mechanic.get("kind", "")) == "status" and str(mechanic.get("status", "")) == status_id:
            return
    assert(false, move_id + " muss Status " + status_id + " enthalten")


func _assert_damage_flag(moves: Dictionary, move_id: String, flag_name: String) -> void:
    var move: Dictionary = moves.get(move_id, {})
    for mechanic_value: Variant in move.get("mechanics", []):
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        if str(mechanic.get("kind", "")) == "damage" and bool(mechanic.get(flag_name, false)):
            return
    assert(false, move_id + " muss Schadensflag " + flag_name + " enthalten")
