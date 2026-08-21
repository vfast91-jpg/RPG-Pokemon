extends "res://scripts/battle_demo_player_language.gd"

# Lightweight, optional type-reference overlay for the battle demo.
# It does not add matchup text to move buttons and does not change the existing
# battle layout. The displayed strengths/weaknesses are read from the same
# central type_chart.json that TypeSystem uses for combat calculations.

const TYPE_HELP_CHART_PATH: String = "res://data/rules/type_chart.json"
const TYPE_HELP_NAMES: Dictionary = {
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
    "fairy": "Fee"
}

var _type_help_button: Button
var _type_help_overlay: Control
var _type_help_previous_paused: bool = false


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    _install_type_help()


func _install_type_help() -> void:
    if battle_panel == null:
        push_error("Typenhilfe: battle_panel fehlt.")
        return

    var old_button: Node = battle_panel.get_node_or_null("TypeHelpButton")
    if old_button != null:
        old_button.queue_free()
    var old_overlay: Node = battle_panel.get_node_or_null("TypeHelpOverlay")
    if old_overlay != null:
        old_overlay.queue_free()

    _type_help_button = Button.new()
    _type_help_button.name = "TypeHelpButton"
    _type_help_button.text = "TYPEN ?"
    _type_help_button.tooltip_text = "Typen-Stärken und -Schwächen anzeigen"
    _type_help_button.custom_minimum_size = Vector2(84.0, 26.0)
    _type_help_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _type_help_button.offset_left = -42.0
    _type_help_button.offset_right = 42.0
    _type_help_button.offset_top = 6.0
    _type_help_button.offset_bottom = 32.0
    _type_help_button.z_index = 80
    _type_help_button.pressed.connect(_toggle_type_help)
    battle_panel.add_child(_type_help_button)

    _type_help_overlay = Control.new()
    _type_help_overlay.name = "TypeHelpOverlay"
    _type_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _type_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _type_help_overlay.z_index = 100
    _type_help_overlay.visible = false
    battle_panel.add_child(_type_help_overlay)

    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.03, 0.05, 0.06, 0.78)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _type_help_overlay.add_child(backdrop)

    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 14.0
    panel.offset_top = 12.0
    panel.offset_right = -14.0
    panel.offset_bottom = -12.0
    panel.add_theme_stylebox_override("panel", _type_help_stylebox(Color("17211f"), Color("e8f2ec"), 2, 10))
    _type_help_overlay.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    panel.add_child(content)

    var header := HBoxContainer.new()
    content.add_child(header)

    var title := Label.new()
    title.text = "TYPEN · STÄRKEN & SCHWÄCHEN"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 17)
    header.add_child(title)

    var close_button := Button.new()
    close_button.text = "✕"
    close_button.tooltip_text = "Typenhilfe schließen"
    close_button.custom_minimum_size = Vector2(34.0, 28.0)
    close_button.pressed.connect(_close_type_help)
    header.add_child(close_button)

    var explanation := Label.new()
    explanation.text = "Attackentyp → Verteidigertyp · Nicht genannte Kombinationen wirken normal. Bei Doppeltypen werden beide Wirkungen kombiniert."
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    explanation.add_theme_font_size_override("font_size", 11)
    content.add_child(explanation)

    var legend := Label.new()
    legend.text = "STARK = 2× Schaden   ·   WENIGER EFFEKTIV = ½× Schaden   ·   KEINE WIRKUNG = 0×"
    legend.add_theme_font_size_override("font_size", 11)
    content.add_child(legend)

    var separator := HSeparator.new()
    content.add_child(separator)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(scroll)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 7)
    scroll.add_child(grid)

    _populate_type_help_grid(grid)


func _populate_type_help_grid(grid: GridContainer) -> void:
    var file := FileAccess.open(TYPE_HELP_CHART_PATH, FileAccess.READ)
    if file == null:
        _add_type_help_error(grid, "Typentabelle konnte nicht geladen werden.")
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        _add_type_help_error(grid, "Typentabelle ist ungültig.")
        return

    var chart: Dictionary = parsed
    var types_value: Variant = chart.get("types", [])
    var effectiveness_value: Variant = chart.get("effectiveness", {})
    if not (types_value is Array) or not (effectiveness_value is Dictionary):
        _add_type_help_error(grid, "Typentabelle ist unvollständig.")
        return

    var all_types: Array = types_value
    var effectiveness: Dictionary = effectiveness_value

    for type_value: Variant in all_types:
        var attack_type: String = str(type_value)
        var card := PanelContainer.new()
        card.custom_minimum_size = Vector2(283.0, 0.0)
        card.add_theme_stylebox_override("panel", _type_help_stylebox(Color("22302d"), Color("6f8981"), 1, 7))
        grid.add_child(card)

        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 2)
        card.add_child(box)

        var type_title := Label.new()
        type_title.text = _type_help_name(attack_type).to_upper()
        type_title.add_theme_font_size_override("font_size", 13)
        box.add_child(type_title)

        box.add_child(_type_help_line(
            "Stark gegen: ",
            _type_help_target_names(effectiveness, attack_type, all_types, 2.0)
        ))
        box.add_child(_type_help_line(
            "Weniger effektiv: ",
            _type_help_target_names(effectiveness, attack_type, all_types, 0.5)
        ))
        box.add_child(_type_help_line(
            "Keine Wirkung: ",
            _type_help_target_names(effectiveness, attack_type, all_types, 0.0)
        ))


func _type_help_line(prefix: String, value: String) -> Label:
    var label := Label.new()
    label.text = prefix + value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 10)
    return label


func _type_help_target_names(
    effectiveness: Dictionary,
    attack_type: String,
    all_types: Array,
    wanted_multiplier: float
) -> String:
    var row_value: Variant = effectiveness.get(attack_type, {})
    var row: Dictionary = row_value if row_value is Dictionary else {}
    var result := PackedStringArray()

    for defender_value: Variant in all_types:
        var defender_type: String = str(defender_value)
        var multiplier: float = float(row.get(defender_type, 1.0))
        if is_equal_approx(multiplier, wanted_multiplier):
            result.append(_type_help_name(defender_type))

    if result.is_empty():
        return "—"
    return ", ".join(result)


func _type_help_name(type_id: String) -> String:
    return str(TYPE_HELP_NAMES.get(type_id, type_id.capitalize()))


func _type_name(type_id: String) -> String:
    return _type_help_name(type_id)


func _add_type_help_error(grid: GridContainer, message: String) -> void:
    var label := Label.new()
    label.text = message
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    grid.add_child(label)


func _toggle_type_help() -> void:
    if _type_help_overlay == null:
        return
    if _type_help_overlay.visible:
        _close_type_help()
    else:
        _open_type_help()


func _open_type_help() -> void:
    if _type_help_overlay == null:
        return
    _type_help_previous_paused = paused
    paused = true
    _type_help_overlay.visible = true
    if _type_help_button != null:
        _type_help_button.release_focus()


func _close_type_help() -> void:
    if _type_help_overlay == null:
        return
    _type_help_overlay.visible = false
    paused = _type_help_previous_paused


func _type_help_stylebox(
    background: Color,
    border: Color,
    border_width: int,
    radius: int
) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.border_width_left = border_width
    style.border_width_top = border_width
    style.border_width_right = border_width
    style.border_width_bottom = border_width
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_right = radius
    style.corner_radius_bottom_left = radius
    style.content_margin_left = 9.0
    style.content_margin_top = 7.0
    style.content_margin_right = 9.0
    style.content_margin_bottom = 7.0
    return style
