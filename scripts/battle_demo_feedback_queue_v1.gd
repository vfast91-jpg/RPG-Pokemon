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
    # battle_demo_feedback_polish normally captures precise mechanic labels in
    # its own override before delegating to the visual renderer. Because this
    # final queue layer delays rendering, capture that information immediately
    # so deferred KEIN-EFFEKT checks keep their existing behavior.
    _tf_capture_custom_feedback(combatant, text)

    if battle_panel == null:
        return

    var combatant_id: String = str(combatant.get("id", ""))
    if combatant_id.is_empty():
        _tf_render_feedback_label(
            combatant,
            text,
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
        "text": text,
        "color": color
    })
    _tf_feedback_queues[combatant_id] = queue

    if bool(_tf_feedback_busy.get(combatant_id, false)):
        return

    # Defer one frame/call-stack step so labels emitted by one resolved action
    # are collected into the same batch. That lets us choose a readable speed
    # while still fitting the usual 2.5-second action-feedback window.
    _tf_feedback_busy[combatant_id] = true
    call_deferred(
        "_tf_begin_feedback_batch",
        combatant_id,
        _tf_feedback_generation
    )


func _tf_capture_custom_feedback(combatant: Dictionary, text: String) -> void:
    if not _feedback_should_capture_custom_label(text):
        return

    var target_id: String = str(combatant.get("id", ""))
    if target_id.is_empty():
        return

    var labels_value: Variant = _feedback_custom_labels.get(target_id, [])
    var labels: Array = labels_value if labels_value is Array else []
    if not labels.has(text):
        labels.append(text)
    _feedback_custom_labels[target_id] = labels


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

    var duration: float = float(
        _tf_feedback_batch_duration.get(
            combatant_id,
            FEEDBACK_QUEUE_MAX_LABEL_SECONDS
        )
    )
    _tf_render_feedback_label(
        combatant_value as Dictionary,
        str(item.get("text", "")),
        item.get("color", Color("ffeaa2")) as Color,
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
