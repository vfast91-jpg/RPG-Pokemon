extends "res://scripts/battle_demo_periodic_wait_fix.gd"

# Final player-facing cleanup for attack previews/tooltips.
# Internal mechanic ids must never leak into the UI. Older summary layers can
# turn ids such as db_break_protect into "db break protect"; translate both the
# underscore and spaced variants through the canonical effect registry.

const TFEffectRegistry = preload("res://scripts/battle/move_effect_registry.gd")


func _move_tooltip(move: Dictionary) -> String:
    return _translate_internal_effect_labels(super._move_tooltip(move))


func _compact_effect_summary(move: Dictionary) -> String:
    return _translate_internal_effect_labels(super._compact_effect_summary(move))


func _player_text_cleanup(source: String) -> String:
    return _translate_internal_effect_labels(super._player_text_cleanup(source))


func _translate_internal_effect_labels(source: String) -> String:
    var text: String = source

    for kind_value: Variant in TFEffectRegistry.EFFECTS.keys():
        var kind: String = str(kind_value)
        if not kind.contains("_"):
            continue

        var label: String = TFEffectRegistry.player_label_for_effect(kind)
        if label.is_empty():
            continue

        text = text.replace(kind, label)
        text = text.replace(kind.replace("_", " "), label)

    return text
