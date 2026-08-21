extends "res://scripts/battle_demo_substitute_position.gd"

# Final player-facing text layer for the Bisasam-family TM test set.
#
# The TM runtime deliberately stores some complex mechanics in runtime flags and
# custom mechanic ids. The generic move preview cannot infer those details and
# historically reduced moves such as Kugelsaat to only "direkter Schaden".
# This layer keeps combat math untouched and gives every Bisasam TM a compact,
# complete German effect summary. Internal database/effect-source text is never
# shown to the player.

const BULBASAUR_TM_SUMMARIES: Dictionary = {
    "take_down": "Schaden · Rückstoß 25 % des angerichteten KP-Schadens",
    "charm": "Angriff ↓ (Statuswert, stark) · 3 Zielaktionen",
    "protect": "nächste Feindattacke geblockt · Wiederholung 100→33→11 % … · laufende Effekte wirken weiter",
    "trailblaze": "Schaden · Treffer: Geschwindigkeit ↑ (Statuswert) · 3 eigene Aktionen",
    "facade": "Schaden · Stärke 140 bei Verbrennung/Vergiftung/Paralyse · ignoriert Verbrennungs-Angriffsmalus",
    "magical_leaf": "Schaden · keine Genauigkeitsprüfung · Schutzschild/Unverwundbarkeit wirken",
    "endure": "3 eigene Aktionen: direkte Feindattacken lassen mind. 1 KP · indirekter/eigener Schaden wirkt",
    "sunny_day": "Sonne 50 s · Feuer +50 % · Wasser −50 % · Solarstrahl sofort · Wachstum stärker",
    "bullet_seed": "2–5 Treffer (35/35/15/15 %) · Genauigkeit 1× · Volltreffer je Treffer",
    "sleep_talk": "nur schlafend · verbraucht 1 Schlafaktion · Zufallsattacke · keine Extra-RPG-AP",
    "seed_bomb": "Schaden",
    "grass_knot": "Schaden · Stärke 20–120 nach Basisgewicht des Ziels",
    "rest": "volle KP + Hauptstatus heilen · danach 2 Schlafaktionen · scheitert bei vollen KP/Schlafschutz",
    "substitute": "25 % Max-KP → Delegator · fängt direkte Treffer + Feindstatus/Senkungen ab · kein Überschussschaden pro Treffer",
    "giga_drain": "Schaden · heilt 50 % des angerichteten KP-Schadens · 0 Schaden = 0 Heilung",
    "energy_ball": "Schaden · 10 %: Verteidigung ↓ (Statuswert) · 3 Zielaktionen",
    "helping_hand": "Verbündeter: Angriff ↑ (Statuswert) · 3 Aktionen · nicht auf sich selbst",
    "grassy_terrain": "3 eigene Aktionen · am Boden: Pflanze +30 % · nach jeder Aktion alle am Boden +1/16 Max-KP",
    "grass_pledge": "Stärke 80 · Kombination 150 · Feuer: −1/8 Max-KP ×3 · Wasser: Geschwindigkeit −50 % ×3",
    "sludge_bomb": "Schaden · 30 % Vergiftung",
    "solar_beam": "1 eigene Aktion laden → automatisch angreifen · Zielplatz fest · Sonne: sofort"
}


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if BULBASAUR_TM_SUMMARIES.has(move_id):
        return str(BULBASAUR_TM_SUMMARIES[move_id])
    return super._compact_effect_summary(move)


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    if log_label == null or not BULBASAUR_TM_SUMMARIES.has(move_id):
        return

    # The generic preview prints the database base power. For the two Bisasam
    # TMs whose actual power changes before execution, show the value that the
    # current actor would really use instead of a misleading static number.
    if move_id == "grass_knot":
        var power_text: String = "Stärke 20–120"
        if not selected_actor.is_empty():
            power_text = "Stärke %d" % _bulba_grass_knot_power(selected_actor, move)
        log_label.text = log_label.text.replace("Stärke 20", power_text)
    elif move_id == "facade" and not selected_actor.is_empty() and _bulba_facade_is_boosted(selected_actor):
        log_label.text = log_label.text.replace("Stärke 70", "Stärke 140")


func _move_tooltip(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    var text: String = super._move_tooltip(move)
    if not BULBASAUR_TM_SUMMARIES.has(move_id):
        return text

    # Old database descriptions and effect-source fields are implementation
    # material. For this TM set the canonical compact German summary below is
    # the single player-facing source of truth.
    text = _bulbasaur_tm_strip_internal_lines(text, move)

    if move_id == "grass_knot":
        var power_text: String = "Stärke 20–120"
        if not selected_actor.is_empty():
            power_text = "Stärke %d" % _bulba_grass_knot_power(selected_actor, move)
        text = text.replace("Stärke 20", power_text)
        text = text.replace("Stärke: 20", "Stärke: " + power_text.trim_prefix("Stärke "))
    elif move_id == "facade" and not selected_actor.is_empty() and _bulba_facade_is_boosted(selected_actor):
        text = text.replace("Stärke 70", "Stärke 140")
        text = text.replace("Stärke: 70", "Stärke: 140")

    var summary: String = _compact_effect_summary(move)
    if not summary.is_empty() and not text.contains(summary):
        text = text.strip_edges() + "\nEffekt: " + summary
    return _final_attack_text(text)


func _bulbasaur_tm_strip_internal_lines(source: String, move: Dictionary) -> String:
    var kept := PackedStringArray()
    var description: String = str(move.get("description", "")).strip_edges()
    var emoji_description: String = (
        str(move.get("emoji", "")) + " " + description
    ).strip_edges()

    for line: String in source.split("\n"):
        var clean: String = line.strip_edges()
        if clean.begins_with("Datenbank-Effekt:"):
            continue
        if clean.contains("db_") or clean.contains("bulba_") or clean.contains("effect_source"):
            continue
        if not description.is_empty() and (clean == description or clean == emoji_description):
            continue
        kept.append(line)
    return "\n".join(kept)
