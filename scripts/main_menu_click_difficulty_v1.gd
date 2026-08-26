extends "res://scripts/main_menu_run_save_v1.gd"

# Difficulty selection is intentionally mouse/touch driven like the rest of
# the adventure UI. No card receives keyboard focus automatically and arrow-key
# navigation must not create a misleading golden preselection border.


func _make_difficulty_button(
    label_text: String,
    difficulty_key: String,
    level_offset: int,
    base_color: Color
) -> Button:
    var button: Button = super._make_difficulty_button(
        label_text,
        difficulty_key,
        level_offset,
        base_color
    )
    button.focus_mode = Control.FOCUS_NONE
    return button


func _show_difficulty_selector() -> void:
    if _difficulty_overlay == null:
        _confirm_difficulty("normal", 0)
        return

    _difficulty_overlay.visible = true
    if _difficulty_first_button != null:
        _difficulty_first_button.release_focus()
