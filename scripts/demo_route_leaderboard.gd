extends RefCounted

const SAVE_PATH: String = "user://demo_route_bestenliste.json"
const MAX_ENTRIES: int = 100
const MAX_NAME_LENGTH: int = 24
const MAX_ROUTE_STAGE: int = 90


static func load_entries() -> Array:
    if not FileAccess.file_exists(SAVE_PATH):
        return []

    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return []

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return []

    var entries_value: Variant = (parsed as Dictionary).get("entries", [])
    if not (entries_value is Array):
        return []

    var entries: Array = []
    for entry_value: Variant in entries_value:
        if entry_value is Dictionary:
            entries.append((entry_value as Dictionary).duplicate(true))

    entries.sort_custom(_entry_before)
    return entries


static func add_entry(entry: Dictionary) -> bool:
    var clean_entry: Dictionary = _normalize_entry(entry)
    if clean_entry.is_empty():
        return false

    var entries: Array = load_entries()
    entries.append(clean_entry)
    entries.sort_custom(_entry_before)
    if entries.size() > MAX_ENTRIES:
        entries.resize(MAX_ENTRIES)

    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false

    file.store_string(JSON.stringify({"version": 1, "entries": entries}, "  "))
    return true


static func team_text(entry: Dictionary) -> String:
    var team_value: Variant = entry.get("team", [])
    if not (team_value is Array) or (team_value as Array).is_empty():
        return "–"

    var parts: Array[String] = []
    for member_value: Variant in team_value:
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        parts.append("%s Lv.%d" % [
            str(member.get("name", "Pokémon")),
            maxi(1, int(member.get("level", 1)))
        ])
    return " · ".join(parts) if not parts.is_empty() else "–"


static func _normalize_entry(entry: Dictionary) -> Dictionary:
    var name: String = str(entry.get("name", "")).strip_edges()
    if name.is_empty():
        return {}
    if name.length() > MAX_NAME_LENGTH:
        name = name.substr(0, MAX_NAME_LENGTH)

    return {
        "name": name,
        "stage": clampi(int(entry.get("stage", 1)), 1, MAX_ROUTE_STAGE),
        "victory": bool(entry.get("victory", false)),
        "outcome": str(entry.get("outcome", "Niederlage")),
        "team": _normalize_team(entry.get("team", [])),
        "timestamp": int(entry.get("timestamp", Time.get_unix_time_from_system()))
    }


static func _normalize_team(team_value: Variant) -> Array:
    var result: Array = []
    if not (team_value is Array):
        return result

    for member_value: Variant in team_value:
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        result.append({
            "species_id": str(member.get("species_id", "")),
            "name": str(member.get("name", "Pokémon")),
            "level": maxi(1, int(member.get("level", 1))),
            "hp": maxi(0, int(member.get("hp", 0))),
            "max_hp": maxi(1, int(member.get("max_hp", 1)))
        })
    return result


static func _entry_before(a_value: Variant, b_value: Variant) -> bool:
    if not (a_value is Dictionary) or not (b_value is Dictionary):
        return false

    var a: Dictionary = a_value
    var b: Dictionary = b_value
    var a_stage: int = int(a.get("stage", 0))
    var b_stage: int = int(b.get("stage", 0))
    if a_stage != b_stage:
        return a_stage > b_stage

    var a_victory: bool = bool(a.get("victory", false))
    var b_victory: bool = bool(b.get("victory", false))
    if a_victory != b_victory:
        return a_victory and not b_victory

    return int(a.get("timestamp", 0)) < int(b.get("timestamp", 0))
