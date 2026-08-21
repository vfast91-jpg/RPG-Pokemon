extends "res://scripts/main.gd"

const LEADERBOARD_ICON_SIZE := 30


func _build_leaderboard_overlay() -> void:
	leaderboard_panel = PanelContainer.new()
	leaderboard_panel.name = "LeaderboardPanel"
	leaderboard_panel.custom_minimum_size = Vector2(1000, 410)
	leaderboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	leaderboard_panel.visible = false
	leaderboard_panel.z_index = 220
	add_child(leaderboard_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	leaderboard_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "BESTENLISTE"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Trainer • Etappe • Team mit Level"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.85, 0.90, 1.0)
	box.add_child(subtitle)

	leaderboard_text = RichTextLabel.new()
	leaderboard_text.custom_minimum_size = Vector2(960, 220)
	leaderboard_text.fit_content = false
	leaderboard_text.scroll_active = true
	leaderboard_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	leaderboard_text.add_theme_font_size_override("normal_font_size", 18)
	box.add_child(leaderboard_text)

	var reset_btn := Button.new()
	reset_btn.text = "Lokale Liste löschen"
	reset_btn.custom_minimum_size = Vector2(0, 42)
	reset_btn.pressed.connect(_on_reset_leaderboard)
	box.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Zurück"
	close_btn.custom_minimum_size = Vector2(0, 46)
	close_btn.pressed.connect(_hide_leaderboard)
	box.add_child(close_btn)

	_refresh_leaderboard()


func _refresh_leaderboard() -> void:
	if leaderboard_text == null:
		return

	leaderboard_text.clear()
	var entries: Array = LEADERBOARD_STORE.top_entries(10)
	if entries.is_empty():
		leaderboard_text.append_text("Noch keine Läufe gespeichert.\nSchließe eine Demo-Route ab.")
		return

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var stage := int(entry.get("stage", 0))
		var player_name := str(entry.get("player_name", "Trainer"))
		leaderboard_text.append_text("%d. %s  •  Etappe %d/90  •  " % [i + 1, player_name, stage])
		_append_leaderboard_team(entry)
		if i < entries.size() - 1:
			leaderboard_text.append_text("\n")


func _append_leaderboard_team(entry: Dictionary) -> void:
	var team: Array = entry.get("team", [])
	var valid_members: Array[Dictionary] = []
	for raw_member in team:
		if typeof(raw_member) == TYPE_DICTIONARY:
			valid_members.append(Dictionary(raw_member))

	if valid_members.is_empty():
		leaderboard_text.append_text("Kein Team gespeichert")
		return

	for i in range(valid_members.size()):
		var member := valid_members[i]
		var pokemon_name := str(member.get("name", "?"))
		var level := int(member.get("level", 1))
		var texture := _leaderboard_monster_texture(pokemon_name)
		if texture != null:
			leaderboard_text.add_image(texture, LEADERBOARD_ICON_SIZE, LEADERBOARD_ICON_SIZE)
		else:
			leaderboard_text.append_text(pokemon_name)
		leaderboard_text.append_text(" Lv.%d" % level)
		if i < valid_members.size() - 1:
			leaderboard_text.append_text("   ")


func _leaderboard_monster_texture(pokemon_name: String) -> Texture2D:
	var clean_name := pokemon_name.strip_edges()
	if clean_name.is_empty():
		return null
	var path := "res://assets/monsters/%s.png" % clean_name
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D
