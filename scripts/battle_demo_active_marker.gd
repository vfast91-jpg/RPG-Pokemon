extends "res://scripts/battle_demo_stat_profiles.gd"

# Final active-turn marker layer.
# A high-contrast white triangle with a dark outline floats closely above the
# player's currently selected Pokemon while the move choice is open.

const TURN_MARKER_BOB_DISTANCE: float = 6.0
const TURN_MARKER_BOB_PERIOD: float = 1.1
const TURN_MARKER_VISIBLE_GAP: float = 7.0
const TURN_MARKER_TIP_Y: float = 8.0
const TURN_MARKER_MIN_Y: float = 8.0
const TURN_MARKER_OUTLINE := Color("17211f")
const TURN_MARKER_FILL := Color("ffffff")

var _turn_marker_time: float = 0.0


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    super._layout_team(area, team, enemy)

    # The marker is only a player-choice cue. Enemy turns remain unmarked.
    if enemy:
        return

    for combatant_value: Variant in team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var sprite: TextureRect = ui.get("texture") as TextureRect
        if sprite == null:
            continue

        var marker: Node2D = _make_turn_marker(area, combatant_id)
        ui["turn_marker"] = marker
        # Pokemon artwork often contains transparent padding. Anchor the marker
        # to the actually visible pixels instead of the 72x72 TextureRect box,
        # otherwise small Pokemon can appear far away from their turn arrow.
        ui["turn_marker_anchor"] = _turn_marker_anchor(sprite)
        cards[combatant_id] = ui

    _update_turn_markers()


func _process(delta: float) -> void:
    # The parent owns ATB/combat timing. Its process intentionally pauses while
    # the player chooses an action; our marker animation keeps running then.
    super._process(delta)
    _turn_marker_time += delta
    _update_turn_markers()


func _make_turn_marker(area: Control, combatant_id: String) -> Node2D:
    var marker := Node2D.new()
    marker.name = "TurnMarker_" + combatant_id
    marker.z_index = 30
    marker.visible = false

    # Two nested triangles create a dependable thick dark contour without
    # relying on emoji rendering or background-dependent colors.
    var outline := Polygon2D.new()
    outline.name = "Outline"
    outline.polygon = PackedVector2Array([
        Vector2(-9.0, -6.0),
        Vector2(9.0, -6.0),
        Vector2(0.0, 8.0)
    ])
    outline.color = TURN_MARKER_OUTLINE
    marker.add_child(outline)

    var fill := Polygon2D.new()
    fill.name = "Fill"
    fill.polygon = PackedVector2Array([
        Vector2(-5.5, -3.5),
        Vector2(5.5, -3.5),
        Vector2(0.0, 4.5)
    ])
    fill.color = TURN_MARKER_FILL
    fill.z_index = 1
    marker.add_child(fill)

    area.add_child(marker)
    return marker


func _turn_marker_anchor(sprite: TextureRect) -> Vector2:
    # Fallback still centers the marker over the TextureRect if texture pixels
    # cannot be inspected for any reason.
    var fallback := Vector2(
        sprite.size.x * 0.5,
        -TURN_MARKER_TIP_Y - TURN_MARKER_VISIBLE_GAP
    )
    var texture: Texture2D = sprite.texture
    if texture == null:
        return fallback

    var texture_size: Vector2 = texture.get_size()
    if texture_size.x <= 0.0 or texture_size.y <= 0.0:
        return fallback

    # BattleTexture uses STRETCH_KEEP_ASPECT_CENTERED. Recreate that geometry so
    # the alpha bounds from the source image map exactly into the 72x72 box.
    var scale: float = minf(
        sprite.size.x / texture_size.x,
        sprite.size.y / texture_size.y
    )
    if scale <= 0.0:
        return fallback

    var rendered_size: Vector2 = texture_size * scale
    var rendered_offset: Vector2 = (sprite.size - rendered_size) * 0.5
    var visible_center_x: float = rendered_offset.x + rendered_size.x * 0.5
    var visible_top_y: float = rendered_offset.y

    var image: Image = texture.get_image()
    if image != null and not image.is_empty():
        var used_rect: Rect2i = image.get_used_rect()
        if used_rect.size.x > 0 and used_rect.size.y > 0:
            visible_center_x = rendered_offset.x + (
                float(used_rect.position.x) + float(used_rect.size.x) * 0.5
            ) * scale
            visible_top_y = rendered_offset.y + float(used_rect.position.y) * scale

    # The triangle's tip is +8px from its origin. With a 7px neutral gap and
    # the existing +/-6px bob, the tip now moves from 1px to 13px above the
    # visible Pokemon: close and unambiguous without changing the nice animation.
    return Vector2(
        visible_center_x,
        visible_top_y - TURN_MARKER_TIP_Y - TURN_MARKER_VISIBLE_GAP
    )


func _update_turn_markers() -> void:
    var active_id: String = ""
    if battle_active \
            and not selected_actor.is_empty() \
            and str(selected_actor.get("side", "")) == "player" \
            and bool(selected_actor.get("alive", false)):
        active_id = str(selected_actor.get("id", ""))

    var bob_offset: float = sin(
        _turn_marker_time * TAU / TURN_MARKER_BOB_PERIOD
    ) * TURN_MARKER_BOB_DISTANCE

    for combatant_value: Variant in player_team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var marker: Node2D = ui.get("turn_marker") as Node2D
        var sprite: TextureRect = ui.get("texture") as TextureRect
        if marker == null or sprite == null:
            continue

        marker.visible = combatant_id == active_id
        if not marker.visible:
            continue

        var fallback_anchor := Vector2(
            sprite.size.x * 0.5,
            -TURN_MARKER_TIP_Y - TURN_MARKER_VISIBLE_GAP
        )
        var anchor_value: Variant = ui.get("turn_marker_anchor", fallback_anchor)
        var anchor: Vector2 = anchor_value if anchor_value is Vector2 else fallback_anchor
        var center_x: float = sprite.position.x + anchor.x
        var base_y: float = maxf(
            TURN_MARKER_MIN_Y,
            sprite.position.y + anchor.y
        )
        marker.position = Vector2(center_x, base_y + bob_offset)
