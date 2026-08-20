extends "res://scripts/battle_demo_adaptive_family_ui.gd"

# Presentation-only readability pass for the combat roster.
#
# The previous fixed 43px card solved 4-vs-4 overlap, but it made every battle
# use the same dense layout. That was especially wasteful in 1-vs-1/2-vs-2 and
# also forced the Pokemon images down to 38-54px. This layer keeps the safe
# compact 4-Pokemon layout while giving smaller teams substantially more room.

var _readable_team_count: int = 1


func _positions_for_count(count: int) -> Array:
    match clampi(count, 1, 4):
        1:
            return [52.0]
        2:
            return [21.0, 93.0]
        3:
            return [5.0, 63.0, 121.0]
        _:
            return [2.0, 46.0, 90.0, 134.0]


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    _readable_team_count = clampi(team.size(), 1, 4)

    # Build the inherited tactical cards, sprites, shadows and connectors first.
    # _make_card() below is dynamically used by that inherited layout pass.
    super._layout_team(area, team, enemy)

    var sprite_side: float = _sprite_side_for_count(_readable_team_count)
    var sprite_size := Vector2(sprite_side, sprite_side)

    for index: int in range(team.size()):
        var combatant_value: Variant = team[index]
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

        sprite.custom_minimum_size = sprite_size
        sprite.size = sprite_size

        # Keep a clear gap between the card and the Pokemon. Larger Pokemon grow
        # toward the middle of the battlefield instead of covering their card.
        var inward: float = float(maxi(0, team.size() - 1 - index)) * 6.0
        var gap: float = 12.0
        var sprite_x: float
        if enemy:
            sprite_x = card.position.x + card.size.x + gap + inward
        else:
            sprite_x = card.position.x - gap - sprite_side - inward

        sprite.position = Vector2(
            sprite_x,
            card.position.y + (card.size.y - sprite_side) * 0.5
        )

        var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
        if shadow != null:
            shadow.position = sprite.position + Vector2(sprite_side * 0.5, sprite_side - 4.0)
            shadow.scale = Vector2(
                maxf(0.9, sprite_side / 50.0),
                maxf(0.9, sprite_side / 72.0)
            )

        var connector: Line2D = area.get_node_or_null("CardConnector_" + combatant_id) as Line2D
        if connector != null:
            _update_roster_connector(connector, card, sprite, enemy)


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: Control = super._make_card(combatant, enemy)
    var count: int = clampi(_readable_team_count, 1, 4)
    var card_height: float = _card_height_for_count(count)

    card.custom_minimum_size = Vector2(ROSTER_CARD_WIDTH, card_height)
    card.size = Vector2(ROSTER_CARD_WIDTH, card_height)
    card.clip_contents = true

    var canvas: Control = card.get_node_or_null("CardCanvas") as Control
    if canvas == null:
        return card

    canvas.custom_minimum_size = Vector2(170.0, maxf(37.0, card_height - 4.0))
    _layout_card_contents(canvas, count)
    return card


func _layout_card_contents(canvas: Control, count: int) -> void:
    var name_label: Label = canvas.get_node_or_null("Name") as Label
    var type_label: Label = canvas.get_node_or_null("Types") as Label
    var status_line: Label = canvas.get_node_or_null("State") as Label
    var hp_bar: ProgressBar = canvas.get_node_or_null("HP") as ProgressBar
    var hp_text: Label = canvas.get_node_or_null("HPText") as Label
    var aggro_label: Label = canvas.get_node_or_null("AggroText") as Label
    var aggro_bar: ProgressBar = canvas.get_node_or_null("Aggro") as ProgressBar
    var atb_bar: ProgressBar = canvas.get_node_or_null("Action") as ProgressBar
    var info_button: Button = canvas.get_node_or_null("Info") as Button

    var atb_label: Label = canvas.get_node_or_null("ATBText") as Label
    if atb_label == null:
        atb_label = Label.new()
        atb_label.name = "ATBText"
        atb_label.add_theme_color_override("font_color", Color("24668f"))
        canvas.add_child(atb_label)

    match count:
        1:
            _apply_large_card_layout(
                name_label, type_label, status_line, hp_bar, hp_text,
                aggro_label, aggro_bar, atb_label, atb_bar, info_button, true
            )
        2:
            _apply_large_card_layout(
                name_label, type_label, status_line, hp_bar, hp_text,
                aggro_label, aggro_bar, atb_label, atb_bar, info_button, false
            )
        3:
            _apply_medium_card_layout(
                name_label, type_label, status_line, hp_bar, hp_text,
                aggro_label, aggro_bar, atb_label, atb_bar, info_button
            )
        _:
            _apply_compact_card_layout(
                name_label, type_label, status_line, hp_bar, hp_text,
                aggro_label, aggro_bar, atb_label, atb_bar, info_button
            )


func _apply_large_card_layout(
    name_label: Label,
    type_label: Label,
    status_line: Label,
    hp_bar: ProgressBar,
    hp_text: Label,
    aggro_label: Label,
    aggro_bar: ProgressBar,
    atb_label: Label,
    atb_bar: ProgressBar,
    info_button: Button,
    extra_room: bool
) -> void:
    var lower_shift: float = 5.0 if extra_room else 0.0

    if name_label != null:
        name_label.position = Vector2(3.0, 1.0)
        name_label.size = Vector2(116.0, 14.0)
        name_label.add_theme_font_size_override("font_size", 11 if extra_room else 10)

    if type_label != null:
        type_label.position = Vector2(3.0, 14.0)
        type_label.size = Vector2(82.0, 10.0)
        type_label.add_theme_font_size_override("font_size", 8 if extra_room else 7)

    if status_line != null:
        status_line.position = Vector2(84.0, 14.0)
        status_line.size = Vector2(64.0, 10.0)
        status_line.add_theme_font_size_override("font_size", 8 if extra_room else 7)

    if hp_bar != null:
        hp_bar.position = Vector2(3.0, 27.0 + lower_shift)
        hp_bar.size = Vector2(145.0, 10.0)
    if hp_text != null:
        hp_text.position = Vector2(3.0, 25.0 + lower_shift)
        hp_text.size = Vector2(145.0, 14.0)
        hp_text.add_theme_font_size_override("font_size", 8)

    if aggro_label != null:
        aggro_label.position = Vector2(3.0, 40.0 + lower_shift)
        aggro_label.size = Vector2(49.0, 10.0)
        aggro_label.add_theme_font_size_override("font_size", 7)
    if aggro_bar != null:
        aggro_bar.position = Vector2(54.0, 44.0 + lower_shift)
        aggro_bar.size = Vector2(94.0, 5.0)

    if atb_label != null:
        atb_label.visible = true
        atb_label.position = Vector2(3.0, 51.0 + lower_shift)
        atb_label.size = Vector2(49.0, 10.0)
        atb_label.add_theme_font_size_override("font_size", 7)
    if atb_bar != null:
        atb_bar.position = Vector2(54.0, 55.0 + lower_shift)
        atb_bar.size = Vector2(94.0, 6.0)

    if info_button != null:
        info_button.position = Vector2(151.0, 2.0)
        info_button.size = Vector2(20.0, 20.0)
        info_button.custom_minimum_size = Vector2(20.0, 20.0)
        info_button.add_theme_font_size_override("font_size", 8)


func _apply_medium_card_layout(
    name_label: Label,
    type_label: Label,
    status_line: Label,
    hp_bar: ProgressBar,
    hp_text: Label,
    aggro_label: Label,
    aggro_bar: ProgressBar,
    atb_label: Label,
    atb_bar: ProgressBar,
    info_button: Button
) -> void:
    if name_label != null:
        name_label.position = Vector2(2.0, 0.0)
        name_label.size = Vector2(116.0, 12.0)
        name_label.add_theme_font_size_override("font_size", 9)
    if type_label != null:
        type_label.position = Vector2(2.0, 10.0)
        type_label.size = Vector2(82.0, 9.0)
        type_label.add_theme_font_size_override("font_size", 7)
    if status_line != null:
        status_line.position = Vector2(84.0, 10.0)
        status_line.size = Vector2(64.0, 9.0)
        status_line.add_theme_font_size_override("font_size", 7)

    if hp_bar != null:
        hp_bar.position = Vector2(2.0, 20.0)
        hp_bar.size = Vector2(146.0, 9.0)
    if hp_text != null:
        hp_text.position = Vector2(2.0, 18.0)
        hp_text.size = Vector2(146.0, 13.0)
        hp_text.add_theme_font_size_override("font_size", 7)

    if aggro_label != null:
        aggro_label.position = Vector2(2.0, 30.0)
        aggro_label.size = Vector2(40.0, 9.0)
        aggro_label.add_theme_font_size_override("font_size", 6)
    if aggro_bar != null:
        aggro_bar.position = Vector2(43.0, 33.0)
        aggro_bar.size = Vector2(105.0, 4.0)

    if atb_label != null:
        atb_label.visible = true
        atb_label.position = Vector2(2.0, 38.0)
        atb_label.size = Vector2(30.0, 9.0)
        atb_label.add_theme_font_size_override("font_size", 6)
    if atb_bar != null:
        atb_bar.position = Vector2(32.0, 42.0)
        atb_bar.size = Vector2(116.0, 5.0)

    if info_button != null:
        info_button.position = Vector2(151.0, 1.0)
        info_button.size = Vector2(18.0, 18.0)
        info_button.custom_minimum_size = Vector2(18.0, 18.0)
        info_button.add_theme_font_size_override("font_size", 7)


func _apply_compact_card_layout(
    name_label: Label,
    type_label: Label,
    status_line: Label,
    hp_bar: ProgressBar,
    hp_text: Label,
    aggro_label: Label,
    aggro_bar: ProgressBar,
    atb_label: Label,
    atb_bar: ProgressBar,
    info_button: Button
) -> void:
    if name_label != null:
        name_label.position = Vector2(1.0, -1.0)
        name_label.size = Vector2(112.0, 11.0)
        name_label.add_theme_font_size_override("font_size", 8)
    if type_label != null:
        type_label.position = Vector2(1.0, 8.0)
        type_label.size = Vector2(84.0, 9.0)
        type_label.add_theme_font_size_override("font_size", 6)
    if status_line != null:
        status_line.position = Vector2(86.0, 8.0)
        status_line.size = Vector2(62.0, 9.0)
        status_line.add_theme_font_size_override("font_size", 6)

    if hp_bar != null:
        hp_bar.position = Vector2(1.0, 17.0)
        hp_bar.size = Vector2(147.0, 8.0)
    if hp_text != null:
        hp_text.position = Vector2(1.0, 15.0)
        hp_text.size = Vector2(147.0, 11.0)
        hp_text.add_theme_font_size_override("font_size", 6)

    if aggro_label != null:
        aggro_label.position = Vector2(1.0, 25.0)
        aggro_label.size = Vector2(39.0, 8.0)
        aggro_label.add_theme_font_size_override("font_size", 6)
    if aggro_bar != null:
        aggro_bar.position = Vector2(40.0, 28.0)
        aggro_bar.size = Vector2(108.0, 4.0)

    if atb_label != null:
        atb_label.visible = false
    if atb_bar != null:
        atb_bar.position = Vector2(1.0, 34.0)
        atb_bar.size = Vector2(147.0, 4.0)

    if info_button != null:
        info_button.position = Vector2(151.0, 1.0)
        info_button.size = Vector2(18.0, 18.0)
        info_button.custom_minimum_size = Vector2(18.0, 18.0)
        info_button.add_theme_font_size_override("font_size", 7)


func _refresh_cards() -> void:
    super._refresh_cards()

    var count_by_side: Dictionary = {
        "player": clampi(player_team.size(), 1, 4),
        "enemy": clampi(enemy_team.size(), 1, 4)
    }

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var card: Control = ui.get("card") as Control
        if card == null:
            continue

        var canvas: Control = card.get_node_or_null("CardCanvas") as Control
        if canvas == null:
            continue

        var side: String = str(combatant.get("side", "player"))
        var count: int = int(count_by_side.get(side, 1))

        var aggro_label: Label = canvas.get_node_or_null("AggroText") as Label
        if aggro_label != null:
            if count <= 2:
                aggro_label.text = "Aggro %.0f" % float(combatant.get("aggro", 0.0))
            else:
                aggro_label.text = "AG %.0f" % float(combatant.get("aggro", 0.0))

        var atb_label: Label = canvas.get_node_or_null("ATBText") as Label
        if atb_label != null and atb_label.visible:
            if count <= 2:
                atb_label.text = "ATB %.0f%%" % float(combatant.get("atb", 0.0))
            else:
                atb_label.text = "ATB"


func _card_height_for_count(count: int) -> float:
    match clampi(count, 1, 4):
        1:
            return 74.0
        2:
            return 64.0
        3:
            return 52.0
        _:
            return 42.0


func _sprite_side_for_count(count: int) -> float:
    match clampi(count, 1, 4):
        1:
            return 102.0
        2:
            return 80.0
        3:
            return 58.0
        _:
            return 48.0
