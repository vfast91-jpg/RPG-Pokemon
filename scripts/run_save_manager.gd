extends Node

# Exactly one active adventure save. MetaProgression and the leaderboard use
# their own files and are deliberately never touched here.
const SAVE_PATH: String = "user://timeflow_run_save.dat"
const SAVE_VERSION: int = 2
const MIN_SUPPORTED_SAVE_VERSION: int = 1
const SAVE_KIND: String = "adventure_route"

# Kept configurable so the persistence layer can be regression-tested without
# ever touching a player's real adventure save.
var save_path: String = SAVE_PATH
var _last_payload_hash: int = 0


func has_run_save() -> bool:
    return not load_run_save().is_empty()


func saved_stage() -> int:
    var payload: Dictionary = load_run_save()
    return maxi(1, int(payload.get("stage", 1))) if not payload.is_empty() else 1


func saved_checkpoint() -> String:
    var payload: Dictionary = load_run_save()
    return str(payload.get("checkpoint", "stage_checkpoint")) if not payload.is_empty() else ""


func saved_version() -> int:
    var payload: Dictionary = load_run_save()
    return int(payload.get("version", 0)) if not payload.is_empty() else 0


func save_route(route: Node, checkpoint: String = "stage_start") -> bool:
    if route == null:
        return false

    var state: Dictionary = _snapshot_script_state(route)
    if state.is_empty():
        push_error("RunSaveManager: Kein speicherbarer Run-Zustand gefunden.")
        return false
    if not state.has("stage") or not state.has("team"):
        push_error("RunSaveManager: Pflichtfelder stage/team fehlen im Run-Snapshot.")
        return false

    var payload_hash: int = hash([checkpoint, state])
    if payload_hash == _last_payload_hash and not load_run_save().is_empty():
        return true

    var payload: Dictionary = {
        "version": SAVE_VERSION,
        "kind": SAVE_KIND,
        "checkpoint": checkpoint,
        "stage": maxi(1, int(route.get("stage"))),
        "saved_at": int(Time.get_unix_time_from_system()),
        "state": state
    }

    # Write and validate a temporary file first. Only after that succeeds is the
    # previous checkpoint moved aside and the new file promoted. A failed write
    # therefore cannot silently destroy the last valid stage-start checkpoint.
    var temp_path: String = save_path + ".tmp"
    var backup_path: String = save_path + ".bak"
    _remove_file_if_exists(temp_path)
    _remove_file_if_exists(backup_path)

    if not _write_payload(temp_path, payload):
        _remove_file_if_exists(temp_path)
        return false

    var moved_previous: bool = false
    if FileAccess.file_exists(save_path):
        var backup_error: Error = DirAccess.rename_absolute(
            ProjectSettings.globalize_path(save_path),
            ProjectSettings.globalize_path(backup_path)
        )
        if backup_error != OK:
            push_error(
                "RunSaveManager: Alter Spielstand konnte nicht gesichert werden (%s)."
                % error_string(backup_error)
            )
            _remove_file_if_exists(temp_path)
            return false
        moved_previous = true

    var promote_error: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp_path),
        ProjectSettings.globalize_path(save_path)
    )
    if promote_error != OK:
        push_error(
            "RunSaveManager: Neuer Spielstand konnte nicht aktiviert werden (%s)."
            % error_string(promote_error)
        )
        if moved_previous and FileAccess.file_exists(backup_path):
            DirAccess.rename_absolute(
                ProjectSettings.globalize_path(backup_path),
                ProjectSettings.globalize_path(save_path)
            )
        _remove_file_if_exists(temp_path)
        return false

    var verified: Dictionary = _load_payload_from_path(save_path)
    if verified.is_empty() or int(verified.get("version", 0)) != SAVE_VERSION:
        push_error("RunSaveManager: Neuer Spielstand konnte nach Aktivierung nicht verifiziert werden.")
        _remove_file_if_exists(save_path)
        if moved_previous and FileAccess.file_exists(backup_path):
            DirAccess.rename_absolute(
                ProjectSettings.globalize_path(backup_path),
                ProjectSettings.globalize_path(save_path)
            )
        return false

    _remove_file_if_exists(backup_path)
    _last_payload_hash = payload_hash
    return true


func load_run_save() -> Dictionary:
    _recover_previous_checkpoint_if_needed()
    return _load_payload_from_path(save_path)


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

    _last_payload_hash = hash([str(payload.get("checkpoint", "")), state])
    return true


func clear_run_save() -> void:
    _last_payload_hash = 0
    _remove_file_if_exists(save_path)
    _remove_file_if_exists(save_path + ".tmp")
    _remove_file_if_exists(save_path + ".bak")


func _write_payload(path: String, payload: Dictionary) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("RunSaveManager: Spielstand konnte nicht geöffnet werden: %s" % path)
        return false

    file.store_var(payload, false)
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    if write_error != OK:
        push_error(
            "RunSaveManager: Fehler beim Schreiben des Spielstands (%s)."
            % error_string(write_error)
        )
        return false

    var verified: Dictionary = _load_payload_from_path(path)
    if verified.is_empty():
        push_error("RunSaveManager: Geschriebener Spielstand konnte nicht verifiziert werden.")
        return false
    return true


func _load_payload_from_path(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}

    var value: Variant = file.get_var(false)
    var read_error: Error = file.get_error()
    file.close()
    if read_error != OK and read_error != ERR_FILE_EOF:
        return {}
    if not (value is Dictionary):
        return {}

    var payload: Dictionary = value as Dictionary
    var version: int = int(payload.get("version", 0))
    if version < MIN_SUPPORTED_SAVE_VERSION or version > SAVE_VERSION:
        return {}
    if str(payload.get("kind", "")) != SAVE_KIND:
        return {}
    if not (payload.get("state", {}) is Dictionary):
        return {}
    return payload


func _recover_previous_checkpoint_if_needed() -> void:
    if FileAccess.file_exists(save_path):
        return

    var backup_path: String = save_path + ".bak"
    if not FileAccess.file_exists(backup_path):
        return

    var restore_error: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(backup_path),
        ProjectSettings.globalize_path(save_path)
    )
    if restore_error != OK:
        push_warning(
            "RunSaveManager: Sicherungskopie konnte nicht wiederhergestellt werden (%s)."
            % error_string(restore_error)
        )


func _remove_file_if_exists(path: String) -> void:
    if not FileAccess.file_exists(path):
        return
    var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if error != OK:
        push_warning(
            "RunSaveManager: Temporäre Spielstandsdatei konnte nicht gelöscht werden (%s)."
            % error_string(error)
        )


func _snapshot_script_state(route: Node) -> Dictionary:
    var state: Dictionary = {}

    for info_value: Variant in route.get_property_list():
        if not (info_value is Dictionary):
            continue

        var info: Dictionary = info_value as Dictionary
        var usage: int = int(info.get("usage", 0))

        # Runtime GDScript members are the actual run state. They do NOT need to
        # carry PROPERTY_USAGE_STORAGE; requiring that flag was the bug that
        # could produce an empty snapshot and therefore no save file at all.
        if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
            continue

        var property_name: String = str(info.get("name", ""))
        _copy_property_if_safe(route, property_name, state)

    # Defensive fallback for the two fields without which a run can never be
    # considered valid, even if Godot changes property usage flags in a future
    # version.
    _copy_property_if_safe(route, "stage", state)
    _copy_property_if_safe(route, "team", state)
    return state


func _copy_property_if_safe(route: Node, property_name: String, state: Dictionary) -> void:
    if property_name.is_empty() or state.has(property_name):
        return
    if _is_save_system_internal(property_name):
        return

    var value: Variant = route.get(property_name)
    if not _is_variant_save_safe(value):
        return
    state[property_name] = value


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
            var array_value: Array = value as Array
            for item: Variant in array_value:
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
