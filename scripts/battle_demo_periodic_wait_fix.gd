extends "res://scripts/battle_demo_bulbasaur_family_tm_final.gd"

# Central action-semantics correction.
# Warten is a real own action in Timeflow. Periodic effects that trigger after
# the affected Pokemon's own action therefore resolve after Warten as well.
# This keeps schwere Vergiftung, Fluch and the already-central burn/poison/seed/
# binding effects consistent with normal move actions.
#
# This final layer also repairs the active-turn triangle after later battle
# layers began stopping _process() while the action menu is paused. The marker
# must keep its calm sinusoidal bob during player decisions, stay anchored to
# the actual Pokemon sprite even inside nested card layouts, and work for both
# human sides in local PvP.


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    super._layout_team(area, team, enemy)

    # The inherited marker layer intentionally created arrows only for the
    # normal player side. In local PvP the enemy side is controlled by Spieler 2,
    # so give those combatants the exact same marker nodes as well.
    if not enemy:
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

        var existing_marker: Node2D = ui.get("turn_marker") as Node2D
        if existing_marker == null:
            ui["turn_marker"] = _make_turn_marker(area, combatant_id)
            ui["turn_marker_anchor"] = _turn_marker_anchor(sprite)
            cards[combatant_id] = ui

    _update_turn_markers()


func _process(delta: float) -> void:
    # battle_demo_bulbasaur_family_tm_final.gd deliberately stops its complete
    # parent process chain while paused. That is correct for ATB, but it also
    # accidentally froze the purely visual turn-marker animation. Remember the
    # pause state before calling the parent and advance only the marker ourselves
    # in that case. During normal battle time the inherited marker already ticks.
    var marker_needs_manual_tick: bool = battle_active and paused
    super._process(delta)

    if marker_needs_manual_tick:
        _turn_marker_time += delta
        _update_turn_markers()


func _update_turn_markers() -> void:
    var active_id: String = ""
    if battle_active \
            and not selected_actor.is_empty() \
            and bool(selected_actor.get("alive", false)):
        active_id = str(selected_actor.get("id", ""))

    var bob_offset: float = sin(
        _turn_marker_time * TAU / TURN_MARKER_BOB_PERIOD
    ) * TURN_MARKER_BOB_DISTANCE

    # Use all combatants rather than only player_team. In normal route battles
    # enemy AI never opens the player action selector, so its marker stays hidden;
    # in PvP the selected enemy-side Pokemon belongs to Spieler 2 and is marked.
    for combatant_value: Variant in combatants:
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

        # The sprite lives inside a nested card/HBox, while the marker lives on
        # BattleArea. sprite.position is therefore in the wrong coordinate space
        # and was the reason the arrow visibly drifted after layout changes.
        var sprite_origin_in_marker_parent: Vector2 = sprite.position
        var marker_parent: Control = marker.get_parent() as Control
        if marker_parent != null:
            sprite_origin_in_marker_parent = sprite.global_position - marker_parent.global_position

        var center_x: float = sprite_origin_in_marker_parent.x + anchor.x
        var base_y: float = maxf(
            TURN_MARKER_MIN_Y,
            sprite_origin_in_marker_parent.y + anchor.y
        )
        marker.position = Vector2(center_x, base_y + bob_offset)


func _choose_wait() -> void:
    if selected_actor.is_empty():
        super._choose_wait()
        return

    var actor: Dictionary = selected_actor
    super._choose_wait()

    if not battle_active or not bool(actor.get("alive", false)):
        return

    _resolve_after_action_effects(actor)
    _refresh_cards()
    _check_end()
