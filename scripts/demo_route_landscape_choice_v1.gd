extends "res://scripts/demo_route_landscape_start_v1.gd"

# Schritt 3 des Landschaftssystems:
# Nach einer vollständig abgearbeiteten Etappe wählt der Spieler die Landschaft
# der nächsten Etappe aus zwei unterschiedlichen Zufallsangeboten. Die Auswahl
# erscheint erst, wenn Level-Up-/Entwicklungs-Popups vollständig erledigt sind.
# Etappe 1 bleibt fest Wiese; 96-100 sind für die späteren festen Endgame-Ziele
# reserviert und erhalten deshalb hier bewusst keine Zufallsauswahl.

const RANDOM_LANDSCAPE_FIRST_STAGE: int = 2
const RANDOM_LANDSCAPE_LAST_STAGE: int = 95
const LANDSCAPE_CHOICE_COUNT: int = 2
const LANDSCAPE_CARD_IMAGE_SIZE: Vector2 = Vector2(168.0, 126.0)
const ROUTE_EVENT_LABEL_MIN_HEIGHT: float = 58.0
const LANDSCAPE_EVENT_LABEL_MIN_HEIGHT: float = 72.0

var _tf_landscape_prepared_stage: int = 1
var _tf_landscape_choice_active: bool = false
var _tf_landscape_choice_waiting: bool = false
var _tf_landscape_choice_sequence_id: int = 0
var _tf_landscape_pending_message: String = ""


func start_route() -> void:
    _tf_landscape_prepared_stage = 1
    _tf_landscape_choice_active = false
    _tf_landscape_choice_waiting = false
    _tf_landscape_choice_sequence_id += 1
    _tf_landscape_pending_message = ""
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    if _tf_should_offer_landscape_choice():
        _tf_queue_landscape_choice(message)
        return
    super._show_stage_choices(message)
    _tf_prepare_route_choice_layout(false)


func _tf_should_offer_landscape_choice() -> bool:
    if stage < RANDOM_LANDSCAPE_FIRST_STAGE or stage > RANDOM_LANDSCAPE_LAST_STAGE:
        return false
    return stage != _tf_landscape_prepared_stage


func _tf_prepare_route_choice_layout(landscape_choice: bool) -> void:
    # Die Etappenzahl steht bereits prominent im Titel. Die zusätzliche
    # Prozent-/Fortschrittszeile nimmt nur Platz weg und bleibt deshalb verborgen.
    if progress_label != null:
        progress_label.visible = false

    # path_box kann von spezialisierten Route-Zuständen ausgeblendet worden sein.
    # Für normale Weg- und insbesondere Landschaftsauswahlen muss er sicher
    # sichtbar sein, sonst existieren die Buttons zwar, sind aber nicht spielbar.
    if path_box != null:
        path_box.visible = true

    # Routentexte sollen vollständig im Layout stehen statt in einem kleinen
    # RichTextLabel-Fenster mit eigener Scrollbar zu verschwinden.
    if event_label != null:
        event_label.fit_content = true
        event_label.scroll_active = false
        event_label.size_flags_vertical = Control.SIZE_FILL
        event_label.custom_minimum_size = Vector2(
            0.0,
            LANDSCAPE_EVENT_LABEL_MIN_HEIGHT if landscape_choice else ROUTE_EVENT_LABEL_MIN_HEIGHT
        )


func _tf_queue_landscape_choice(message: String) -> void:
    _tf_landscape_pending_message = message
    if _tf_landscape_choice_active or _tf_landscape_choice_waiting:
        return

    _tf_landscape_choice_waiting = true
    _tf_landscape_choice_sequence_id += 1
    var sequence_id: int = _tf_landscape_choice_sequence_id

    visible = true
    restart_button.visible = false
    continue_button.visible = false
    _clear_container(path_box)
    _clear_container(capture_actions)
    _tf_prepare_route_choice_layout(true)
    title_label.text = "Etappe %d von %d" % [stage, ENDGAME_ROUTE_STAGE_COUNT]
    event_label.text = message

    _tf_wait_for_progression_then_show_landscapes(sequence_id)


func _tf_wait_for_progression_then_show_landscapes(sequence_id: int) -> void:
    # Mindestens einen Frame warten: Level-Up-Popups werden in der bestehenden
    # Route teilweise deferred geöffnet. Die Queue selbst ist aber bereits
    # gefüllt und verhindert, dass die Landschaftsauswahl zu früh erscheint.
    await get_tree().process_frame

    while _route_progression_presentation_pending():
        if sequence_id != _tf_landscape_choice_sequence_id:
            return
        await get_tree().process_frame

    if sequence_id != _tf_landscape_choice_sequence_id:
        return

    _tf_landscape_choice_waiting = false
    _tf_show_landscape_choice_cards()


func _tf_show_landscape_choice_cards() -> void:
    var choices: Array[String] = _tf_random_landscape_choice_ids()
    if choices.size() != LANDSCAPE_CHOICE_COUNT:
        push_error("Landschaftsauswahl benötigt genau zwei gültige Landschaften.")
        _tf_landscape_prepared_stage = stage
        super._show_stage_choices(_tf_landscape_pending_message)
        _tf_prepare_route_choice_layout(false)
        return

    _tf_landscape_choice_active = true
    visible = true
    restart_button.visible = false
    continue_button.visible = false
    _clear_container(path_box)
    _clear_container(capture_actions)
    _tf_prepare_route_choice_layout(true)

    title_label.text = "Etappe %d von %d" % [stage, ENDGAME_ROUTE_STAGE_COUNT]

    var intro: String = "[b]Wohin führt dein Weg?[/b]\nWähle die Landschaft für Etappe %d." % stage
    if not _tf_landscape_pending_message.is_empty():
        event_label.text = _tf_landscape_pending_message + "\n\n" + intro
    else:
        event_label.text = intro

    var row := HBoxContainer.new()
    row.name = "LandscapeChoiceRow"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_theme_constant_override("separation", 10)
    path_box.add_child(row)

    for landscape_id: String in choices:
        var landscape: Dictionary = route_landscape(landscape_id)
        row.add_child(_tf_make_landscape_choice_card(landscape_id, landscape))

    _refresh_team_panel()


func _tf_make_landscape_choice_card(landscape_id: String, landscape: Dictionary) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(184.0, 160.0)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override(
        "panel",
        _panel(Color("162620"), Color("8cab7c"), 9, 5.0)
    )

    var content := VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 4)
    card.add_child(content)

    var background_path: String = str(landscape.get("background", "")).strip_edges()
    var texture_value: Resource = load(background_path)

    var image_button := TextureButton.new()
    image_button.name = "LandscapeImage_" + landscape_id
    image_button.custom_minimum_size = LANDSCAPE_CARD_IMAGE_SIZE
    image_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    image_button.ignore_texture_size = true
    image_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    image_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    image_button.tooltip_text = "Diese Landschaft für Etappe %d wählen." % stage
    if texture_value is Texture2D:
        image_button.texture_normal = texture_value as Texture2D
    image_button.pressed.connect(_tf_select_landscape.bind(landscape_id))
    content.add_child(image_button)

    var name_button := Button.new()
    name_button.name = "LandscapeName_" + landscape_id
    name_button.text = str(landscape.get("name", landscape_id))
    name_button.custom_minimum_size = Vector2(168.0, 26.0)
    name_button.add_theme_font_size_override("font_size", 11)
    name_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    name_button.tooltip_text = "Diese Landschaft für Etappe %d wählen." % stage
    name_button.pressed.connect(_tf_select_landscape.bind(landscape_id))
    content.add_child(name_button)

    return card


func _tf_select_landscape(landscape_id: String) -> void:
    if not _tf_landscape_choice_active:
        return

    var landscape: Dictionary = route_landscape(landscape_id)
    if landscape.is_empty():
        return

    _tf_landscape_choice_active = false
    _tf_landscape_choice_waiting = false
    _tf_landscape_choice_sequence_id += 1
    current_landscape_id = landscape_id
    _tf_landscape_prepared_stage = stage
    _tf_apply_current_landscape_background()

    var chosen_name: String = str(landscape.get("name", landscape_id))
    var next_message: String = _tf_landscape_pending_message
    if not next_message.is_empty():
        next_message += "\n\n"
    next_message += "[b]🗺 Neue Landschaft: %s[/b]" % chosen_name
    _tf_landscape_pending_message = ""

    super._show_stage_choices(next_message)
    _tf_prepare_route_choice_layout(false)


func _tf_random_landscape_choice_ids() -> Array[String]:
    var pool: Array[String] = _tf_available_landscape_ids()
    if pool.size() < LANDSCAPE_CHOICE_COUNT:
        return []

    pool.shuffle()
    var result: Array[String] = []
    for index: int in range(LANDSCAPE_CHOICE_COUNT):
        result.append(pool[index])
    return result


func _tf_available_landscape_ids() -> Array[String]:
    _tf_load_landscape_registry()
    var result: Array[String] = []

    for id_value: Variant in _landscape_by_id.keys():
        var landscape_id: String = str(id_value)
        var landscape_value: Variant = _landscape_by_id.get(landscape_id, {})
        if not (landscape_value is Dictionary):
            continue
        var landscape: Dictionary = landscape_value as Dictionary
        var background_path: String = str(landscape.get("background", "")).strip_edges()
        if background_path.is_empty() or not FileAccess.file_exists(background_path):
            continue
        result.append(landscape_id)

    return result
