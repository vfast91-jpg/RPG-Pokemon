extends "res://scripts/battle_demo_route_boss.gd"

# Glumanda-Familie: finaler Gate-1-Runtime-Layer.
# Reuses the existing central database, Status, weather, charge/recharge,
# forced-sequence and target systems. Only mechanics that did not yet exist
# centrally are bridged here.

const CF_WEIGHT_PATH: String = "res://data/gen1_species_weights_v1.json"
const CF_SANDSTORM_DURATION_SECONDS: float = 50.0
const CF_SANDSTORM_PULSE_SECONDS: float = 10.0
const CF_SANDSTORM_DAMAGE_FRACTION: float = 1.0 / 16.0
const CF_SANDSTORM_IMMUNE_TYPES: Array[String] = ["rock", "ground", "steel"]
const CF_FLY_DOUBLE_HIT_MOVES: Array[String] = ["gust", "twister"]
const CF_FLY_ALLOWED_MOVES: Array[String] = ["gust", "twister", "thunder", "hurricane"]
const CF_TEMPER_FLARE_BOOST_OUTCOMES: Array[String] = ["miss", "immune", "failed"]

const CF_SUMMARIES: Dictionary = {
    "metal_claw": "Schaden · Treffer: 10 % Chance auf Angriff ↑ (Statuswert) · 3 eigene Aktionen",
    "swift": "alle Gegner · keine normale Genauigkeitsprüfung · volle Stärke pro Ziel",
    "rock_tomb": "Schaden · Treffer: Geschwindigkeit ↓ (Statuswert) · 3 Zielaktionen",
    "flame_charge": "Schaden · Treffer: Geschwindigkeit ↑ (Statuswert) · 3 eigene Aktionen",
    "fling": "Schaden wird mit Statuswert statt Angriff berechnet",
    "dragon_tail": "Schaden · Treffer: Statuswert-basierte ATB-Pause",
    "dig": "1 Aktion eingraben · Bild verschwindet · nächste eigene Aktion automatischer Angriff · Erdbeben trifft doppelt",
    "brick_break": "Schaden · Treffer: Team-Barrieren der Zielseite werden entfernt · Schutzschild bleibt echter Block",
    "shadow_claw": "Schaden · erhöhte Volltrefferchance",
    "fire_punch": "Schaden · 10 % Verbrennung",
    "rock_slide": "alle Gegner · 30 % ATB-Rückwurf pro getroffenem Ziel",
    "dragon_dance": "Angriff ↑ + Geschwindigkeit ↑ (Statuswert) · 3 eigene Aktionen",
    "will_o_wisp": "verursacht Verbrennung",
    "dragon_pulse": "zuverlässiger Drachenschaden",
    "fire_blast": "starker Feuerschaden · 10 % Verbrennung",
    "fire_pledge": "Stärke 80 · nach kompatibler Säule eines Verbündeten Stärke 150 + Feldeffekt",
    "outrage": "2–3 automatische Angriffe · danach Verwirrung",
    "overheat": "starker Schaden · Treffer: eigener Angriff stark ↓ (Statuswert) · 3 eigene Aktionen",
    "focus_blast": "starker Schaden · 10 % Verteidigung ↓ (Statuswert) · 3 Zielaktionen",
    "focus_punch": "1 voller Aktionszyklus Fokus · dann Stärke 150 · direkter gegnerischer KP-Schaden unterbricht",
    "temper_flare": "Stärke 150 nach miss / immune / failed der vorherigen eigenen Attacke",
    "breaking_swipe": "alle Gegner · Treffer: Angriff ↓ (Statuswert) · 3 Zielaktionen",
    "acrobatics": "feste Stärke 110 · bewusste AP-7-Balance im itemfreien Timeflow",
    "air_cutter": "alle Gegner · erhöhte Volltrefferchance",
    "sandstorm": "50 s Wetter · alle 10 s Sandsturm-Puls · Gestein/Boden/Stahl immun · Gestein Verteidigung +50 %",
    "fly": "1 Aktion hochfliegen · Bild verschwindet · nächste eigene Aktion Angriff · spezielle Luft-Gegenangriffe möglich",
    "blast_burn": "Stärke 150 · erfolgreicher Treffer erzwingt nächste Regenerationsaktion",
    "heat_crash": "Stärke 40–120 nach Gewichtsverhältnis · gegen minimierte Ziele doppelt",
    "scorching_sands": "Schaden · 30 % Verbrennung · taut Anwender bzw. getroffenes Ziel auf",
    "dragon_cheer": "alle anderen Verbündeten: Volltrefferstufe +1 · Drachen +2 · 3 eigene Aktionen"
}

var _cf_active_move_id: String = ""
var _cf_spread_move_id: String = ""
var _cf_weights_kg: Dictionary = {}
var _cf_sandstorm_next_pulse: float = CF_SANDSTORM_PULSE_SECONDS
var _cf_pledge_pending: Dictionary = {"player": {}, "enemy": {}}


func _load_data() -> void:
    super._load_data()
    _cf_load_weights()


func _cf_load_weights() -> void:
    _cf_weights_kg = {}
    var file: FileAccess = FileAccess.open(CF_WEIGHT_PATH, FileAccess.READ)
    if file == null:
        push_error("Gewichtsdaten fehlen: " + CF_WEIGHT_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Gewichtsdaten sind ungültig: " + CF_WEIGHT_PATH)
        return
    var weights_value: Variant = (parsed as Dictionary).get("weights_kg", {})
    if weights_value is Dictionary:
        _cf_weights_kg = (weights_value as Dictionary).duplicate(true)


func _start_battle() -> void:
    _cf_reset_family_state()
    super._start_battle()


func open_config() -> void:
    _cf_reset_family_state()
    super.open_config()


func _cf_reset_family_state() -> void:
    _cf_active_move_id = ""
    _cf_spread_move_id = ""
    _cf_sandstorm_next_pulse = CF_SANDSTORM_PULSE_SECONDS
    _cf_pledge_pending = {"player": {}, "enemy": {}}


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["cf_focus_punch_active"] = false
    combatant["cf_dragon_cheer_actions"] = 0
    combatant["cf_dragon_cheer_stage"] = 0
    combatant["cf_fire_pledge_ticks"] = 0
    combatant["cf_fire_pledge_source_id"] = ""
    combatant["cf_rainbow_actions"] = 0
    return combatant
