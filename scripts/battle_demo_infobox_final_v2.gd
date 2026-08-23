extends "res://scripts/battle_demo_v22_runtime_completion_v1.gd"

# Final responsive attack-infobox layer.
#
# Semantic standardization lives in battle_demo_move_info_standard_v1.gd. This
# layer only solves the remaining layout problem: simple moves stay compact,
# complex/special moves may grow, and truly long explanations become scrollable
# instead of being clipped outside the battle command panel.

const INFOBOX_TEXT_HEIGHT_MIN: float = 54.0
const INFOBOX_TEXT_HEIGHT_MAX: float = 112.0
const INFOBOX_COMMAND_HEIGHT_BASE: float = 154.0
const INFOBOX_COMMAND_HEIGHT_MAX: float = 212.0
const INFOBOX_TEXT_PADDING: float = 8.0


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    _fit_attack_infobox_to_content()


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    _fit_attack_infobox_to_content()


func _set_log(text: String) -> void:
    super._set_log(text)
    _fit_attack_infobox_to_content()


func _fit_attack_infobox_to_content() -> void:
    if log_label == null:
        return

    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_label.fit_content = false
    log_label.scroll_following = false

    var natural_height: float = maxf(
        INFOBOX_TEXT_HEIGHT_MIN,
        float(log_label.get_content_height()) + INFOBOX_TEXT_PADDING
    )
    var shown_height: float = _infobox_shown_text_height(natural_height)
    log_label.custom_minimum_size.y = shown_height
    log_label.scroll_active = natural_height > INFOBOX_TEXT_HEIGHT_MAX + 0.5

    var content: VBoxContainer = log_label.get_parent() as VBoxContainer
    if content == null:
        return
    var command: PanelContainer = content.get_parent() as PanelContainer
    if command == null:
        return

    # Grow the command panel upward only as much as the visible text needs.
    # Very long special cases stop at the cap and use the RichTextLabel scroll.
    var extra_height: float = maxf(0.0, shown_height - INFOBOX_TEXT_HEIGHT_MIN)
    var command_height: float = clampf(
        INFOBOX_COMMAND_HEIGHT_BASE + extra_height,
        INFOBOX_COMMAND_HEIGHT_BASE,
        INFOBOX_COMMAND_HEIGHT_MAX
    )
    command.offset_top = -command_height


func _infobox_shown_text_height(natural_height: float) -> float:
    return clampf(
        natural_height,
        INFOBOX_TEXT_HEIGHT_MIN,
        INFOBOX_TEXT_HEIGHT_MAX
    )
