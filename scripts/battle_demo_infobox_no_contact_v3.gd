extends "res://scripts/battle_demo_v22_effective_speed_integrity_v1.gd"

# Final player-facing infobox cleanup.
#
# The battle info area is deliberately compact during normal play: it always
# shows only two text lines. Longer move explanations can be opened explicitly
# with a clearly labelled control and closed again afterwards. Generic battle
# messages such as Warten never show that control.
#
# While expanded, the command panel becomes a temporary foreground overlay so
# Pokemon sprites, roster/status cards and their hover content can never cover
# the explanation. Collapsing restores the panel's original stacking/input
# behaviour.

const INFOBOX_COLLAPSED_TEXT_HEIGHT: float = 36.0
const INFOBOX_EXPANDED_TEXT_HEIGHT_MAX: float = 220.0
const INFOBOX_COLLAPSED_COMMAND_HEIGHT: float = 136.0
const INFOBOX_EXPANDED_COMMAND_HEIGHT_MAX: float = 320.0
const INFOBOX_COMPACT_TEXT_PADDING: float = 4.0
const INFOBOX_OVERFLOW_TOLERANCE: float = 4.0
const INFOBOX_EXPANDED_Z_INDEX: int = 900

var _attack_infobox_expanded: bool = false
var _attack_infobox_toggle: Button = null
var _attack_infobox_is_move_preview: bool = false
var _attack_infobox_command: PanelContainer = null
var _attack_infobox_command_base_z_index: int = 0
var _attack_infobox_command_base_mouse_filter: int = Control.MOUSE_FILTER_STOP
var _attack_infobox_command_state_captured: bool = false


func _standard_feature_bits(move: Dictionary) -> Array[String]:
    var bits: Array[String] = super._standard_feature_bits(move)
    bits.erase("Kontakt")
    return bits


func _summary_needs_player_fallback(move: Dictionary, text: String) -> bool:
    # Never replace a concise, player-readable special summary with the complete
    # database prose just because the summary happens to be short. That was what
    # made attacks such as Schlecker balloon to several lines.
    #
    # A bare "Schaden" is different: for moves whose real rule lives in runtime
    # metadata (dynamic power, recoil conditions, etc.) it contains no special
    # information at all. In that case use the player-facing description.
    # Likewise, newly added family prefixes must never leak as labels such as
    # "ad modifier" into the combat UI.
    if _contains_internal_infobox_token(text) or _contains_untranslated_runtime_family_label(text):
        return true
    if text.is_empty():
        return _move_has_complex_player_rule(move)
    if (
        text.strip_edges() == "Schaden"
        and _move_has_complex_player_rule(move)
        and _move_has_readable_player_fallback(move)
    ):
        return true
    return false


func _contains_untranslated_runtime_family_label(source: String) -> bool:
    var lower: String = source.strip_edges().to_lower()
    return lower.begins_with("ad_") or lower.begins_with("ad ")


func _move_has_readable_player_fallback(move: Dictionary) -> bool:
    if not _clean_player_fallback_fragment(str(move.get("description", ""))).is_empty():
        return true
    return _has_player_special_rules(move)


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    # A newly inspected move always starts in the compact everyday view. The
    # inherited preview may call _set_log(), so mark the text as a move preview
    # again only after that inherited work is complete.
    _attack_infobox_expanded = false
    _attack_infobox_is_move_preview = false
    super._preview_move(move_id, move, touch_confirm)
    _attack_infobox_is_move_preview = true
    _fit_attack_infobox_to_content()


func _set_log(text: String) -> void:
    # Generic battle messages (including Warten) are not expandable move
    # descriptions. They must never advertise hidden information that does not
    # exist behind the control.
    _attack_infobox_expanded = false
    _attack_infobox_is_move_preview = false
    super._set_log(text)


func _fit_attack_infobox_to_content() -> void:
    if log_label == null:
        return

    _ensure_attack_infobox_toggle()

    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_label.fit_content = false
    log_label.scroll_following = false

    var natural_height: float = maxf(
        INFOBOX_COLLAPSED_TEXT_HEIGHT,
        float(log_label.get_content_height()) + INFOBOX_COMPACT_TEXT_PADDING
    )
    var has_hidden_content: bool = _attack_infobox_has_hidden_content(natural_height)

    # Do not leave an expanded empty/short box behind when the text changes.
    if not has_hidden_content:
        _attack_infobox_expanded = false

    var shown_height: float = _infobox_shown_text_height(natural_height)
    log_label.custom_minimum_size.y = shown_height
    log_label.scroll_active = (
        _attack_infobox_expanded
        and natural_height > INFOBOX_EXPANDED_TEXT_HEIGHT_MAX + 0.5
    )

    _sync_attack_infobox_toggle(has_hidden_content)

    var content: VBoxContainer = log_label.get_parent() as VBoxContainer
    if content == null:
        return
    var command: PanelContainer = content.get_parent() as PanelContainer
    if command == null:
        return

    _sync_attack_infobox_foreground(command)

    var command_height: float = INFOBOX_COLLAPSED_COMMAND_HEIGHT
    if _attack_infobox_expanded:
        var extra_height: float = maxf(
            0.0,
            shown_height - INFOBOX_COLLAPSED_TEXT_HEIGHT
        )
        command_height = clampf(
            INFOBOX_COLLAPSED_COMMAND_HEIGHT + extra_height,
            INFOBOX_COLLAPSED_COMMAND_HEIGHT,
            INFOBOX_EXPANDED_COMMAND_HEIGHT_MAX
        )
    command.offset_top = -command_height


func _sync_attack_infobox_foreground(command: PanelContainer) -> void:
    if command == null:
        return

    if (
        not _attack_infobox_command_state_captured
        or _attack_infobox_command != command
    ):
        _attack_infobox_command = command
        _attack_infobox_command_base_z_index = command.z_index
        _attack_infobox_command_base_mouse_filter = int(command.mouse_filter)
        _attack_infobox_command_state_captured = true

    command.z_index = _attack_infobox_overlay_z_index(
        _attack_infobox_command_base_z_index
    )
    command.mouse_filter = _attack_infobox_overlay_mouse_filter(
        _attack_infobox_command_base_mouse_filter
    )


func _attack_infobox_overlay_z_index(base_z_index: int) -> int:
    return INFOBOX_EXPANDED_Z_INDEX if _attack_infobox_expanded else base_z_index


func _attack_infobox_overlay_mouse_filter(base_mouse_filter: int) -> int:
    return (
        Control.MOUSE_FILTER_STOP
        if _attack_infobox_expanded
        else base_mouse_filter
    )


func _attack_infobox_has_hidden_content(natural_height: float) -> bool:
    return (
        _attack_infobox_is_move_preview
        and natural_height
        > INFOBOX_COLLAPSED_TEXT_HEIGHT + INFOBOX_OVERFLOW_TOLERANCE
    )


func _infobox_shown_text_height(natural_height: float) -> float:
    if not _attack_infobox_expanded:
        return INFOBOX_COLLAPSED_TEXT_HEIGHT
    return clampf(
        natural_height,
        INFOBOX_COLLAPSED_TEXT_HEIGHT,
        INFOBOX_EXPANDED_TEXT_HEIGHT_MAX
    )


func _ensure_attack_infobox_toggle() -> void:
    if log_label == null:
        return
    if _attack_infobox_toggle != null and is_instance_valid(_attack_infobox_toggle):
        return

    var toggle: Button = Button.new()
    toggle.name = "AttackInfoExpandToggle"
    toggle.flat = true
    toggle.focus_mode = Control.FOCUS_NONE
    toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    toggle.tooltip_text = "Mehr anzeigen"
    toggle.anchor_left = 1.0
    toggle.anchor_right = 1.0
    toggle.anchor_top = 0.0
    toggle.anchor_bottom = 0.0
    toggle.offset_left = -136.0
    toggle.offset_right = -4.0
    toggle.offset_top = 2.0
    toggle.offset_bottom = 29.0
    toggle.alignment = HORIZONTAL_ALIGNMENT_RIGHT
    toggle.add_theme_font_size_override("font_size", 11)
    toggle.z_index = 20
    toggle.pressed.connect(_toggle_attack_infobox_expanded)
    log_label.add_child(toggle)
    _attack_infobox_toggle = toggle


func _sync_attack_infobox_toggle(has_hidden_content: bool) -> void:
    if _attack_infobox_toggle == null or not is_instance_valid(_attack_infobox_toggle):
        return
    _attack_infobox_toggle.visible = has_hidden_content
    _attack_infobox_toggle.text = _attack_infobox_toggle_text()
    _attack_infobox_toggle.tooltip_text = (
        "Weniger anzeigen" if _attack_infobox_expanded else "Mehr anzeigen"
    )


func _attack_infobox_toggle_text() -> String:
    # Explicit wording is intentional: the control must be understandable even
    # to young players who do not already know what a bare chevron means.
    return "Weniger anzeigen ▲" if _attack_infobox_expanded else "Mehr anzeigen ▼"


func _toggle_attack_infobox_expanded() -> void:
    if _attack_infobox_toggle == null or not is_instance_valid(_attack_infobox_toggle):
        return
    if not _attack_infobox_toggle.visible:
        return
    _attack_infobox_expanded = not _attack_infobox_expanded
    _fit_attack_infobox_to_content()
