extends RefCounted
class_name MovePresenter

const Registry = preload("res://scripts/battle/move_effect_registry.gd")


static func modifier_text(kind: String, multiplier: float) -> String:
    var safe_multiplier: float = maxf(0.0001, multiplier)
    match kind:
        "outgoing_damage_mod":
            return "Angriff " + _signed_percent((safe_multiplier - 1.0) * 100.0)
        "incoming_damage_mod":
            # Current runtime stores this effect as a defense denominator.
            # Convert that storage value to the semantic defense change shown
            # to the player (e.g. 0.80 => Verteidigung -20 %).
            return "Verteidigung " + _signed_percent((safe_multiplier - 1.0) * 100.0)
        "accuracy_mod":
            return "Genauigkeit " + _signed_percent((safe_multiplier - 1.0) * 100.0)
        "atb_cycle_mod":
            return "Geschwindigkeit " + _signed_percent((1.0 / safe_multiplier - 1.0) * 100.0)
        _:
            var label: String = Registry.player_label_for_effect(kind)
            return label if not label.is_empty() else "Effekt"


static func modifier_token(kind: String, multiplier: float) -> String:
    var safe_multiplier: float = maxf(0.0001, multiplier)
    var value: float = 0.0
    var label: String = ""
    match kind:
        "outgoing_damage_mod":
            label = "ANG"
            value = safe_multiplier - 1.0
        "incoming_damage_mod":
            label = "DEF"
            value = safe_multiplier - 1.0
        "accuracy_mod":
            label = "GEN"
            value = safe_multiplier - 1.0
        "atb_cycle_mod":
            label = "GES"
            value = 1.0 / safe_multiplier - 1.0
        _:
            return ""
    return label + ("+" if value >= 0.0 else "-")


static func effect_summary(move: Dictionary) -> String:
    var pieces: Array[String] = []
    var mechanics_value: Variant = move.get("mechanics", move.get("effects", []))
    if not (mechanics_value is Array):
        return ""

    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        var kind: String = str(mechanic.get("kind", ""))
        if kind == "apply_status":
            kind = "status"

        var text: String = ""
        match kind:
            "damage":
                text = "Schaden"
            "status", "db_status":
                var status_id: String = str(mechanic.get("status", ""))
                text = Registry.player_label_for_status(status_id)
                if mechanic.has("chance") and float(mechanic.get("chance", 1.0)) < 0.999:
                    text = _percent(float(mechanic.get("chance", 0.0)) * 100.0) + " " + text
            "outgoing_damage_mod":
                text = "Angriff nach Statuswert"
            "incoming_damage_mod":
                text = "Verteidigung nach Statuswert"
            "accuracy_mod":
                text = "Genauigkeit nach Statuswert"
            "atb_cycle_mod":
                text = "Geschwindigkeit nach Statuswert"
            "db_incoming_accuracy":
                text = "Genauigkeit gegen das Ziel nach Statuswert"
            "db_next_cycle_mod":
                text = "Geschwindigkeit der nächsten Aktion nach Statuswert"
            "db_team_modifier":
                var modifier_kind: String = str(mechanic.get("modifier_kind", ""))
                text = _modifier_attribute_label(modifier_kind) + " des Teams nach Statuswert"
            "db_on_ko_modifier":
                var ko_kind: String = str(mechanic.get("modifier_kind", ""))
                text = "Bei K.O.: " + _modifier_attribute_label(ko_kind) + " nach Statuswert"
            "recoil":
                text = "Rückstoß " + _percent(float(mechanic.get("fraction", 0.0)) * 100.0) + " des verursachten KP-Schadens"
            "atb_knockback":
                text = _percent(float(mechanic.get("chance", 0.0)) * 100.0) + " Zurückschrecken"
            "db_chance_mechanic":
                var nested_value: Variant = mechanic.get("mechanic", {})
                if nested_value is Dictionary:
                    var nested_move: Dictionary = {"mechanics": [nested_value]}
                    var nested: String = effect_summary(nested_move)
                    text = _percent(float(mechanic.get("chance", 0.0)) * 100.0) + " " + nested
            _:
                text = Registry.player_label_for_effect(kind)

        var duration: String = _duration_text(mechanic)
        if not duration.is_empty() and not text.is_empty():
            text += " · " + duration
        if not text.is_empty() and not pieces.has(text):
            pieces.append(text)

    return " · ".join(pieces)


static func sanitize_tooltip(source: String) -> String:
    var kept := PackedStringArray()
    for line: String in source.split("\n"):
        var clean: String = line.strip_edges()
        var lower: String = clean.to_lower()
        if clean.begins_with("Datenbank-Effekt:"):
            continue
        if (
            lower.contains("effect_source")
            or lower.contains("incoming_damage_mod")
            or lower.contains("outgoing_damage_mod")
            or lower.contains("atb_cycle_mod")
            or lower.contains("db_")
        ):
            continue
        kept.append(line)
    return "\n".join(kept).strip_edges()


static func is_player_safe(source: String) -> bool:
    var lower: String = source.to_lower()
    return (
        not source.contains("×")
        and not lower.contains("incoming_damage_mod")
        and not lower.contains("outgoing_damage_mod")
        and not lower.contains("atb_cycle_mod")
        and not lower.contains("db_")
        and not lower.contains("effect_source")
        and not lower.contains("initiative")
        and not lower.contains("spezial ")
        and not lower.contains("verwundbar")
        and not lower.contains("tempo")
    )


static func _modifier_attribute_label(kind: String) -> String:
    match kind:
        "outgoing_damage_mod":
            return "Angriff"
        "incoming_damage_mod":
            return "Verteidigung"
        "accuracy_mod":
            return "Genauigkeit"
        "atb_cycle_mod":
            return "Geschwindigkeit"
        _:
            return "Attribut"


static func _duration_text(mechanic: Dictionary) -> String:
    var duration_text: String = str(mechanic.get("duration", ""))
    if duration_text == "3_actions":
        return "3 eigene Aktionen"
    if mechanic.has("duration_actions"):
        var actions: int = maxi(1, int(mechanic.get("duration_actions", 1)))
        return str(actions) + " eigene Aktion" + ("" if actions == 1 else "en")
    return ""


static func _signed_percent(value: float) -> String:
    var rounded: int = int(round(absf(value)))
    if rounded == 0:
        return "±0 %"
    return ("+" if value > 0.0 else "−") + str(rounded) + " %"


static func _percent(value: float) -> String:
    return str(int(round(value))) + " %"
