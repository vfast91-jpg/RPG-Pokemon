extends "res://scripts/battle_demo_stockpile_infobox_v1.gd"

# Final presentation fix for the mandatory Doppelboss fights on stages
# 20, 40, 60 and 80. The normal roster formation is deliberately compact and
# works for ordinary 72px Pokemon, but two enlarged 108px boss sprites consume
# the complete battle-area height and crowd the player's formation. Give only
# these milestone waves their own stable two-slot formation.

const MILESTONE_BOSS_SPRITE_SCALE: float = 1.5
const MILESTONE_BOSS_SPRITE_GAP: float = 14.0
const MILESTONE_BOSS_SLOT_RATIOS: Array[float] = [0.24, 0.76]
const MILESTONE_BOSS_ATB_RATE_MULTIPLIER: float = 1.5
const VisibleTextureLayout = preload("res://scripts/ui/visible_texture_layout.gd")


func _process(delta: float) -> void:
    if battle_active and not paused and _is_milestone_double_boss_wave():
        _apply_milestone_double_boss_atb_bonus(delta)
    super._process(delta)


func _apply_milestone_double_boss_atb_bonus(delta: float) -> void:
    var bonus_factor: float = MILESTONE_BOSS_ATB_RATE_MULTIPLIER - 1.0
    for combatant_value: Variant in enemy_team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("boss", false)) or not bool(combatant.get("alive", false)):
            continue

        var effective_speed: float = float(combatant.get("speed", 10))
        if bool(combatant.get("paralyzed", false)):
            effective_speed *= 0.5

        var cycle: float = maxf(0.01, float(combatant.get("cycle", 1.0)))
        var normal_gain: float = delta * (12.0 + effective_speed * 0.62) / cycle
        combatant["atb"] = minf(
            100.0,
            float(combatant.get("atb", 0.0)) + normal_gain * bonus_factor
        )


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

    # Milestone bosses use the same 150% sprite size as the bosses from special
    # encounters. Their card-to-sprite gap also matches the canonical enemy
    # roster gap so they no longer sit unnecessarily far back on their side.
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

        # Pokemon PNGs have very different transparent margins. Positioning the
        # TextureRect itself therefore makes compact species such as Diglett sit
        # far below their card even though the invisible box is centered.
        # Align the actually visible alpha bounds instead. The TextureRect may
        # extend outside BattleArea; only transparent pixels are clipped there.
        var visible_rect: Rect2 = VisibleTextureLayout.visible_rect(sprite)
        sprite.position = VisibleTextureLayout.position_visible_right_of_card(
            area.size,
            Rect2(card.position, card.size),
            visible_rect,
            MILESTONE_BOSS_SPRITE_GAP
        )

        # Re-anchor shadow and connector after the final sprite geometry. With
        # the milestone sprite back at the canonical 150% boss size, the inherited
        # boss shadow scale and the visible-foot anchor match the Pokemon again.
        var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
        if shadow != null:
            _position_milestone_boss_shadow(shadow, sprite, visible_rect)

        var connector: Line2D = ui.get("connector") as Line2D
        if connector != null:
            _update_milestone_boss_connector(connector, card, sprite, visible_rect)


func _milestone_boss_visible_rect(sprite: TextureRect) -> Rect2:
    return VisibleTextureLayout.visible_rect(sprite)


func _position_milestone_boss_shadow(
    shadow: Polygon2D,
    sprite: TextureRect,
    visible_rect: Rect2
) -> void:
    shadow.position = VisibleTextureLayout.visible_foot(sprite.position, visible_rect)
    shadow.scale = ROUTE_BOSS_SHADOW_SCALE


func _update_milestone_boss_connector(
    connector: Line2D,
    card: Control,
    sprite: TextureRect,
    visible_rect: Rect2
) -> void:
    connector.points = VisibleTextureLayout.enemy_connector_points(
        Rect2(card.position, card.size),
        sprite.position,
        visible_rect
    )
