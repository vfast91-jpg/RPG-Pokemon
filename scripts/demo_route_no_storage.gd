extends "res://scripts/demo_route_radar_hp_normalized.gd"

# Active demo-route rule: there is no Pokemon storage/box system.
# A full four-Pokemon team can either replace one member or decline the capture.
# Declining the capture grants the same 25% XP multiplier as the direct path for
# the immediately following stage battle, so choosing a capture path is not a
# completely lost reward when the offered Pokemon is not wanted.

const CAPTURE_DECLINE_XP_MULTIPLIER: float = 1.25

var main_menu_confirmation: ConfirmationDialog


func _ready() -> void:
    super._ready()
    _hide_legacy_storage_ui()
    _build_main_menu_confirmation()


func start_route() -> void:
    super.start_route()
    # Keep the inherited legacy array permanently inert. Nothing in the active
    # route may add Pokemon to it or expose it to the player.
    storage.clear()
    _hide_legacy_storage_ui()


func _refresh_team_panel() -> void:
    super._refresh_team_panel()
    _hide_legacy_storage_ui()


func _hide_legacy_storage_ui() -> void:
    if storage_label == null:
        return
    storage_label.text = ""
    storage_label.tooltip_text = ""
    storage_label.visible = false


func _build_main_menu_confirmation() -> void:
    if main_menu_confirmation != null:
        return

    main_menu_confirmation = ConfirmationDialog.new()
    main_menu_confirmation.title = "Demo-Route abbrechen?"
    main_menu_confirmation.dialog_text = (
        "Willst du deinen aktuellen Durchlauf wirklich abbrechen?\n"
        + "Dein Fortschritt in dieser Demo-Route geht verloren."
    )
    main_menu_confirmation.ok_button_text = "DURCHLAUF ABBRECHEN"
    main_menu_confirmation.cancel_button_text = "WEITERSPIELEN"
    main_menu_confirmation.unresizable = true
    main_menu_confirmation.exclusive = true
    main_menu_confirmation.confirmed.connect(_confirm_main_menu)
    add_child(main_menu_confirmation)


func _go_main_menu() -> void:
    if main_menu_confirmation == null:
        _build_main_menu_confirmation()
    main_menu_confirmation.popup_centered(Vector2i(420, 180))


func _confirm_main_menu() -> void:
    visible = false
    request_main_menu.emit()


func _begin_capture_event() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false

    if battle_demo == null:
        return

    var capture_level: int = _capture_level_for_stage(stage)
    var max_reachable_level: int = _max_reachable_level_from_stage(capture_level, stage)
    var roots: Array = battle_demo.route_species_ids_valid_through_level(max_reachable_level)
    if roots.is_empty():
        event_label.text = "An dieser Fangstelle taucht heute kein vollständig designbares Pokémon auf."
        continue_button.visible = true
        return

    var root_id: String = str(roots.pick_random())
    var species_id: String = battle_demo.route_resolve_species_for_level(root_id, capture_level)
    if species_id.is_empty():
        event_label.text = "Diese Begegnung wurde verworfen, weil die verpflichtende Entwicklungsform noch nicht eindeutig auflösbar ist."
        continue_button.visible = true
        return

    pending_capture = battle_demo.route_new_member(species_id, capture_level)
    if pending_capture.is_empty():
        event_label.text = "Das Pokémon konnte nicht aus den Speziesdaten erzeugt werden."
        continue_button.visible = true
        return

    pending_capture.erase("prevent_evolution")
    var name: String = str(pending_capture.get("name", battle_demo.route_species_name(species_id)))

    if team.size() < ROUTE_TEAM_MAX:
        team.append(pending_capture)
        pending_capture = {}
        event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen und deinem Team hinzugefügt." % [name, capture_level]
        continue_button.visible = true
        _refresh_team_panel()
        return

    event_label.text = (
        "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen. Dein Team mit vier Pokémon ist voll. "
        + "Möchtest du ein Team-Pokémon ersetzen oder den Fang nicht aufnehmen und dafür 25%% mehr EP im Etappenkampf erhalten?"
    ) % [name, capture_level]
    _show_full_team_capture_actions()


func _show_full_team_capture_actions() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false

    var replace_button := Button.new()
    replace_button.text = "TEAM-POKÉMON ERSETZEN"
    replace_button.pressed.connect(_show_replace_choices)
    capture_actions.add_child(replace_button)

    var decline_button := Button.new()
    decline_button.text = "NICHT AUFNEHMEN · +25% EP"
    decline_button.tooltip_text = "Das gefangene Pokémon wird nicht ins Team aufgenommen. Der unmittelbar folgende Etappenkampf gibt 25% mehr EP."
    decline_button.pressed.connect(_decline_pending_capture)
    capture_actions.add_child(decline_button)


func _decline_pending_capture() -> void:
    if pending_capture.is_empty():
        return

    var name: String = str(pending_capture.get("name", "Pokémon"))
    pending_capture = {}
    stage_xp_multiplier = maxf(stage_xp_multiplier, CAPTURE_DECLINE_XP_MULTIPLIER)
    _clear_container(capture_actions)
    event_label.text = (
        "[b]%s wird nicht ins Team aufgenommen.[/b]\n"
        + "Als Ausgleich erhält dein Team im unmittelbar folgenden Etappenkampf [b]25%% mehr EP[/b]."
    ) % name
    continue_button.visible = true
    _refresh_team_panel()


# Compatibility guard for stale inherited callbacks. Storage no longer exists
# as an active route mechanic, so an old store action behaves like declining.
func _store_pending_capture() -> void:
    _decline_pending_capture()


func _show_replace_choices() -> void:
    if pending_capture.is_empty():
        return

    _clear_container(capture_actions)
    continue_button.visible = false

    var prompt := Label.new()
    prompt.text = "Welches Pokémon soll dein Team verlassen?"
    prompt.add_theme_font_size_override("font_size", 9)
    capture_actions.add_child(prompt)

    # The active route is capped at four Pokemon. Four 24px rows plus their
    # spacing fit into 106px, so use the otherwise free vertical room instead
    # of forcing the player to scroll just to reach team slots 3 and 4.
    var choices_scroll := ScrollContainer.new()
    choices_scroll.custom_minimum_size = Vector2(0, 106)
    choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    capture_actions.add_child(choices_scroll)

    var choices_box := VBoxContainer.new()
    choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices_box.add_theme_constant_override("separation", 2)
    choices_scroll.add_child(choices_box)

    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        var button := Button.new()
        button.text = "%d. %s Lv.%d" % [
            index + 1,
            str(member.get("name", "Pokémon")),
            int(member.get("level", 1))
        ]
        button.custom_minimum_size = Vector2(0, 24)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_replace_team_member.bind(index))
        choices_box.add_child(button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.pressed.connect(_begin_capture_event_again)
    capture_actions.add_child(back_button)


func _begin_capture_event_again() -> void:
    if pending_capture.is_empty():
        return

    var name: String = str(pending_capture.get("name", "Pokémon"))
    var level: int = maxi(1, int(pending_capture.get("level", _capture_level_for_stage(stage))))
    event_label.text = (
        "[b]Fangwiese[/b]\n%s Lv.%d wartet auf deine Entscheidung: "
        + "Team-Pokémon ersetzen oder nicht aufnehmen und 25%% mehr EP erhalten?"
    ) % [name, level]
    _show_full_team_capture_actions()


func _replace_team_member(index: int) -> void:
    if pending_capture.is_empty() or index < 0 or index >= team.size():
        return

    var old_member_value: Variant = team[index]
    if not (old_member_value is Dictionary):
        return
    var old_member: Dictionary = old_member_value

    var new_name: String = str(pending_capture.get("name", "Pokémon"))
    var old_name: String = str(old_member.get("name", "Pokémon"))
    team[index] = pending_capture
    pending_capture = {}

    _clear_container(capture_actions)
    event_label.text = "%s kommt ins Team. %s verlässt dein Team." % [new_name, old_name]
    continue_button.visible = true
    _refresh_team_panel()
