extends "res://scripts/battle_demo_attribute_wording.gd"

# Final guardrail for every player-facing attack/stat text.
#
# Older presentation layers historically exposed internal combat multipliers
# such as "eingehender Schaden ×1.25". Those values are useful internally, but
# the player should always see the affected attribute and its percentage change:
# Angriff, Verteidigung, Genauigkeit and Geschwindigkeit.
#
# This layer deliberately changes presentation only. Combat math and stored
# runtime multipliers remain untouched.


func _move_tooltip(move: Dictionary) -> String:
    return _final_attack_text(super._move_tooltip(move))


func _compact_effect_summary(move: Dictionary) -> String:
    return _final_attack_text(super._compact_effect_summary(move))


func _detail_info(combatant: Dictionary) -> String:
    return _final_attack_text(super._detail_info(combatant))


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
            return _final_attack_text(super._modifier_detail_text(kind, multiplier))


func _player_text_cleanup(source: String) -> String:
    return _final_attack_text(super._player_text_cleanup(source))


func _final_attack_text(source: String) -> String:
    var text: String = source

    # Canonical vocabulary first. This catches old text coming from database
    # descriptions as well as inherited UI summaries.
    text = text.replace("verursachter Schaden", "Angriff")
    text = text.replace("verursachten Schaden", "Angriff")
    text = text.replace("eingehender Schaden erhöht", "Verteidigung gesenkt")
    text = text.replace("eingehender Schaden gesenkt", "Verteidigung erhöht")
    text = text.replace("eingehender Schaden ↑", "Verteidigung ↓")
    text = text.replace("eingehender Schaden ↓", "Verteidigung ↑")
    text = text.replace("Eingehender Schaden ↑", "Verteidigung ↓")
    text = text.replace("Eingehender Schaden ↓", "Verteidigung ↑")
    text = text.replace("Schutz ↑", "Verteidigung ↑")
    text = text.replace("Schutz ↓", "Verteidigung ↓")

    # Convert every legacy numeric multiplier that can still leak through the
    # older UI layers. For incoming damage and cycle duration the visible stat
    # changes inversely: damage ×1.25 means Defense ×0.80 = Defense −20%.
    text = _replace_legacy_multiplier(
        text,
        "Gesamt eingehender Schaden: ×",
        "Gesamt Verteidigung: ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt eingehender Schaden: x",
        "Gesamt Verteidigung: ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt Verteidigung: ×",
        "Gesamt Verteidigung: ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt Verteidigung: x",
        "Gesamt Verteidigung: ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "eingehender Schaden ×",
        "Verteidigung ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "eingehender Schaden x",
        "Verteidigung ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "Eingehender Schaden: ca. ×",
        "Verteidigung: ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "Eingehender Schaden: ca. x",
        "Verteidigung: ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "Verteidigung ×",
        "Verteidigung ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Verteidigung x",
        "Verteidigung ",
        "direct"
    )

    text = _replace_legacy_multiplier(
        text,
        "Gesamt verursachter Schaden: ×",
        "Gesamt Angriff: ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt verursachter Schaden: x",
        "Gesamt Angriff: ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt Angriff: ×",
        "Gesamt Angriff: ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt Angriff: x",
        "Gesamt Angriff: ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Angriff ×",
        "Angriff ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Angriff x",
        "Angriff ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Nächster Schaden: ×",
        "Angriff für nächste Schadensattacke: ",
        "direct"
    )

    text = _replace_legacy_multiplier(
        text,
        "Gesamt Genauigkeit: ×",
        "Gesamt Genauigkeit: ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt Genauigkeit: x",
        "Gesamt Genauigkeit: ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Genauigkeit ×",
        "Genauigkeit ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Genauigkeit x",
        "Genauigkeit ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Nächste Genauigkeit: ×",
        "Genauigkeit für nächste Attacke: ",
        "direct"
    )

    text = _replace_legacy_multiplier(
        text,
        "Gesamt Aktionszyklus: ×",
        "Gesamt Geschwindigkeit: ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt Aktionszyklus: x",
        "Gesamt Geschwindigkeit: ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt ATB-Zyklus: ×",
        "Gesamt Geschwindigkeit: ",
        "inverse"
    )
    text = _replace_legacy_multiplier(
        text,
        "Gesamt Geschwindigkeit: ×",
        "Gesamt Geschwindigkeit: ",
        "direct"
    )

    # AP/recovery timing is easier to understand as a percentage delta than as
    # an internal multiplier. Example: ×2.10 becomes +110%, ×0.90 becomes −10%.
    text = _replace_legacy_multiplier(
        text,
        "Ladezeit der Aktionsleiste ×",
        "Ladezeit der Aktionsleiste ",
        "direct"
    )
    text = _replace_legacy_multiplier(
        text,
        "Ladezeit der Aktionsleiste x",
        "Ladezeit der Aktionsleiste ",
        "direct"
    )

    return text


func _replace_legacy_multiplier(
    source: String,
    marker: String,
    replacement_prefix: String,
    mode: String
) -> String:
    var text: String = source
    var search_from: int = 0

    while true:
        var marker_index: int = text.find(marker, search_from)
        if marker_index < 0:
            break

        var number_start: int = marker_index + marker.length()
        var number_end: int = number_start
        while number_end < text.length():
            var character: String = text.substr(number_end, 1)
            if "0123456789.,".contains(character):
                number_end += 1
            else:
                break

        if number_end <= number_start:
            search_from = number_start
            continue

        var raw_number: String = text.substr(
            number_start,
            number_end - number_start
        ).replace(",", ".")
        if not raw_number.is_valid_float():
            search_from = number_end
            continue

        var multiplier: float = float(raw_number)
        if mode == "inverse":
            multiplier = 1.0 / maxf(0.0001, multiplier)

        var replacement: String = replacement_prefix + _signed_percent_delta(multiplier)
        text = (
            text.substr(0, marker_index)
            + replacement
            + text.substr(number_end)
        )
        search_from = marker_index + replacement.length()

    return text
