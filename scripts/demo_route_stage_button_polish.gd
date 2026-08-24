extends "res://scripts/demo_route_tm_database_bridge_v1.gd"

# Subtle route CTA polish: keep the established route UI, but give the
# stage-battle action a clearer centered hierarchy without flashy effects.


func _ready() -> void:
    super._ready()
    _polish_stage_battle_button()


func _polish_stage_battle_button() -> void:
    if continue_button == null:
        return

    continue_button.text = "ZUM ETAPPENKAMPF  →"
    continue_button.custom_minimum_size = Vector2(330, 42)
    continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    continue_button.tooltip_text = ""

    continue_button.add_theme_font_size_override("font_size", 12)
    continue_button.add_theme_color_override("font_color", Color("f6e7a3"))
    continue_button.add_theme_color_override("font_hover_color", Color("fff1b0"))
    continue_button.add_theme_color_override("font_pressed_color", Color("e6d58e"))
    continue_button.add_theme_color_override("font_focus_color", Color("fff1b0"))

    continue_button.add_theme_stylebox_override(
        "normal",
        _stage_battle_button_style(Color("1b2924"), Color("bda95b"), 1)
    )
    continue_button.add_theme_stylebox_override(
        "hover",
        _stage_battle_button_style(Color("22352d"), Color("e0c968"), 2)
    )
    continue_button.add_theme_stylebox_override(
        "pressed",
        _stage_battle_button_style(Color("15231e"), Color("c6b461"), 2)
    )
    continue_button.add_theme_stylebox_override(
        "focus",
        _stage_battle_button_style(Color("1b2924"), Color("e0c968"), 2)
    )


func _stage_battle_button_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(8)
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    return style
