extends Node

## Dauerhafter, run-uebergreifender Fortschritt.
##
## Dieser Speicher ist absichtlich vom spaeteren Run-Save getrennt. Ein neuer Run
## darf den Pokedex daher nicht loeschen. Fangsysteme muessen nur
## `MetaProgression.record_caught(species_id)` aufrufen.

signal pokedex_changed(species_id: String)

const SCHEMA_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://meta_progression.json"

var save_path: String = DEFAULT_SAVE_PATH
var _data: Dictionary = {}


func _ready() -> void:
    load_progress()


func load_progress() -> void:
    _data = _default_data()

    if not FileAccess.file_exists(save_path):
        return

    var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        push_warning("Meta-Fortschritt konnte nicht geoeffnet werden: " + save_path)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_warning("Meta-Fortschritt ist unlesbar; es wird mit leerem Fortschritt weitergearbeitet.")
        return

    var loaded: Dictionary = parsed
    var pokedex_value: Variant = loaded.get("pokedex", {})
    if not (pokedex_value is Dictionary):
        push_warning("Meta-Fortschritt enthaelt keinen gueltigen Pokedex; es wird mit leerem Fortschritt weitergearbeitet.")
        return

    _data = loaded
    _data["schema_version"] = int(_data.get("schema_version", SCHEMA_VERSION))
    _data["pokedex"] = pokedex_value


func save_progress() -> bool:
    _ensure_structure()
    _data["schema_version"] = SCHEMA_VERSION

    var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        push_error("Meta-Fortschritt konnte nicht gespeichert werden: " + save_path)
        return false

    file.store_string(JSON.stringify(_data, "\t"))
    return true


func record_seen(species_id: String) -> bool:
    var sid: String = _normalize_species_id(species_id)
    if sid.is_empty():
        push_warning("Leere species_id kann nicht im Pokedex registriert werden.")
        return false

    var entry: Dictionary = _entry_for(sid)
    if bool(entry.get("seen", false)):
        return false

    var now: int = int(Time.get_unix_time_from_system())
    entry["seen"] = true
    entry["first_seen_unix"] = now
    _set_entry(sid, entry)
    save_progress()
    pokedex_changed.emit(sid)
    return true


func record_caught(species_id: String) -> bool:
    var sid: String = _normalize_species_id(species_id)
    if sid.is_empty():
        push_warning("Leere species_id kann nicht im Pokedex registriert werden.")
        return false

    var entry: Dictionary = _entry_for(sid)
    if bool(entry.get("caught", false)):
        return false

    var now: int = int(Time.get_unix_time_from_system())
    if not bool(entry.get("seen", false)):
        entry["seen"] = true
        entry["first_seen_unix"] = now

    entry["caught"] = true
    entry["first_caught_unix"] = now
    _set_entry(sid, entry)
    save_progress()
    pokedex_changed.emit(sid)
    return true


func is_seen(species_id: String) -> bool:
    var entry: Dictionary = _entry_for(_normalize_species_id(species_id))
    return bool(entry.get("seen", false))


func is_caught(species_id: String) -> bool:
    var entry: Dictionary = _entry_for(_normalize_species_id(species_id))
    return bool(entry.get("caught", false))


func get_entry(species_id: String) -> Dictionary:
    return _entry_for(_normalize_species_id(species_id)).duplicate(true)


func get_seen_species_ids() -> Array[String]:
    return _species_ids_with_flag("seen")


func get_caught_species_ids() -> Array[String]:
    return _species_ids_with_flag("caught")


func get_unlocked_run_start_species_ids() -> Array[String]:
    ## Grundlage fuer die spaetere Run-Start-Auswahl oder Zufallsauswahl.
    ## Welche UI/Regel daraus waehlt, wird bewusst erst spaeter entschieden.
    return get_caught_species_ids()


func reset_meta_progression() -> bool:
    ## Ausschliesslich fuer bewusste "Gesamtfortschritt loeschen"-Funktionen/Tests.
    ## Ein normaler neuer Run darf diese Methode NICHT aufrufen.
    _data = _default_data()
    var saved: bool = save_progress()
    if saved:
        pokedex_changed.emit("")
    return saved


func _default_data() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "pokedex": {}
    }


func _ensure_structure() -> void:
    if not (_data is Dictionary):
        _data = _default_data()
    if not (_data.get("pokedex", {}) is Dictionary):
        _data["pokedex"] = {}


func _normalize_species_id(species_id: String) -> String:
    return species_id.strip_edges()


func _entry_for(species_id: String) -> Dictionary:
    if species_id.is_empty():
        return {}
    _ensure_structure()
    var pokedex: Dictionary = _data["pokedex"]
    var value: Variant = pokedex.get(species_id, {})
    if value is Dictionary:
        return (value as Dictionary).duplicate(true)
    return {}


func _set_entry(species_id: String, entry: Dictionary) -> void:
    _ensure_structure()
    var pokedex: Dictionary = _data["pokedex"]
    pokedex[species_id] = entry
    _data["pokedex"] = pokedex


func _species_ids_with_flag(flag_name: String) -> Array[String]:
    _ensure_structure()
    var result: Array[String] = []
    var pokedex: Dictionary = _data["pokedex"]

    for species_key: Variant in pokedex.keys():
        var value: Variant = pokedex[species_key]
        if value is Dictionary and bool((value as Dictionary).get(flag_name, false)):
            result.append(str(species_key))

    result.sort()
    return result
