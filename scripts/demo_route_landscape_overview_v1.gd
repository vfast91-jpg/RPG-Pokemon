extends "res://scripts/demo_route_landscape_choice_v1.gd"

# Schritt 4 des Landschaftssystems:
# Die aktuelle Landschaft ist ein echter Route-Zustand und bleibt im
# Etappenbildschirm sichtbar. Vor jedem normalen oder besonderen Route-Kampf
# wird ihr Hintergrund erneut gesetzt, damit der Kampf immer zur Route passt.

# Die normale Etappenansicht muss vollständig in den 640x360-Viewport passen.
# Da das Fenster auf 1280x720 skaliert wird, zählt hier jeder interne Pixel
# doppelt. Die Landschaftskarte bleibt deshalb bewusst kompakt und der Hinweis
# bleibt einzeilig. So bleibt auch der untere Goldrahmen zuverlässig sichtbar.
const CURRENT_LANDSCAPE_CARD_HEIGHT: float = 54.0
const CURRENT_LANDSCAPE_THUMBNAIL_SIZE: Vector2 = Vector2(66.0, 46.0)


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)

    # Während der separaten Landschaftsauswahl sollen nur die zwei Zielkarten
    # sichtbar sein. Sobald eine Landschaft gewählt ist, erscheint die kompakte
    # Anzeige wieder im normalen Etappenbildschirm.
    if _tf_landscape_choice_active or _tf_landscape_choice_waiting:
        return
    _tf_show_current_landscape_card()


func _tf_select_landscape(landscape_id: String) -> void:
    var had_active_choice: bool = _tf_landscape_choice_active
    super._tf_select_landscape(landscape_id)
    if had_active_choice and not _tf_landscape_choice_active:
        AudioManager.play_landscape_travel_sfx()
    if _tf_landscape_choice_active or _tf_landscape_choice_waiting:
        return
    _tf_show_current_landscape_card()


func _start_stage_battle() -> void:
    _tf_apply_current_landscape_background()
    super._start_stage_battle()


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    _tf_apply_current_landscape_background()
    super._start_special_battle(kind, enemy_party, heading)


func route_current_landscape_name() -> String:
    var landscape: Dictionary = route_current_landscape()
    return str(landscape.get("name", current_landscape_id))


func _tf_show_current_landscape_card() -> void:
    if path_box == null:
        return

    var old_card: Node = path_box.get_node_or_null("CurrentLandscapeCard")
    if old_card != null:
        old_card.free()

    var landscape: Dictionary = route_current_landscape()
    if landscape.is_empty():
        return

    var card: Control = _tf_make_current_landscape_card(landscape)
    path_box.add_child(card)
    path_box.move_child(card, 0)


func _tf_make_current_landscape_card(landscape: Dictionary) -> Control:
    var card := PanelContainer.new()
    card.name = "CurrentLandscapeCard"
    card.custom_minimum_size = Vector2(0.0, CURRENT_LANDSCAPE_CARD_HEIGHT)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override(
        "panel",
        _panel(Color("162620"), Color("739a82"), 8, 3.0)
    )

    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 7)
    card.add_child(row)

    var thumbnail := TextureRect.new()
    thumbnail.name = "CurrentLandscapeThumbnail"
    thumbnail.custom_minimum_size = CURRENT_LANDSCAPE_THUMBNAIL_SIZE
    thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    thumbnail.clip_contents = true
    thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background_path: String = str(landscape.get("background", "")).strip_edges()
    var texture_value: Resource = load(background_path)
    if texture_value is Texture2D:
        thumbnail.texture = texture_value as Texture2D
    row.add_child(thumbnail)

    var text_box := VBoxContainer.new()
    text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_box.alignment = BoxContainer.ALIGNMENT_CENTER
    text_box.add_theme_constant_override("separation", 1)
    row.add_child(text_box)

    var caption := Label.new()
    caption.name = "CurrentLandscapeCaption"
    caption.text = "🗺 AKTUELLE LANDSCHAFT"
    caption.add_theme_font_size_override("font_size", 8)
    caption.add_theme_color_override("font_color", Color("a7cdbb"))
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(caption)

    var name_label := Label.new()
    name_label.name = "CurrentLandscapeName"
    name_label.text = str(landscape.get("name", current_landscape_id))
    name_label.add_theme_font_size_override("font_size", 13)
    name_label.add_theme_color_override("font_color", Color("fff0ad"))
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(name_label)

    var hint := Label.new()
    hint.name = "CurrentLandscapeHint"
    hint.text = "Bestimmt Kampfhintergrund und Pokémon-Typen dieser Etappe."
    hint.add_theme_font_size_override("font_size", 7)
    hint.add_theme_color_override("font_color", Color("b8d3c7"))
    hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    text_box.add_child(hint)

    return card
