extends "res://scripts/battle_demo_boss_residual_hp_fix_v1.gd"

const SpotlightIndicatorRules = preload("res://scripts/battle/spotlight_indicator_rules.gd")

const SPOTLIGHT_BADGE_SIZE: Vector2 = Vector2(64.0, 13.0)
const SPOTLIGHT_HALO_POINTS: int = 32

var _spotlight_badge_style: StyleBoxFlat
var _spotlight_badge_target_style: StyleBoxFlat
var _spotlight_active_ids: Dictionary = {}


func _refresh_cards() -> void:
    super._refresh_cards()
    _refresh_spotlight_visuals()


func _refresh_spotlight_visuals() -> void:
    _ensure_spotlight_styles()

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        if combatant_id.is_empty():
            continue

        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var sprite: TextureRect = ui.get("texture") as TextureRect
        if sprite == null or not is_instance_valid(sprite):
            continue

        var spotlight_active: bool = SpotlightIndicatorRules.is_active(combatant, int(action_serial))
        var halo: Line2D = ui.get("spotlight_halo") as Line2D
        var badge: PanelContainer = ui.get("spotlight_badge") as PanelContainer

        if not spotlight_active:
            if halo != null and is_instance_valid(halo):
                halo.visible = false
            if badge != null and is_instance_valid(badge):
                badge.visible = false
            _spotlight_active_ids[combatant_id] = false
            continue

        var parent: Node = sprite.get_parent()
        if parent == null:
            continue

        if halo == null or not is_instance_valid(halo):
            halo = _make_spotlight_halo(combatant_id)
            parent.add_child(halo)
            ui["spotlight_halo"] = halo
        elif halo.get_parent() != parent:
            var old_halo_parent: Node = halo.get_parent()
            if old_halo_parent != null:
                old_halo_parent.remove_child(halo)
            parent.add_child(halo)

        if badge == null or not is_instance_valid(badge):
            badge = _make_spotlight_badge(combatant_id)
            parent.add_child(badge)
            ui["spotlight_badge"] = badge
        elif badge.get_parent() != parent:
            var old_badge_parent: Node = badge.get_parent()
            if old_badge_parent != null:
                old_badge_parent.remove_child(badge)
            parent.add_child(badge)

        cards[combatant_id] = ui

        var incoming_target: bool = _incoming_target_count(combatant) > 0
        _layout_spotlight_halo(halo, sprite, incoming_target)
        _layout_spotlight_badge(badge, sprite, incoming_target)
        halo.visible = true
        badge.visible = true

        if not bool(_spotlight_active_ids.get(combatant_id, false)):
            _play_spotlight_activation(halo, badge)
        _spotlight_active_ids[combatant_id] = true


func _make_spotlight_halo(combatant_id: String) -> Line2D:
    var halo := Line2D.new()
    halo.name = "SpotlightHalo_" + combatant_id
    halo.width = 2.0
    halo.antialiased = true
    halo.z_index = 9
    return halo


func _make_spotlight_badge(combatant_id: String) -> PanelContainer:
    var badge := PanelContainer.new()
    badge.name = "SpotlightBadge_" + combatant_id
    badge.custom_minimum_size = SPOTLIGHT_BADGE_SIZE
    badge.size = SPOTLIGHT_BADGE_SIZE
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge.z_index = 13

    var label := Label.new()
    label.name = "Label"
    label.text = "SPOTLIGHT"
    label.custom_minimum_size = SPOTLIGHT_BADGE_SIZE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 7)
    label.add_theme_color_override("font_color", Color("ffe7a0"))
    badge.add_child(label)
    return badge


func _layout_spotlight_halo(halo: Line2D, sprite: TextureRect, incoming_target: bool) -> void:
    var radius_x: float = sprite.size.x * 0.5 + 4.0
    var radius_y: float = sprite.size.y * 0.45 + 3.0
    var points := PackedVector2Array()
    for step: int in range(SPOTLIGHT_HALO_POINTS + 1):
        var angle: float = TAU * float(step) / float(SPOTLIGHT_HALO_POINTS)
        points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
    halo.points = points
    halo.position = sprite.position + sprite.size * 0.5
    halo.z_index = maxi(3, sprite.z_index - 1)
    if incoming_target:
        halo.width = 3.0
        halo.default_color = Color("ffd95cff")
    else:
        halo.width = 2.0
        halo.default_color = Color("e4c45ca8")


func _layout_spotlight_badge(badge: PanelContainer, sprite: TextureRect, incoming_target: bool) -> void:
    var parent_control: Control = sprite.get_parent() as Control
    var badge_x: float = sprite.position.x + (sprite.size.x - SPOTLIGHT_BADGE_SIZE.x) * 0.5
    var badge_y: float = maxf(2.0, sprite.position.y - SPOTLIGHT_BADGE_SIZE.y + 2.0)
    if parent_control != null:
        badge_x = clampf(
            badge_x,
            2.0,
            maxf(2.0, parent_control.size.x - SPOTLIGHT_BADGE_SIZE.x - 2.0)
        )
        badge_y = clampf(
            badge_y,
            2.0,
            maxf(2.0, parent_control.size.y - SPOTLIGHT_BADGE_SIZE.y - 2.0)
        )
    badge.position = Vector2(badge_x, badge_y)
    badge.size = SPOTLIGHT_BADGE_SIZE
    badge.z_index = sprite.z_index + 3
    badge.add_theme_stylebox_override(
        "panel",
        _spotlight_badge_target_style if incoming_target else _spotlight_badge_style
    )


func _play_spotlight_activation(halo: Line2D, badge: PanelContainer) -> void:
    halo.modulate = Color(1.0, 1.0, 1.0, 0.30)
    badge.modulate = Color(1.0, 1.0, 1.0, 0.30)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(halo, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.16)
    tween.tween_property(badge, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.16)


func _ensure_spotlight_styles() -> void:
    if _spotlight_badge_style != null and _spotlight_badge_target_style != null:
        return

    _spotlight_badge_style = StyleBoxFlat.new()
    _spotlight_badge_style.bg_color = Color("2d281bd9")
    _spotlight_badge_style.border_color = Color("d7b64aff")
    _spotlight_badge_style.set_border_width_all(1)
    _spotlight_badge_style.set_corner_radius_all(4)
    _spotlight_badge_style.content_margin_left = 3.0
    _spotlight_badge_style.content_margin_right = 3.0
    _spotlight_badge_style.content_margin_top = 0.0
    _spotlight_badge_style.content_margin_bottom = 0.0

    _spotlight_badge_target_style = _spotlight_badge_style.duplicate()
    _spotlight_badge_target_style.bg_color = Color("493b18f2")
    _spotlight_badge_target_style.border_color = Color("ffd96aff")
    _spotlight_badge_target_style.set_border_width_all(2)
