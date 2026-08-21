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
# human sides in local PvP. Runde 0 uses the same marker globally: hovering a
# priority/opening move may replace the info text, but it must never hide which
# Pokemon the player is currently choosing that opening action for.
#
# Timeflow spread damage is also resolved here, at the shared final battle
# layer. A damaging move that currently has several living targets keeps its
# listed base power, but the final damage to every intended target is scaled by
# target count: 1 -> 100 %, 2 -> 75 %, 3 -> 60 %, 4 or more -> 50 %.

var _timeflow_spread_damage_multiplier: float = 1.0
var _timeflow_spread_damage_target_ids: Dictionary = {}


func _timeflow_spread_damage_scale(target_count: int) -> float:
    match target_count:
        0, 1:
            return 1.0
        2:
            return 0.75
        3:
            return 0.60
        _:
            return 0.50


func _timeflow_move_has_direct_damage(move: Dictionary) -> bool:
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false

    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        if str(mechanic.get("kind", "")) == "damage":
            return true
    return false


func _execute_move(actor: Dictionary, move_id: String) -> void:
    _timeflow_spread_damage_multiplier = 1.0
    _timeflow_spread_damage_target_ids = {}

    var move: Dictionary = _move_data(move_id)
    if not move.is_empty() and _timeflow_move_has_direct_damage(move):
        var targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
        var living_target_count: int = 0

        for target_value: Variant in targets:
            if not (target_value is Dictionary):
                continue
            var target: Dictionary = target_value
            if not bool(target.get("alive", false)):
                continue

            living_target_count += 1
            var target_id: String = str(target.get("id", ""))
            if not target_id.is_empty():
                _timeflow_spread_damage_target_ids[target_id] = true

        _timeflow_spread_damage_multiplier = _timeflow_spread_damage_scale(living_target_count)

    super._execute_move(actor, move_id)

    _timeflow_spread_damage_multiplier = 1.0
    _timeflow_spread_damage_target_ids = {}


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    # Let every inherited damage rule resolve first (weather, terrain, crits,
    # type effectiveness, move-specific power changes, etc.). Spread scaling is
    # deliberately the final damage modifier so all spread moves obey one rule.
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0 or _timeflow_spread_damage_multiplier >= 0.9999:
        return damage

    var target_id: String = str(target.get("id", ""))
    if target_id.is_empty() or not _timeflow_spread_damage_target_ids.has(target_id):
        return damage

    return maxi(1, int(round(float(damage) * _timeflow_spread_damage_multiplier)))


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


func _show_opening_choice(actor: Dictionary, opening_moves: Array[String]) -> void:
    super._show_opening_choice(actor, opening_moves)

    # Runde 0 previously described the acting Pokemon only in the log. Hovering
    # a move replaces that text with the move preview, so the player lost the
    # visual context of whose priority action is being chosen. Treat the current
    # opening candidate as the selected actor as well; the global marker system
    # can then communicate the same information without competing with previews.
    if not battle_active or not opening_phase_active:
        return
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return

    selected_actor = actor
    _update_turn_markers()


func _choose_opening_move(actor: Dictionary, move_id: String) -> void:
    # The marker represents a pending human decision, not the later resolution
    # animation. Clear it first; if another Pokemon still needs a Runde-0 choice,
    # its _show_opening_choice() call immediately moves the marker to that actor.
    selected_actor = {}
    _update_turn_markers()
    super._choose_opening_move(actor, move_id)


func _skip_opening_move() -> void:
    selected_actor = {}
    _update_turn_markers()
    super._skip_opening_move()


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
