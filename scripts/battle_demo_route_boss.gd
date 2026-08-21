extends "res://scripts/battle_demo_player_effect_labels.gd"

# Route-only mini-boss presentation. Normal test battles and normal route
# battles keep their existing combatant stats and roster layout unchanged.

const ROUTE_BOSS_SPRITE_SCALE: float = 1.5
const ROUTE_BOSS_CARD_HEIGHT: float = 60.0
const ROUTE_BOSS_HP_BAR_GAP: float = 8.0


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not route_mode or enemy_team.is_empty() or _route_enemy_party.is_empty():
        return

    var boss_found: bool = false
    var count: int = mini(enemy_team.size(), _route_enemy_party.size())
    for index: int in range(count):
        var source_value: Variant = _route_enemy_party[index]
        if not (source_value is Dictionary):
            continue
        var source: Dictionary = source_value
        if not bool(source.get("boss", false)):
            continue

        var combatant_value: Variant = enemy_team[index]
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var base_max_hp: int = maxi(1, int(combatant.get("max_hp", 1)))
        var hp_multiplier: float = maxf(1.0, float(source.get("hp_multiplier", 2.0)))
        var boss_max_hp: int = maxi(base_max_hp, int(round(float(base_max_hp) * hp_multiplier)))

        # One continuous HP pool. Damage is never stopped at a bar boundary;
        # the two bars below are only two windows onto this single value.
        combatant["boss"] = true
        combatant["boss_base_max_hp"] = base_max_hp
        combatant["boss_hp_multiplier"] = hp_multiplier
        combatant["max_hp"] = boss_max_hp
        combatant["hp"] = boss_max_hp
        boss_found = true

    if boss_found:
        _decorate_route_boss_cards()
        _refresh_cards()
        _set_log("👑 Eine Seltene Begegnung! Der Mini-Boss besitzt zwei vollständige KP-Leisten.")


func _decorate_route_boss_cards() -> void:
    for combatant_value: Variant in enemy_team:
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

        # The boss is intentionally unmistakable: taller status card and a
        # sprite that is 50% larger than the normal fixed roster sprite.
        var old_height: float = card.size.y
        card.custom_minimum_size.y = maxf(ROUTE_BOSS_CARD_HEIGHT, card.custom_minimum_size.y)
        card.size.y = maxf(ROUTE_BOSS_CARD_HEIGHT, card.size.y)
        card.position.y -= (card.size.y - old_height) * 0.5

        var canvas: Control = card.get_node_or_null("CardCanvas") as Control
        if canvas != null:
            canvas.custom_minimum_size.y = maxf(ROUTE_BOSS_CARD_HEIGHT - 4.0, canvas.custom_minimum_size.y)
            _arrange_boss_card_meters(canvas, ui, combatant)

        var normal_sprite_size: Vector2 = sprite.size
        if normal_sprite_size.x <= 0.0 or normal_sprite_size.y <= 0.0:
            normal_sprite_size = Vector2(72.0, 72.0)
        var boss_size: Vector2 = normal_sprite_size * ROUTE_BOSS_SPRITE_SCALE
        sprite.custom_minimum_size = boss_size
        sprite.size = boss_size

        var area: Control = sprite.get_parent() as Control
        if area != null:
            # Keep the enlarged sprite vertically centered on its enlarged card.
            var desired_y: float = card.position.y + (card.size.y - boss_size.y) * 0.5
            sprite.position.y = clampf(desired_y, 0.0, maxf(0.0, area.size.y - boss_size.y))

            var connector: Line2D = ui.get("connector") as Line2D
            if connector != null:
                _update_roster_connector(connector, card, sprite, true)

            var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
            if shadow != null:
                shadow.position = sprite.position + Vector2(boss_size.x * 0.5, boss_size.y - 5.0)
                shadow.scale = Vector2(ROUTE_BOSS_SPRITE_SCALE, 1.25)

            var badge := Label.new()
            badge.name = "BossBadge_" + combatant_id
            badge.text = "👑 MINI-BOSS"
            badge.position = sprite.position + Vector2(-4.0, -16.0)
            badge.size = Vector2(boss_size.x + 20.0, 16.0)
            badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            badge.add_theme_font_size_override("font_size", 11)
            badge.add_theme_color_override("font_color", Color("ffe16b"))
            badge.add_theme_constant_override("outline_size", 2)
            badge.add_theme_color_override("font_outline_color", Color("382b12"))
            badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
            badge.z_index = 12
            area.add_child(badge)
            ui["boss_badge"] = badge

        cards[combatant_id] = ui


func _arrange_boss_card_meters(canvas: Control, ui: Dictionary, combatant: Dictionary) -> void:
    var name_label: Label = canvas.get_node_or_null("Name") as Label
    if name_label != null:
        name_label.text = "👑 BOSS · %s Lv.%d" % [
            str(combatant.get("name", "Pokémon")),
            int(combatant.get("level", 1))
        ]
        name_label.size.x = 145.0

    var hp_back: Panel = ui.get("hp_back") as Panel
    var hp_fill: Panel = ui.get("hp_fill") as Panel
    if hp_back != null:
        hp_back.position.y = 20.0
    if hp_fill != null:
        hp_fill.position.y = 20.0

    var second_back := Panel.new()
    second_back.name = "BossHP2Back"
    second_back.position = Vector2(ROSTER_METER_X, 20.0 + ROUTE_BOSS_HP_BAR_GAP)
    second_back.size = Vector2(ROSTER_METER_WIDTH, ROSTER_METER_HEIGHT)
    second_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    second_back.add_theme_stylebox_override("panel", _meter_style(Color("c8c8c2")))
    canvas.add_child(second_back)

    var second_fill := Panel.new()
    second_fill.name = "BossHP2Fill"
    second_fill.position = second_back.position
    second_fill.size = second_back.size
    second_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    second_fill.add_theme_stylebox_override("panel", _meter_style(Color("55b85a")))
    canvas.add_child(second_fill)

    var aggro_label: Label = ui.get("aggro_label") as Label
    var aggro_back: Panel = ui.get("aggro_back") as Panel
    var aggro_fill: Panel = ui.get("aggro_fill") as Panel
    if aggro_label != null:
        aggro_label.position.y = 36.0
    if aggro_back != null:
        aggro_back.position.y = 37.0
    if aggro_fill != null:
        aggro_fill.position.y = 37.0

    var atb_text: Label = ui.get("atb_text") as Label
    var atb_back: Panel = ui.get("atb_back") as Panel
    var atb_fill: Panel = ui.get("atb_fill") as Panel
    if atb_text != null:
        atb_text.position.y = 46.0
    if atb_back != null:
        atb_back.position.y = 47.0
    if atb_fill != null:
        atb_fill.position.y = 47.0

    var hp_controller: ProgressBar = ui.get("hp") as ProgressBar
    if hp_controller != null:
        hp_controller.max_value = float(maxi(1, int(combatant.get("boss_base_max_hp", 1))))

    ui["boss_hp2_back"] = second_back
    ui["boss_hp2_fill"] = second_fill


func _refresh_cards() -> void:
    super._refresh_cards()

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("boss", false)):
            continue

        var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var base_max_hp: float = maxf(1.0, float(combatant.get("boss_base_max_hp", 1)))
        var total_hp: float = clampf(float(combatant.get("hp", 0)), 0.0, float(combatant.get("max_hp", 1)))

        # The upper bar is consumed first. As soon as damage exceeds it, the
        # same single HP value naturally continues into the lower bar.
        var upper_hp: float = clampf(total_hp - base_max_hp, 0.0, base_max_hp)
        var lower_hp: float = clampf(total_hp, 0.0, base_max_hp)
        _set_meter_fill(ui.get("hp_fill") as Panel, upper_hp / base_max_hp)
        _set_meter_fill(ui.get("boss_hp2_fill") as Panel, lower_hp / base_max_hp)

        var hp_text: Label = ui.get("hp_text") as Label
        if hp_text != null:
            hp_text.text = "KP %d/%d" % [int(total_hp), int(combatant.get("max_hp", 1))]

        var hp_controller: ProgressBar = ui.get("hp") as ProgressBar
        if hp_controller != null:
            hp_controller.max_value = base_max_hp
            hp_controller.value = upper_hp
