extends "res://scripts/demo_route_stage50_mirror_v1.gd"

# Travel-companion extension event.
# Unlocks exactly when stage 25 begins, is guaranteed among that stage's three
# route choices, and remains a normal random route option from stage 25 onward.

const EVENT_CAMPFIRE: String = "campfire"
const CAMPFIRE_UNLOCK_STAGE: int = 25
const CAMPFIRE_EXTENSION_STAGES: int = 5

var _campfire_unlock_announced: bool = false
var _campfire_unlock_dialog: AcceptDialog


func start_route() -> void:
    # A new adventure must always receive the stage-25 introduction again.
    # Saved adventures restore this flag through RunSaveManager instead.
    _campfire_unlock_announced = false
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    var should_announce: bool = (
        stage == CAMPFIRE_UNLOCK_STAGE
        and not _campfire_unlock_announced
    )

    # Set this before the inherited stage checkpoint is saved so reloading stage
    # 25 can never repeat the tutorial popup.
    if should_announce:
        _campfire_unlock_announced = true

    super._show_stage_choices(message)

    if should_announce and visible:
        call_deferred("_show_campfire_unlock_popup")


func _route_event_pool_for_stage(current_stage: int) -> Array[String]:
    var pool: Array[String] = super._route_event_pool_for_stage(current_stage)
    if current_stage >= CAMPFIRE_UNLOCK_STAGE and not pool.has(EVENT_CAMPFIRE):
        pool.append(EVENT_CAMPFIRE)
    return pool


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    if current_stage != CAMPFIRE_UNLOCK_STAGE:
        return choices

    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == EVENT_CAMPFIRE:
            return choices

    var campfire_choice: Dictionary = _active_event_choice(EVENT_CAMPFIRE, current_stage)
    if choices.size() < 3:
        choices.append(campfire_choice)
    else:
        # Preserve two naturally rolled options and reserve exactly one of the
        # three stage-25 slots for the newly introduced mechanic.
        choices[choices.size() - 1] = campfire_choice
    return choices


func _active_event_choice(kind: String, current_stage: int) -> Dictionary:
    if kind == EVENT_CAMPFIRE:
        return {
            "kind": EVENT_CAMPFIRE,
            "label": "🔥 Gemeinsam am Lagerfeuer",
            "hint": "Wähle einen Reisegefährten. Er bleibt 5 weitere Etappen bei dir."
        }
    return super._active_event_choice(kind, current_stage)


func _choose_path(choice: Dictionary) -> void:
    var kind: String = str(choice.get("kind", ""))
    if kind != EVENT_CAMPFIRE:
        super._choose_path(choice)
        return

    _set_path_buttons_disabled(true)
    _clear_container(capture_actions)
    continue_button.visible = false
    path_box.visible = false
    stage_xp_multiplier = 1.0
    _begin_campfire_event()


func _begin_campfire_event() -> void:
    event_label.text = (
        "[b]🔥 Gemeinsam am Lagerfeuer[/b]\n"
        + "Wähle einen Reisegefährten. Er bleibt [b]5 weitere Etappen[/b] bei dir."
    )

    var added_button: bool = false
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value as Dictionary
        _ensure_member_companion_duration(member)
        team[index] = member

        var remaining: int = int(member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT))
        var button := Button.new()
        button.text = "%s · 🧭 %d → %d Etappen" % [
            str(member.get("name", "Pokémon")),
            remaining,
            remaining + CAMPFIRE_EXTENSION_STAGES
        ]
        button.custom_minimum_size = Vector2(0, 30)
        button.tooltip_text = (
            "%s bleibt nach dieser Rast 5 Etappen länger bei dir."
            % str(member.get("name", "Dieses Pokémon"))
        )
        button.pressed.connect(_on_campfire_companion_selected.bind(index))
        capture_actions.add_child(button)
        added_button = true

    if not added_button:
        event_label.text = "Für das Lagerfeuer ist gerade kein Reisegefährte verfügbar."
        continue_button.visible = true


func _on_campfire_companion_selected(team_index: int) -> void:
    if team_index < 0 or team_index >= team.size():
        return

    var member_value: Variant = team[team_index]
    if not (member_value is Dictionary):
        return

    var member: Dictionary = member_value as Dictionary
    _ensure_member_companion_duration(member)

    var previous_remaining: int = int(
        member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT)
    )
    var new_remaining: int = previous_remaining + CAMPFIRE_EXTENSION_STAGES
    member[COMPANION_REMAINING_KEY] = new_remaining
    team[team_index] = member

    var companion_name: String = str(member.get("name", "Dein Reisegefährte"))
    var summary: String = (
        "[b]🔥 Gemeinsam am Lagerfeuer[/b]\n"
        + "%s genießt die gemeinsame Zeit und möchte noch ein Stück länger mit dir reisen.\n"
        + "[b]+5 Etappen[/b] · 🧭 %d → %d Etappen"
    ) % [companion_name, previous_remaining, new_remaining]

    _clear_container(capture_actions)
    last_route_message = summary
    event_label.text = summary
    continue_button.visible = true
    _refresh_team_panel()

    # The extension is committed immediately. The inherited save layer turns
    # this into the normal ready-for-battle checkpoint, so reloads cannot grant
    # the same +5 twice.
    _autosave_run("team_change")


func _show_campfire_unlock_popup() -> void:
    if stage != CAMPFIRE_UNLOCK_STAGE or not visible:
        return

    var dialog: AcceptDialog = _ensure_campfire_unlock_dialog()
    dialog.dialog_text = (
        "Ab jetzt gibt es eine neue Möglichkeit:\n\n"
        + "🔥 Gemeinsam am Lagerfeuer\n"
        + "Wähle einen Reisegefährten. Er bleibt 5 weitere Etappen bei dir.\n\n"
        + "Auf Etappe 25 ist das Lagerfeuer garantiert unter deinen drei Möglichkeiten. "
        + "Danach kann es immer wieder auftauchen."
    )
    dialog.popup_centered(Vector2i(500, 230))


func _ensure_campfire_unlock_dialog() -> AcceptDialog:
    if _campfire_unlock_dialog != null and is_instance_valid(_campfire_unlock_dialog):
        return _campfire_unlock_dialog

    _campfire_unlock_dialog = AcceptDialog.new()
    _campfire_unlock_dialog.name = "CampfireUnlockDialog"
    _campfire_unlock_dialog.title = "Neue Möglichkeit freigeschaltet"
    _campfire_unlock_dialog.ok_button_text = "VERSTANDEN"
    add_child(_campfire_unlock_dialog)
    return _campfire_unlock_dialog
