extends "res://scripts/battle_demo_infobox_final_v2.gd"

# Serializes floating combat feedback per Pokemon.
#
# Several mechanics can emit multiple player-facing labels in the same action.
# Showing all of them at the same card position makes them unreadable. This
# layer keeps exactly one floating label active per combatant and plays further
# labels in FIFO order. Different combatants keep independent queues, so useful
# simultaneous feedback on attacker and target is preserved.

const FEEDBACK_QUEUE_WINDOW_SECONDS: float = 2.35
const FEEDBACK_QUEUE_MAX_LABEL_SECONDS: float = 2.15
const FEEDBACK_QUEUE_MIN_LABEL_SECONDS: float = 0.58
const FEEDBACK_QUEUE_GAP_SECONDS: float = 0.06

var _tf_feedback_queues: Dictionary = {}
var _tf_feedback_busy: Dictionary = {}
var _tf_feedback_batch_duration: Dictionary = {}
var _tf_feedback_generation: int = 0


func _start_battle() -> void:
    # Invalidate callbacks from a previous battle before rebuilding combat UI.
    _tf_feedback_generation += 1
    _tf_feedback_queues.clear()
    _tf_feedback_busy.clear()
    _tf_feedback_batch_duration.clear()
    super._start_battle()


func _spawn_feedback_label(combatant: Dictionary, text: String, color: Color) -> void:
    var player_text: String = _tf_prepare_feedback_text(combatant, text)
    if player_text.strip_edges().is_empty():
        return

    # Preserve every inherited non-visual side effect (especially the custom
    # feedback capture used by deferred KEIN-EFFEKT validation), but suppress
    # the old renderer itself. Rendering is handled by this queue below.
    _tf_run_inherited_feedback_side_effects(combatant, player_text, color)

    if battle_panel == null:
        return

    var combatant_id: String = str(combatant.get("id", ""))
    if combatant_id.is_empty():
        _tf_render_feedback_label(
            combatant,
            player_text,
            color,
            FEEDBACK_QUEUE_MAX_LABEL_SECONDS,
            "",
            _tf_feedback_generation
        )
        return

    var queue_value: Variant = _tf_feedback_queues.get(combatant_id, [])
    var queue: Array = queue_value if queue_value is Array else []
    queue.append({
        "combatant": combatant,
        "text": player_text,
        "color": color
    })
    _tf_feedback_queues[combatant_id] = queue

    if bool(_tf_feedback_busy.get(combatant_id, false)):
        return

    # Defer one call-stack step so labels emitted by one resolved action are
    # collected into the same batch. This gives short bursts an adaptive speed
    # while keeping them inside the normal action-feedback window.
    _tf_feedback_busy[combatant_id] = true
    call_deferred(
        "_tf_begin_feedback_batch",
        combatant_id,
        _tf_feedback_generation
    )


func _tf_prepare_feedback_text(combatant: Dictionary, text: String) -> String:
    # Keep the V22 final vocabulary guard that previously sat at the visual
    # entry point. The queue must never reintroduce historical wording.
    var player_text: String = _v22_standardize_player_text(text)

    # Preserve the central type-immunity correction from the inherited V22
    # layer. A stale specialist label must not claim WIRKUNGSLOS when the
    # authoritative TypeSystem says the direct-damage move has a multiplier.
    var upper: String = player_text.to_upper()
    var looks_like_old_type_immunity: bool = (
        upper.contains("WIRKUNGSLOS")
        or upper == "KEINE WIRKUNG"
        or upper == "KEINE WIRKUNG."
    )
    if looks_like_old_type_immunity and _tf_current_move_is_direct_damage():
        var move: Dictionary = _move_data(_feedback_active_move_id)
        var move_type: String = str(move.get("type", ""))
        if TypeSystem.is_known_type(move_type):
            var multiplier: float = TypeSystem.get_multiplier(
                move_type,
                _type_array(combatant.get("types", []))
            )
            if not is_zero_approx(multiplier):
                var central_feedback: String = TypeSystem.get_feedback_text(multiplier).strip_edges()
                if central_feedback.is_empty():
                    return ""
                player_text = central_feedback.trim_suffix(".").trim_suffix("!").to_upper()

    return player_text


func _tf_run_inherited_feedback_side_effects(
    combatant: Dictionary,
    text: String,
    color: Color
) -> void:
    # The legacy renderer exits immediately when battle_panel is null. Temporarily
    # hiding the panel therefore lets the complete inherited override chain run
    # its text guards/capture logic without creating a second visual label.
    var saved_battle_panel: Variant = battle_panel
    battle_panel = null
    super._spawn_feedback_label(combatant, text, color)
    battle_panel = saved_battle_panel


func _tf_begin_feedback_batch(combatant_id: String, generation: int) -> void:
    if generation != _tf_feedback_generation:
        _tf_clear_feedback_target(combatant_id)
        return

    var queue_value: Variant = _tf_feedback_queues.get(combatant_id, [])
    var queue: Array = queue_value if queue_value is Array else []
    if queue.is_empty():
        _tf_clear_feedback_target(combatant_id)
        return

    _tf_feedback_batch_duration[combatant_id] = _tf_feedback_duration(queue.size())
    _tf_play_next_feedback_label(combatant_id, generation)


func _tf_feedback_duration(label_count: int) -> float:
    var count: int = maxi(1, label_count)
    var gap_total: float = FEEDBACK_QUEUE_GAP_SECONDS * float(maxi(0, count - 1))
    var available: float = maxf(
        FEEDBACK_QUEUE_MIN_LABEL_SECONDS,
        FEEDBACK_QUEUE_WINDOW_SECONDS - gap_total
    )
    return clampf(
        available / float(count),
        FEEDBACK_QUEUE_MIN_LABEL_SECONDS,
        FEEDBACK_QUEUE_MAX_LABEL_SECONDS
    )


func _tf_play_next_feedback_label(combatant_id: String, generation: int) -> void:
    if generation != _tf_feedback_generation or battle_panel == null:
        _tf_clear_feedback_target(combatant_id)
        return

    var queue_value: Variant = _tf_feedback_queues.get(combatant_id, [])
    var queue: Array = queue_value if queue_value is Array else []
    if queue.is_empty():
        _tf_clear_feedback_target(combatant_id)
        return

    var item_value: Variant = queue.pop_front()
    _tf_feedback_queues[combatant_id] = queue
    if not (item_value is Dictionary):
        _tf_feedback_label_finished(combatant_id, generation)
        return

    var item: Dictionary = item_value
    var combatant_value: Variant = item.get("combatant", {})
    if not (combatant_value is Dictionary):
        _tf_feedback_label_finished(combatant_id, generation)
        return

    var color_value: Variant = item.get("color", Color("ffeaa2"))
    var item_color: Color = color_value if color_value is Color else Color("ffeaa2")
    var duration: float = float(
        _tf_feedback_batch_duration.get(
            combatant_id,
            FEEDBACK_QUEUE_MAX_LABEL_SECONDS
        )
    )
    _tf_render_feedback_label(
        combatant_value as Dictionary,
        str(item.get("text", "")),
        item_color,
        duration,
        combatant_id,
        generation
    )


func _tf_render_feedback_label(
    combatant: Dictionary,
    text: String,
    color: Color,
    duration: float,
    combatant_id: String,
    generation: int
) -> void:
    var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
    if not (ui_value is Dictionary):
        _tf_feedback_label_finished(combatant_id, generation)
        return

    var ui: Dictionary = ui_value
    var card: Control = ui.get("card") as Control
    if card == null:
        _tf_feedback_label_finished(combatant_id, generation)
        return

    var label: Label = Label.new()
    label.text = text
    label.position = card.global_position + Vector2(8.0, -19.0)
    label.z_index = 60
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color("18211f"))
    label.add_theme_constant_override("outline_size", 4)
    battle_panel.add_child(label)

    var fade_seconds: float = minf(0.38, maxf(0.18, duration * 0.32))
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(
        label,
        "position:y",
        label.position.y - FEEDBACK_RISE_PIXELS,
        duration
    )
    tween.tween_property(label, "modulate:a", 0.0, fade_seconds).set_delay(
        maxf(0.0, duration - fade_seconds)
    )
    tween.chain().tween_callback(label.queue_free)

    if combatant_id.is_empty():
        return

    tween.chain().tween_interval(FEEDBACK_QUEUE_GAP_SECONDS)
    tween.chain().tween_callback(
        _tf_feedback_label_finished.bind(combatant_id, generation)
    )


func _tf_feedback_label_finished(combatant_id: String, generation: int) -> void:
    if combatant_id.is_empty():
        return
    if generation != _tf_feedback_generation:
        _tf_clear_feedback_target(combatant_id)
        return

    var queue_value: Variant = _tf_feedback_queues.get(combatant_id, [])
    var queue: Array = queue_value if queue_value is Array else []
    if queue.is_empty():
        _tf_clear_feedback_target(combatant_id)
        return

    _tf_play_next_feedback_label(combatant_id, generation)


func _tf_clear_feedback_target(combatant_id: String) -> void:
    _tf_feedback_queues.erase(combatant_id)
    _tf_feedback_busy.erase(combatant_id)
    _tf_feedback_batch_duration.erase(combatant_id)
