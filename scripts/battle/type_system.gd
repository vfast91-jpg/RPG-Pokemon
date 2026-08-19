extends Node

const TYPE_CHART_PATH := "res://data/rules/type_chart.json"

var _chart: Dictionary = {}
var _effectiveness: Dictionary = {}
var _feedback: Dictionary = {}
var _default_multiplier := 1.0
var _known_types: Dictionary = {}

func _ready() -> void:
    _load_type_chart()

func _load_type_chart() -> void:
    var file := FileAccess.open(TYPE_CHART_PATH, FileAccess.READ)
    if file == null:
        push_error("TypeSystem: Typentabelle konnte nicht geladen werden: %s" % TYPE_CHART_PATH)
        return

    var parsed = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("TypeSystem: Typentabelle enthält kein gültiges JSON-Objekt.")
        return

    _chart = parsed
    _effectiveness = _chart.get("effectiveness", {})
    _feedback = _chart.get("feedback", {})
    _default_multiplier = float(_chart.get("default_multiplier", 1.0))
    _known_types.clear()

    for type_id in _chart.get("types", []):
        _known_types[str(type_id)] = true

func is_known_type(type_id: String) -> bool:
    return _known_types.has(type_id.to_lower())

func get_multiplier(attack_type: String, defender_types: Array) -> float:
    var normalized_attack := attack_type.to_lower()
    if not is_known_type(normalized_attack):
        push_warning("TypeSystem: Unbekannter Attackentyp '%s'. Neutraler Multiplikator wird verwendet." % attack_type)
        return _default_multiplier

    var attack_row: Dictionary = _effectiveness.get(normalized_attack, {})
    var result := 1.0
    var applied_types := 0

    for defender_type in defender_types:
        if defender_type == null:
            continue
        var normalized_defender := str(defender_type).to_lower()
        if normalized_defender.is_empty():
            continue
        if not is_known_type(normalized_defender):
            push_warning("TypeSystem: Unbekannter Verteidigertyp '%s'. Dieser Typ wird neutral behandelt." % str(defender_type))
            continue

        result *= float(attack_row.get(normalized_defender, _default_multiplier))
        applied_types += 1

    if applied_types == 0:
        return _default_multiplier
    return result

func get_feedback_key(multiplier: float) -> String:
    if is_zero_approx(multiplier):
        return "immune"
    if multiplier < 1.0:
        return "resisted"
    if multiplier > 1.0:
        return "super_effective"
    return "neutral"

func get_feedback_text(multiplier: float) -> String:
    var key := get_feedback_key(multiplier)
    return str(_feedback.get(key, ""))

func evaluate(attack_type: String, defender_types: Array) -> Dictionary:
    var multiplier := get_multiplier(attack_type, defender_types)
    return {
        "multiplier": multiplier,
        "feedback_key": get_feedback_key(multiplier),
        "feedback_text": get_feedback_text(multiplier)
    }

func apply_to_damage(base_damage: float, attack_type: String, defender_types: Array) -> float:
    return base_damage * get_multiplier(attack_type, defender_types)
