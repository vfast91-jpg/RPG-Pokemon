extends "res://scripts/demo_route_events_v1.gd"

# Phase H compatibility cleanup.
# Several older route layers still contain Direct/Dangerous/+25%-XP callbacks
# because later, valuable UI/evolution fixes inherit through them. Deleting
# those files wholesale would risk unrelated regressions. This active top layer
# makes the obsolete entry points unreachable and harmless while preserving the
# mature inherited systems beneath them.
#
# This final layer also owns the compact Fangwiese replacement layout. The base
# route gives the event text all remaining vertical space and an older swap UI
# explicitly disables its scrollbar. On smaller windows that can push slot 4
# below the visible area. Keep the normal roomy route layout everywhere else,
# but make capture decisions compact and reliably scrollable.

const DEFAULT_EVENT_LABEL_HEIGHT: float = 58.0
const CAPTURE_EVENT_LABEL_HEIGHT: float = 44.0
const CAPTURE_PREVIEW_MAX_HEIGHT: float = 100.0
const REPLACEMENT_SCROLL_HEIGHT: float = 86.0


func _show_stage_choices(message: String = "") -> void:
    stage_xp_multiplier = 1.0
    super._show_stage_choices(message)
    _set_capture_layout_compact(false)


func _show_current_capture_offer() -> void:
    super._show_current_capture_offer()
    _set_capture_layout_compact(true)
    _compact_capture_preview_card()


func _show_replace_choices() -> void:
    if pending_capture.is_empty():
        return

    # Reuse the established replacement buttons/callbacks, then only correct
    # their presentation in this active top layer.
    super._show_replace_choices()
    _set_capture_layout_compact(true)

    # Keep the found Pokémon visible while choosing whom to replace. Put its
    # preview directly beneath the Fangwiese text instead of below the choices.
    var preview: Node = capture_actions.get_node_or_null("CapturePokemonPreview")
    if preview == null:
        _add_capture_preview_card()
        preview = capture_actions.get_node_or_null("CapturePokemonPreview")
    if preview != null:
        capture_actions.move_child(preview, 0)
        _compact_capture_preview_card()

    # The legacy replacement UI deliberately disabled scrolling because four
    # rows theoretically fit. In the real route layout they can be clipped, so
    # give the list a fixed compact viewport and enable vertical scrolling.
    for child: Node in capture_actions.get_children():
        if child is ScrollContainer:
            var choices_scroll := child as ScrollContainer
            choices_scroll.custom_minimum_size = Vector2(0.0, REPLACEMENT_SCROLL_HEIGHT)
            choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            choices_scroll.size_flags_vertical = Control.SIZE_FILL
            choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
            choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
            choices_scroll.scroll_vertical = 0
            break


func _set_capture_layout_compact(compact: bool) -> void:
    if event_label == null:
        return

    if compact:
        event_label.custom_minimum_size = Vector2(0.0, CAPTURE_EVENT_LABEL_HEIGHT)
        # Do not let this RichTextLabel consume all spare route-panel height.
        # Its own scrollbar remains available if a future capture message grows.
        event_label.size_flags_vertical = Control.SIZE_FILL
    else:
        event_label.custom_minimum_size = Vector2(0.0, DEFAULT_EVENT_LABEL_HEIGHT)
        event_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _compact_capture_preview_card() -> void:
    if capture_actions == null:
        return
    var card_node: Node = capture_actions.get_node_or_null("CapturePokemonPreview")
    if not (card_node is Control):
        return

    var card := card_node as Control
    card.custom_minimum_size = Vector2(
        card.custom_minimum_size.x,
        minf(card.custom_minimum_size.y, CAPTURE_PREVIEW_MAX_HEIGHT)
        if card.custom_minimum_size.y > 0.0
        else CAPTURE_PREVIEW_MAX_HEIGHT
    )
    card.size_flags_vertical = Control.SIZE_FILL


func _choose_path(choice: Dictionary) -> void:
    var kind: String = str(choice.get("kind", ""))
    if kind == EVENT_DIRECT or kind == EVENT_DANGEROUS:
        stage_xp_multiplier = 1.0
        _show_stage_choices(
            "Dieser alte Weg gehört nicht mehr zum aktiven Routensystem. "
            + "Die drei Wegoptionen wurden neu ausgewürfelt."
        )
        return

    stage_xp_multiplier = 1.0
    super._choose_path(choice)


func _decline_tm_reward() -> void:
    # Stale inherited buttons/callbacks must never restore the retired +25%-EP
    # consolation reward. The active Fundstelle always returns to its six-choice
    # selection instead.
    stage_xp_multiplier = 1.0
    if _fundstelle_active:
        _show_fundstelle_options()
    else:
        _show_stage_choices("Die alte +25%-EP-TM-Alternative existiert nicht mehr.")


func _decline_pending_capture() -> void:
    # The active Fangwiese uses up to three explicit searches and no XP
    # consolation. If a stale inherited callback reaches this method, interpret
    # it as leaving the current Fangwiese without a capture.
    stage_xp_multiplier = 1.0
    if not pending_capture.is_empty():
        _leave_capture_without_capture()
