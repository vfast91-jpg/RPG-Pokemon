extends "res://scripts/battle_demo_periodic_wait_fix.gd"

# Final player-facing attack-information layer.
#
# The info strip must explain what a move really does. It is not enough to
# translate internal mechanic ids. Complex mechanics therefore get a canonical,
# player-readable summary that reflects the current runtime behavior. The normal
# preview still supplies type, category, power, accuracy, target and AP timing.

const TFEffectRegistry = preload("res://scripts/battle/move_effect_registry.gd")

const INFOBOX_EFFECT_OVERRIDES: Dictionary = {
    "feint": (
        "Schaden · entfernt einen vorhandenen Schutzschild und trifft trotzdem "
        + "· funktioniert auch ohne Schutzschild"
    ),
    "safeguard": (
        "Alle aktiven Verbündeten: jeweils 3 eigene Aktionen Schutz vor neuen "
        + "Hauptstatuszuständen · vorhandene Status bleiben · Reserve nicht betroffen"
    ),
    "rage_powder": (
        "3 eigene Aktionen: gegnerische Einzelzielattacken werden auf den Anwender "
        + "umgelenkt · überschreibt dafür die Aggro-Zielregel · Flächenattacken nicht "
        + "· endet bei K.O."
    ),
    "bug_bite": (
        "Schaden · Beereninteraktion ist noch nicht aktiv (Itemsystem fehlt) "
        + "· aktuell normale Stärke-60-Schadensattacke"
    )
}


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    if log_label == null:
        return

    var text: String = _sanitize_player_infobox(log_label.text)
    var special_bits: Array[String] = []
    var priority: int = int(round(float(move.get("priority", 0))))

    if priority != 0 and not text.contains("Priorität"):
        special_bits.append("Priorität " + ("+" if priority > 0 else "") + str(priority))
    if bool(move.get("opening", false)) and not text.contains("Runde 0"):
        special_bits.append("Runde 0")
    if bool(move.get("area", false)) and not text.contains("Flächenwirkung"):
        special_bits.append("Flächenwirkung")

    if not special_bits.is_empty():
        var lines: PackedStringArray = text.split("\n")
        if not lines.is_empty():
            lines[0] = lines[0] + " · " + " · ".join(special_bits)
            text = "\n".join(lines)

    log_label.text = text


func _move_tooltip(move: Dictionary) -> String:
    return _sanitize_player_infobox(super._move_tooltip(move))


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if INFOBOX_EFFECT_OVERRIDES.has(move_id):
        return str(INFOBOX_EFFECT_OVERRIDES[move_id])
    return _sanitize_player_infobox(super._compact_effect_summary(move))


func _player_text_cleanup(source: String) -> String:
    return _sanitize_player_infobox(super._player_text_cleanup(source))


func _sanitize_player_infobox(source: String) -> String:
    var text: String = _translate_internal_effect_labels(source)
    var kept := PackedStringArray()

    # Implementation metadata must never be visible to the player. All useful
    # behavior is represented by the normal fields or the compact effect summary.
    for line: String in text.split("\n"):
        var clean: String = line.strip_edges()
        var lower: String = clean.to_lower()
        if clean.begins_with("Datenbank-Effekt:"):
            continue
        if lower.contains("effect_source"):
            continue
        kept.append(line)

    return "\n".join(kept).strip_edges()


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
