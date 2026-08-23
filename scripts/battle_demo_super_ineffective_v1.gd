extends "res://scripts/battle_demo_remaining_gen1_species_v1.gd"

# Timeflow-Typenregel: klassische Typenimmunitäten sind nicht mehr 0x, sondern
# 0.25x ("Super ineffektiv"). Dieser oberste Battle-Layer stellt zusätzlich
# sicher, dass die laufende Schadensberechnung dieselbe zentrale Typentabelle
# verwendet und dass Matrix/Matchup-UI die neue Stufe eindeutig rot darstellt.

const SUPER_INEFFECTIVE_MAX_MULTIPLIER: float = 0.25
const SUPER_INEFFECTIVE_COLOR: Color = Color("8f3b3b")


func _type_effect(move_type: String, target_types_value: Variant) -> float:
    if move_type == "typeless":
        return 1.0
    return TypeSystem.get_multiplier(move_type, _type_array(target_types_value))


func _effectiveness_name(multiplier: float) -> String:
    if _tf_is_super_ineffective(multiplier):
        return "super ineffektiv"
    return super._effectiveness_name(multiplier)


func _matrix_text(multiplier: float) -> String:
    if is_equal_approx(multiplier, 0.25):
        return "¼"
    if is_equal_approx(multiplier, 0.125):
        return "⅛"
    return super._matrix_text(multiplier)


func _matrix_background(multiplier: float) -> Color:
    if _tf_is_super_ineffective(multiplier):
        return SUPER_INEFFECTIVE_COLOR
    return super._matrix_background(multiplier)


func _matrix_tooltip(multiplier: float) -> String:
    if _tf_is_super_ineffective(multiplier):
        return "super ineffektiv (%s×)" % _decimal(multiplier, 2)
    return super._matrix_tooltip(multiplier)


func _install_type_help() -> void:
    super._install_type_help()
    if _type_help_overlay == null:
        return
    _tf_update_type_help_legend(_type_help_overlay)


func _tf_update_type_help_legend(node: Node) -> bool:
    if node is Label:
        var label: Label = node as Label
        if label.text.contains("LINKS Angriff") and label.text.contains("Verteidigung"):
            label.text = (
                "LINKS Angriff · OBEN Verteidigung    2 = stark    "
                + "½ = weniger effektiv    ¼ = super ineffektiv    leer = normal"
            )
            return true

    for child: Node in node.get_children():
        if _tf_update_type_help_legend(child):
            return true
    return false


func _feedback_result(target: Dictionary, before: Dictionary) -> Dictionary:
    var result: Dictionary = super._feedback_result(target, before)
    if not _tf_current_move_is_direct_damage():
        return result

    var hp_before: int = int(before.get("hp", target.get("hp", 0)))
    var hp_after: int = int(target.get("hp", 0))
    if hp_after >= hp_before:
        return result

    var move: Dictionary = _move_data(_feedback_active_move_id)
    var move_type: String = str(move.get("type", "normal"))
    if not TypeSystem.is_known_type(move_type):
        return result

    var types_value: Variant = before.get("types", target.get("types", []))
    var target_types: Array = _type_array(types_value)
    var multiplier: float = TypeSystem.get_multiplier(move_type, target_types)
    if not _tf_is_super_ineffective(multiplier):
        return result

    var text: String = str(result.get("text", ""))
    if not text.contains("SUPER INEFFEKTIV"):
        text = "SUPER INEFFEKTIV" if text.is_empty() else text + " · SUPER INEFFEKTIV"
    result["text"] = text
    result["kind"] = "negative"
    return result


func _tf_current_move_is_direct_damage() -> bool:
    if _feedback_active_move_id.is_empty():
        return false
    var move: Dictionary = _move_data(_feedback_active_move_id)
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false
    for mechanic_value: Variant in mechanics_value:
        if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "damage":
            return true
    return false


func _tf_is_super_ineffective(multiplier: float) -> bool:
    return (
        multiplier > 0.0
        and multiplier <= SUPER_INEFFECTIVE_MAX_MULTIPLIER + 0.0001
    )
