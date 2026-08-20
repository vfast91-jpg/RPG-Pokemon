extends Node

## Dauerhafter, run-uebergreifender Fortschritt.
##
## Dieser Speicher ist absichtlich vom spaeteren Run-Save getrennt. Ein neuer Run
## darf den Pokedex daher nicht loeschen. Fangsysteme muessen nur
## `MetaProgression.record_caught(species_id)` aufrufen.
##
## Wichtig: Fuer spaetere Run-Starts wird nicht die konkret gefangene
## Entwicklungsstufe freigeschaltet, sondern ihre Entwicklungslinie. Wird z. B.
## Tauboga gefangen, wird die Taubsi-Linie freigeschaltet und Taubsi ist die
## niedrige Startform fuer einen neuen Run.

signal pokedex_changed(species_id: String)

const SCHEMA_VERSION: int = 2
const DEFAULT_SAVE_PATH: String = "user://meta_progression.json"
const EVOLUTION_RULES_PATH: String = "res://data/rules/evolution_chains.json"

var save_path: String = DEFAULT_SAVE_PATH
var _data: Dictionary = {}
var _evolution_rules: Dictionary = {}


func _ready() -> void:
    load_progress()


func load_progress() -> void:
    _data = _default_data()
    _load_evolution_rules()

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
    _ensure_structure()
    _migrate_family_unlocks_from_caught_species()
    _data["schema_version"] = SCHEMA_VERSION


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

    var now: int = int(Time.get_unix_time_from_system())
    var entry: Dictionary = _entry_for(sid)
    var species_changed: bool = false

    if not bool(entry.get("seen", false)):
        entry["seen"] = true
        entry["first_seen_unix"] = now
        species_changed = true

    if not bool(entry.get("caught", false)):
        entry["caught"] = true
        entry["first_caught_unix"] = now
        species_changed = true

    if species_changed:
        _set_entry(sid, entry)

    var family_changed: bool = _unlock_evolution_family_for(sid, now)
    if not species_changed and not family_changed:
        return false

    save_progress()
    pokedex_changed.emit(sid)
    return true


func is_seen(species_id: String) -> bool:
    var entry: Dictionary = _entry_for(_normalize_species_id(species_id))
    return bool(entry.get("seen", false))


func is_caught(species_id: String) -> bool:
    ## Bezieht sich weiterhin auf die konkret gefangene Form fuer eine spaetere
    ## detaillierte Pokedex-Anzeige. Der Run-Start benutzt dagegen Familien.
    var entry: Dictionary = _entry_for(_normalize_species_id(species_id))
    return bool(entry.get("caught", false))


func get_entry(species_id: String) -> Dictionary:
    return _entry_for(_normalize_species_id(species_id)).duplicate(true)


func get_seen_species_ids() -> Array[String]:
    return _species_ids_with_flag("seen")


func get_caught_species_ids() -> Array[String]:
    return _species_ids_with_flag("caught")


func get_evolution_family_base_species_id(species_id: String) -> String:
    ## Liefert die niedrigste bekannte Form der Entwicklungslinie. Dabei werden
    ## sowohl lineare `target`-Regeln als auch verzweigte `choices` verfolgt.
    var sid: String = _normalize_species_id(species_id)
    if sid.is_empty():
        return ""

    _load_evolution_rules()
    var level_evolutions_value: Variant = _evolution_rules.get("level_evolutions", {})
    if not (level_evolutions_value is Dictionary):
        return sid

    var level_evolutions: Dictionary = level_evolutions_value
    var parent_by_target: Dictionary = {}
    for source_value: Variant in level_evolutions.keys():
        var source_id: String = str(source_value)
        var rule_value: Variant = level_evolutions[source_value]
        if not (rule_value is Dictionary):
            continue
        for target_id: String in _evolution_target_ids(rule_value as Dictionary):
            if not target_id.is_empty() and not parent_by_target.has(target_id):
                parent_by_target[target_id] = source_id

    var current: String = sid
    var visited: Dictionary = {}
    while parent_by_target.has(current) and not visited.has(current):
        visited[current] = true
        current = str(parent_by_target[current])

    return current


func is_evolution_family_unlocked(species_id: String) -> bool:
    var base_id: String = get_evolution_family_base_species_id(species_id)
    if base_id.is_empty():
        return false
    _ensure_structure()
    var families: Dictionary = _data["unlocked_evolution_families"]
    return families.has(base_id)


func get_unlocked_evolution_family_base_ids() -> Array[String]:
    _ensure_structure()
    var families: Dictionary = _data["unlocked_evolution_families"]
    var result: Array[String] = []
    for family_key: Variant in families.keys():
        result.append(str(family_key))
    result.sort()
    return result


func get_unlocked_run_start_species_ids() -> Array[String]:
    ## Grundlage fuer die spaetere Run-Start-Auswahl oder Zufallsauswahl.
    ## Der Pool enthaelt bewusst die niedrigste Form jeder gefangenen
    ## Entwicklungslinie, nicht die konkret gefangene Entwicklungsstufe.
    ## Welche UI/Regel daraus waehlt, wird bewusst erst spaeter entschieden.
    return get_unlocked_evolution_family_base_ids()


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
        "pokedex": {},
        "unlocked_evolution_families": {}
    }


func _ensure_structure() -> void:
    if not (_data is Dictionary):
        _data = _default_data()
    if not (_data.get("pokedex", {}) is Dictionary):
        _data["pokedex"] = {}
    if not (_data.get("unlocked_evolution_families", {}) is Dictionary):
        _data["unlocked_evolution_families"] = {}


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


func _load_evolution_rules() -> void:
    if not _evolution_rules.is_empty():
        return

    var file: FileAccess = FileAccess.open(EVOLUTION_RULES_PATH, FileAccess.READ)
    if file == null:
        push_warning("Entwicklungsregeln konnten fuer den Meta-Fortschritt nicht geladen werden.")
        _evolution_rules = {"level_evolutions": {}}
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        _evolution_rules = parsed
    else:
        push_warning("Entwicklungsregeln sind unlesbar; Spezies werden vorlaeufig als eigene Familien behandelt.")
        _evolution_rules = {"level_evolutions": {}}


func _evolution_target_ids(rule: Dictionary) -> Array[String]:
    var result: Array[String] = []

    var choices_value: Variant = rule.get("choices", [])
    if choices_value is Array:
        for choice_value: Variant in choices_value:
            if choice_value is Dictionary:
                var choice: Dictionary = choice_value
                _append_evolution_target(
                    result,
                    choice.get("target", choice.get("evolves_into", ""))
                )
            else:
                _append_evolution_target(result, choice_value)

    var direct_value: Variant = rule.get("target", rule.get("evolves_into", ""))
    if direct_value is Array:
        for target_value: Variant in direct_value:
            _append_evolution_target(result, target_value)
    else:
        _append_evolution_target(result, direct_value)

    return result


func _append_evolution_target(result: Array[String], target_value: Variant) -> void:
    var target_id: String = str(target_value).strip_edges()
    if target_id.is_empty() or result.has(target_id):
        return
    result.append(target_id)


func _unlock_evolution_family_for(species_id: String, unlocked_at: int) -> bool:
    var base_id: String = get_evolution_family_base_species_id(species_id)
    if base_id.is_empty():
        return false

    _ensure_structure()
    var families: Dictionary = _data["unlocked_evolution_families"]
    if families.has(base_id):
        return false

    families[base_id] = {
        "base_species_id": base_id,
        "first_unlocked_by_species_id": species_id,
        "first_unlocked_unix": unlocked_at
    }
    _data["unlocked_evolution_families"] = families
    return true


func _migrate_family_unlocks_from_caught_species() -> void:
    ## Alte Schema-v1-Spielstaende hatten nur konkret gefangene Spezies.
    ## Daraus werden beim Laden automatisch die passenden Familien erzeugt.
    var changed: bool = false
    for sid: String in get_caught_species_ids():
        var entry: Dictionary = _entry_for(sid)
        var caught_at: int = int(entry.get("first_caught_unix", 0))
        if _unlock_evolution_family_for(sid, caught_at):
            changed = true

    if changed:
        save_progress()
