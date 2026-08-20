extends "res://scripts/battle_demo_type_badges.gd"

# Presentation-only layer for the active combat lab.
# Combat rules stay in the inherited scripts; this layer only improves visuals
# and the action-selection layout.

const DEFAULT_BATTLE_BACKGROUND_PATH: String = "res://assets/battle_backgrounds/meadow_placeholder.svg"
const CARD_UI_WIDTH: float = 176.0
const SPRITE_UI_SIZE: Vector2 = Vector2(50.0, 50.0)
const ENEMY_CARD_X: float = 8.0
const PLAYER_CARD_X: float = 448.0
const ENEMY_SPRITE_X: float = 196.0
const PLAYER_SPRITE_X: float = 386.0
const FORMATION_INSET_STEP: float = 7.0
const ACTION_BUTTON_MIN_SIZE: Vector2 = Vector2(176.0, 34.0)

var battle_background_path: String = DEFAULT_BATTLE_BACKGROUND_PATH
var _battle_background_rect: TextureRect = null


func _build_battle(root: Control) -> void:
    super._build_battle(root)

    var area: Control = battle_panel.get_node_or_null("BattleArea") as Control
    if area != null:
        _install_battle_background(area)

    _polish_action_grid()


func set_battle_background(path: String) -> void:
    if path.is_empty() or not ResourceLoader.exists(path):
        push_warning("Kampfhintergrund nicht gefunden: " + path)
        return

    battle_background_path = path
    if _battle_background_rect != null:
        _battle_background_rect.texture = load(battle_background_path) as Texture2D


func _install_battle_background(area: Control) -> void:
    _battle_background_rect = TextureRect.new()
    _battle_background_rect.name = "BattleBackground"
    _battle_background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _battle_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _battle_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _battle_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _battle_background_rect.z_index = -10
    _battle_background_rect.texture = load(battle_background_path) as Texture2D
    area.add_child(_battle_background_rect)
    area.move_child(_battle_background_rect, 0)


func _polish_action_grid() -> void:
    if action_grid == null:
        return

    action_grid.columns = 3
    action_grid.add_theme_constant_override("h_separation", 4)
    action_grid.add_theme_constant_override("v_separation", 4)

    var action_scroll: ScrollContainer = action_grid.get_parent() as ScrollContainer
    if action_scroll != null:
        action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        action_scroll.custom_minimum_size = Vector2(0.0, 72.0)


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    var positions: Array = _positions_for_count(team.size())

    for index: int in range(team.size()):
        var combatant_value: Variant = team[index]
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value

        var card: Control = _make_card(combatant, enemy)
        card.custom_minimum_size.x = CARD_UI_WIDTH
        card.size.x = CARD_UI_WIDTH
        card.position = Vector2(
            ENEMY_CARD_X if enemy else PLAYER_CARD_X,
            float(positions[index])
        )
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
        sprite.custom_minimum_size = SPRITE_UI_SIZE
        sprite.size = SPRITE_UI_SIZE
        sprite.z_index = 10
        sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

        # Top rows are moved a little farther toward the center. With several
        # Pokemon this creates a subtle inverted-V formation without exaggerating it.
        var inward: float = float(maxi(0, team.size() - 1 - index)) * FORMATION_INSET_STEP
        var sprite_x: float = ENEMY_SPRITE_X + inward if enemy else PLAYER_SPRITE_X - inward
        sprite.position = Vector2(
            sprite_x,
            float(positions[index]) + (card.size.y - SPRITE_UI_SIZE.y) * 0.5
        )

        ui["texture"] = sprite
        cards[combatant_id] = ui

        _add_sprite_shadow(area, sprite, combatant_id)
        _add_card_connector(area, card, sprite, enemy, combatant_id)


func _add_sprite_shadow(area: Control, sprite: TextureRect, combatant_id: String) -> void:
    var shadow: Polygon2D = Polygon2D.new()
    shadow.name = "SpriteShadow_" + combatant_id
    shadow.color = Color(0.04, 0.08, 0.06, 0.24)
    shadow.z_index = 2

    var points: PackedVector2Array = PackedVector2Array()
    var segments: int = 18
    for step: int in range(segments):
        var angle: float = TAU * float(step) / float(segments)
        points.append(Vector2(cos(angle) * 22.0, sin(angle) * 5.0))
    shadow.polygon = points
    shadow.position = sprite.position + Vector2(SPRITE_UI_SIZE.x * 0.5, SPRITE_UI_SIZE.y - 4.0)
    area.add_child(shadow)


func _add_card_connector(
    area: Control,
    card: Control,
    sprite: TextureRect,
    enemy: bool,
    combatant_id: String
) -> void:
    var line: Line2D = Line2D.new()
    line.name = "CardConnector_" + combatant_id
    line.width = 2.0
    line.default_color = Color("f6edc9b8")
    line.antialiased = true
    line.z_index = 4

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
    area.add_child(line)


func _combatant_card(combatant: Dictionary) -> Control:
    # Move-emoji animations inherited from battle_demo_move_emojis.gd should
    # travel between the actual Pokemon images, not between their stat cards.
    var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
    if ui_value is Dictionary:
        var ui: Dictionary = ui_value
        var sprite: Control = ui.get("texture") as Control
        if sprite != null and sprite.get_parent() != null:
            return sprite
    return super._combatant_card(combatant)


func _prompt_player(actor: Dictionary) -> void:
    # Keep all inherited selection logic (touch behavior, opening-only filtering,
    # previews, AP rules) and only restyle the finished button set.
    super._prompt_player(actor)
    _polish_action_buttons(actor)


func _show_opening_choice(actor: Dictionary, opening_moves: Array[String]) -> void:
    super._show_opening_choice(actor, opening_moves)
    _polish_action_buttons(actor)


func _polish_action_buttons(actor: Dictionary) -> void:
    if action_grid == null:
        return

    var moves_all_value: Variant = data.get("moves", {})
    var moves_all: Dictionary = moves_all_value if moves_all_value is Dictionary else {}
    var actor_moves_value: Variant = actor.get("moves", [])
    var actor_moves: Array = actor_moves_value if actor_moves_value is Array else []

    for child: Node in action_grid.get_children():
        if not (child is Button):
            continue

        var button: Button = child as Button
        var utility: bool = button.text.contains("Warten") or button.text.contains("Eröffnungsaktion")
        var type_id: String = "typeless"

        if not utility:
            for move_value: Variant in actor_moves:
                var move_id: String = str(move_value)
                var move_value_data: Variant = moves_all.get(move_id, {})
                if not (move_value_data is Dictionary):
                    continue
                var move: Dictionary = move_value_data
                if button.text.contains(str(move.get("name", move_id))):
                    type_id = str(move.get("type", "normal"))
                    break

        _style_action_button(button, type_id, utility)


func _style_action_button(button: Button, type_id: String, utility: bool) -> void:
    button.custom_minimum_size = ACTION_BUTTON_MIN_SIZE
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.clip_text = true
    button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    button.add_theme_font_size_override("font_size", 10)
    button.add_theme_color_override("font_color", Color("fffbed"))
    button.add_theme_color_override("font_hover_color", Color("ffffff"))
    button.add_theme_color_override("font_pressed_color", Color("ffffff"))

    var accent: Color = Color("d8c65e") if utility else _type_badge_color(type_id)
    button.add_theme_stylebox_override("normal", _action_style(accent, 0.74))
    button.add_theme_stylebox_override("hover", _action_style(accent, 0.60))
    button.add_theme_stylebox_override("pressed", _action_style(accent, 0.48))
    button.add_theme_stylebox_override("focus", _action_style(accent, 0.56))


func _action_style(accent: Color, darkness: float) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    var bg: Color = accent.darkened(darkness)
    bg.a = 0.96
    style.bg_color = bg
    style.border_color = accent
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 4.0
    style.content_margin_bottom = 4.0
    return style
