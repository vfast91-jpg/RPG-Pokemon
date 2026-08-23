extends "res://scripts/demo_route_balance_polish.gd"

# Generic evolution presentation layer for the demo route.
#
# Rules and target validation live in EvolutionResolver. This file only presents
# either a mandatory branch choice or the completed before/after evolution.
# Branching data is intentionally generic: two, three or many targets all use
# the same UI and no species-specific code is required here.

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

var _evolution_choice_queue: Array = []
var _evolution_choice_overlay: Control
var _evolution_choice_title: Label
var _evolution_choice_subtitle: Label
var _evolution_choice_scroll: ScrollContainer
var _evolution_choice_buttons: GridContainer
var _evolution_choice_source_sprite: TextureRect
var _evolution_choice_source_missing: Label
var _evolution_choice_source_name: Label
var _active_evolution_choice: Dictionary = {}


func _ready() -> void:
    super._ready()
    _build_evolution_popup()
    _build_evolution_choice_popup()


# Public presentation hook used after an evolution has actually been applied.
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


# Public presentation hook for a branching evolution. `choices` is produced by
# EvolutionResolver and may contain any number of targets.
func queue_evolution_choice(
    member_index: int,
    before_species_id: String,
    level: int,
    choices: Array
) -> void:
    if choices.size() < 2:
        push_warning("Entwicklungswahl benötigt mindestens zwei Ziele.")
        return

    _evolution_choice_queue.append({
        "member_index": member_index,
        "before_species_id": before_species_id,
        "level": maxi(1, level),
        "choices": choices.duplicate(true)
    })
    call_deferred("_try_show_evolution_choice_popup")


# Compatibility/data helper for layers that do not use the central resolver.
# New species packs may use either the legacy single target or `choices`.
func route_available_evolution(member: Dictionary) -> Dictionary:
    var species_id: String = str(member.get("species_id", ""))
    var species: Dictionary = _evolution_species_data(species_id)
    var evolution_value: Variant = species.get("evolution", {})
    if not (evolution_value is Dictionary):
        return {}

    var evolution: Dictionary = evolution_value
    var current_level: int = maxi(1, int(member.get("level", 1)))
    var required_level: int = int(evolution.get("evolution_level", evolution.get("level", 0)))
    if required_level > 0 and current_level < required_level:
        return {}

    var choices_value: Variant = evolution.get("choices", [])
    if choices_value is Array and (choices_value as Array).size() > 1:
        var normalized_choices: Array = []
        for choice_value: Variant in choices_value:
            if not (choice_value is Dictionary):
                continue
            var choice: Dictionary = choice_value
            var target_id: String = str(choice.get("target", choice.get("evolves_into", "")))
            if target_id.is_empty():
                continue
            normalized_choices.append({
                "target_species_id": target_id,
                "required_level": int(choice.get("level", choice.get("evolution_level", required_level))),
                "target_available": not _evolution_species_data(target_id).is_empty()
            })
        if normalized_choices.size() > 1:
            return {
                "required_level": required_level,
                "mandatory": true,
                "requires_player_choice": true,
                "choices": normalized_choices
            }

    var target_species_id: String = str(evolution.get("evolves_into", evolution.get("target", "")))
    if target_species_id.is_empty():
        return {}

    return {
        "target_species_id": target_species_id,
        "required_level": required_level,
        "mandatory": true,
        "requires_player_choice": false
    }


func _build_evolution_choice_popup() -> void:
    if root == null:
        return

    _evolution_choice_overlay = Control.new()
    _evolution_choice_overlay.name = "EvolutionChoiceOverlay"
    _evolution_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _evolution_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _evolution_choice_overlay.z_index = 111
    _evolution_choice_overlay.visible = false
    root.add_child(_evolution_choice_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.84)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _evolution_choice_overlay.add_child(shade)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -330.0
    panel.offset_top = -225.0
    panel.offset_right = 330.0
    panel.offset_bottom = 225.0
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("172923"), Color("ffe576"), 14, 12.0)
    )
    _evolution_choice_overlay.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 7)
    panel.add_child(content)

    _evolution_choice_title = Label.new()
    _evolution_choice_title.text = "🌟 ENTWICKLUNG WÄHLEN"
    _evolution_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _evolution_choice_title.add_theme_font_size_override("font_size", 20)
    _evolution_choice_title.add_theme_color_override("font_color", Color("ffe576"))
    content.add_child(_evolution_choice_title)

    _evolution_choice_subtitle = Label.new()
    _evolution_choice_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _evolution_choice_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _evolution_choice_subtitle.custom_minimum_size = Vector2(0, 32)
    _evolution_choice_subtitle.add_theme_font_size_override("font_size", 11)
    _evolution_choice_subtitle.add_theme_color_override("font_color", Color("dce8e3"))
    content.add_child(_evolution_choice_subtitle)

    var source_panel := PanelContainer.new()
    source_panel.custom_minimum_size = Vector2(0, 58)
    source_panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("13231e"), Color("45675a"), 9, 5.0)
    )
    content.add_child(source_panel)

    var source_row := HBoxContainer.new()
    source_row.alignment = BoxContainer.ALIGNMENT_CENTER
    source_row.add_theme_constant_override("separation", 10)
    source_panel.add_child(source_row)

    var source_image_area := Control.new()
    source_image_area.custom_minimum_size = Vector2(52, 52)
    source_image_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
    source_row.add_child(source_image_area)

    _evolution_choice_source_sprite = TextureRect.new()
    _evolution_choice_source_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _evolution_choice_source_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _evolution_choice_source_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _evolution_choice_source_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    source_image_area.add_child(_evolution_choice_source_sprite)

    _evolution_choice_source_missing = Label.new()
    _evolution_choice_source_missing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _evolution_choice_source_missing.text = "Bild\nfolgt"
    _evolution_choice_source_missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _evolution_choice_source_missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _evolution_choice_source_missing.add_theme_font_size_override("font_size", 8)
    _evolution_choice_source_missing.add_theme_color_override("font_color", Color("8da098"))
    _evolution_choice_source_missing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    source_image_area.add_child(_evolution_choice_source_missing)

    var source_info := VBoxContainer.new()
    source_info.alignment = BoxContainer.ALIGNMENT_CENTER
    source_info.add_theme_constant_override("separation", 1)
    source_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
    source_row.add_child(source_info)

    var source_label := Label.new()
    source_label.text = "AUSGANGSFORM"
    source_label.add_theme_font_size_override("font_size", 8)
    source_label.add_theme_color_override("font_color", Color("9fb2aa"))
    source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    source_info.add_child(source_label)

    _evolution_choice_source_name = Label.new()
    _evolution_choice_source_name.add_theme_font_size_override("font_size", 14)
    _evolution_choice_source_name.add_theme_color_override("font_color", Color("ffffff"))
    _evolution_choice_source_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    source_info.add_child(_evolution_choice_source_name)

    _evolution_choice_scroll = ScrollContainer.new()
    _evolution_choice_scroll.custom_minimum_size = Vector2(0, 235)
    _evolution_choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _evolution_choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _evolution_choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _evolution_choice_scroll.follow_focus = true
    content.add_child(_evolution_choice_scroll)

    _evolution_choice_buttons = GridContainer.new()
    _evolution_choice_buttons.columns = 3
    _evolution_choice_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _evolution_choice_buttons.add_theme_constant_override("h_separation", 8)
    _evolution_choice_buttons.add_theme_constant_override("v_separation", 8)
    _evolution_choice_scroll.add_child(_evolution_choice_buttons)

    var note := Label.new()
    note.text = "Die Entwicklung ist verpflichtend – nur das Ziel wird gewählt."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 8)
    note.add_theme_color_override("font_color", Color("9fb2aa"))
    content.add_child(note)


func _try_show_evolution_choice_popup() -> void:
    if _evolution_choice_overlay == null or _evolution_choice_overlay.visible:
        return
    if _levelup_overlay != null and _levelup_overlay.visible:
        return
    if _evolution_overlay != null and _evolution_overlay.visible:
        return
    if _evolution_choice_queue.is_empty():
        return

    _show_next_evolution_choice_popup()


func _show_next_evolution_choice_popup() -> void:
    if _evolution_choice_overlay == null:
        return
    if _evolution_choice_queue.is_empty():
        _evolution_choice_overlay.visible = false
        _active_evolution_choice = {}
        return

    var request_value: Variant = _evolution_choice_queue.pop_front()
    if not (request_value is Dictionary):
        _show_next_evolution_choice_popup()
        return

    _active_evolution_choice = (request_value as Dictionary).duplicate(true)
    var before_species_id: String = str(_active_evolution_choice.get("before_species_id", ""))
    var before_name: String = _evolution_species_name(before_species_id)
    var level: int = maxi(1, int(_active_evolution_choice.get("level", 1)))
    _evolution_choice_subtitle.text = "%s kann sich auf mehrere Arten entwickeln. Wähle die gewünschte Form:" % before_name

    _evolution_choice_source_name.text = "%s · Lv.%d" % [before_name, level]
    var source_texture: Texture2D = _evolution_texture(before_species_id, before_name)
    _evolution_choice_source_sprite.texture = source_texture
    _evolution_choice_source_missing.visible = source_texture == null

    for child: Node in _evolution_choice_buttons.get_children():
        _evolution_choice_buttons.remove_child(child)
        child.queue_free()

    var choices_value: Variant = _active_evolution_choice.get("choices", [])
    var choices: Array = choices_value if choices_value is Array else []
    var first_enabled_button: Button = null

    for choice_value: Variant in choices:
        if not (choice_value is Dictionary):
            continue
        var choice: Dictionary = choice_value
        var target_id: String = str(choice.get("target_species_id", ""))
        if target_id.is_empty():
            continue

        var target_name: String = _evolution_species_name(target_id)
        var target_available: bool = bool(choice.get("target_available", true))
        var button: Button = _make_evolution_choice_card(
            before_name,
            target_id,
            target_name,
            target_available
        )
        _evolution_choice_buttons.add_child(button)

        if target_available and first_enabled_button == null:
            first_enabled_button = button

    if _evolution_choice_scroll != null:
        _evolution_choice_scroll.scroll_vertical = 0

    _evolution_choice_overlay.visible = true
    if first_enabled_button != null:
        first_enabled_button.grab_focus()


func _make_evolution_choice_card(
    before_name: String,
    target_species_id: String,
    target_name: String,
    target_available: bool
) -> Button:
    var button := Button.new()
    button.text = ""
    button.custom_minimum_size = Vector2(190, 166)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_ALL
    button.disabled = not target_available
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.tooltip_text = (
        "Entwickle %s zu %s" % [before_name, target_name]
        if target_available
        else "%s ist noch nicht vollständig verfügbar." % target_name
    )
    button.add_theme_stylebox_override(
        "normal",
        _evolution_choice_card_style(Color("182a24"), Color("45675a"), 1)
    )
    button.add_theme_stylebox_override(
        "hover",
        _evolution_choice_card_style(Color("1d352c"), Color("9fe7bd"), 2)
    )
    button.add_theme_stylebox_override(
        "focus",
        _evolution_choice_card_style(Color("1d352c"), Color("ffe576"), 3)
    )
    button.add_theme_stylebox_override(
        "pressed",
        _evolution_choice_card_style(Color("24392f"), Color("ffe576"), 2)
    )
    button.add_theme_stylebox_override(
        "disabled",
        _evolution_choice_card_style(Color("14211d"), Color("394942"), 1)
    )
    if target_available:
        button.pressed.connect(_on_evolution_choice_button.bind(target_species_id))

    var margin := MarginContainer.new()
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", 8)
    margin.add_theme_constant_override("margin_top", 7)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_bottom", 7)
    button.add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var card_content := VBoxContainer.new()
    card_content.alignment = BoxContainer.ALIGNMENT_CENTER
    card_content.add_theme_constant_override("separation", 3)
    card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(card_content)

    var image_area := Control.new()
    image_area.custom_minimum_size = Vector2(0, 96)
    image_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    image_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card_content.add_child(image_area)

    var sprite := TextureRect.new()
    sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sprite.texture = _evolution_texture(target_species_id, target_name)
    image_area.add_child(sprite)

    var missing := Label.new()
    missing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    missing.text = "Bild folgt"
    missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    missing.add_theme_font_size_override("font_size", 9)
    missing.add_theme_color_override("font_color", Color("8da098"))
    missing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    missing.visible = sprite.texture == null
    image_area.add_child(missing)

    var name_label := Label.new()
    name_label.text = target_name
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 14)
    name_label.add_theme_color_override(
        "font_color",
        Color("ffffff") if target_available else Color("83928b")
    )
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card_content.add_child(name_label)

    var type_row := HBoxContainer.new()
    type_row.alignment = BoxContainer.ALIGNMENT_CENTER
    type_row.add_theme_constant_override("separation", 4)
    type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card_content.add_child(type_row)

    if not target_available:
        type_row.add_child(_make_evolution_status_badge("DATEN FEHLEN"))
    else:
        var types: Array = _evolution_species_types(target_species_id)
        if types.is_empty():
            type_row.add_child(_make_evolution_status_badge("TYPDATEN FEHLEN"))
        else:
            for type_value: Variant in types:
                var type_id: String = str(type_value)
                if not type_id.is_empty():
                    type_row.add_child(_make_evolution_type_badge(type_id))

    return button


func _evolution_choice_card_style(
    background: Color,
    border: Color,
    border_width: int
) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(10)
    style.content_margin_left = 0.0
    style.content_margin_top = 0.0
    style.content_margin_right = 0.0
    style.content_margin_bottom = 0.0
    return style


func _make_evolution_type_badge(type_id: String) -> Control:
    var badge := PanelContainer.new()
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style := StyleBoxFlat.new()
    style.bg_color = _evolution_type_color(type_id)
    style.set_corner_radius_all(4)
    style.content_margin_left = 5.0
    style.content_margin_right = 5.0
    style.content_margin_top = 1.0
    style.content_margin_bottom = 1.0
    badge.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.text = _evolution_type_name(type_id).to_upper()
    label.add_theme_font_size_override("font_size", 8)
    label.add_theme_color_override("font_color", Color("ffffff"))
    label.add_theme_color_override("font_outline_color", Color("17211f"))
    label.add_theme_constant_override("outline_size", 1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge.add_child(label)
    return badge


func _make_evolution_status_badge(text: String) -> Control:
    var badge := PanelContainer.new()
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style := StyleBoxFlat.new()
    style.bg_color = Color("4c3d3d")
    style.set_corner_radius_all(4)
    style.content_margin_left = 5.0
    style.content_margin_right = 5.0
    style.content_margin_top = 1.0
    style.content_margin_bottom = 1.0
    badge.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 7)
    label.add_theme_color_override("font_color", Color("d5c6c6"))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge.add_child(label)
    return badge


func _evolution_species_types(species_id: String) -> Array:
    var species: Dictionary = _evolution_species_data(species_id)
    var types_value: Variant = species.get("types", {})
    var result: Array = []

    if types_value is Dictionary:
        var types: Dictionary = types_value
        var primary: String = str(types.get("primary", ""))
        var secondary_value: Variant = types.get("secondary", null)
        var secondary: String = "" if secondary_value == null else str(secondary_value)
        if not primary.is_empty():
            result.append(primary)
        if not secondary.is_empty() and secondary != primary:
            result.append(secondary)
        return result

    if types_value is Array:
        for type_value: Variant in types_value:
            var type_id: String = str(type_value)
            if not type_id.is_empty() and not result.has(type_id):
                result.append(type_id)

    return result


func _evolution_type_name(type_id: String) -> String:
    var names: Dictionary = {
        "normal": "Normal",
        "fire": "Feuer",
        "water": "Wasser",
        "electric": "Elektro",
        "grass": "Pflanze",
        "ice": "Eis",
        "fighting": "Kampf",
        "poison": "Gift",
        "ground": "Boden",
        "flying": "Flug",
        "psychic": "Psycho",
        "bug": "Käfer",
        "rock": "Gestein",
        "ghost": "Geist",
        "dragon": "Drache",
        "dark": "Unlicht",
        "steel": "Stahl",
        "fairy": "Fee",
        "typeless": "Typenlos"
    }
    return str(names.get(type_id, type_id))


func _evolution_type_color(type_id: String) -> Color:
    match type_id:
        "normal":
            return Color("8f989a")
        "fire":
            return Color("d85b45")
        "water":
            return Color("4f86cf")
        "electric":
            return Color("c9a51f")
        "grass":
            return Color("5b9f55")
        "ice":
            return Color("63aeb4")
        "fighting":
            return Color("b34b45")
        "poison":
            return Color("9250a3")
        "ground":
            return Color("a87845")
        "flying":
            return Color("7187c7")
        "psychic":
            return Color("c95b86")
        "bug":
            return Color("7f9637")
        "rock":
            return Color("9b8647")
        "ghost":
            return Color("655c94")
        "dragon":
            return Color("6352b4")
        "dark":
            return Color("66564f")
        "steel":
            return Color("77858f")
        "fairy":
            return Color("c97fa5")
        _:
            return Color("68736f")


func _on_evolution_choice_button(target_species_id: String) -> void:
    if _active_evolution_choice.is_empty():
        return

    var request: Dictionary = _active_evolution_choice.duplicate(true)
    _active_evolution_choice = {}
    _evolution_choice_overlay.visible = false
    _on_evolution_choice_selected(request, target_species_id)

    # A completed evolution result gets presentation priority. If the callback
    # queued another branch immediately afterwards, it follows that result.
    call_deferred("_try_show_evolution_popup")
    call_deferred("_try_show_evolution_choice_popup")


# Virtual callback implemented by the gameplay layer. The UI itself never
# mutates Pokémon state and therefore cannot accidentally invent a target.
func _on_evolution_choice_selected(_request: Dictionary, _target_species_id: String) -> void:
    push_warning("Entwicklungswahl wurde angezeigt, aber kein Gameplay-Handler ist aktiv.")


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
    if _levelup_overlay != null and _levelup_overlay.visible:
        return
    if _evolution_choice_overlay != null and _evolution_choice_overlay.visible:
        return
    _show_next_evolution_popup()


func _show_next_evolution_popup() -> void:
    if _evolution_overlay == null:
        return
    if _evolution_queue.is_empty():
        _evolution_overlay.visible = false
        call_deferred("_try_show_evolution_choice_popup")
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
    var direct_path: String = "res://assets/%s.png" % display_name
    if ResourceLoader.exists(direct_path):
        var direct_value: Variant = load(direct_path)
        if direct_value is Texture2D:
            return direct_value

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
        call_deferred("_try_show_evolution_choice_popup")
        call_deferred("_try_show_evolution_popup")


func _on_evolution_continue() -> void:
    if _evolution_queue.is_empty():
        _evolution_overlay.visible = false
        call_deferred("_try_show_evolution_choice_popup")
        return
    _show_next_evolution_popup()
