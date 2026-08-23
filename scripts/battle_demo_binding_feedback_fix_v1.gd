extends "res://scripts/battle_demo_v22_playability_gate_v1.gd"

# Final binding feedback correction.
#
# The shared binding runtime correctly owns duration and periodic damage, but its
# historical tick feedback was hard-coded to "WICKEL". That made Whirlpool (and
# every other binding move) look as if Wrap/Wickel were dealing the periodic
# damage. Preserve the generic binding mechanics and remember the actual source
# move only for player-facing feedback.


func _apply_binding(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var aggro: float = super._apply_binding(actor, target, mechanic)
    if aggro <= 0.0:
        return aggro

    var binding_value: Variant = target.get("binding_effect", {})
    if not (binding_value is Dictionary) or (binding_value as Dictionary).is_empty():
        return aggro

    var binding: Dictionary = binding_value
    var move: Dictionary = _active_special_move
    if move.is_empty() and not _v22_active_move_id.is_empty():
        move = _move_data(_v22_active_move_id)

    var move_id: String = str(move.get("id", _v22_active_move_id))
    var move_name: String = str(move.get("name", "")).strip_edges()
    var move_emoji: String = str(move.get("emoji", "")).strip_edges()

    binding["source_move_id"] = move_id
    binding["tick_label"] = _binding_tick_label(move_name, move_emoji)
    target["binding_effect"] = binding
    return aggro


func _binding_tick_label(move_name: String, move_emoji: String) -> String:
    if move_name.is_empty():
        return "🪢 FESSELUNG"
    var prefix: String = move_emoji if not move_emoji.is_empty() else "🪢"
    return (prefix + " " + move_name.to_upper()).strip_edges()


func _resolve_binding_tick(target: Dictionary) -> void:
    var binding_value: Variant = target.get("binding_effect", {})
    if not (binding_value is Dictionary) or (binding_value as Dictionary).is_empty():
        return
    var binding: Dictionary = binding_value

    if _effect_source_occupant(binding).is_empty():
        target["binding_effect"] = {}
        return

    var fraction: float = float(binding.get("damage_fraction", DEFAULT_BINDING_DAMAGE_FRACTION))
    var tick_label: String = str(binding.get("tick_label", "🪢 FESSELUNG"))
    _deal_periodic_damage(target, fraction, tick_label)

    var ticks_left: int = int(binding.get("ticks_left", 1)) - 1
    if ticks_left <= 0 or not bool(target.get("alive", false)):
        target["binding_effect"] = {}
    else:
        binding["ticks_left"] = ticks_left
        target["binding_effect"] = binding
