extends "res://scripts/battle_demo_stockpile_infobox_v1.gd"

# Final presentation fix for the mandatory Doppelboss fights on stages
# 20, 40, 60 and 80. The normal roster formation is deliberately compact and
# works for ordinary 72px Pokemon, but two enlarged 108px boss sprites need a
# dedicated two-slot layout that stays centred and visually follows the normal
# enemy formation toward the middle of the battlefield.

const MILESTONE_BOSS_SPRITE_SCALE: float = 1.5
const MILESTONE_BOSS_SPRITE_GAP: float = 14.0
const MILESTONE_BOSS_CARD_GAP: float = 14.0
const MILESTONE_BOSS_FORWARD_OFFSET: float = 12.0
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


func _refresh_cards() -> void:
    super._refresh_cards()
    # Generic card refreshes can touch roster geometry again after the wave was
    # laid out. Re-apply only this milestone formation so cards, Pokemon,
    # shadows and connector lines always finish the refresh on the same anchors.
    if _is_milestone_double_boss_wave():
        _apply_milestone_double_boss_layout()


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

    var boss_side: float = ROSTER_SPRITE_SIDE * MILESTONE_BOSS_SPRITE_SCALE
    var boss_size := Vector2(boss_side, boss_side)
    var boss_slots: Array[Dictionary] = []

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

        boss_slots.append({
            "combatant_id": combatant_id,
            "ui": ui,
            "card": card,
            "sprite": sprite,
        })

    if boss_slots.size() != 2:
        return

    # Centre the complete pair as one formation instead of pinning one boss near
    # the top and the other near the bottom. The gap is based on the real card
    # heights, so the pair remains centred even if the boss-card height changes.
    var total_card_height: float = MILESTONE_BOSS_CARD_GAP
    for slot_value: Dictionary in boss_slots:
        var slot_card: Control = slot_value.get("card") as Control
        total_card_height += slot_card.size.y

    var next_card_y: float = maxf(0.0, (area.size.y - total_card_height) * 0.5)

    for slot_index: int in range(boss_slots.size()):
        var slot: Dictionary = boss_slots[slot_index]
        var combatant_id: String = str(slot.get("combatant_id", ""))
        var ui: Dictionary = slot.get("ui", {}) as Dictionary
        var card: Control = slot.get("card") as Control
        var sprite: TextureRect = slot.get("sprite") as TextureRect

        card.position.x = ROSTER_EDGE_MARGIN
        card.position.y = clampf(
            next_card_y,
            0.0,
            maxf(0.0, area.size.y - card.size.y)
        )
        next_card_y += card.size.y + MILESTONE_BOSS_CARD_GAP

        sprite.custom_minimum_size = boss_size
        sprite.size = boss_size

        # Align by the actually visible pixels, not by transparent PNG margins.
        # Both bosses move slightly toward the battlefield centre; the upper boss
        # receives the normal enemy-formation step on top, recreating the same
        # inward diagonal used by ordinary two-Pokemon enemy teams.
        var visible_rect: Rect2 = VisibleTextureLayout.visible_rect(sprite)
        var inward_step: float = (
            MILESTONE_BOSS_FORWARD_OFFSET
            + float(boss_slots.size() - 1 - slot_index) * ROSTER_FORMATION_STEP
        )
        sprite.position = VisibleTextureLayout.position_visible_right_of_card(
            area.size,
            Rect2(card.position, card.size),
            visible_rect,
            MILESTONE_BOSS_SPRITE_GAP + inward_step
        )

        # Keep shadow and connector tied to the final visible sprite geometry.
        # This is also re-applied after every card refresh, preventing a generic
        # roster pass from leaving a stale shadow behind when the sprite moves.
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
