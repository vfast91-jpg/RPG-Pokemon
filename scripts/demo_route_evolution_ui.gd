extends "res://scripts/demo_route_balance_polish.gd"

# Evolution presentation layer for the demo route.
#
# This intentionally does NOT decide when an evolution happens. The gameplay
# system can later call queue_evolution_event(...) once an evolution was
# accepted/resolved. That keeps evolution rules separate from presentation.
#
# Supported species-data contract (already used by the project design data):
# evolution: {
#     "evolves_into": "target_species_id",
#     "evolution_level": 16,
#     "evolution_optional": true
# }
# Individual monsters may suppress evolution with prevent_evolution = true.
#
# Sprite convention: assets/<German display name>.png
# Example: res://assets/Bisasam.png

var _evolution_queue: Array = []
var _evolution_overlay: Control
var _evolution_before_sprite: TextureRect
var _evolution_after_sprite: TextureRect
var _evolution_before_name: Label
var _evolution_after_name: Label
var _evolution_before_missing: Label
var _evolution_after_missing: Label
var _evolution_message: Label
var _evolution_continue: Button


func _ready() -> void:
    super._ready()
    _build_evolution_popup()


# Public presentation hook for the future evolution system.
func queue_evolution_event(
    before_species_id: String,
    after_species_id: String,
    before_name: String = "",
    after_name: String = ""
) -> void:
    var resolved_before_name: String = before_name
    var resolved_after_name: String = after_name

    if resolved_before_name.is_empty():
        resolved_before_name = _evolution_species_name(before_species_id)
    if resolved_after_name.is_empty():
        resolved_after_name = _evolution_species_name(after_species_id)

    _evolution_queue.append({
        "before_species_id": before_species_id,
        "after_species_id": after_species_id,
        "before_name": resolved_before_name,
        "after_name": resolved_after_name
    })
    call_deferred("_try_show_evolution_popup")


# Small data helper so later gameplay code can ask whether a member currently
# has an evolution available without duplicating the species-data parsing.
func route_available_evolution(member: Dictionary) -> Dictionary:
    if bool(member.get("prevent_evolution", false)):
        return {}

    var species_id: String = str(member.get("species_id", ""))
    var species: Dictionary = _evolution_species_data(species_id)
    var evolution_value: Variant = species.get("evolution", {})
    if not (evolution_value is Dictionary):
        return {}

    var evolution: Dictionary = evolution_value
    var target_species_id: String = str(evolution.get("evolves_into", ""))
    var required_level: int = int(evolution.get("evolution_level", 0))
    var current_level: int = int(member.get("level", 1))

    if target_species_id.is_empty():
        return {}
    if required_level > 0 and current_level < required_level:
        return {}

    return {
        "target_species_id": target_species_id,
        "required_level": required_level,
        "optional": bool(evolution.get("evolution_optional", true))
    }


func _build_evolution_popup() -> void:
    if root == null:
        return

    _evolution_overlay = Control.new()
    _evolution_overlay.name = "EvolutionOverlay"
    _evolution_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _evolution_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _evolution_overlay.z_index = 110
    _evolution_overlay.visible = false
    root.add_child(_evolution_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.76)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _evolution_overlay.add_child(shade)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -210.0
    panel.offset_top = -145.0
    panel.offset_right = 210.0
    panel.offset_bottom = 145.0
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("172923"), Color("9fe7bd"), 12, 11.0)
    )
    _evolution_overlay.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 6)
    panel.add_child(content)

    var heading := Label.new()
    heading.text = "🌟 ENTWICKLUNG!"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 19)
    heading.add_theme_color_override("font_color", Color("ffe576"))
    content.add_child(heading)

    var subtitle := Label.new()
    subtitle.text = "Dein Pokémon hat sich entwickelt!"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 11)
    subtitle.add_theme_color_override("font_color", Color("c8d8d1"))
    content.add_child(subtitle)

    var evolution_row := HBoxContainer.new()
    evolution_row.alignment = BoxContainer.ALIGNMENT_CENTER
    evolution_row.add_theme_constant_override("separation", 12)
    content.add_child(evolution_row)

    var before_slot: VBoxContainer = _make_evolution_sprite_slot()
    _evolution_before_sprite = before_slot.get_node("Sprite") as TextureRect
    _evolution_before_missing = before_slot.get_node("Missing") as Label
    _evolution_before_name = before_slot.get_node("Name") as Label
    evolution_row.add_child(before_slot)

    var arrow := Label.new()
    arrow.text = "➜"
    arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    arrow.custom_minimum_size = Vector2(40, 80)
    arrow.add_theme_font_size_override("font_size", 30)
    arrow.add_theme_color_override("font_color", Color("9fe7bd"))
    evolution_row.add_child(arrow)

    var after_slot: VBoxContainer = _make_evolution_sprite_slot()
    _evolution_after_sprite = after_slot.get_node("Sprite") as TextureRect
    _evolution_after_missing = after_slot.get_node("Missing") as Label
    _evolution_after_name = after_slot.get_node("Name") as Label
    evolution_row.add_child(after_slot)

    _evolution_message = Label.new()
    _evolution_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _evolution_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _evolution_message.custom_minimum_size = Vector2(0, 28)
    _evolution_message.add_theme_font_size_override("font_size", 13)
    _evolution_message.add_theme_color_override("font_color", Color("ffffff"))
    content.add_child(_evolution_message)

    _evolution_continue = Button.new()
    _evolution_continue.text = "WEITER"
    _evolution_continue.custom_minimum_size = Vector2(150, 28)
    _evolution_continue.pressed.connect(_on_evolution_continue)
    content.add_child(_evolution_continue)


func _make_evolution_sprite_slot() -> VBoxContainer:
    var slot := VBoxContainer.new()
    slot.custom_minimum_size = Vector2(135, 128)
    slot.alignment = BoxContainer.ALIGNMENT_CENTER

    var sprite := TextureRect.new()
    sprite.name = "Sprite"
    sprite.custom_minimum_size = Vector2(108, 94)
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    slot.add_child(sprite)

    var missing := Label.new()
    missing.name = "Missing"
    missing.text = "Bild folgt"
    missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    missing.add_theme_font_size_override("font_size", 8)
    missing.add_theme_color_override("font_color", Color("8da098"))
    missing.visible = false
    slot.add_child(missing)

    var name_label := Label.new()
    name_label.name = "Name"
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 14)
    name_label.add_theme_color_override("font_color", Color("ffffff"))
    slot.add_child(name_label)

    return slot


func _try_show_evolution_popup() -> void:
    if _evolution_overlay == null or _evolution_overlay.visible:
        return

    # Level-up details should always be read first. The evolution popup follows
    # immediately afterwards instead of covering the existing Level-Up window.
    if _levelup_overlay != null and _levelup_overlay.visible:
        return

    _show_next_evolution_popup()


func _show_next_evolution_popup() -> void:
    if _evolution_overlay == null:
        return
    if _evolution_queue.is_empty():
        _evolution_overlay.visible = false
        return

    var event_value: Variant = _evolution_queue.pop_front()
    if not (event_value is Dictionary):
        _show_next_evolution_popup()
        return

    var event: Dictionary = event_value
    var before_species_id: String = str(event.get("before_species_id", ""))
    var after_species_id: String = str(event.get("after_species_id", ""))
    var before_name: String = str(event.get("before_name", "Pokémon"))
    var after_name: String = str(event.get("after_name", "Pokémon"))

    _evolution_before_name.text = before_name
    _evolution_after_name.text = after_name
    _evolution_message.text = "%s hat sich zu %s entwickelt!" % [before_name, after_name]

    _set_evolution_sprite(
        _evolution_before_sprite,
        _evolution_before_missing,
        before_species_id,
        before_name
    )
    _set_evolution_sprite(
        _evolution_after_sprite,
        _evolution_after_missing,
        after_species_id,
        after_name
    )

    _evolution_overlay.visible = true
    _evolution_continue.grab_focus()


func _set_evolution_sprite(
    sprite: TextureRect,
    missing_label: Label,
    species_id: String,
    display_name: String
) -> void:
    var texture: Texture2D = _evolution_texture(species_id, display_name)
    sprite.texture = texture
    missing_label.visible = texture == null
    if texture == null:
        missing_label.text = "Bild folgt: %s.png" % display_name


func _evolution_texture(species_id: String, display_name: String) -> Texture2D:
    # Preferred convention requested for the project: German Pokémon name.
    var direct_path: String = "res://assets/%s.png" % display_name
    if ResourceLoader.exists(direct_path):
        var direct_value: Variant = load(direct_path)
        if direct_value is Texture2D:
            return direct_value

    # Compatibility fallback for the current battle-demo asset resolver.
    if battle_demo != null and battle_demo.has_method("route_species_texture"):
        var texture_value: Variant = battle_demo.route_species_texture(species_id)
        if texture_value is Texture2D:
            return texture_value

    return null


func _evolution_species_name(species_id: String) -> String:
    if battle_demo != null and battle_demo.has_method("route_species_name"):
        var routed_name: String = str(battle_demo.route_species_name(species_id))
        if not routed_name.is_empty():
            return routed_name

    var species: Dictionary = _evolution_species_data(species_id)
    var display_name: String = str(species.get("display_name", species.get("name", "")))
    if not display_name.is_empty():
        return display_name

    return species_id.capitalize()


func _evolution_species_data(species_id: String) -> Dictionary:
    if battle_demo == null:
        return {}

    var data_value: Variant = battle_demo.get("data")
    if not (data_value is Dictionary):
        return {}

    var species_value: Variant = (data_value as Dictionary).get("species", {})
    if not (species_value is Dictionary):
        return {}

    var definition_value: Variant = (species_value as Dictionary).get(species_id, {})
    return definition_value if definition_value is Dictionary else {}


func _on_levelup_continue() -> void:
    super._on_levelup_continue()
    if _levelup_overlay != null and not _levelup_overlay.visible:
        call_deferred("_try_show_evolution_popup")


func _on_evolution_continue() -> void:
    if _evolution_queue.is_empty():
        _evolution_overlay.visible = false
        return
    _show_next_evolution_popup()
