extends "res://scripts/battle_demo_double_boss_feedback_v1.gd"

# Systemweiter Notfall-Fallback für Pokémon ohne regulär nutzbare Attacke.
# Warten und Vorne! bleiben Systemaktionen und zählen ausdrücklich nicht mit.
# Verzweifler ist nicht lernbar, wird nicht dauerhaft am Pokémon gespeichert und
# verschwindet automatisch wieder, sobald mindestens eine echte Runtime-Attacke
# verfügbar ist. In Timeflow verursacht Verzweifler bewusst KEINEN Rückstoß.

const STRUGGLE_RULE_PATH: String = "res://data/rules/struggle_fallback_v1.json"
const STRUGGLE_DEFAULT_ID: String = "struggle"

var _tf_struggle_rule: Dictionary = {}
var _tf_struggle_move: Dictionary = {}
var _tf_struggle_move_id: String = STRUGGLE_DEFAULT_ID
var _tf_system_action_tokens: Array[String] = ["wait", "warten", "forward", "front", "vorne"]
var _tf_struggle_damage_depth: int = 0


func _load_data() -> void:
    super._load_data()
    _tf_load_struggle_rule()
    _tf_install_struggle_runtime_move()


func _tf_load_struggle_rule() -> void:
    _tf_struggle_rule.clear()
    _tf_struggle_move = _tf_default_struggle_move()
    _tf_struggle_move_id = STRUGGLE_DEFAULT_ID
    _tf_system_action_tokens = ["wait", "warten", "forward", "front", "vorne"]

    var file: FileAccess = FileAccess.open(STRUGGLE_RULE_PATH, FileAccess.READ)
    if file == null:
        push_warning("Verzweifler-Regel fehlt; interner Fallback wird verwendet: " + STRUGGLE_RULE_PATH)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_warning("Verzweifler-Regel ist ungültig; interner Fallback wird verwendet.")
        return

    _tf_struggle_rule = (parsed as Dictionary).duplicate(true)
    _tf_struggle_move_id = str(_tf_struggle_rule.get("fallback_move_id", STRUGGLE_DEFAULT_ID)).strip_edges()
    if _tf_struggle_move_id.is_empty():
        _tf_struggle_move_id = STRUGGLE_DEFAULT_ID

    var move_value: Variant = _tf_struggle_rule.get("move", {})
    if move_value is Dictionary and not (move_value as Dictionary).is_empty():
        _tf_struggle_move = (move_value as Dictionary).duplicate(true)
        _tf_struggle_move["id"] = _tf_struggle_move_id

    var aliases_value: Variant = _tf_struggle_rule.get("excluded_system_actions", [])
    if aliases_value is Array:
        for alias_value: Variant in aliases_value:
            var alias_token: String = _tf_normalize_action_token(str(alias_value))
            if not alias_token.is_empty() and not _tf_system_action_tokens.has(alias_token):
                _tf_system_action_tokens.append(alias_token)


func _tf_install_struggle_runtime_move() -> void:
    if _tf_struggle_move.is_empty():
        _tf_struggle_move = _tf_default_struggle_move()

    var runtime_moves_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_moves_value if runtime_moves_value is Dictionary else {}
    runtime_moves[_tf_struggle_move_id] = _tf_struggle_move.duplicate(true)
    data["moves"] = runtime_moves

    # Einige bestehende Runtime-Layer lesen aus dem kanonischen Pack statt aus
    # data["moves"]. Der System-Fallback wird deshalb auch dort gespiegelt, ohne
    # ihn einer Spezies-Lernliste hinzuzufügen.
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_moves_value if canonical_moves_value is Dictionary else {}
    canonical_moves[_tf_struggle_move_id] = _tf_struggle_move.duplicate(true)
    _canonical_pack["moves"] = canonical_moves


func _tf_default_struggle_move() -> Dictionary:
    return {
        "id": STRUGGLE_DEFAULT_ID,
        "name": "Verzweifler",
        "description": "Typneutraler Notfallangriff. Nur verfügbar, wenn keine reguläre Attacke nutzbar ist. Verursacht keinen Rückstoß.",
        "emoji": "💢",
        # 'normal' hält den bestehenden Attacken-Contract gültig. Die eigentliche
        # Schadensauflösung wird unten ausschließlich für Verzweifler typneutral.
        "type": "normal",
        "category": "physical",
        "power": 50,
        "accuracy": null,
        "original_pp": null,
        "ap": 4,
        "target": "enemy_highest_aggro",
        "area": false,
        "contact": true,
        "priority": 0,
        "opening": false,
        "mechanics": [{"kind": "damage"}],
        "status_scaling": {"enabled": false},
        "aggro": {"mode": "damage"},
        "special_rules": [
            "System-Fallback; nicht lernbar.",
            "Typneutraler Schaden.",
            "Kein Rückstoß."
        ],
        "required_behavior_tests": ["struggle_fallback_test"],
        "runtime": {
            "runtime_supported": true,
            "partial": false,
            "typeless_damage": true,
            "fallback_only": true
        }
    }


func _move_data(move_id: String) -> Dictionary:
    if move_id == _tf_struggle_move_id and not _tf_struggle_move.is_empty():
        return _tf_struggle_move.duplicate(true)
    return super._move_data(move_id)


func _prompt_player(actor: Dictionary) -> void:
    var original_moves_value: Variant = actor.get("moves", [])
    var original_moves: Array = original_moves_value.duplicate() if original_moves_value is Array else []
    actor["moves"] = _tf_effective_combat_moves(actor, original_moves)
    super._prompt_player(actor)
    actor["moves"] = original_moves


func _enemy_act(actor: Dictionary) -> void:
    var original_moves_value: Variant = actor.get("moves", [])
    var original_moves: Array = original_moves_value.duplicate() if original_moves_value is Array else []
    actor["moves"] = _tf_effective_combat_moves(actor, original_moves)
    super._enemy_act(actor)
    actor["moves"] = original_moves


func _tf_effective_combat_moves(_actor: Dictionary, source_moves: Array) -> Array:
    var usable: Array = []
    for move_value: Variant in source_moves:
        var move_id: String = str(move_value).strip_edges()
        if not _tf_regular_move_available(move_id):
            continue
        if not usable.has(move_id):
            usable.append(move_id)

    if usable.is_empty():
        return [_tf_struggle_move_id]
    return usable


func _tf_regular_move_available(move_id: String) -> bool:
    if move_id.is_empty() or move_id == _tf_struggle_move_id:
        return false
    if _tf_is_system_action(move_id):
        return false
    if not _runtime_has_move(move_id):
        return false

    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return false
    if _tf_is_system_action(str(move.get("name", ""))):
        return false
    return true


func _tf_is_system_action(value: String) -> bool:
    var token: String = _tf_normalize_action_token(value)
    return not token.is_empty() and _tf_system_action_tokens.has(token)


func _tf_normalize_action_token(value: String) -> String:
    return value.strip_edges().to_lower().replace("!", "")


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if move_id != _tf_struggle_move_id:
        super._execute_move(actor, move_id)
        return

    _tf_struggle_damage_depth += 1
    super._execute_move(actor, move_id)
    _tf_struggle_damage_depth = maxi(0, _tf_struggle_damage_depth - 1)


func _tf_damage_type(move_type: String) -> String:
    if _tf_struggle_damage_depth > 0:
        return "typeless"
    return move_type


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    return super._damage(actor, target, power, _tf_damage_type(move_type), category)


func _move_tooltip(move: Dictionary) -> String:
    if str(move.get("id", "")) == _tf_struggle_move_id:
        return (
            "Verzweifler\n"
            + "AP: " + str(move.get("ap", 4)) + "\n"
            + "Stärke: " + str(move.get("power", 50)) + "\n"
            + "Genauigkeit: trifft immer\n"
            + "Typ: Typneutral\n"
            + "Nur verfügbar, wenn keine reguläre Attacke nutzbar ist.\n"
            + "Kein Rückstoß."
        )
    return super._move_tooltip(move)
