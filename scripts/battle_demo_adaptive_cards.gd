extends "res://scripts/battle_demo_family_lab.gd"

# Stable tactical roster presentation.
#
# This file is the single authority for battle cards, Pokemon sprite sizing and
# combat formation. Team size changes positions only; dimensions never change.
# The visible meters deliberately use plain ColorRects instead of ProgressBars,
# because themed ProgressBars enforce their own minimum height and were the
# reason KP/Aggro/ATB visually escaped and overlapped the cards.

const ROSTER_CARD_WIDTH: float = 176.0
const ROSTER_CARD_HEIGHT: float = 52.0
const ROSTER_SPRITE_SIDE: float = 72.0
const ROSTER_INFO_SIZE: Vector2 = Vector2(18.0, 18.0)
const ROSTER_EDGE_MARGIN: float = 8.0
const ROSTER_CARD_SPRITE_GAP: float = 14.0
const ROSTER_FORMATION_STEP: float = 10.0
const ROSTER_METER_X: float = 52.0
const ROSTER_METER_WIDTH: float = 96.0
const ROSTER_METER_HEIGHT: float = 6.0

var _roster_card_default: StyleBoxFlat
var _roster_card_active: StyleBoxFlat
var _roster_card_target: StyleBoxFlat
var _roster_card_fainted: StyleBoxFlat


func _positions_for_count(count: int) -> Array:
    # One fixed 52px card format in the 216px HD battle area.
    # Only the slot positions change. Four cards retain 2px gaps and fit fully.
    match clampi(count, 1, 4):
        1:
            return [82.0]
        2:
            return [55.0, 109.0]
        3:
            return [28.0, 82.0, 136.0]
        _:
            return [1.0, 55.0, 109.0, 163.0]


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    _ensure_roster_card_styles()

    var card := PanelContainer.new()
    card.name = "RosterCard_" + str(combatant.get("id", ""))
    card.custom_minimum_size = Vector2(ROSTER_CARD_WIDTH, ROSTER_CARD_HEIGHT)
    card.size = Vector2(ROSTER_CARD_WIDTH, ROSTER_CARD_HEIGHT)
    card.clip_contents = true
    card.add_theme_stylebox_override("panel", _roster_card_default)

    # Plain Control is intentional: child controls can never resize the card.
    var canvas := Control.new()
    canvas.name = "CardCanvas"
    canvas.mouse_filter = Control.MOUSE_FILTER_PASS
    canvas.custom_minimum_size = Vector2(170.0, 48.0)
    card.add_child(canvas)

    var name_label := Label.new()
    name_label.name = "Name"
    name_label.text = str(combatant.get("name", "Pokemon")) + " Lv." + str(combatant.get("level", 1))
    name_label.position = Vector2(2.0, 0.0)
    name_label.size = Vector2(116.0, 12.0)
    name_label.clip_text = true
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.add_theme_font_size_override("font_size", 9)
    name_label.add_theme_color_override("font_color", Color("26322e"))
    canvas.add_child(name_label)

    var type_label := Label.new()
    type_label.name = "Types"
    type_label.position = Vector2(2.0, 10.0)
    type_label.size = Vector2(82.0, 9.0)
    type_label.clip_text = true
    type_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    type_label.add_theme_font_size_override("font_size", 7)
    type_label.add_theme_constant_override("outline_size", 1)
    type_label.add_theme_color_override("font_outline_color", Color("ffffffaa"))
    var types: Array = _type_array(combatant.get("types", []))
    type_label.text = _roster_type_text(types)
    if not types.is_empty():
        type_label.add_theme_color_override("font_color", _type_badge_color(str(types[0])).darkened(0.18))
    else:
        type_label.add_theme_color_override("font_color", Color("53605b"))
    canvas.add_child(type_label)

    var status_line := Label.new()
    status_line.name = "State"
    status_line.position = Vector2(84.0, 10.0)
    status_line.size = Vector2(64.0, 9.0)
    status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status_line.clip_text = true
    status_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    status_line.add_theme_font_size_override("font_size", 7)
    status_line.add_theme_color_override("font_color", Color("5a4646"))
    canvas.add_child(status_line)

    # Separate text and meter columns. No text is drawn on top of a meter.
    var hp_text := _make_meter_label(canvas, "HPText", Vector2(2.0, 19.0), "KP 0/0", Color("31533a"))
    var aggro_label := _make_meter_label(canvas, "AggroText", Vector2(2.0, 29.0), "AG 0", Color("7b2d2d"))
    var atb_text := _make_meter_label(canvas, "ATBText", Vector2(2.0, 39.0), "ATB 0%", Color("24668f"))

    var hp_meter: Dictionary = _make_meter(
        canvas, "HP", Vector2(ROSTER_METER_X, 20.0),
        Color("c8c8c2"), Color("55b85a")
    )
    var aggro_meter: Dictionary = _make_meter(
        canvas, "Aggro", Vector2(ROSTER_METER_X, 30.0),
        Color("d8b8b5"), Color("d94c4c")
    )
    var atb_meter: Dictionary = _make_meter(
        canvas, "ATB", Vector2(ROSTER_METER_X, 40.0),
        Color("b5b5aa"), Color("42aef5")
    )

    # Hidden compatibility controllers: inherited battle logic writes values to
    # ProgressBars. Keeping invisible controllers preserves that contract while
    # the visible meters remain immune to theme minimum-size inflation.
    var hp_controller := ProgressBar.new()
    hp_controller.name = "HPController"
    hp_controller.visible = false
    hp_controller.max_value = float(maxi(1, int(combatant.get("max_hp", 1))))
    hp_controller.value = float(combatant.get("hp", 0))
    canvas.add_child(hp_controller)

    var aggro_controller := ProgressBar.new()
    aggro_controller.name = "AggroController"
    aggro_controller.visible = false
    aggro_controller.max_value = 100.0
    canvas.add_child(aggro_controller)

    var atb_controller := ProgressBar.new()
    atb_controller.name = "ATBController"
    atb_controller.visible = false
    atb_controller.max_value = 100.0
    atb_controller.value = float(combatant.get("atb", 0.0))
    canvas.add_child(atb_controller)

    var info_button := Button.new()
    info_button.name = "Info"
    info_button.text = "i"
    info_button.position = Vector2(151.0, 1.0)
    info_button.size = ROSTER_INFO_SIZE
    info_button.custom_minimum_size = ROSTER_INFO_SIZE
    info_button.focus_mode = Control.FOCUS_NONE
    info_button.add_theme_font_size_override("font_size", 7)
    info_button.add_theme_stylebox_override("normal", _info_button_style(Color("4b3e46"), Color("806b73")))
    info_button.add_theme_stylebox_override("hover", _info_button_style(Color("5e4e58"), Color("aa8f99")))
    info_button.add_theme_stylebox_override("pressed", _info_button_style(Color("392f35"), Color("c7a6b2")))
    info_button.add_theme_stylebox_override("focus", _info_button_style(Color("4b3e46"), Color("aa8f99")))
    info_button.tooltip_text = "Pokemon-Details anzeigen"
    info_button.pressed.connect(_show_info.bind(combatant))
    canvas.add_child(info_button)

    # The sprite starts inside the card only as a convenient construction point.
    # _layout_team reparents it into the battlefield immediately afterwards.
    var texture_box := TextureRect.new()
    texture_box.name = "BattleTexture"
    texture_box.position = Vector2(-ROSTER_SPRITE_SIDE, -ROSTER_SPRITE_SIDE)
    texture_box.size = Vector2(ROSTER_SPRITE_SIDE, ROSTER_SPRITE_SIDE)
    texture_box.custom_minimum_size = Vector2(ROSTER_SPRITE_SIDE, ROSTER_SPRITE_SIDE)
    texture_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_box.flip_h = enemy
    texture_box.texture = _species_texture(str(combatant.get("name", "")))
    canvas.add_child(texture_box)

    # Inherited refresh layers still expect a status label. Keep it hidden so it
    # has zero visual/layout influence while preserving compatibility.
    var legacy_status := Label.new()
    legacy_status.name = "LegacyStatus"
    legacy_status.visible = false
    canvas.add_child(legacy_status)

    var combatant_id: String = str(combatant.get("id", ""))
    cards[combatant_id] = {
        "card": card,
        "texture": texture_box,
        "hp": hp_controller,
        "hp_text": hp_text,
        "hp_fill": hp_meter["fill"],
        "hp_back": hp_meter["background"],
        "atb": atb_controller,
        "atb_text": atb_text,
        "atb_fill": atb_meter["fill"],
        "atb_back": atb_meter["background"],
        "aggro": aggro_controller,
        "aggro_label": aggro_label,
        "aggro_fill": aggro_meter["fill"],
        "aggro_back": aggro_meter["background"],
        "status": legacy_status,
        "status_line": status_line,
        "info": info_button
    }
    return card


func _make_meter_label(
    canvas: Control,
    node_name: String,
    position_value: Vector2,
    initial_text: String,
    color: Color
) -> Label:
    var label := Label.new()
    label.name = node_name
    label.text = initial_text
    label.position = position_value
    label.size = Vector2(48.0, 8.0)
    label.clip_text = true
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.add_theme_font_size_override("font_size", 6)
    label.add_theme_color_override("font_color", color)
    canvas.add_child(label)
    return label


func _make_meter(
    canvas: Control,
    node_name: String,
    position_value: Vector2,
    background_color: Color,
    fill_color: Color
) -> Dictionary:
    var background := ColorRect.new()
    background.name = node_name + "Back"
    background.position = position_value
    background.size = Vector2(ROSTER_METER_WIDTH, ROSTER_METER_HEIGHT)
    background.color = background_color
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(background)

    var fill := ColorRect.new()
    fill.name = node_name + "Fill"
    fill.position = position_value
    fill.size = Vector2(ROSTER_METER_WIDTH, ROSTER_METER_HEIGHT)
    fill.color = fill_color
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(fill)

    return {"background": background, "fill": fill}


func _info_button_style(background: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(4)
    style.content_margin_left = 0.0
    style.content_margin_right = 0.0
    style.content_margin_top = 0.0
    style.content_margin_bottom = 0.0
    return style


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    # Do not call the inherited layout here. This file owns battle-card and
    # sprite geometry completely, preventing later/earlier layers from fighting
    # over dimensions and formation.
    var positions: Array = _positions_for_count(team.size())

    for index: int in range(team.size()):
        var combatant_value: Variant = team[index]
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value

        var card: Control = _make_card(combatant, enemy)
        var card_x: float = ROSTER_EDGE_MARGIN if enemy else area.size.x - ROSTER_EDGE_MARGIN - ROSTER_CARD_WIDTH
        card.position = Vector2(card_x, float(positions[index]))
        card.z_index = 8
        area.add_child(card)

        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var sprite: TextureRect = ui.get("texture") as TextureRect
        if sprite == null:
            continue

        var old_parent: Node = sprite.get_parent()
        if old_parent != null:
            old_parent.remove_child(sprite)
        area.add_child(sprite)

        sprite.name = "BattleSprite_" + combatant_id
        sprite.custom_minimum_size = Vector2(ROSTER_SPRITE_SIDE, ROSTER_SPRITE_SIDE)
        sprite.size = Vector2(ROSTER_SPRITE_SIDE, ROSTER_SPRITE_SIDE)
        sprite.z_index = 10
        sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

        # Upward-pointing formation: the TOP slot is farthest toward the battle
        # center; every lower slot steps back toward its own side.
        var inward: float = float(maxi(0, team.size() - 1 - index)) * ROSTER_FORMATION_STEP
        var sprite_x: float
        if enemy:
            sprite_x = card.position.x + ROSTER_CARD_WIDTH + ROSTER_CARD_SPRITE_GAP + inward
        else:
            sprite_x = card.position.x - ROSTER_CARD_SPRITE_GAP - ROSTER_SPRITE_SIDE - inward

        var desired_y: float = card.position.y + (ROSTER_CARD_HEIGHT - ROSTER_SPRITE_SIDE) * 0.5
        var max_sprite_y: float = maxf(0.0, area.size.y - ROSTER_SPRITE_SIDE)
        sprite.position = Vector2(sprite_x, clampf(desired_y, 0.0, max_sprite_y))

        ui["texture"] = sprite
        cards[combatant_id] = ui

        _add_roster_shadow(area, sprite, combatant_id)
        _add_roster_connector(area, card, sprite, enemy, combatant_id)


func _add_roster_shadow(area: Control, sprite: TextureRect, combatant_id: String) -> void:
    var shadow := Polygon2D.new()
    shadow.name = "SpriteShadow_" + combatant_id
    shadow.color = Color(0.04, 0.08, 0.06, 0.24)
    shadow.z_index = 2

    var points := PackedVector2Array()
    var segments: int = 18
    for step: int in range(segments):
        var angle: float = TAU * float(step) / float(segments)
        points.append(Vector2(cos(angle) * 28.0, sin(angle) * 6.0))
    shadow.polygon = points
    shadow.position = sprite.position + Vector2(ROSTER_SPRITE_SIDE * 0.5, ROSTER_SPRITE_SIDE - 5.0)
    area.add_child(shadow)


func _add_roster_connector(
    area: Control,
    card: Control,
    sprite: TextureRect,
    enemy: bool,
    combatant_id: String
) -> void:
    var line := Line2D.new()
    line.name = "CardConnector_" + combatant_id
    line.width = 2.0
    line.default_color = Color("f6edc9b8")
    line.antialiased = true
    line.z_index = 4
    area.add_child(line)
    _update_roster_connector(line, card, sprite, enemy)


func _refresh_cards() -> void:
    # Let inherited battle logic update its compatibility controllers, tooltips,
    # target logic and sprite tinting first. Then render our fixed visual layer.
    super._refresh_cards()
    _ensure_roster_card_styles()

    var active_id: String = str(selected_actor.get("id", "")) if not selected_actor.is_empty() else ""

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value

        var hp: float = float(combatant.get("hp", 0))
        var max_hp: float = maxf(1.0, float(combatant.get("max_hp", 1)))
        var atb: float = clampf(float(combatant.get("atb", 0.0)), 0.0, 100.0)
        var aggro: float = float(combatant.get("aggro", 0.0))
        var max_aggro: float = _max_aggro_for_side(str(combatant.get("side", "")))

        var hp_text: Label = ui.get("hp_text") as Label
        if hp_text != null:
            hp_text.text = "KP %d/%d" % [int(hp), int(max_hp)]

        var aggro_label: Label = ui.get("aggro_label") as Label
        if aggro_label != null:
            aggro_label.text = "AG %.0f" % aggro

        var atb_text: Label = ui.get("atb_text") as Label
        if atb_text != null:
            atb_text.text = "ATB %d%%" % int(round(atb))

        _set_meter_fill(ui.get("hp_fill") as ColorRect, hp / max_hp)
        _set_meter_fill(ui.get("aggro_fill") as ColorRect, aggro / maxf(1.0, max_aggro))
        _set_meter_fill(ui.get("atb_fill") as ColorRect, atb / 100.0)

        var status_line: Label = ui.get("status_line") as Label
        if status_line != null:
            status_line.text = _roster_status_text(combatant, combatant_id == active_id)
            if not bool(combatant.get("alive", false)):
                status_line.add_theme_color_override("font_color", Color("666666"))
            elif combatant_id == active_id:
                status_line.add_theme_color_override("font_color", Color("8a6410"))
            elif _incoming_target_count(combatant) > 0:
                status_line.add_theme_color_override("font_color", Color("a33333"))
            else:
                status_line.add_theme_color_override("font_color", Color("5a4646"))

        var card: PanelContainer = ui.get("card") as PanelContainer
        if card != null:
            if not bool(combatant.get("alive", false)):
                card.add_theme_stylebox_override("panel", _roster_card_fainted)
            elif combatant_id == active_id:
                card.add_theme_stylebox_override("panel", _roster_card_active)
            elif _incoming_target_count(combatant) > 0:
                card.add_theme_stylebox_override("panel", _roster_card_target)
            else:
                card.add_theme_stylebox_override("panel", _roster_card_default)


func _set_meter_fill(fill: ColorRect, ratio: float) -> void:
    if fill == null:
        return
    fill.size = Vector2(
        ROSTER_METER_WIDTH * clampf(ratio, 0.0, 1.0),
        ROSTER_METER_HEIGHT
    )


func _roster_status_text(combatant: Dictionary, active: bool) -> String:
    if not bool(combatant.get("alive", false)):
        return "K.O."

    var pieces: Array[String] = []
    if active:
        pieces.append("▶ ZUG")

    var target_count: int = _incoming_target_count(combatant)
    if target_count > 0:
        pieces.append("🎯×%d" % target_count)

    for token: String in _status_tokens(combatant):
        if token.contains("ZIEL"):
            continue
        var short_token: String = token.replace("AM ZUG", "ZUG")
        if not pieces.has(short_token):
            pieces.append(short_token)
        if pieces.size() >= 2:
            break

    return " · ".join(pieces) if not pieces.is_empty() else ""


func _roster_type_text(types: Array) -> String:
    var names: Array[String] = []
    for type_value: Variant in types:
        var type_id: String = str(type_value)
        if type_id.is_empty():
            continue
        names.append(_type_badge_name(type_id).to_upper())
    return " / ".join(names)


func _update_roster_connector(
    line: Line2D,
    card: Control,
    sprite: TextureRect,
    enemy: bool
) -> void:
    var card_edge: Vector2
    var sprite_edge: Vector2
    if enemy:
        card_edge = card.position + Vector2(card.size.x, card.size.y * 0.5)
        sprite_edge = sprite.position + Vector2(0.0, sprite.size.y * 0.5)
    else:
        card_edge = card.position + Vector2(0.0, card.size.y * 0.5)
        sprite_edge = sprite.position + Vector2(sprite.size.x, sprite.size.y * 0.5)

    var midpoint: Vector2 = (card_edge + sprite_edge) * 0.5
    line.points = PackedVector2Array([
        card_edge,
        Vector2(midpoint.x, card_edge.y),
        Vector2(midpoint.x, sprite_edge.y),
        sprite_edge
    ])


func _ensure_roster_card_styles() -> void:
    if _roster_card_default != null:
        return

    _roster_card_default = _panel(Color("f8f1dcef"), Color("34443d"), 5, 2.0)
    _roster_card_active = _panel(Color("fff4cdef"), Color("e0a52f"), 5, 2.0)
    _roster_card_target = _panel(Color("ffe6e6ef"), Color("cf3434"), 5, 2.0)
    _roster_card_fainted = _panel(Color("e8e8e8d8"), Color("6a6a6a"), 5, 2.0)
    _roster_card_active.set_border_width_all(3)
    _roster_card_target.set_border_width_all(3)
