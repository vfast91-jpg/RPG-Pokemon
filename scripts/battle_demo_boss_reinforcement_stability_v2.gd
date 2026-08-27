extends "res://scripts/battle_demo_sketch_battle_local_v1.gd"

# Final stability/reflow layer for the ordinary "Besondere Begegnung" boss.
#
# The reinforcement system is implemented much lower in the inheritance stack.
# Several newer battle/UI layers also touch roster geometry after that ancestor
# has positioned the boss, shadows and connector lines. That made the stage-10
# encounter look correct briefly and then drift back to generic roster anchors.
# This leaf deliberately runs last and treats card, visible sprite, shadow and
# connector as one formation unit.
#
# It also closes a transition deadlock: the old implementation restored the raw
# `paused` value from the instant the HP bar broke. A transient action-resolution
# pause could therefore survive after the reinforcement animation even though no
# player prompt was open, leaving Timeflow frozen with an empty command area.

const StableReinforcementVisibleLayout = preload("res://scripts/ui/visible_texture_layout.gd")

const STABLE_REINFORCEMENT_TOP_CENTER_RATIO: float = 0.25
const STABLE_REINFORCEMENT_BOSS_CENTER_RATIO: float = 0.50
const STABLE_REINFORCEMENT_BOTTOM_CENTER_RATIO: float = 0.75
const STABLE_REINFORCEMENT_EDGE_PADDING: float = 8.0
const STABLE_REINFORCEMENT_FORWARD_OFFSET: float = 6.0
const STABLE_REINFORCEMENT_CONNECTOR_MAX_WIDTH: float = 2.0
const STABLE_REINFORCEMENT_CONNECTOR_MAX_ALPHA: float = 0.78


func _route_begin_wave() -> void:
    super._route_begin_wave()
    # All inherited route/boss decorators have finished at this point. Re-apply
    # the standard-boss geometry once from the active leaf so the initial
    # one-boss phase already uses the same anchors as phase 2.
    _stabilize_standard_reinforcement_encounter()


func _refresh_cards() -> void:
    super._refresh_cards()
    # This must stay after `super`: lower UI layers update generic roster
    # geometry while refreshing. Running here makes the special formation the
    # final authority instead of letting a later generic shadow/line pass win.
    _stabilize_standard_reinforcement_encounter()


func _stabilize_standard_reinforcement_encounter() -> void:
    if not route_mode or not battle_active:
        return

    var boss: Dictionary = _boss_reinforcement_leader()
    if boss.is_empty():
        return

    if bool(boss.get("boss_reinforcement_spawned", false)):
        _apply_stable_reinforcement_formation(boss)
    else:
        _apply_stable_single_boss_formation(boss)


func _apply_stable_single_boss_formation(boss: Dictionary) -> void:
    var area: Control = _battle_area_for_reinforcements()
    if area == null:
        return
    _position_stable_reinforcement_slot(
        area,
        boss,
        STABLE_REINFORCEMENT_BOSS_CENTER_RATIO,
        true
    )


func _apply_stable_reinforcement_formation(boss: Dictionary) -> void:
    var area: Control = _battle_area_for_reinforcements()
    if area == null:
        return

    var adds: Array[Dictionary] = _reinforcement_adds_for_boss(str(boss.get("id", "")))
    if adds.size() < 2:
        return

    # Quarter-height slots keep the helpers visibly away from the screen edges
    # while leaving the enlarged boss in the optical centre. Every related node
    # uses the same centre, so cards, Pokemon, shadows and lines cannot drift
    # independently during the 1 -> 3 transition.
    _position_stable_reinforcement_slot(
        area,
        adds[0],
        STABLE_REINFORCEMENT_TOP_CENTER_RATIO,
        false
    )
    _position_stable_reinforcement_slot(
        area,
        boss,
        STABLE_REINFORCEMENT_BOSS_CENTER_RATIO,
        true
    )
    _position_stable_reinforcement_slot(
        area,
        adds[1],
        STABLE_REINFORCEMENT_BOTTOM_CENTER_RATIO,
        false
    )


func _position_stable_reinforcement_slot(
    area: Control,
    combatant: Dictionary,
    center_ratio: float,
    boss_slot: bool
) -> void:
    var combatant_id: String = str(combatant.get("id", ""))
    var ui_value: Variant = cards.get(combatant_id, {})
    if not (ui_value is Dictionary):
        return

    var ui: Dictionary = ui_value as Dictionary
    var card: Control = ui.get("card") as Control
    var sprite: TextureRect = ui.get("texture") as TextureRect
    if card == null or sprite == null:
        return

    var center_y: float = area.size.y * center_ratio
    var min_card_y: float = STABLE_REINFORCEMENT_EDGE_PADDING
    var max_card_y: float = maxf(
        min_card_y,
        area.size.y - STABLE_REINFORCEMENT_EDGE_PADDING - card.size.y
    )
    card.position = Vector2(
        ROSTER_EDGE_MARGIN,
        clampf(center_y - card.size.y * 0.5, min_card_y, max_card_y)
    )

    var sprite_scale: float = (
        ROUTE_BOSS_SPRITE_SCALE if boss_slot else BOSS_REINFORCEMENT_ADD_SPRITE_SCALE
    )
    var sprite_size := Vector2(ROSTER_SPRITE_SIDE, ROSTER_SPRITE_SIDE) * sprite_scale
    sprite.custom_minimum_size = sprite_size
    sprite.size = sprite_size

    var visible_rect: Rect2 = StableReinforcementVisibleLayout.visible_rect(sprite)
    var visible_gap: float = ROSTER_CARD_SPRITE_GAP
    if not boss_slot:
        # The helpers remain slightly in front of the boss, but the old +20 px
        # offset made their status connectors dominate the battlefield.
        visible_gap += STABLE_REINFORCEMENT_FORWARD_OFFSET

    sprite.position = StableReinforcementVisibleLayout.position_visible_right_of_card(
        area.size,
        Rect2(card.position, card.size),
        visible_rect,
        visible_gap
    )

    var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
    if shadow != null:
        # Anchor to the actually visible Pokemon instead of the TextureRect box.
        # This is especially important for species with asymmetric transparent
        # PNG margins such as the Rabauz used by the stage-10 encounter.
        shadow.position = StableReinforcementVisibleLayout.visible_foot(
            sprite.position,
            visible_rect
        )
        shadow.scale = ROUTE_BOSS_SHADOW_SCALE if boss_slot else Vector2.ONE * sprite_scale

    var connector: Line2D = ui.get("connector") as Line2D
    if connector != null:
        connector.points = StableReinforcementVisibleLayout.enemy_connector_points(
            Rect2(card.position, card.size),
            sprite.position,
            visible_rect
        )
        connector.begin_cap_mode = Line2D.LINE_CAP_ROUND
        connector.end_cap_mode = Line2D.LINE_CAP_ROUND
        if not boss_slot:
            connector.width = minf(connector.width, STABLE_REINFORCEMENT_CONNECTOR_MAX_WIDTH)
            var connector_color: Color = connector.default_color
            connector_color.a = minf(
                connector_color.a,
                STABLE_REINFORCEMENT_CONNECTOR_MAX_ALPHA
            )
            connector.default_color = connector_color

    cards[combatant_id] = ui


func _finish_boss_reinforcement_transition() -> void:
    # Do not restore the raw pause snapshot. During real move resolution that
    # value may be a short-lived technical pause with no UI owner. Only genuine
    # interactive pause owners are allowed to survive the transition.
    _boss_reinforcement_transition_running = false
    _boss_reinforcement_transition_started_msec = 0
    _boss_reinforcement_pause_before = false

    if not battle_active:
        return

    paused = _reinforcement_has_real_pause_owner()
    _stabilize_standard_reinforcement_encounter()
    call_deferred("_reinforcement_post_transition_resume_guard")


func _reinforcement_has_real_pause_owner() -> bool:
    if not selected_actor.is_empty():
        return true
    if opening_phase_active:
        return true
    return info_panel != null and info_panel.visible


func _reinforcement_post_transition_resume_guard() -> void:
    if not battle_active or _boss_reinforcement_transition_running:
        return

    _stabilize_standard_reinforcement_encounter()
    if paused and not _reinforcement_has_real_pause_owner():
        # Last-resort guard against a stale pause written by an inherited
        # animation callback after the phase transition completed.
        paused = false
