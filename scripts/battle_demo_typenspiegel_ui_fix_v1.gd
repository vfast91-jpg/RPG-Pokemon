extends "res://scripts/battle_demo_phase_animation_fix_v1.gd"

# Final hotfix for combat-visible type changes and Typenspiegel feedback.
#
# Typenspiegel changes the user's current combat types. The inherited mechanic
# already changed the combat data correctly, but its success label was attached
# to the user while generic target feedback still evaluated the selected enemy
# as unchanged and therefore displayed KEIN EFFEKT. In addition, the compact
# type badges were built only once when the combat card was created.


func _ad_reflect_type(actor: Dictionary, target: Dictionary) -> float:
    var types: Array = _type_array(target.get("types", []))
    if types.is_empty():
        return 0.0

    actor["types"] = types.duplicate()

    # The selected enemy is the visible source of the copied type. Putting the
    # precise success result on that target also prevents the generic deferred
    # KEIN-EFFEKT fallback from appearing for a successful Typenspiegel.
    _spawn_feedback_label(target, "🪞 TYP KOPIERT", Color("cbd9ef"))
    return 3.0


func _refresh_cards() -> void:
    super._refresh_cards()

    # Type badges represent the CURRENT combat types, not only the species'
    # starting types. This keeps Typenspiegel, Wandler and future type-changing
    # mechanics visually synchronized with the combat state.
    for combatant_value: Variant in combatants:
        if combatant_value is Dictionary:
            _refresh_current_type_badges(combatant_value as Dictionary)


func _refresh_current_type_badges(combatant: Dictionary) -> void:
    var combatant_id: String = str(combatant.get("id", ""))
    if combatant_id.is_empty():
        return

    var ui_value: Variant = cards.get(combatant_id, {})
    if not (ui_value is Dictionary):
        return

    var hp_bar: ProgressBar = (ui_value as Dictionary).get("hp") as ProgressBar
    if hp_bar == null:
        return

    var content: VBoxContainer = hp_bar.get_parent() as VBoxContainer
    if content == null:
        return

    var type_row: HBoxContainer = content.get_node_or_null("TypeBadges") as HBoxContainer
    if type_row == null:
        return

    var current_types: Array = _type_array(combatant.get("types", []))
    var signature: String = ""
    for type_value: Variant in current_types:
        if not signature.is_empty():
            signature += "|"
        signature += str(type_value)

    if str(type_row.get_meta("current_type_signature", "")) == signature:
        return

    for child: Node in type_row.get_children():
        type_row.remove_child(child)
        child.queue_free()

    for type_value: Variant in current_types:
        var type_id: String = str(type_value)
        if not type_id.is_empty():
            type_row.add_child(_make_type_badge(type_id))

    type_row.visible = type_row.get_child_count() > 0
    type_row.set_meta("current_type_signature", signature)
