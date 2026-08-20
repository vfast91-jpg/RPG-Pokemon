extends "res://scripts/battle_demo_feedback_polish.gd"

# Compact type badges for the always-visible battle cards.
# They reuse the combatant's existing `types` data and share the name row so
# even 4-vs-4 battles keep the current compact card height.


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: Control = super._make_card(combatant, enemy)
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

    var header: HBoxContainer = HBoxContainer.new()
    header.name = "NameAndTypes"
    header.add_theme_constant_override("separation", 2)
    content.add_child(header)
    content.move_child(header, 0)

    name_label.reparent(header)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.clip_text = true
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

    for type_value: Variant in types:
        var type_id: String = str(type_value)
        if type_id.is_empty():
            continue
        header.add_child(_make_type_badge(type_id))


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
