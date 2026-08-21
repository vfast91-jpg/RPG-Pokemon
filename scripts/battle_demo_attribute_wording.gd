extends "res://scripts/battle_demo_type_help.gd"

# Canonical player-facing vocabulary for combat effects.
# One mechanic = one visible name everywhere. Internal field names stay intact.
#
# Angriff          -> outgoing_damage_mod
# Verteidigung     -> incoming_damage_mod
# Genauigkeit      -> accuracy_mod
# Geschwindigkeit -> timed atb_cycle_mod
# Aktionsleiste    -> direct fill/knockback/pause
# Aktionszeit      -> one-shot recovery/AP timing


func _feedback_result(target: Dictionary, before: Dictionary) -> Dictionary:
    var result: Dictionary = super._feedback_result(target, before)
    var text: String = str(result.get("text", ""))

    # Floating feedback above a Pokemon must always name the real attribute and
    # show the exact currently active percentage, never a synonym like Schutz.
    var attack_after: float = _combined_timed_modifier(target, "outgoing_damage_mod")
    var attack_change: int = _compare_float(
        float(before.get("attack_mult", 1.0)),
        attack_after
    )
    if attack_change != 0:
        var attack_text: String = (
            "ANGRIFF " + _signed_percent_delta(attack_after) + " · 3 AKTIONEN"
        )
        text = text.replace("ANGRIFF ↑ · 3 AKTIONEN", attack_text)
        text = text.replace("ANGRIFF ↓ · 3 AKTIONEN", attack_text)

    var defense_after: float = _combined_timed_modifier(target, "incoming_damage_mod")
    var defense_change: int = _compare_float(
        float(before.get("defense_mult", 1.0)),
        defense_after
    )
    if defense_change != 0:
        var defense_text: String = (
            "VERTEIDIGUNG " + _signed_percent_delta(defense_after) + " · 3 AKTIONEN"
        )
        text = text.replace("SCHUTZ ↑ · 3 AKTIONEN", defense_text)
        text = text.replace("SCHUTZ ↓ · 3 AKTIONEN", defense_text)
        text = text.replace("VERTEIDIGUNG ↑ · 3 AKTIONEN", defense_text)
        text = text.replace("VERTEIDIGUNG ↓ · 3 AKTIONEN", defense_text)

    var accuracy_after: float = _combined_timed_modifier(target, "accuracy_mod")
    var accuracy_change: int = _compare_float(
        float(before.get("accuracy_mult", 1.0)),
        accuracy_after
    )
    if accuracy_change != 0:
        var accuracy_text: String = (
            "GENAUIGKEIT " + _signed_percent_delta(accuracy_after) + " · 3 AKTIONEN"
        )
        text = text.replace("GENAUIGKEIT ↑ · 3 AKTIONEN", accuracy_text)
        text = text.replace("GENAUIGKEIT ↓ · 3 AKTIONEN", accuracy_text)

    var cycle_after: float = _combined_timed_modifier(target, "atb_cycle_mod")
    var cycle_change: int = _compare_float(
        float(before.get("next_cycle", 1.0)),
        cycle_after
    )
    if cycle_change != 0:
        var speed_text: String = (
            "GESCHWINDIGKEIT "
            + _signed_percent_delta(_speed_multiplier_from_cycle(cycle_after))
            + " · 3 AKTIONEN"
        )
        text = text.replace("ATB LANGSAMER · 3 AKTIONEN", speed_text)
        text = text.replace("ATB SCHNELLER · 3 AKTIONEN", speed_text)
        text = text.replace("AKTIONSLEISTE LANGSAMER · 3 AKTIONEN", speed_text)
        text = text.replace("AKTIONSLEISTE SCHNELLER · 3 AKTIONEN", speed_text)
        text = text.replace("GESCHWINDIGKEIT ↑ · 3 AKTIONEN", speed_text)
        text = text.replace("GESCHWINDIGKEIT ↓ · 3 AKTIONEN", speed_text)

    # A direct knockback changes the bar itself, not the Speed attribute.
    var fill_before: float = float(before.get("atb", 0.0))
    var fill_after: float = float(target.get("atb", 0.0))
    if fill_after < fill_before - 0.5:
        var lost_fill: int = int(round(fill_before - fill_after))
        text = text.replace("ATB ↓", "AKTIONSLEISTE −%d%%" % lost_fill)
        text = text.replace("AKTIONSLEISTE ↓", "AKTIONSLEISTE −%d%%" % lost_fill)

    result["text"] = _canonical_attribute_text(text)
    return result


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var inherited: Array[String] = super._status_tokens(combatant)
    var result: Array[String] = []
    for token: String in inherited:
        var clean: String = _canonical_attribute_text(token)
        if clean.begins_with("ANG "):
            clean = "ANGRIFF " + clean.trim_prefix("ANG ")
        elif clean.begins_with("VER "):
            clean = "VERTEIDIGUNG " + clean.trim_prefix("VER ")
        elif clean.begins_with("GEN "):
            clean = "GENAUIGKEIT " + clean.trim_prefix("GEN ")
        elif clean.begins_with("GES "):
            clean = "GESCHWINDIGKEIT " + clean.trim_prefix("GES ")
        result.append(clean)
    return result


func _modifier_detail_text(kind: String, multiplier: float) -> String:
    match kind:
        "outgoing_damage_mod":
            return "Angriff " + _signed_percent_delta(multiplier)
        "incoming_damage_mod":
            return "Verteidigung " + _signed_percent_delta(multiplier)
        "accuracy_mod":
            return "Genauigkeit " + _signed_percent_delta(multiplier)
        "atb_cycle_mod":
            return (
                "Geschwindigkeit "
                + _signed_percent_delta(_speed_multiplier_from_cycle(multiplier))
            )
        _:
            return _canonical_attribute_text(super._modifier_detail_text(kind, multiplier))


func _detail_info(combatant: Dictionary) -> String:
    return _canonical_attribute_text(super._detail_info(combatant))


func _move_tooltip(move: Dictionary) -> String:
    return _canonical_attribute_text(super._move_tooltip(move))


func _compact_effect_summary(move: Dictionary) -> String:
    return _canonical_attribute_text(super._compact_effect_summary(move))


func _player_text_cleanup(source: String) -> String:
    return _canonical_attribute_text(super._player_text_cleanup(source))


func _canonical_attribute_text(source: String) -> String:
    var text: String = source

    # Never use Schutz as a synonym for the Defense attribute. Real guard/shield
    # mechanics keep their proper names such as Schutzschild or Lichtschild.
    text = text.replace("SCHUTZ ↑", "VERTEIDIGUNG ↑")
    text = text.replace("SCHUTZ ↓", "VERTEIDIGUNG ↓")
    text = text.replace("Schutz erhöht", "Verteidigung erhöht")
    text = text.replace("Schutz gesenkt", "Verteidigung gesenkt")

    # Attribute descriptions should say what changes, not describe the damage
    # consequence indirectly.
    text = text.replace("eingehender Schaden ↑", "Verteidigung ↓")
    text = text.replace("eingehender Schaden ↓", "Verteidigung ↑")
    text = text.replace("verursachter Schaden ↑", "Angriff ↑")
    text = text.replace("verursachter Schaden ↓", "Angriff ↓")

    # Natural-language move descriptions from older database entries.
    text = text.replace(
        "macht das Ziel verwundbarer",
        "senkt die Verteidigung des Ziels"
    )
    text = text.replace(
        "macht alle Gegner verwundbarer",
        "senkt die Verteidigung aller Gegner"
    )
    text = text.replace(
        "das Ziel stark verwundbar macht",
        "die Verteidigung des Ziels stark senkt"
    )
    text = text.replace(
        "das Ziel verwundbarer zu machen",
        "die Verteidigung des Ziels zu senken"
    )
    text = text.replace(
        "kann verwundbar machen",
        "kann die Verteidigung senken"
    )

    # Tempo/Initiative are not alternate names in player-facing combat text.
    text = text.replace("Initiative", "Geschwindigkeit")
    text = text.replace("Tempo erhöht", "Geschwindigkeit erhöht")
    text = text.replace("Tempo senkt", "Geschwindigkeit senkt")

    return text
