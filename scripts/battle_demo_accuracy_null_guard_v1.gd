extends "res://scripts/battle_demo_gen2_missing_moves_v24_25_v1.gd"

# Runtime hotfix for per-target accuracy handling.
# Some move states intentionally use accuracy = null to mean "skip the normal
# accuracy roll". Godot cannot construct float(null), so the inherited
# Squirtle-family helper must guard nullable values before conversion.


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
