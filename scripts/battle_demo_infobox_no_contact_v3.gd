extends "res://scripts/battle_demo_v22_effective_speed_integrity_v1.gd"

# Final player-facing infobox cleanup.
#
# - Contact is a combat-internal property and does not consume presentation space.
# - Short/two-line messages stay compact instead of reserving a third text line.
# - Long explanations stop growing into the battlefield and become scrollable.
# - A short, already-readable special-effect summary stays short; the verbose
#   description/special-rules fallback is reserved for missing or technical text.

const INFOBOX_COMPACT_TEXT_HEIGHT_MIN: float = 36.0
const INFOBOX_COMPACT_TEXT_HEIGHT_MAX: float = 76.0
const INFOBOX_COMPACT_COMMAND_HEIGHT_BASE: float = 136.0
const INFOBOX_COMPACT_COMMAND_HEIGHT_MAX: float = 176.0
const INFOBOX_COMPACT_TEXT_PADDING: float = 4.0


func _standard_feature_bits(move: Dictionary) -> Array[String]:
    var bits: Array[String] = super._standard_feature_bits(move)
    bits.erase("Kontakt")
    return bits


func _summary_needs_player_fallback(move: Dictionary, text: String) -> bool:
    # Never replace a concise, player-readable special summary with the complete
    # database prose just because the summary happens to be short. That was what
    # made attacks such as Schlecker balloon to several lines.
    if _contains_internal_infobox_token(text):
        return true
    if text.is_empty():
        return _move_has_complex_player_rule(move)
    return false


func _fit_attack_infobox_to_content() -> void:
    if log_label == null:
        return

    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_label.fit_content = false
    log_label.scroll_following = false

    # Two text lines are the compact baseline again. Only actual content makes
    # the box taller; very long special cases hit the cap and scroll internally.
    var natural_height: float = maxf(
        INFOBOX_COMPACT_TEXT_HEIGHT_MIN,
        float(log_label.get_content_height()) + INFOBOX_COMPACT_TEXT_PADDING
    )
    var shown_height: float = _infobox_shown_text_height(natural_height)
    log_label.custom_minimum_size.y = shown_height
    log_label.scroll_active = natural_height > INFOBOX_COMPACT_TEXT_HEIGHT_MAX + 0.5

    var content: VBoxContainer = log_label.get_parent() as VBoxContainer
    if content == null:
        return
    var command: PanelContainer = content.get_parent() as PanelContainer
    if command == null:
        return

    var extra_height: float = maxf(0.0, shown_height - INFOBOX_COMPACT_TEXT_HEIGHT_MIN)
    var command_height: float = clampf(
        INFOBOX_COMPACT_COMMAND_HEIGHT_BASE + extra_height,
        INFOBOX_COMPACT_COMMAND_HEIGHT_BASE,
        INFOBOX_COMPACT_COMMAND_HEIGHT_MAX
    )
    command.offset_top = -command_height


func _infobox_shown_text_height(natural_height: float) -> float:
    return clampf(
        natural_height,
        INFOBOX_COMPACT_TEXT_HEIGHT_MIN,
        INFOBOX_COMPACT_TEXT_HEIGHT_MAX
    )
