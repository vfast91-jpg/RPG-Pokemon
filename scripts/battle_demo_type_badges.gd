extends "res://scripts/battle_demo_feedback_polish.gd"

# Compact type badges for the always-visible battle cards.
# They reuse the combatant's existing `types` data and sit directly below the
# Pokemon name while keeping 4-vs-4 battles inside the existing battle area.


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: Control = super._make_card(combatant, enemy)
    card.custom_minimum_size.y = 52.0
    card.size.y = 52.0
    _attach_type_badges(combatant)
    return card


func _attach_type_badges(combatant: Dictionary) -> void:
    var combatant_id: String = str(combatant.get("id", ""))
    var ui_value: Variant = cards.get(combatant_id, {})
    if not (ui_value is Dictionary):
        return

    var ui: Dictionary = ui_value
    var hp_bar: ProgressBar = ui.get("hp") as ProgressBar
    if hp_bar == null:
        return

    var content: VBoxContainer = hp_bar.get_parent() as VBoxContainer
    if content == null or content.get_child_count() == 0:
        return

    var name_label: Label = content.get_child(0) as Label
    if name_label == null:
        return

    var types: Array = _type_array(combatant.get("types", []))
    if types.is_empty():
        return

    # Make just enough vertical room for the new row without making the combat
    # cards overlap when four Pokemon are visible on one side.
    name_label.add_theme_font_size_override("font_size", 8)
    name_label.clip_text = true
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    hp_bar.custom_minimum_size.y = 8.0

    var atb_bar: ProgressBar = ui.get("atb") as ProgressBar
    if atb_bar != null:
        atb_bar.custom_minimum_size.y = 4.0

    var aggro_bar: ProgressBar = ui.get("aggro") as ProgressBar
    if aggro_bar != null:
        aggro_bar.custom_minimum_size.y = 4.0

    var aggro_label: Label = ui.get("aggro_label") as Label
    if aggro_label != null:
        aggro_label.custom_minimum_size = Vector2(28.0, 6.0)
        aggro_label.add_theme_font_size_override("font_size", 6)

    var status_label: Label = ui.get("status") as Label
    if status_label != null:
        status_label.add_theme_font_size_override("font_size", 6)

    var type_row: HBoxContainer = HBoxContainer.new()
    type_row.name = "TypeBadges"
    type_row.custom_minimum_size.y = 7.0
    type_row.add_theme_constant_override("separation", 2)

    for type_value: Variant in types:
        var type_id: String = str(type_value)
        if type_id.is_empty():
            continue
        type_row.add_child(_make_type_badge(type_id))

    if type_row.get_child_count() == 0:
        type_row.queue_free()
        return

    content.add_child(type_row)
    content.move_child(type_row, hp_bar.get_index())


func _make_type_badge(type_id: String) -> Control:
    var badge: PanelContainer = PanelContainer.new()
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = _type_badge_color(type_id)
    style.set_corner_radius_all(3)
    style.content_margin_left = 3.0
    style.content_margin_right = 3.0
    style.content_margin_top = 0.0
    style.content_margin_bottom = 0.0
    badge.add_theme_stylebox_override("panel", style)

    var label: Label = Label.new()
    label.text = _type_badge_name(type_id).to_upper()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 6)
    label.add_theme_color_override("font_color", Color("ffffff"))
    label.add_theme_color_override("font_outline_color", Color("17211f"))
    label.add_theme_constant_override("outline_size", 1)
    badge.add_child(label)

    return badge


func _type_badge_name(type_id: String) -> String:
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


func _type_badge_color(type_id: String) -> Color:
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
