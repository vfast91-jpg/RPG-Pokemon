extends "res://scripts/battle_demo_status_stage_scaling_v1.gd"

# Phase 2 for the ordinary single route boss.
#
# Contract comes from the route layer. When the first of the two boss HP bars is
# depleted, Timeflow freezes briefly, the boss visibly calls for help and two
# normal-stat same-species combatants join the enemy side. Their species is never
# resolved through evolution rules; only their level is changed.

const BOSS_REINFORCEMENT_MAX_ENEMY_COUNT: int = 4
const BOSS_REINFORCEMENT_ADD_SPRITE_SCALE: float = 0.66
const BOSS_REINFORCEMENT_CARD_EDGE_MARGIN: float = 4.0
const BOSS_REINFORCEMENT_ANGER_SECONDS: float = 0.34
const BOSS_REINFORCEMENT_FADE_SECONDS: float = 0.28
const BOSS_REINFORCEMENT_HOLD_SECONDS: float = 0.22

var _boss_reinforcement_transition_running: bool = false
var _boss_reinforcement_pause_before: bool = false


func _process(delta: float) -> void:
    # A dedicated lock is used in addition to `paused`, so no ATB can advance
    # between the HP-bar break and the deferred transition coroutine.
    if _boss_reinforcement_transition_running:
        return
    super._process(delta)


func _route_begin_wave() -> void:
    super._route_begin_wave()
    _bind_route_boss_reinforcement_contract()


func _refresh_cards() -> void:
    super._refresh_cards()

    var boss: Dictionary = _boss_reinforcement_leader()
    if boss.is_empty():
        return

    if bool(boss.get("boss_reinforcement_spawned", false)):
        _apply_boss_reinforcement_formation(boss)
        return

    if _boss_reinforcement_transition_running:
        return
    if not _boss_should_call_reinforcements(boss):
        return

    boss["boss_reinforcement_started"] = true
    _boss_reinforcement_pause_before = paused
    paused = true
    _boss_reinforcement_transition_running = true
    call_deferred("_run_boss_reinforcement_transition", str(boss.get("id", "")))


func _bind_route_boss_reinforcement_contract() -> void:
    if not route_mode or _route_enemy_party.size() != 1 or enemy_team.size() != 1:
        return

    var source_value: Variant = _route_enemy_party[0]
    var boss_value: Variant = enemy_team[0]
    if not (source_value is Dictionary) or not (boss_value is Dictionary):
        return

    var source: Dictionary = source_value as Dictionary
    var boss: Dictionary = boss_value as Dictionary
    if not bool(source.get("boss_reinforcement_enabled", false)):
        return
    if not bool(source.get("boss", false)) or not bool(boss.get("boss", false)):
        return
    if bool(source.get("milestone_double_boss", false)):
        return

    boss["boss_reinforcement_enabled"] = true
    boss["boss_reinforcement_count"] = clampi(
        int(source.get("boss_reinforcement_count", 2)),
        1,
        BOSS_REINFORCEMENT_MAX_ENEMY_COUNT - 1
    )
    boss["boss_reinforcement_species_id"] = str(
        source.get("boss_reinforcement_species_id", boss.get("species_id", ""))
    )
    boss["boss_reinforcement_level"] = maxi(
        1,
        int(source.get("boss_reinforcement_level", boss.get("level", 1)))
    )
    boss["boss_reinforcement_hp_multiplier"] = maxf(
        1.0,
        float(source.get("boss_reinforcement_hp_multiplier", 1.0))
    )
    boss["boss_reinforcement_start_atb"] = clampf(
        float(source.get("boss_reinforcement_start_atb", 0.0)),
        0.0,
        100.0
    )
    boss["boss_reinforcement_trigger_remaining_bars"] = maxi(
        1,
        int(source.get("boss_reinforcement_trigger_remaining_bars", 1))
    )
    boss["boss_reinforcement_started"] = false
    boss["boss_reinforcement_spawned"] = false


func _boss_reinforcement_leader() -> Dictionary:
    for combatant_value: Variant in enemy_team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value as Dictionary
        if bool(combatant.get("boss_reinforcement_enabled", false)):
            return combatant
    return {}


func _boss_should_call_reinforcements(boss: Dictionary) -> bool:
    if not route_mode or not battle_active:
        return false
    if not bool(boss.get("boss_reinforcement_enabled", false)):
        return false
    if bool(boss.get("boss_reinforcement_started", false)):
        return false
    if not bool(boss.get("alive", false)) or float(boss.get("hp", 0.0)) <= 0.0:
        return false
    if enemy_team.size() != 1:
        return false

    var base_max_hp: float = maxf(1.0, float(boss.get("boss_base_max_hp", 0.0)))
    var remaining_bars: int = maxi(
        1,
        int(boss.get("boss_reinforcement_trigger_remaining_bars", 1))
    )
    var trigger_hp: float = base_max_hp * float(remaining_bars)
    return float(boss.get("hp", 0.0)) <= trigger_hp


func _run_boss_reinforcement_transition(boss_id: String) -> void:
    var boss: Dictionary = _reinforcement_combatant_by_id(boss_id)
    if boss.is_empty() or not battle_active:
        _finish_boss_reinforcement_transition()
        return

    var area: Control = _battle_area_for_reinforcements()
    var ui_value: Variant = cards.get(boss_id, {})
    if area == null or not (ui_value is Dictionary):
        _finish_boss_reinforcement_transition()
        return

    var ui: Dictionary = ui_value as Dictionary
    var sprite: TextureRect = ui.get("texture") as TextureRect
    if sprite == null:
        _finish_boss_reinforcement_transition()
        return

    var boss_name: String = str(boss.get("name", "Der Boss"))
    var reinforcement_level: int = maxi(1, int(boss.get("boss_reinforcement_level", 1)))
    var message: String = "%s ruft Verstärkung!" % boss_name
    _set_log(
        "[b]💢 %s[/b] Zwei %s auf Lv.%d schließen sich dem Kampf an."
        % [message, boss_name, reinforcement_level]
    )

    var banner: PanelContainer = _create_boss_reinforcement_banner(area, message)
    var anger_icon: Label = _create_boss_anger_icon(area, sprite)
    await _animate_boss_anger(sprite)

    if not battle_active or not bool(boss.get("alive", false)):
        _free_reinforcement_effect(banner)
        _free_reinforcement_effect(anger_icon)
        _finish_boss_reinforcement_transition()
        return

    var reinforcements: Array[Dictionary] = _spawn_boss_reinforcements(boss)
    if reinforcements.is_empty():
        _free_reinforcement_effect(banner)
        _free_reinforcement_effect(anger_icon)
        _finish_boss_reinforcement_transition()
        return

    _layout_reinforcement_visuals(reinforcements)
    boss["boss_reinforcement_spawned"] = true
    _apply_boss_reinforcement_formation(boss)
    _refresh_cards()
    await _fade_in_boss_reinforcements(reinforcements)
    await get_tree().create_timer(BOSS_REINFORCEMENT_HOLD_SECONDS).timeout

    _free_reinforcement_effect(banner)
    _free_reinforcement_effect(anger_icon)
    _finish_boss_reinforcement_transition()
    _refresh_cards()


func _spawn_boss_reinforcements(boss: Dictionary) -> Array[Dictionary]:
    var created: Array[Dictionary] = []
    var species_id: String = str(
        boss.get("boss_reinforcement_species_id", boss.get("species_id", ""))
    )
    if species_id.is_empty():
        return created

    var level: int = maxi(1, int(boss.get("boss_reinforcement_level", 1)))
    var requested_count: int = maxi(1, int(boss.get("boss_reinforcement_count", 2)))
    var available_slots: int = maxi(0, BOSS_REINFORCEMENT_MAX_ENEMY_COUNT - enemy_team.size())
    var spawn_count: int = mini(requested_count, available_slots)
    var hp_multiplier: float = maxf(
        1.0,
        float(boss.get("boss_reinforcement_hp_multiplier", 1.0))
    )
    var start_atb: float = clampf(
        float(boss.get("boss_reinforcement_start_atb", 0.0)),
        0.0,
        100.0
    )

    for _spawn_index: int in range(spawn_count):
        var setup: Dictionary = {
            "species_id": species_id,
            "level": level
        }
        var combatant: Dictionary = _make_combatant("enemy", enemy_team.size(), setup)
        if combatant.is_empty():
            continue

        # Exact boss species + requested reinforcement level. No evolution
        # resolver is invoked here, so a low-level reinforcement never turns
        # into an earlier evolutionary stage.
        combatant["species_id"] = species_id
        combatant["boss"] = false
        combatant["boss_reinforcement"] = true
        combatant["boss_reinforcement_leader_id"] = str(boss.get("id", ""))
        combatant["atb"] = start_atb

        if hp_multiplier > 1.0:
            var normal_max_hp: int = maxi(1, int(combatant.get("max_hp", 1)))
            combatant["max_hp"] = maxi(1, int(round(float(normal_max_hp) * hp_multiplier)))
            combatant["hp"] = int(combatant["max_hp"])

        enemy_team.append(combatant)
        combatants.append(combatant)
        enemy_setup.append(setup.duplicate(true))
        created.append(combatant)

    return created


func _layout_reinforcement_visuals(reinforcements: Array[Dictionary]) -> void:
    var area: Control = _battle_area_for_reinforcements()
    if area == null or reinforcements.is_empty():
        return
    _layout_team(area, reinforcements, true)


func _apply_boss_reinforcement_formation(boss: Dictionary) -> void:
    var area: Control = _battle_area_for_reinforcements()
    if area == null:
        return

    var adds: Array[Dictionary] = _reinforcement_adds_for_boss(str(boss.get("id", "")))
    if adds.size() < 2:
        return

    # The boss keeps the exact route-boss center geometry it already had in
    # phase 1. The weaker helpers use smaller presentation-only sprites in the
    # top/bottom slots, which prevents sprite, shadow and status-card collisions
    # inside the fixed 640x216 battle area without changing their combat stats.
    _position_reinforcement_slot(area, adds[0], "top", false)
    _position_reinforcement_slot(area, boss, "center", true)
    _position_reinforcement_slot(area, adds[1], "bottom", false)


func _reinforcement_adds_for_boss(boss_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for combatant_value: Variant in enemy_team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value as Dictionary
        if not bool(combatant.get("boss_reinforcement", false)):
            continue
        if str(combatant.get("boss_reinforcement_leader_id", "")) != boss_id:
            continue
        result.append(combatant)
    return result


func _position_reinforcement_slot(
    area: Control,
    combatant: Dictionary,
    slot: String,
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

    card.position.x = ROSTER_EDGE_MARGIN
    match slot:
        "top":
            card.position.y = BOSS_REINFORCEMENT_CARD_EDGE_MARGIN
        "bottom":
            card.position.y = maxf(
                BOSS_REINFORCEMENT_CARD_EDGE_MARGIN,
                area.size.y - BOSS_REINFORCEMENT_CARD_EDGE_MARGIN - card.size.y
            )
        _:
            card.position.y = clampf(
                (area.size.y - card.size.y) * 0.5,
                0.0,
                maxf(0.0, area.size.y - card.size.y)
            )

    var sprite_scale: float = (
        ROUTE_BOSS_SPRITE_SCALE if boss_slot else BOSS_REINFORCEMENT_ADD_SPRITE_SCALE
    )
    var sprite_size: Vector2 = Vector2(ROSTER_SPRITE_SIDE, ROSTER_SPRITE_SIDE) * sprite_scale
    sprite.custom_minimum_size = sprite_size
    sprite.size = sprite_size

    var sprite_x: float = card.position.x + ROSTER_CARD_WIDTH + ROSTER_CARD_SPRITE_GAP
    if not boss_slot:
        sprite_x += 44.0
    var sprite_y: float = clampf(
        card.position.y + (card.size.y - sprite.size.y) * 0.5,
        0.0,
        maxf(0.0, area.size.y - sprite.size.y)
    )
    sprite.position = Vector2(sprite_x, sprite_y)

    var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
    if shadow != null:
        _position_boss_reinforcement_shadow(shadow, sprite, sprite_scale, boss_slot)

    var connector: Line2D = ui.get("connector") as Line2D
    if connector != null:
        _update_roster_connector(connector, card, sprite, true)


func _position_boss_reinforcement_shadow(
    shadow: Polygon2D,
    sprite: TextureRect,
    sprite_scale: float,
    boss_slot: bool
) -> void:
    var foot_ratio: float = ROUTE_BOSS_SHADOW_FOOT_Y_RATIO if boss_slot else (
        (ROSTER_SPRITE_SIDE - 5.0) / ROSTER_SPRITE_SIDE
    )
    shadow.position = sprite.position + Vector2(
        sprite.size.x * 0.5,
        sprite.size.y * foot_ratio
    )

    if not boss_slot:
        shadow.scale = Vector2.ONE * sprite_scale
        return

    var route_scale_span: float = maxf(0.001, ROUTE_BOSS_SPRITE_SCALE - 1.0)
    var scale_progress: float = clampf((sprite_scale - 1.0) / route_scale_span, 0.0, 1.0)
    shadow.scale = Vector2(
        lerpf(1.0, ROUTE_BOSS_SHADOW_SCALE.x, scale_progress),
        lerpf(1.0, ROUTE_BOSS_SHADOW_SCALE.y, scale_progress)
    )


func _create_boss_reinforcement_banner(area: Control, text: String) -> PanelContainer:
    var banner := PanelContainer.new()
    banner.name = "BossReinforcementBanner"
    banner.position = Vector2(area.size.x * 0.5 - 150.0, 8.0)
    banner.size = Vector2(300.0, 34.0)
    banner.z_index = 40
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style := StyleBoxFlat.new()
    style.bg_color = Color("241919e8")
    style.border_color = Color("e0b45a")
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.content_margin_left = 10.0
    style.content_margin_right = 10.0
    style.content_margin_top = 4.0
    style.content_margin_bottom = 4.0
    banner.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.text = "💢 " + text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", Color("ffe8b0"))
    label.add_theme_constant_override("outline_size", 2)
    label.add_theme_color_override("font_outline_color", Color("321b1b"))
    banner.add_child(label)
    area.add_child(banner)
    return banner


func _create_boss_anger_icon(area: Control, sprite: TextureRect) -> Label:
    var anger := Label.new()
    anger.name = "BossAngerIcon"
    anger.text = "💢"
    anger.size = Vector2(28.0, 28.0)
    anger.position = sprite.position + Vector2(sprite.size.x * 0.5 - 14.0, -2.0)
    anger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    anger.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    anger.add_theme_font_size_override("font_size", 20)
    anger.add_theme_constant_override("outline_size", 2)
    anger.add_theme_color_override("font_outline_color", Color("3b1717"))
    anger.z_index = 41
    anger.mouse_filter = Control.MOUSE_FILTER_IGNORE
    area.add_child(anger)
    return anger


func _animate_boss_anger(sprite: TextureRect) -> void:
    var base_position: Vector2 = sprite.position
    var base_modulate: Color = sprite.modulate
    var angry_modulate := Color(1.0, 0.55, 0.55, base_modulate.a)
    var tween: Tween = create_tween()
    tween.tween_property(sprite, "modulate", angry_modulate, 0.07)
    tween.tween_property(sprite, "position", base_position + Vector2(-4.0, 0.0), 0.045)
    tween.tween_property(sprite, "position", base_position + Vector2(4.0, 0.0), 0.055)
    tween.tween_property(sprite, "position", base_position + Vector2(-3.0, 0.0), 0.05)
    tween.tween_property(sprite, "position", base_position + Vector2(3.0, 0.0), 0.05)
    tween.tween_property(sprite, "position", base_position, 0.045)
    tween.tween_property(sprite, "modulate", base_modulate, 0.075)
    await tween.finished
    sprite.position = base_position
    sprite.modulate = base_modulate


func _fade_in_boss_reinforcements(reinforcements: Array[Dictionary]) -> void:
    var area: Control = _battle_area_for_reinforcements()
    if area == null:
        return

    var nodes: Array[CanvasItem] = []
    for combatant: Dictionary in reinforcements:
        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if ui_value is Dictionary:
            var ui: Dictionary = ui_value as Dictionary
            for key: String in ["card", "texture", "connector"]:
                var item: CanvasItem = ui.get(key) as CanvasItem
                if item != null and not nodes.has(item):
                    nodes.append(item)
        var shadow: CanvasItem = area.get_node_or_null("SpriteShadow_" + combatant_id) as CanvasItem
        if shadow != null and not nodes.has(shadow):
            nodes.append(shadow)

    if nodes.is_empty():
        return

    for item: CanvasItem in nodes:
        var hidden: Color = item.modulate
        hidden.a = 0.0
        item.modulate = hidden

    var tween: Tween = create_tween()
    for item: CanvasItem in nodes:
        var visible_color: Color = item.modulate
        visible_color.a = 1.0
        tween.parallel().tween_property(
            item,
            "modulate",
            visible_color,
            BOSS_REINFORCEMENT_FADE_SECONDS
        )
    await tween.finished


func _battle_area_for_reinforcements() -> Control:
    if battle_panel == null:
        return null
    return battle_panel.get_node_or_null("BattleArea") as Control


func _reinforcement_combatant_by_id(combatant_id: String) -> Dictionary:
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value as Dictionary
        if str(combatant.get("id", "")) == combatant_id:
            return combatant
    return {}


func _free_reinforcement_effect(node: Node) -> void:
    if node != null and is_instance_valid(node):
        node.queue_free()


func _finish_boss_reinforcement_transition() -> void:
    _boss_reinforcement_transition_running = false
    if battle_active:
        paused = _boss_reinforcement_pause_before
