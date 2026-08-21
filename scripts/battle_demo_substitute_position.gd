extends "res://scripts/battle_demo_config_scroll.gd"

# Final visual correction for Delegator.
# The teddy should stand protectively in front of the Pokemon, close to the
# ground, instead of sitting on top of the sprite. "Front" is mirrored by side:
# player Pokemon stand on the right and face left; enemies face right.

func _bulba_refresh_substitute_markers() -> void:
    super._bulba_refresh_substitute_markers()

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var card_value: Variant = cards.get(str(combatant.get("id", "")), {})
        if not (card_value is Dictionary):
            continue

        var texture_value: Variant = (card_value as Dictionary).get("texture", null)
        if not (texture_value is TextureRect):
            continue
        var texture: TextureRect = texture_value
        var marker: Label = texture.get_node_or_null("SubstituteMarker") as Label
        if marker == null or not marker.visible:
            continue

        # Keep the marker low and just inside the leading edge of the 72x72
        # battle sprite. Using the live texture size also keeps this correct if
        # the sprite dimensions change later.
        var marker_width: float = 20.0
        var ground_y: float = maxf(0.0, texture.size.y - 27.0)
        var front_x: float
        if str(combatant.get("side", "")) == "player":
            front_x = 2.0
        else:
            front_x = maxf(0.0, texture.size.x - marker_width - 2.0)

        marker.position = Vector2(front_x, ground_y)
        marker.z_index = 40
