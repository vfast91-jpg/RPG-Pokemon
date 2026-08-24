extends "res://scripts/battle_demo_v22_semi_invulnerable_integrity_v1.gd"

# Final Ditto/Wandler integrity layer.
# Keeps the true combatant identity (id/species_id, HP, level, aggro, ATB and
# status state) intact while copying the target's battle form and making that
# copied form immediately visible on the battlefield.


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) == "f64_transform":
        return _ditto_apply_transform(actor, target)
    return super._effect(actor, target, mechanic)


func _ditto_apply_transform(actor: Dictionary, target: Dictionary) -> float:
    if (
        actor.is_empty()
        or target.is_empty()
        or not bool(actor.get("alive", false))
        or not bool(target.get("alive", false))
    ):
        return 0.0
    if bool(actor.get("f64_transformed", false)):
        _spawn_feedback_label(actor, "✖ BEREITS VERWANDELT", Color("d9a5a5"))
        return 0.0
    if bool(target.get("f64_transformed", false)):
        _spawn_feedback_label(target, "✖ VERWANDELTES ZIEL", Color("d9a5a5"))
        return 0.0
    if bool(target.get("bulba_substitute_active", false)):
        _spawn_feedback_label(target, "🪆 DELEGATOR BLOCKIERT", Color("d9c9a5"))
        return 0.0

    # Keep the battle-form name free of UI decoration. _actor_name() already
    # appends the level and therefore must not be stored back into actor["name"].
    var target_name: String = str(target.get("name", "Pokémon"))
    if not actor.has("f64_original_name"):
        actor["f64_original_name"] = str(actor.get("name", "Ditto"))
    actor["f64_transform_target_id"] = str(target.get("id", ""))
    actor["f64_transform_target_name"] = target_name

    actor["types"] = _type_array(target.get("types", [])).duplicate()
    actor["attack"] = int(target.get("attack", actor.get("attack", 1)))
    actor["defense"] = int(target.get("defense", actor.get("defense", 1)))
    actor["special"] = int(target.get("special", actor.get("special", 1)))
    actor["speed"] = int(target.get("speed", actor.get("speed", 1)))

    var target_moves_value: Variant = target.get("moves", [])
    actor["moves"] = (
        (target_moves_value as Array).duplicate()
        if target_moves_value is Array
        else []
    )
    actor["timed_modifiers"] = _f64_copy_timed_modifiers(target, actor)

    # The combatant dictionary is battle-local. Change only the visible name;
    # species_id stays Ditto so persistent/original species identity is retained.
    actor["name"] = target_name
    actor["f64_transformed"] = true

    _ditto_refresh_transform_visuals(actor)
    _spawn_feedback_label(actor, "🧬 WANDLER → " + target_name, Color("d3c7ef"))
    return 0.0


func _ditto_refresh_transform_visuals(actor: Dictionary) -> void:
    var actor_id: String = str(actor.get("id", ""))
    if actor_id.is_empty() or not cards.has(actor_id):
        _refresh_cards()
        return

    var ui_value: Variant = cards.get(actor_id, {})
    if not (ui_value is Dictionary):
        _refresh_cards()
        return
    var ui: Dictionary = ui_value

    var texture_value: Variant = ui.get("texture", null)
    if texture_value is TextureRect:
        # Sprite lookup needs the plain species/form name, never the level-decorated
        # _actor_name() string (for example "Mampfaxo Lv.4").
        var form_name: String = str(
            actor.get("f64_transform_target_name", actor.get("name", ""))
        )
        (texture_value as TextureRect).texture = _species_texture(form_name)

    var card_value: Variant = ui.get("card", null)
    if card_value is Control:
        var card: Control = card_value as Control

        var name_node: Node = card.find_child("Name", true, false)
        if name_node is Label:
            # _actor_name() already renders exactly one level suffix.
            (name_node as Label).text = _actor_name(actor)

        var type_node: Node = card.find_child("Types", true, false)
        if type_node is Label:
            var type_label: Label = type_node as Label
            var types: Array = _type_array(actor.get("types", []))
            type_label.text = _roster_type_text(types)
            if not types.is_empty():
                type_label.add_theme_color_override(
                    "font_color",
                    _type_badge_color(str(types[0])).darkened(0.18)
                )
            else:
                type_label.add_theme_color_override("font_color", Color("53605b"))

    _refresh_cards()
