extends "res://scripts/battle_demo_database_nidoran_f_family.gd"

# Active family chain:
# battle_demo_database_nidoran_f_family.gd extends
# res://scripts/battle_demo_database_sandshrew_family.gd.
#
# Final visual polish for the optional type-reference button.
# Keeps the button compact and visually consistent with the battle UI without
# changing the type-help overlay, combat layout, or battle mechanics.


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    _polish_type_help_button()


func _polish_type_help_button() -> void:
    if _type_help_button == null:
        return

    _type_help_button.text = "TYPEN"
    _type_help_button.tooltip_text = "Typen-Stärken und -Schwächen anzeigen"
    _type_help_button.custom_minimum_size = Vector2(76.0, 25.0)
    _type_help_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _type_help_button.offset_left = -38.0
    _type_help_button.offset_right = 38.0
    _type_help_button.offset_top = 7.0
    _type_help_button.offset_bottom = 32.0
    _type_help_button.focus_mode = Control.FOCUS_NONE

    _type_help_button.add_theme_font_size_override("font_size", 11)
    _type_help_button.add_theme_color_override("font_color", Color("f8f1dc"))
    _type_help_button.add_theme_color_override("font_hover_color", Color("fff4cd"))
    _type_help_button.add_theme_color_override("font_pressed_color", Color("ffe46c"))
    _type_help_button.add_theme_color_override("font_disabled_color", Color("8e9993"))

    _type_help_button.add_theme_stylebox_override(
        "normal",
        _type_help_utility_style(Color("18231fe8"), Color("bfae63"), 1)
    )
    _type_help_button.add_theme_stylebox_override(
        "hover",
        _type_help_utility_style(Color("22312cf2"), Color("f5df78"), 1)
    )
    _type_help_button.add_theme_stylebox_override(
        "pressed",
        _type_help_utility_style(Color("101918f5"), Color("ffe46c"), 2)
    )
    _type_help_button.add_theme_stylebox_override(
        "disabled",
        _type_help_utility_style(Color("18231f99"), Color("65716b"), 1)
    )


func _type_help_utility_style(
    background: Color,
    border: Color,
    border_width: int
) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(6)
    style.content_margin_left = 9.0
    style.content_margin_right = 9.0
    style.content_margin_top = 4.0
    style.content_margin_bottom = 4.0
    return style
