extends "res://scripts/demo_route_milestone_double_boss_v1.gd"

# Schritt 2 des Landschaftssystems:
# Jede neue Route beginnt verbindlich auf Wiese / Ebene. Die spätere Auswahl
# anderer Landschaften wird in den folgenden Schritten auf diesem Zustand aufbauen.

const LANDSCAPE_DATA_PATH: String = "res://data/landscapes_v1.json"
const START_LANDSCAPE_ID: String = "meadow"

var current_landscape_id: String = START_LANDSCAPE_ID
var _landscape_by_id: Dictionary = {}


func start_route() -> void:
    current_landscape_id = START_LANDSCAPE_ID
    _tf_load_landscape_registry()
    super.start_route()
    _tf_apply_current_landscape_background()


func _start_stage_battle() -> void:
    # Die aktuell gewählte Landschaft ist für JEDEN Etappenkampf verbindlich.
    # Etappe 1 beginnt fest auf der Wiese; ab Etappe 2 bleibt exakt die Landschaft
    # erhalten, die der Spieler zuvor in der Landschaftsauswahl gewählt hat.
    if stage == 1:
        current_landscape_id = START_LANDSCAPE_ID

    # Vor dem Start setzen, damit der Kampf bereits mit dem richtigen Bild öffnet.
    _tf_apply_current_landscape_background()
    super._start_stage_battle()

    # Einige geerbte Präsentations-Layer aktualisieren beim Kampfstart ihren HUD-
    # Zustand. Danach noch einmal die Route als autoritative Quelle anwenden, damit
    # kein Fallback-Hintergrund (insbesondere die Wiese) die Auswahl überschreibt.
    _tf_apply_current_landscape_background()


func route_current_landscape_id() -> String:
    return current_landscape_id


func route_current_landscape() -> Dictionary:
    _tf_load_landscape_registry()
    var value: Variant = _landscape_by_id.get(current_landscape_id, {})
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func route_landscape(id: String) -> Dictionary:
    _tf_load_landscape_registry()
    var value: Variant = _landscape_by_id.get(id, {})
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _tf_load_landscape_registry() -> void:
    if not _landscape_by_id.is_empty():
        return

    var file: FileAccess = FileAccess.open(LANDSCAPE_DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Landschaftsregister fehlt: " + LANDSCAPE_DATA_PATH)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Landschaftsregister ist ungültig: " + LANDSCAPE_DATA_PATH)
        return

    var entries_value: Variant = (parsed as Dictionary).get("landscapes", [])
    if not (entries_value is Array):
        push_error("Landschaftsregister enthält keine Landschaftsliste.")
        return

    for entry_value: Variant in entries_value:
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value as Dictionary
        var landscape_id: String = str(entry.get("id", "")).strip_edges()
        if landscape_id.is_empty():
            continue
        _landscape_by_id[landscape_id] = entry.duplicate(true)


func _tf_apply_current_landscape_background() -> void:
    # Der BattleDemo ist im Hauptbaum ein Geschwisterknoten der Route. Ältere
    # Route-Layer stellen bereits battle_demo bereit; der direkte Lookup ist nur
    # der robuste Fallback und ersetzt die inzwischen entfernte _find_battle_demo()-Methode.
    var active_battle_demo: Node = battle_demo as Node
    if active_battle_demo == null:
        var parent: Node = get_parent()
        if parent != null:
            active_battle_demo = parent.get_node_or_null("BattleDemo")
    if active_battle_demo == null:
        return

    var landscape: Dictionary = route_current_landscape()
    var background_path: String = str(landscape.get("background", "")).strip_edges()
    if background_path.is_empty():
        push_warning("Für Landschaft '%s' fehlt ein Hintergrundpfad." % current_landscape_id)
        return
    if not active_battle_demo.has_method("set_battle_background"):
        push_warning("BattleDemo unterstützt set_battle_background noch nicht.")
        return

    active_battle_demo.call("set_battle_background", background_path)
