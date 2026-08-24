extends "res://scripts/battle_demo_stockpile_infobox_v1.gd"

# Final presentation fix for the mandatory Doppelboss fights on stages
# 20, 40, 60 and 80. The normal roster formation is deliberately compact and
# works for ordinary 72px Pokemon, but two enlarged 108px boss sprites consume
# the complete battle-area height and crowd the player's formation. Give only
# these milestone waves their own stable two-slot formation.

const MILESTONE_BOSS_SPRITE_SCALE: float = 1.32
const MILESTONE_BOSS_SPRITE_GAP: float = 6.0
const MILESTONE_BOSS_SLOT_RATIOS: Array[float] = [0.24, 0.76]


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not _is_milestone_double_boss_wave():
        return

    _apply_milestone_double_boss_layout()


func _is_milestone_double_boss_wave() -> bool:
    if not route_mode or enemy_team.size() != 2 or _route_enemy_party.size() != 2:
        return false

    for source_value: Variant in _route_enemy_party:
        if not (source_value is Dictionary):
            return false
        if not bool((source_value as Dictionary).get("milestone_double_boss", false)):
            return false

    return true


func _apply_milestone_double_boss_layout() -> void:
    if battle_panel == null:
        return

    var area: Control = battle_panel.get_node_or_null("BattleArea") as Control
    if area == null:
        return

    # Double bosses stay visibly larger than ordinary Pokemon, but no longer use
    # the 150% single-boss size. At 132% both sprites have real breathing room
    # above/below each other and remain clearly separated from the player team.
    var boss_side: float = ROSTER_SPRITE_SIDE * MILESTONE_BOSS_SPRITE_SCALE
    var boss_size := Vector2(boss_side, boss_side)

    for index: int in range(2):
        var combatant_value: Variant = enemy_team[index]
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("boss", false)):
            continue

        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var card: Control = ui.get("card") as Control
        var sprite: TextureRect = ui.get("texture") as TextureRect
        if card == null or sprite == null:
            continue

        var center_y: float = area.size.y * MILESTONE_BOSS_SLOT_RATIOS[index]

        # Both boss cards use the same left edge and the same vertical center as
        # their Pokemon. This removes the old diagonal/staggered formation that
        # made card-to-Pokemon ownership visually ambiguous.
        card.position.x = ROSTER_EDGE_MARGIN
        card.position.y = clampf(
            center_y - card.size.y * 0.5,
            0.0,
            maxf(0.0, area.size.y - card.size.y)
        )

        sprite.custom_minimum_size = boss_size
        sprite.size = boss_size
        sprite.position = Vector2(
            card.position.x + card.size.x + MILESTONE_BOSS_SPRITE_GAP,
            clampf(
                center_y - boss_size.y * 0.5,
                0.0,
                maxf(0.0, area.size.y - boss_size.y)
            )
        )

        # Re-anchor shadow and connector after the final sprite geometry. The
        # inherited boss shadow keeps its enlarged boss scale, so both bosses now
        # have the same correctly sized ground contact at their actual feet.
        var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
        if shadow != null:
            _position_route_boss_shadow(shadow, sprite)

        var connector: Line2D = ui.get("connector") as Line2D
        if connector != null:
            _update_roster_connector(connector, card, sprite, true)
