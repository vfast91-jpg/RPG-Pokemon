extends "res://scripts/battle_demo_family_lab.gd"

# Fixed tactical roster cards for the combat lab.
#
# The previous adaptive version still inherited VBox/HBox minimum sizes from the
# older readable-card stack. Setting card.size.y therefore could not actually
# make a dense card smaller: its children silently forced the panel back open
# and 4-Pokemon teams overlapped.
#
# This layer deliberately does NOT reuse that container hierarchy. Every roster
# card is a fixed-height PanelContainer with one plain Control canvas and
# explicitly positioned children. Child minimum sizes can no longer change the
# card height, so 1-4 Pokemon always fit in the 178px battle field.

const ROSTER_CARD_HEIGHT: float = 43.0
const ROSTER_CARD_WIDTH: float = 176.0
const ROSTER_INFO_SIZE: Vector2 = Vector2(18.0, 18.0)

var _roster_card_default: StyleBoxFlat
var _roster_card_active: StyleBoxFlat
var _roster_card_target: StyleBoxFlat
var _roster_card_fainted: StyleBoxFlat


func _positions_for_count(count: int) -> Array:
    match count:
        1:
            return [67.0]
        2:
            return [42.0, 93.0]
        3:
            return [18.0, 68.0, 118.0]
        _:
            # Four fixed 43px rows plus 1px gaps = 175px.
            return [1.0, 45.0, 89.0, 133.0]


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    _ensure_roster_card_styles()

    var card := PanelContainer.new()
    card.name = "RosterCard_" + str(combatant.get("id", ""))
    card.custom_minimum_size = Vector2(ROSTER_CARD_WIDTH, ROSTER_CARD_HEIGHT)
    card.size = Vector2(ROSTER_CARD_WIDTH, ROSTER_CARD_HEIGHT)
    card.clip_contents = true
    card.add_theme_stylebox_override("panel", _roster_card_default)

    # Plain Control is intentional. Containers derive their minimum size from
    # children; this canvas does not, which makes the 43px card height binding.
    var canvas := Control.new()
    canvas.name = "CardCanvas"
    canvas.mouse_filter = Control.MOUSE_FILTER_PASS
    canvas.custom_minimum_size = Vector2(170.0, 37.0)
    card.add_child(canvas)

    var name_label := Label.new()
    name_label.name = "Name"
    name_label.text = str(combatant.get("name", "Pokemon")) + " Lv." + str(combatant.get("level", 1))
    name_label.position = Vector2(1.0, -1.0)
    name_label.size = Vector2(112.0, 11.0)
    name_label.clip_text = true
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.add_theme_font_size_override("font_size", 8)
    name_label.add_theme_color_override("font_color", Color("26322e"))
    canvas.add_child(name_label)

    var type_label := Label.new()
    type_label.name = "Types"
    type_label.position = Vector2(1.0, 8.0)
    type_label.size = Vector2(86.0, 9.0)
    type_label.clip_text = true
    type_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    type_label.add_theme_font_size_override("font_size", 6)
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
    status_line.position = Vector2(87.0, 8.0)
    status_line.size = Vector2(61.0, 9.0)
    status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status_line.clip_text = true
    status_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    status_line.add_theme_font_size_override("font_size", 6)
    status_line.add_theme_color_override("font_color", Color("5a4646"))
    canvas.add_child(status_line)

    var hp_bar := ProgressBar.new()
    hp_bar.name = "HP"
    hp_bar.position = Vector2(1.0, 17.0)
    hp_bar.size = Vector2(147.0, 8.0)
    hp_bar.max_value = float(maxi(1, int(combatant.get("max_hp", 1))))
    hp_bar.value = float(combatant.get("hp", 0))
    hp_bar.show_percentage = false
    hp_bar.add_theme_stylebox_override("background", _bar(Color("c8c8c2"), 2))
    hp_bar.add_theme_stylebox_override("fill", _bar(Color("55b85a"), 2))
    canvas.add_child(hp_bar)

    var hp_text := Label.new()
    hp_text.name = "HPText"
    hp_text.position = Vector2(1.0, 15.0)
    hp_text.size = Vector2(147.0, 11.0)
    hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_text.add_theme_font_size_override("font_size", 6)
    hp_text.add_theme_color_override("font_color", Color("25332e"))
    hp_text.add_theme_color_override("font_outline_color", Color("ffffffcc"))
    hp_text.add_theme_constant_override("outline_size", 1)
    canvas.add_child(hp_text)

    var aggro_label := Label.new()
    aggro_label.name = "AggroText"
    aggro_label.position = Vector2(1.0, 25.0)
    aggro_label.size = Vector2(39.0, 8.0)
    aggro_label.add_theme_font_size_override("font_size", 6)
    aggro_label.add_theme_color_override("font_color", Color("7b2d2d"))
    canvas.add_child(aggro_label)

    var aggro_bar := ProgressBar.new()
    aggro_bar.name = "Aggro"
    aggro_bar.position = Vector2(40.0, 28.0)
    aggro_bar.size = Vector2(108.0, 4.0)
    aggro_bar.max_value = 100.0
    aggro_bar.show_percentage = false
    aggro_bar.add_theme_stylebox_override("background", _bar(Color("d8b8b5"), 2))
    aggro_bar.add_theme_stylebox_override("fill", _bar(Color("d94c4c"), 2))
    canvas.add_child(aggro_bar)

    var atb_bar := ProgressBar.new()
    atb_bar.name = "Action"
    atb_bar.position = Vector2(1.0, 34.0)
    atb_bar.size = Vector2(147.0, 4.0)
    atb_bar.max_value = 100.0
    atb_bar.value = float(combatant.get("atb", 0.0))
    atb_bar.show_percentage = false
    atb_bar.add_theme_stylebox_override("background", _bar(Color("b5b5aa"), 2))
    atb_bar.add_theme_stylebox_override("fill", _bar(Color("42aef5"), 2))
    canvas.add_child(atb_bar)

    # A small corner button replaces the old full-height dark info column.
    var info_button := Button.new()
    info_button.name = "Info"
    info_button.text = "i"
    info_button.position = Vector2(151.0, 1.0)
    info_button.size = ROSTER_INFO_SIZE
    info_button.custom_minimum_size = ROSTER_INFO_SIZE
    info_button.focus_mode = Control.FOCUS_NONE
    info_button.add_theme_font_size_override("font_size", 7)
    info_button.tooltip_text = "Pokemon-Details anzeigen"
    info_button.pressed.connect(_show_info.bind(combatant))
    canvas.add_child(info_button)

    # The battle-field presentation layer reparents this TextureRect out of the
    # card and places it in the center formation. Because canvas is not a
    # Container, the temporary child can never enlarge the card.
    var texture_box := TextureRect.new()
    texture_box.name = "BattleTexture"
    texture_box.position = Vector2(-64.0, -64.0)
    texture_box.size = Vector2(36.0, 36.0)
    texture_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_box.flip_h = enemy
    texture_box.texture = _species_texture(str(combatant.get("name", "")))
    canvas.add_child(texture_box)

    # Keep a hidden compatibility label because the inherited refresh stack
    # writes its legacy status string. It has no layout influence here.
    var legacy_status := Label.new()
    legacy_status.visible = false
    canvas.add_child(legacy_status)

    var combatant_id: String = str(combatant.get("id", ""))
    cards[combatant_id] = {
        "card": card,
        "texture": texture_box,
        "hp": hp_bar,
        "hp_text": hp_text,
        "atb": atb_bar,
        "aggro": aggro_bar,
        "aggro_label": aggro_label,
        "status": legacy_status,
        "status_line": status_line,
        "info": info_button
    }
    return card


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    # Keep the inherited battlefield composition (side positions, shadows,
    # connectors and sprite reparenting), but feed it the fixed roster cards.
    super._layout_team(area, team, enemy)

    var sprite_size_value: float = 50.0
    match team.size():
        1:
            sprite_size_value = 54.0
        2:
            sprite_size_value = 50.0
        3:
            sprite_size_value = 44.0
        _:
            sprite_size_value = 38.0
    var sprite_size := Vector2(sprite_size_value, sprite_size_value)

    for combatant_value: Variant in team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var card: Control = ui.get("card") as Control
        var sprite: TextureRect = ui.get("texture") as TextureRect
        if card == null or sprite == null:
            continue

        var old_center: Vector2 = sprite.position + sprite.size * 0.5
        sprite.custom_minimum_size = sprite_size
        sprite.size = sprite_size
        sprite.position = old_center - sprite_size * 0.5
        sprite.position.y = card.position.y + (card.size.y - sprite_size.y) * 0.5

        var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
        if shadow != null:
            shadow.position = sprite.position + Vector2(sprite.size.x * 0.5, sprite.size.y - 4.0)

        var connector: Line2D = area.get_node_or_null("CardConnector_" + combatant_id) as Line2D
        if connector != null:
            _update_roster_connector(connector, card, sprite, enemy)


func _refresh_cards() -> void:
    # Inherited battle logic updates values, tooltips and sprite tinting first.
    # We then repaint only the presentation that belongs to this roster design.
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

        var hp_text: Label = ui.get("hp_text") as Label
        if hp_text != null:
            hp_text.text = "KP %d/%d" % [int(combatant.get("hp", 0)), int(combatant.get("max_hp", 0))]

        var aggro_label: Label = ui.get("aggro_label") as Label
        if aggro_label != null:
            aggro_label.text = "AG %.0f" % float(combatant.get("aggro", 0.0))

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
        var short_token: String = token
        short_token = short_token.replace("AM ZUG", "ZUG")
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

    _roster_card_default = _panel(Color("f8f1dce8"), Color("34443d"), 5, 2.0)
    _roster_card_active = _panel(Color("fff4cdef"), Color("e0a52f"), 5, 2.0)
    _roster_card_target = _panel(Color("ffe6e6ef"), Color("cf3434"), 5, 2.0)
    _roster_card_fainted = _panel(Color("e8e8e8c8"), Color("6a6a6a"), 5, 2.0)
    _roster_card_active.set_border_width_all(3)
    _roster_card_target.set_border_width_all(3)
