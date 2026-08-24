extends Node

# Exactly one active adventure save. MetaProgression and the leaderboard use
# their own files and are deliberately never touched here.
const SAVE_PATH: String = "user://timeflow_run_save.dat"
const SAVE_VERSION: int = 1
const SAVE_KIND: String = "adventure_route"

var _last_state_hash: int = 0


func has_run_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH) and not load_run_save().is_empty()


func saved_stage() -> int:
    var payload: Dictionary = load_run_save()
    return maxi(1, int(payload.get("stage", 1))) if not payload.is_empty() else 1


func save_route(route: Node, checkpoint: String = "autosave") -> bool:
    if route == null:
        return false

    var state: Dictionary = _snapshot_script_state(route)
    if state.is_empty():
        return false

    var state_hash: int = hash(state)
    if state_hash == _last_state_hash and FileAccess.file_exists(SAVE_PATH):
        return true

    var payload: Dictionary = {
        "version": SAVE_VERSION,
        "kind": SAVE_KIND,
        "checkpoint": checkpoint,
        "stage": maxi(1, int(route.get("stage"))),
        "saved_at": int(Time.get_unix_time_from_system()),
        "state": state
    }

    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("RunSaveManager: Spielstand konnte nicht geöffnet werden: %s" % SAVE_PATH)
        return false

    file.store_var(payload, false)
    file.flush()
    file.close()
    _last_state_hash = state_hash
    return true


func load_run_save() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}

    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}

    var value: Variant = file.get_var(false)
    file.close()
    if not (value is Dictionary):
        return {}

    var payload: Dictionary = value as Dictionary
    if int(payload.get("version", 0)) != SAVE_VERSION:
        return {}
    if str(payload.get("kind", "")) != SAVE_KIND:
        return {}
    if not (payload.get("state", {}) is Dictionary):
        return {}
    return payload


func restore_route(route: Node) -> bool:
    if route == null:
        return false

    var payload: Dictionary = load_run_save()
    if payload.is_empty():
        return false

    var state: Dictionary = payload.get("state", {}) as Dictionary
    var known_properties: Dictionary = {}
    for info_value: Variant in route.get_property_list():
        if not (info_value is Dictionary):
            continue
        var info: Dictionary = info_value as Dictionary
        known_properties[str(info.get("name", ""))] = true

    for key_value: Variant in state.keys():
        var property_name: String = str(key_value)
        if not known_properties.has(property_name):
            continue
        route.set(property_name, state[key_value])

    _last_state_hash = hash(state)
    return true


func clear_run_save() -> void:
    _last_state_hash = 0
    if not FileAccess.file_exists(SAVE_PATH):
        return

    var absolute_path: String = ProjectSettings.globalize_path(SAVE_PATH)
    var error: Error = DirAccess.remove_absolute(absolute_path)
    if error != OK:
        push_warning("RunSaveManager: Spielstand konnte nicht gelöscht werden (%s)." % error_string(error))


func _snapshot_script_state(route: Node) -> Dictionary:
    var state: Dictionary = {}

    for info_value: Variant in route.get_property_list():
        if not (info_value is Dictionary):
            continue

        var info: Dictionary = info_value as Dictionary
        var usage: int = int(info.get("usage", 0))
        if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
            continue

        var property_name: String = str(info.get("name", ""))
        if property_name.is_empty() or _is_save_system_internal(property_name):
            continue

        var value: Variant = route.get(property_name)
        if not _is_variant_save_safe(value):
            continue

        state[property_name] = value

    return state


func _is_save_system_internal(property_name: String) -> bool:
    return (
        property_name.begins_with("_run_save_")
        or property_name.begins_with("_run_exit_")
        or property_name == "_autosave_timer"
    )


func _is_variant_save_safe(value: Variant) -> bool:
    match typeof(value):
        TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
            return false
        TYPE_ARRAY:
            for item: Variant in value as Array:
                if not _is_variant_save_safe(item):
                    return false
            return true
        TYPE_DICTIONARY:
            var dictionary: Dictionary = value as Dictionary
            for key_value: Variant in dictionary.keys():
                if not _is_variant_save_safe(key_value):
                    return false
                if not _is_variant_save_safe(dictionary[key_value]):
                    return false
            return true
        _:
            return true
