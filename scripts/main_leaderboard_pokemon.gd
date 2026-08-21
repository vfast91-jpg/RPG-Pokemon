extends "res://scripts/main.gd"

const LEADERBOARD_ICON_SIZE := 20
const LEADERBOARD_NAME_MAX_LENGTH := 14


func _build_leaderboard_overlay() -> void:
    super._build_leaderboard_overlay()

    if leaderboard_text == null:
        return

    var content := leaderboard_text.get_parent() as VBoxContainer
    if content == null:
        return

    var reset_button := Button.new()
    reset_button.name = "ResetLeaderboardButton"
    reset_button.text = "Lokale Liste löschen"
    reset_button.custom_minimum_size = Vector2(180, 30)
    reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    reset_button.pressed.connect(_on_reset_leaderboard)
    content.add_child(reset_button)

    # Keep the existing ZURÜCK button as the last control in the panel.
    var child_count := content.get_child_count()
    if child_count >= 2:
        content.move_child(reset_button, child_count - 2)


func _refresh_leaderboard() -> void:
    if leaderboard_text == null:
        return

    leaderboard_text.clear()
    var entries: Array = LeaderboardStore.load_entries()
    if entries.is_empty():
        leaderboard_text.add_text("Noch keine Läufe gespeichert.\nSchließe eine Demo-Route ab.")
        return

    for i in range(mini(entries.size(), 10)):
        var entry_value: Variant = entries[i]
        if not (entry_value is Dictionary):
            continue

        var entry: Dictionary = entry_value
        var stage := int(entry.get("stage", 0))
        var player_name := _short_leaderboard_name(str(entry.get("name", "Trainer")))
        leaderboard_text.add_text("%d. %s • Et.%d • " % [i + 1, player_name, stage])
        _append_leaderboard_team(entry)
        if i < mini(entries.size(), 10) - 1:
            leaderboard_text.add_text("\n")

    leaderboard_text.scroll_to_line(0)


func _append_leaderboard_team(entry: Dictionary) -> void:
    var team_value: Variant = entry.get("team", [])
    if not (team_value is Array):
        leaderboard_text.add_text("Kein Team gespeichert")
        return

    var team: Array = team_value
    var valid_members: Array[Dictionary] = []
    for raw_member: Variant in team:
        if raw_member is Dictionary:
            valid_members.append(raw_member)

    if valid_members.is_empty():
        leaderboard_text.add_text("Kein Team gespeichert")
        return

    for i in range(valid_members.size()):
        var member: Dictionary = valid_members[i]
        var pokemon_name := str(member.get("name", "?"))
        var level := int(member.get("level", 1))
        var texture := _leaderboard_monster_texture(pokemon_name)
        if texture != null:
            leaderboard_text.add_image(texture, LEADERBOARD_ICON_SIZE, LEADERBOARD_ICON_SIZE)
        else:
            leaderboard_text.add_text(pokemon_name)
        leaderboard_text.add_text(" Lv.%d" % level)
        if i < valid_members.size() - 1:
            leaderboard_text.add_text("  ")


func _short_leaderboard_name(player_name: String) -> String:
    var clean_name := player_name.strip_edges()
    if clean_name.is_empty():
        return "Trainer"
    if clean_name.length() <= LEADERBOARD_NAME_MAX_LENGTH:
        return clean_name
    return clean_name.left(LEADERBOARD_NAME_MAX_LENGTH - 1) + "…"


func _leaderboard_monster_texture(pokemon_name: String) -> Texture2D:
    var clean_name := pokemon_name.strip_edges()
    if clean_name.is_empty():
        return null

    var path := "res://assets/monsters/%s.png" % clean_name
    if not ResourceLoader.exists(path):
        return null
    return ResourceLoader.load(path) as Texture2D


func _on_reset_leaderboard() -> void:
    var save_path := ProjectSettings.globalize_path(LeaderboardStore.SAVE_PATH)
    if FileAccess.file_exists(LeaderboardStore.SAVE_PATH):
        var remove_error := DirAccess.remove_absolute(save_path)
        if remove_error != OK:
            push_warning("Bestenliste konnte nicht gelöscht werden: %s" % error_string(remove_error))
    _refresh_leaderboard()
