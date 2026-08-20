extends "res://scripts/battle_demo_family_lab.gd"

# Adaptive battle-card layout.
# The readable-card polish is useful for 1-3 Pokemon, but four 54px cards do
# not fit into the 178px battle area. Keep the roomy layout when possible and
# switch only 4-Pokemon teams to a compact single-meta-row layout.

const COMPACT_TEAM_SIZE: int = 4
const COMPACT_CARD_HEIGHT: float = 43.0
const COMPACT_SPRITE_SIZE: Vector2 = Vector2(42.0, 42.0)

var _compact_card_default: StyleBoxFlat
var _compact_card_active: StyleBoxFlat
var _compact_card_target: StyleBoxFlat


func _positions_for_count(count: int) -> Array:
    match count:
        1:
            return [62.0]
        2:
            return [31.0, 93.0]
        3:
            return [5.0, 62.0, 119.0]
        _:
            # 4 x 43px plus three 1px gaps = 175px. This fits cleanly into
            # the inherited 178px battle area without clipping or overlap.
            return [1.0, 45.0, 89.0, 133.0]


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: Control = super._make_card(combatant, enemy)
    var team_size: int = enemy_team.size() if enemy else player_team.size()
    var compact: bool = team_size >= COMPACT_TEAM_SIZE

    var combatant_id: String = str(combatant.get("id", ""))
    var ui_value: Variant = cards.get(combatant_id, {})
    if not (ui_value is Dictionary):
        return card
    var ui: Dictionary = ui_value
    ui["compact_card"] = compact

    if not compact:
        cards[combatant_id] = ui
        return card

    card.custom_minimum_size.y = COMPACT_CARD_HEIGHT
    card.size.y = COMPACT_CARD_HEIGHT

    var hp_bar: ProgressBar = ui.get("hp") as ProgressBar
    var content: VBoxContainer = hp_bar.get_parent() as VBoxContainer if hp_bar != null else null
    if content != null:
        var name_label: Label = content.get_child(0) as Label if content.get_child_count() > 0 else null
        if name_label != null:
            name_label.add_theme_font_size_override("font_size", 7)

        var type_row: HBoxContainer = content.get_node_or_null("TypeBadges") as HBoxContainer
        if type_row != null:
            type_row.custom_minimum_size.y = 7.0
            type_row.add_theme_constant_override("separation", 1)
            for badge_value: Variant in type_row.get_children():
                if badge_value is PanelContainer and (badge_value as PanelContainer).get_child_count() > 0:
                    var badge_label: Label = (badge_value as PanelContainer).get_child(0) as Label
                    if badge_label != null:
                        badge_label.add_theme_font_size_override("font_size", 5)

            # Reuse the status-chip container, but place it in the same row as
            # the type badges instead of consuming a whole extra line.
            var chip_row: HBoxContainer = ui.get("status_chips") as HBoxContainer
            if chip_row != null and chip_row.get_parent() == content:
                content.remove_child(chip_row)
                type_row.add_child(chip_row)
                chip_row.custom_minimum_size.y = 7.0
                chip_row.add_theme_constant_override("separation", 1)
                chip_row.set_meta("compact", true)

    if hp_bar != null:
        hp_bar.custom_minimum_size.y = 6.0

    var atb_bar: ProgressBar = ui.get("atb") as ProgressBar
    if atb_bar != null:
        atb_bar.custom_minimum_size.y = 3.0

    var aggro_bar: ProgressBar = ui.get("aggro") as ProgressBar
    if aggro_bar != null:
        aggro_bar.custom_minimum_size.y = 3.0

    var aggro_label: Label = ui.get("aggro_label") as Label
    if aggro_label != null:
        aggro_label.custom_minimum_size = Vector2(37.0, 5.0)
        aggro_label.add_theme_font_size_override("font_size", 5)

    var status_label: Label = ui.get("status") as Label
    if status_label != null:
        status_label.visible = false
        status_label.custom_minimum_size.y = 0.0

    var info_button: Button = ui.get("info") as Button
    if info_button != null:
        info_button.custom_minimum_size = Vector2(20.0, 26.0)
        info_button.add_theme_font_size_override("font_size", 8)

    cards[combatant_id] = ui
    return card


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    super._layout_team(area, team, enemy)
    if team.size() < COMPACT_TEAM_SIZE:
        return

    # The normal 50px sprites would slightly collide at the compact 4-slot
    # spacing. Shrink only this dense formation and keep their centers aligned.
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
        sprite.custom_minimum_size = COMPACT_SPRITE_SIZE
        sprite.size = COMPACT_SPRITE_SIZE
        sprite.position = old_center - COMPACT_SPRITE_SIZE * 0.5
        sprite.position.y = card.position.y + (card.size.y - COMPACT_SPRITE_SIZE.y) * 0.5

        var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
        if shadow != null:
            shadow.position = sprite.position + Vector2(sprite.size.x * 0.5, sprite.size.y - 4.0)

        var connector: Line2D = area.get_node_or_null("CardConnector_" + combatant_id) as Line2D
        if connector != null:
            _update_compact_connector(connector, card, sprite, enemy)


func _update_compact_connector(
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


func _refresh_cards() -> void:
    super._refresh_cards()
    _ensure_compact_card_styles()

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
        if not bool(ui.get("compact_card", false)):
            continue

        var chip_row: HBoxContainer = ui.get("status_chips") as HBoxContainer
        if chip_row != null:
            var compact_tokens: Array[String] = []
            for token: String in _status_tokens(combatant):
                # Active/target state already has a strong card border and
                # sprite tint. Reserve the tiny chip space for actual effects.
                if token.contains("ZIEL"):
                    continue
                compact_tokens.append(token)
            _refresh_compact_status_chips(chip_row, compact_tokens)

        var card: PanelContainer = ui.get("card") as PanelContainer
        if card != null:
            var target_count: int = _incoming_target_count(combatant)
            if combatant_id == active_id:
                card.add_theme_stylebox_override("panel", _compact_card_active)
            elif target_count > 0:
                card.add_theme_stylebox_override("panel", _compact_card_target)
            else:
                card.add_theme_stylebox_override("panel", _compact_card_default)


func _refresh_compact_status_chips(row: HBoxContainer, tokens: Array[String]) -> void:
    for child: Node in row.get_children():
        child.queue_free()

    if tokens.is_empty():
        return

    row.add_child(_make_compact_status_chip(tokens[0]))
    if tokens.size() > 1:
        row.add_child(_make_compact_status_chip("+%d" % (tokens.size() - 1)))


func _make_compact_status_chip(text: String) -> Control:
    var chip := PanelContainer.new()
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style := StyleBoxFlat.new()
    style.bg_color = _status_chip_color(text)
    style.set_corner_radius_all(2)
    style.content_margin_left = 2.0
    style.content_margin_right = 2.0
    style.content_margin_top = 0.0
    style.content_margin_bottom = 0.0
    chip.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 5)
    label.add_theme_color_override("font_color", Color("ffffff"))
    label.add_theme_color_override("font_outline_color", Color("17211f"))
    label.add_theme_constant_override("outline_size", 1)
    chip.add_child(label)
    return chip


func _ensure_compact_card_styles() -> void:
    if _compact_card_default != null:
        return

    _compact_card_default = _panel(Color("f8f1dce8"), Color("34443d"), 5, 2.0)
    _compact_card_active = _panel(Color("fff4cdef"), Color("f2b84b"), 5, 2.0)
    _compact_card_target = _panel(Color("ffe6e6ef"), Color("dc3f3f"), 5, 2.0)
    _compact_card_active.set_border_width_all(3)
    _compact_card_target.set_border_width_all(3)
