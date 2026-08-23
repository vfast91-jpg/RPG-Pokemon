extends "res://scripts/battle_demo_remaining_gen1_species_v1.gd"

# Timeflow-Typenregel: klassische Typenimmunitäten sind nicht mehr 0x, sondern
# 0.25x ("Super ineffektiv"). Dieser Battle-Layer stellt zusätzlich sicher,
# dass Schadensberechnung UND Spieler-Feedback dieselbe zentrale Typentabelle
# verwenden. Alte Immunitäts-Texte dürfen daher niemals neben realem Schaden
# erscheinen.

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

    var move: Dictionary = _move_data(_feedback_active_move_id)
    var move_type: String = str(move.get("type", "normal"))
    if not TypeSystem.is_known_type(move_type):
        return result

    var types_value: Variant = before.get("types", target.get("types", []))
    var target_types: Array = _type_array(types_value)
    var multiplier: float = TypeSystem.get_multiplier(move_type, target_types)

    var hp_before: int = int(before.get("hp", target.get("hp", 0)))
    var hp_after: int = int(target.get("hp", 0))
    var actual_damage: int = maxi(0, hp_before - hp_after)

    # One source of truth: whenever real HP damage happened, any inherited
    # "immune / no effect" fragment is provably stale and must be removed.
    if actual_damage > 0:
        result["text"] = _tf_remove_contradictory_no_effect_feedback(
            str(result.get("text", ""))
        )

        var feedback_text: String = TypeSystem.get_feedback_text(multiplier).strip_edges()
        if not feedback_text.is_empty():
            feedback_text = feedback_text.trim_suffix(".").trim_suffix("!").to_upper()
            result["text"] = _tf_append_unique_feedback(
                str(result.get("text", "")),
                feedback_text
            )

        # Type disadvantage is bad feedback for the acting side even though the
        # target also lost HP; retain the established red combat-result color.
        if multiplier < 1.0:
            result["kind"] = "negative"
        return result

    # A true 0x is the only case in which the central type system may call a
    # damaging attack ineffective. Timeflow's former immunities are 0.25x, so
    # Ghost -> Normal (e.g. Schlecker -> Mauzi) can never enter this branch.
    if is_zero_approx(multiplier):
        result["text"] = _tf_append_unique_feedback(
            _tf_remove_generic_no_effect_feedback(str(result.get("text", ""))),
            "KEINE WIRKUNG"
        )
        result["kind"] = "neutral"

    return result


func _tf_remove_contradictory_no_effect_feedback(source: String) -> String:
    var kept: Array[String] = []
    for fragment_value: String in source.split(" · "):
        var fragment: String = fragment_value.strip_edges()
        if fragment.is_empty():
            continue
        var upper: String = fragment.to_upper()
        if (
            upper.contains("KEIN EFFEKT")
            or upper.contains("KEINE WIRKUNG")
            or upper.contains("WIRKUNGSLOS")
            or upper == "IMMUN"
            or upper.ends_with(" IMMUN")
        ):
            continue
        kept.append(fragment)
    return " · ".join(kept)


func _tf_remove_generic_no_effect_feedback(source: String) -> String:
    var kept: Array[String] = []
    for fragment_value: String in source.split(" · "):
        var fragment: String = fragment_value.strip_edges()
        if fragment.is_empty():
            continue
        if fragment.to_upper().contains("KEIN EFFEKT"):
            continue
        kept.append(fragment)
    return " · ".join(kept)


func _tf_append_unique_feedback(source: String, addition: String) -> String:
    var clean_source: String = source.strip_edges()
    var clean_addition: String = addition.strip_edges()
    if clean_addition.is_empty():
        return clean_source
    if clean_source.to_upper().contains(clean_addition.to_upper()):
        return clean_source
    if clean_source.is_empty():
        return clean_addition
    return clean_source + " · " + clean_addition


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
