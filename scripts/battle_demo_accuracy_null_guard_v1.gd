extends "res://scripts/battle_demo_gen2_missing_moves_v24_25_v1.gd"

# Runtime hotfix for per-target accuracy handling.
# Some move states intentionally use accuracy = null to mean "skip the normal
# accuracy roll". Godot cannot construct float(null), so the inherited
# Squirtle-family helper must guard nullable values before conversion.

var _status_action_block_active: bool = false


func _sf_prepare_per_target_accuracy(actor: Dictionary, move: Dictionary, targets: Array) -> void:
    _sf_filtered_target_ids.clear()

    var accuracy_value: Variant = move.get("accuracy", null)
    if accuracy_value == null:
        _sf_filter_targets = false
        return

    _sf_filter_targets = true
    var base_accuracy: float = float(accuracy_value)

    var actor_accuracy_value: Variant = actor.get("accuracy_mult", 1.0)
    var actor_multiplier: float = 1.0 if actor_accuracy_value == null else maxf(0.0, float(actor_accuracy_value))
    actor_multiplier *= maxf(0.0, _combined_timed_modifier(actor, "accuracy_mod"))

    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_multiplier: float = 1.0
        if int(target.get("action_serial", 0)) < int(target.get("db_incoming_accuracy_expires", 0)):
            var incoming_accuracy_value: Variant = target.get("db_incoming_accuracy_mult", 1.0)
            if incoming_accuracy_value != null:
                target_multiplier = maxf(0.0, float(incoming_accuracy_value))

        var hit_chance: float = clampf(base_accuracy * actor_multiplier * target_multiplier / 100.0, 0.0, 1.0)
        if randf() <= hit_chance:
            _sf_filtered_target_ids[str(target.get("id", ""))] = true

    if _sf_filtered_target_ids.is_empty() and not targets.is_empty():
        move["accuracy"] = 0.0
        _sf_filter_targets = false
    else:
        move["accuracy"] = null


# Status-action feedback integrity.
# The inherited combat core already owns the actual probabilities and damage:
# confusion uses its central self-hit roll and paralysis its central 25% action
# loss. We only surface those already-resolved outcomes on the acting Pokémon.
# Freeze already has its own dedicated popup in battle_demo_zf_status_v1.gd.
func _execute_move(actor: Dictionary, move_id: String) -> void:
    _status_action_block_active = false
    super._execute_move(actor, move_id)
    _status_action_block_active = false


func _set_log(text: String) -> void:
    var paralysis_block: bool = text.contains(" ist paralysiert und kann nicht handeln.")
    var confusion_self_hit: bool = text.contains(" ist verwirrt und verletzt sich selbst")
    var freeze_block: bool = text.contains(" ist eingefroren und kann nicht handeln.")

    if paralysis_block or confusion_self_hit or freeze_block:
        _status_action_block_active = true

    if paralysis_block:
        var paralysis_actor: Dictionary = _status_feedback_actor_from_log(text)
        if not paralysis_actor.is_empty():
            _spawn_feedback_label(paralysis_actor, "⚡ PARALYSIERT", Color("f4d45e"))
    elif confusion_self_hit:
        var confusion_actor: Dictionary = _status_feedback_actor_from_log(text)
        if not confusion_actor.is_empty():
            _spawn_feedback_label(confusion_actor, "😵 VERWIRRT", Color("d8c7ff"))

    super._set_log(text)


func _spawn_feedback_label(combatant: Dictionary, text: String, color: Color) -> void:
    if _status_action_block_active and _is_status_block_no_effect_feedback(text):
        return
    super._spawn_feedback_label(combatant, text, color)


func _status_feedback_actor_from_log(text: String) -> Dictionary:
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if text.begins_with(_actor_name(candidate) + " "):
            return candidate
    return {}


func _is_status_block_no_effect_feedback(text: String) -> bool:
    var normalized: String = text.strip_edges().to_upper()
    return (
        normalized.contains("KEINE WIRKUNG")
        or normalized.contains("WIRKUNGSLOS")
        or normalized.contains("NO EFFECT")
    )
