extends "res://scripts/battle_demo_adaptive_family_ui.gd"

# Fixed presentation standard for every combat team size.
# Card and Pokemon-image dimensions never change with the number of combatants.
# Only vertical placement changes so 1-4 Pokemon stay centered and readable.

const STANDARD_CARD_HEIGHT: float = 52.0
const STANDARD_SPRITE_SIDE: float = 64.0
const STANDARD_CARD_SPRITE_GAP: float = 12.0


func _positions_for_count(count: int) -> Array:
    # These positions are based on the 216px HD battle field. The 52px cards
    # therefore use the exact same dimensions in 1v1, 2v2, 3v3 and 4v4.
    match clampi(count, 1, 4):
        1:
            return [82.0]
        2:
            return [54.0, 110.0]
        3:
            return [28.0, 82.0, 136.0]
        _:
            return [4.0, 57.0, 110.0, 163.0]


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: Control = super._make_card(combatant, enemy)
    card.custom_minimum_size = Vector2(ROSTER_CARD_WIDTH, STANDARD_CARD_HEIGHT)
    card.size = Vector2(ROSTER_CARD_WIDTH, STANDARD_CARD_HEIGHT)
    card.clip_contents = true

    var canvas: Control = card.get_node_or_null("CardCanvas") as Control
    if canvas == null:
        return card

    canvas.custom_minimum_size = Vector2(170.0, 48.0)
    _apply_standard_card_layout(canvas)
    return card


func _apply_standard_card_layout(canvas: Control) -> void:
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
        atb_label.text = "ATB"
        atb_label.add_theme_color_override("font_color", Color("24668f"))
        canvas.add_child(atb_label)

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
        aggro_label.size = Vector2(42.0, 9.0)
        aggro_label.add_theme_font_size_override("font_size", 6)
    if aggro_bar != null:
        aggro_bar.position = Vector2(44.0, 33.0)
        aggro_bar.size = Vector2(104.0, 4.0)

    if atb_label != null:
        atb_label.visible = true
        atb_label.position = Vector2(2.0, 39.0)
        atb_label.size = Vector2(30.0, 9.0)
        atb_label.add_theme_font_size_override("font_size", 6)
    if atb_bar != null:
        atb_bar.position = Vector2(32.0, 43.0)
        atb_bar.size = Vector2(116.0, 5.0)

    if info_button != null:
        info_button.position = Vector2(151.0, 1.0)
        info_button.size = Vector2(18.0, 18.0)
        info_button.custom_minimum_size = Vector2(18.0, 18.0)
        info_button.add_theme_font_size_override("font_size", 7)


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    # Inherited layout builds cards, sprites, shadows and connector lines.
    # Afterwards we enforce one fixed visual size for every team size.
    super._layout_team(area, team, enemy)

    var sprite_size := Vector2(STANDARD_SPRITE_SIDE, STANDARD_SPRITE_SIDE)

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

        # Slight horizontal staggering keeps fixed 64px sprites legible even in
        # 4v4 without ever shrinking them.
        var stagger: float = float(index % 2) * 8.0
        var sprite_x: float
        if enemy:
            sprite_x = card.position.x + card.size.x + STANDARD_CARD_SPRITE_GAP + stagger
        else:
            sprite_x = card.position.x - STANDARD_CARD_SPRITE_GAP - STANDARD_SPRITE_SIDE - stagger

        sprite.position = Vector2(
            sprite_x,
            card.position.y + (card.size.y - STANDARD_SPRITE_SIDE) * 0.5
        )

        var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
        if shadow != null:
            shadow.position = sprite.position + Vector2(STANDARD_SPRITE_SIDE * 0.5, STANDARD_SPRITE_SIDE - 4.0)
            shadow.scale = Vector2(1.18, 1.0)

        var connector: Line2D = area.get_node_or_null("CardConnector_" + combatant_id) as Line2D
        if connector != null:
            _update_roster_connector(connector, card, sprite, enemy)


func _refresh_cards() -> void:
    super._refresh_cards()

    # Keep labels stable as well: no short/long variant based on team size.
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

        var aggro_label: Label = canvas.get_node_or_null("AggroText") as Label
        if aggro_label != null:
            aggro_label.text = "AG %.0f" % float(combatant.get("aggro", 0.0))

        var atb_label: Label = canvas.get_node_or_null("ATBText") as Label
        if atb_label != null:
            atb_label.text = "ATB"
