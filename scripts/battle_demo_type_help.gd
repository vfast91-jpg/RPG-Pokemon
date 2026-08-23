extends "res://scripts/battle_demo_player_language.gd"

# Optional type-reference overlay for the battle demo.
# The battle HUD stays unchanged; opening TYPEN shows the complete 18x18
# single-type effectiveness matrix at once, without any scrolling.
# The matrix reads the same central type_chart.json used by TypeSystem.

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

const TYPE_HELP_SHORT_NAMES: Dictionary = {
    "normal": "NOR",
    "fire": "FEU",
    "water": "WAS",
    "electric": "ELE",
    "grass": "PFL",
    "ice": "EIS",
    "fighting": "KAM",
    "poison": "GIF",
    "ground": "BOD",
    "flying": "FLU",
    "psychic": "PSY",
    "bug": "KÄF",
    "rock": "GES",
    "ghost": "GEI",
    "dragon": "DRA",
    "dark": "UNL",
    "steel": "STA",
    "fairy": "FEE"
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
    backdrop.color = Color(0.03, 0.05, 0.06, 0.80)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _type_help_overlay.add_child(backdrop)

    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 8.0
    panel.offset_top = 8.0
    panel.offset_right = -8.0
    panel.offset_bottom = -8.0
    panel.add_theme_stylebox_override(
        "panel",
        _type_help_stylebox(Color("17211f"), Color("e8f2ec"), 2, 9, 6.0)
    )
    _type_help_overlay.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 3)
    panel.add_child(content)

    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 25.0
    content.add_child(header)

    var title := Label.new()
    title.text = "TYPENMATRIX"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 15)
    title.add_theme_color_override("font_color", Color("ffe46c"))
    header.add_child(title)

    var close_button := Button.new()
    close_button.text = "×"
    close_button.tooltip_text = "Typenhilfe schließen"
    close_button.custom_minimum_size = Vector2(30.0, 24.0)
    close_button.pressed.connect(_close_type_help)
    header.add_child(close_button)

    var legend := Label.new()
    legend.text = "LINKS Angriff · OBEN Verteidigung    2 = stark    ½ / ¼ = weniger effektiv    leer = normal"
    legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    legend.add_theme_font_size_override("font_size", 8)
    legend.add_theme_color_override("font_color", Color("d6ded9"))
    content.add_child(legend)

    var matrix_center := CenterContainer.new()
    matrix_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    matrix_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(matrix_center)

    var matrix_frame := PanelContainer.new()
    matrix_frame.add_theme_stylebox_override(
        "panel",
        _type_help_stylebox(Color("101918"), Color("5d746a"), 1, 5, 3.0)
    )
    matrix_center.add_child(matrix_frame)

    var grid := GridContainer.new()
    grid.name = "TypeMatrix"
    grid.columns = 19
    grid.add_theme_constant_override("h_separation", 1)
    grid.add_theme_constant_override("v_separation", 1)
    matrix_frame.add_child(grid)

    _populate_type_help_matrix(grid)


func _populate_type_help_matrix(grid: GridContainer) -> void:
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
    grid.columns = all_types.size() + 1

    grid.add_child(_matrix_corner_cell())
    for defender_value: Variant in all_types:
        var defender_type: String = str(defender_value)
        grid.add_child(_matrix_header_cell(defender_type, true))

    for attack_value: Variant in all_types:
        var attack_type: String = str(attack_value)
        grid.add_child(_matrix_header_cell(attack_type, false))

        var row_value: Variant = effectiveness.get(attack_type, {})
        var row: Dictionary = row_value if row_value is Dictionary else {}
        for defender_value: Variant in all_types:
            var defender_type: String = str(defender_value)
            var multiplier: float = float(row.get(defender_type, 1.0))
            grid.add_child(_matrix_value_cell(attack_type, defender_type, multiplier))


func _matrix_corner_cell() -> PanelContainer:
    var cell := PanelContainer.new()
    cell.custom_minimum_size = Vector2(54.0, 17.0)
    cell.add_theme_stylebox_override(
        "panel",
        _matrix_cell_style(Color("273833"), Color("6f8981"))
    )

    var label := Label.new()
    label.text = "ANG\\VER"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 6)
    label.add_theme_color_override("font_color", Color("ffe46c"))
    cell.add_child(label)
    return cell


func _matrix_header_cell(type_id: String, top: bool) -> PanelContainer:
    var cell := PanelContainer.new()
    cell.custom_minimum_size = Vector2(25.0 if top else 54.0, 17.0 if top else 13.0)
    cell.tooltip_text = _type_help_name(type_id)
    cell.add_theme_stylebox_override(
        "panel",
        _matrix_cell_style(_type_help_header_color(type_id), Color("5d746a"))
    )

    var label := Label.new()
    label.text = str(TYPE_HELP_SHORT_NAMES.get(type_id, type_id.left(3).to_upper())) if top else _type_help_name(type_id).to_upper()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.clip_text = true
    label.add_theme_font_size_override("font_size", 6 if top else 7)
    label.add_theme_color_override("font_color", Color("ffffff"))
    label.add_theme_color_override("font_outline_color", Color("17211f"))
    label.add_theme_constant_override("outline_size", 1)
    cell.add_child(label)
    return cell


func _matrix_value_cell(
    attack_type: String,
    defender_type: String,
    multiplier: float
) -> PanelContainer:
    var cell := PanelContainer.new()
    cell.custom_minimum_size = Vector2(25.0, 13.0)
    cell.tooltip_text = "%s gegen %s: %s" % [
        _type_help_name(attack_type),
        _type_help_name(defender_type),
        _matrix_tooltip(multiplier)
    ]
    cell.add_theme_stylebox_override(
        "panel",
        _matrix_cell_style(_matrix_background(multiplier), Color("42544e"))
    )

    var label := Label.new()
    label.text = _matrix_text(multiplier)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 7)
    label.add_theme_color_override("font_color", _matrix_text_color(multiplier))
    cell.add_child(label)
    return cell


func _matrix_text(multiplier: float) -> String:
    if is_zero_approx(multiplier):
        return "0"
    if is_equal_approx(multiplier, 0.25):
        return "¼"
    if is_equal_approx(multiplier, 0.5):
        return "½"
    if multiplier < 1.0:
        return str(multiplier)
    if multiplier > 1.0:
        return "2" if is_equal_approx(multiplier, 2.0) else str(multiplier)
    return ""


func _matrix_background(multiplier: float) -> Color:
    if is_equal_approx(multiplier, 0.25):
        return Color("7b3f42")
    if is_zero_approx(multiplier):
        return Color("66445f")
    if multiplier < 1.0:
        return Color("8b733f")
    if multiplier > 1.0:
        return Color("3f7651")
    return Color("1d2926")


func _matrix_text_color(multiplier: float) -> Color:
    if is_equal_approx(multiplier, 1.0):
        return Color("718078")
    return Color("ffffff")


func _matrix_tooltip(multiplier: float) -> String:
    if is_equal_approx(multiplier, 0.25):
        return "weniger effektiv (¼×)"
    if is_zero_approx(multiplier):
        return "keine Wirkung (0×)"
    if is_equal_approx(multiplier, 0.5):
        return "weniger effektiv (½×)"
    if multiplier < 1.0:
        return "weniger effektiv (%s×)" % str(multiplier)
    if multiplier > 1.0:
        return "stark (%s×)" % str(multiplier)
    return "normal (1×)"


func _matrix_cell_style(background: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(1)
    style.content_margin_left = 1.0
    style.content_margin_right = 1.0
    style.content_margin_top = 0.0
    style.content_margin_bottom = 0.0
    return style


func _type_help_header_color(type_id: String) -> Color:
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


func _type_help_name(type_id: String) -> String:
    return str(TYPE_HELP_NAMES.get(type_id, type_id.capitalize()))


func _type_name(type_id: String) -> String:
    return _type_help_name(type_id)


func _add_type_help_error(grid: GridContainer, message: String) -> void:
    grid.columns = 1
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
    radius: int,
    margin: float
) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = margin
    style.content_margin_top = margin
    style.content_margin_right = margin
    style.content_margin_bottom = margin
    return style
