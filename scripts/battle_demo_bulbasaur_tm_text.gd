extends "res://scripts/battle_demo_config_scroll.gd"

# Final player-facing text layer for the Bisasam-family TM test set.
#
# The TM runtime deliberately stores some complex mechanics in runtime flags and
# custom mechanic ids. The generic move preview cannot infer those details and
# historically reduced moves such as Kugelsaat to only "direkter Schaden".
# This layer keeps combat math untouched and gives every Bisasam TM a compact,
# complete German effect summary. Internal database/effect-source text is never
# shown to the player.

const BULBASAUR_TM_SUMMARIES: Dictionary = {
    "take_down": "direkter Schaden · Rückstoß: 25 % des tatsächlich verursachten Schadens",
    "charm": "Angriff ↓ (Statuswert-basiert, stark) · 3 eigene Aktionen des Ziels",
    "protect": "blockiert die nächste feindliche Attacke · direkte Wiederholung: 100 % → 33 % → 11 % …",
    "trailblaze": "direkter Schaden · bei Treffer: Geschwindigkeit ↑ (Statuswert-basiert) · 3 eigene Aktionen",
    "facade": "direkter Schaden · Stärke 140 bei Verbrennung, Vergiftung, schwerer Vergiftung oder Paralyse · ignoriert nur den Verbrennungs-Angriffsmalus",
    "magical_leaf": "direkter Schaden · trifft ohne normale Genauigkeitsprüfung · Schutzschild/Unverwundbarkeit wirken weiter",
    "endure": "direkte feindliche Attacken können KP 3 eigene Aktionen lang nicht unter 1 senken · indirekter/eigener Schaden wirkt weiter",
    "sunny_day": "Sonne 50 s Kampfzeit · Feuer-Schaden +50 % · Wasser-Schaden −50 % · Solarstrahl sofort · Wachstum verstärkt",
    "bullet_seed": "2–5 Treffer · Genauigkeit einmal pro Attacke · eigener Volltrefferwurf je Treffer · Verteilung 35/35/15/15 %",
    "sleep_talk": "nur im Schlaf · 1 Schlafaktion · zufällige geeignete bekannte Attacke · keine zusätzlichen RPG-AP",
    "seed_bomb": "direkter Schaden",
    "grass_knot": "direkter Schaden · Stärke 20–120 abhängig vom Basisgewicht des Ziels",
    "rest": "volle KP + Hauptstatus heilen · danach Schlaf für genau 2 eigene Aktionsmöglichkeiten · scheitert bei vollen KP/Schlafschutz",
    "substitute": "25 % Max-KP → Delegator mit gleicher KP-Menge · fängt direkte Angriffe sowie feindliche Status-/Debuffeffekte ab · kein Überschussschaden pro Treffer",
    "giga_drain": "direkter Schaden · heilt 50 % des tatsächlich verursachten KP-Schadens · keine Heilung bei 0 Schaden",
    "energy_ball": "direkter Schaden · 10 %: Verteidigung ↓ (Statuswert-basiert) · 3 eigene Aktionen des Ziels",
    "helping_hand": "gewählter Verbündeter: Angriff ↑ (Statuswert-basiert) · 3 eigene Aktionen · nicht auf den Anwender selbst",
    "grassy_terrain": "3 eigene Aktionen des Anwenders · am Boden: Pflanzen-Schaden +30 % · nach jeder Aktion Heilung um 1/16 Max-KP für alle am Boden",
    "grass_pledge": "Stärke 80 · mit Feuer-/Wassersäulen: Stärke 150 · Feuer: 1/8 Max-KP ×3 · Wasser: Geschwindigkeit −50 % ×3",
    "sludge_bomb": "direkter Schaden · 30 % Chance auf Vergiftung",
    "solar_beam": "1 eigene Aktion aufladen, dann automatisch angreifen · Zielplatz bleibt fest · unter Sonne ohne Aufladen"
}


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if BULBASAUR_TM_SUMMARIES.has(move_id):
        return str(BULBASAUR_TM_SUMMARIES[move_id])
    return super._compact_effect_summary(move)


func _move_tooltip(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    var text: String = super._move_tooltip(move)
    if not BULBASAUR_TM_SUMMARIES.has(move_id):
        return text

    # effect_source is an internal database field. It may contain technical
    # identifiers or implementation vocabulary and must never leak into the UI.
    text = _bulbasaur_tm_strip_internal_lines(text)

    # Variable/conditional power should not leave a misleading static number in
    # the header while the player is deciding which attack to use.
    if move_id == "grass_knot":
        var power_text: String = "Stärke 20–120"
        if not selected_actor.is_empty():
            power_text = "Stärke %d" % _bulba_grass_knot_power(selected_actor, move)
        text = text.replace("Stärke 20", power_text)
        text = text.replace("Stärke: 20", power_text)
    elif move_id == "facade" and not selected_actor.is_empty() and _bulba_facade_is_boosted(selected_actor):
        text = text.replace("Stärke 70", "Stärke 140")
        text = text.replace("Stärke: 70", "Stärke: 140")

    return _final_attack_text(text)


func _bulbasaur_tm_strip_internal_lines(source: String) -> String:
    var kept := PackedStringArray()
    for line: String in source.split("\n"):
        var clean: String = line.strip_edges()
        if clean.begins_with("Datenbank-Effekt:"):
            continue
        if clean.contains("db_") or clean.contains("bulba_") or clean.contains("effect_source"):
            continue
        kept.append(line)
    return "\n".join(kept)
