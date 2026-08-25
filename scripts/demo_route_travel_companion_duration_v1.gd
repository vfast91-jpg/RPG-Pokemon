extends "res://scripts/demo_route_boss_reinforcement_v1.gd"

# Travel companions deliberately stay for a limited part of the adventure.
# The stage on which a Pokemon joins counts as the first shared stage. A member
# therefore leaves after 30 completed stages together, independent of KOs,
# level-ups, evolutions or battle type.

const COMPANION_STAGE_LIMIT: int = 30
const COMPANION_REMAINING_KEY: String = "travel_stages_remaining"

# This is the stage for which the current remaining values are already valid.
# Keeping the checkpoint makes repeated redraws/resume screens on the same stage
# harmless: a stage can consume companion duration at most once.
var _companion_duration_checkpoint_stage: int = 0


func start_route() -> void:
    # A genuinely new adventure starts a fresh duration clock. Saved adventures
    # restore this variable through RunSaveManager instead of calling start_route.
    _companion_duration_checkpoint_stage = 0
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    var departed: Array[String] = _advance_companion_durations_to_stage(stage)
    var combined_message: String = _message_with_companion_departures(message, departed)

    if not departed.is_empty():
        _refresh_team_panel()

    # Without a reserve system there is no legal battle party if every current
    # companion leaves on the same transition. End cleanly instead of allowing
    # a later battle button to soft-lock on an empty team.
    if not departed.is_empty() and team.is_empty():
        var finish_message: String = combined_message
        if not finish_message.is_empty():
            finish_message += "\n\n"
        finish_message += "Dein letzter Reisegefährte ist weitergezogen. Dein Abenteuer endet hier."
        _finish_run(false, finish_message)
        return

    super._show_stage_choices(combined_message)


func _advance_companion_durations_to_stage(target_stage: int) -> Array[String]:
    _ensure_team_companion_durations()

    var normalized_stage: int = maxi(1, target_stage)
    if _companion_duration_checkpoint_stage <= 0:
        _companion_duration_checkpoint_stage = normalized_stage
        return []

    if normalized_stage <= _companion_duration_checkpoint_stage:
        return []

    var completed_stages: int = normalized_stage - _companion_duration_checkpoint_stage
    _companion_duration_checkpoint_stage = normalized_stage

    var departed: Array[String] = []
    for index: int in range(team.size() - 1, -1, -1):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value
        var remaining: int = maxi(0, int(member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT)))
        remaining = maxi(0, remaining - completed_stages)
        member[COMPANION_REMAINING_KEY] = remaining

        if remaining <= 0:
            departed.push_front(str(member.get("name", "Pokémon")))
            team.remove_at(index)
        else:
            team[index] = member

    return departed


func _ensure_team_companion_durations() -> void:
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        _ensure_member_companion_duration(member)
        team[index] = member


func _ensure_member_companion_duration(member: Dictionary) -> void:
    # Missing means old save/newly created member. Existing values are never
    # reset here, including low values carried through evolution or save/load.
    if not member.has(COMPANION_REMAINING_KEY):
        member[COMPANION_REMAINING_KEY] = COMPANION_STAGE_LIMIT


func _ensure_pending_companion_duration() -> void:
    if pending_capture.is_empty():
        return
    _ensure_member_companion_duration(pending_capture)


func _accept_pending_capture() -> void:
    _ensure_pending_companion_duration()
    super._accept_pending_capture()


func _replace_team_member(index: int) -> void:
    _ensure_pending_companion_duration()
    super._replace_team_member(index)


func _message_with_companion_departures(message: String, departed: Array[String]) -> String:
    if departed.is_empty():
        return message

    var lines: Array[String] = []
    for companion_name: String in departed:
        lines.append("[b]🧭 %s[/b] setzt seine eigene Reise fort und verlässt dein Team." % companion_name)

    var departure_text: String = "\n".join(lines)
    if message.is_empty():
        return departure_text
    return message + "\n\n" + departure_text


func _companion_remaining_stages(member: Dictionary) -> int:
    return clampi(
        int(member.get(COMPANION_REMAINING_KEY, COMPANION_STAGE_LIMIT)),
        0,
        999
    )


func _make_route_team_card(member: Dictionary, index: int) -> Control:
    _ensure_member_companion_duration(member)
    var card: Control = super._make_route_team_card(member, index)
    var remaining: int = _companion_remaining_stages(member)
    _append_companion_duration_to_first_label(card, remaining)
    _set_companion_duration_tooltip(card, remaining)
    return card


func _append_companion_duration_to_first_label(node: Node, remaining: int) -> bool:
    if node is Label:
        var label: Label = node as Label
        if not label.text.is_empty():
            label.text += "  ·  🧭 %d Et." % remaining
            return true

    for child: Node in node.get_children():
        if _append_companion_duration_to_first_label(child, remaining):
            return true
    return false


func _set_companion_duration_tooltip(node: Node, remaining: int) -> bool:
    if node is Button:
        var button: Button = node as Button
        if button.flat and button.text.is_empty():
            button.tooltip_text = "Reisegefährte · noch %d gemeinsame Etappen" % remaining
            return true

    for child: Node in node.get_children():
        if _set_companion_duration_tooltip(child, remaining):
            return true
    return false


func _show_route_member_info(index: int) -> void:
    super._show_route_member_info(index)
    if index < 0 or index >= team.size() or _route_info_body == null:
        return
    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return

    var remaining: int = _companion_remaining_stages(member_value as Dictionary)
    _route_info_body.text += (
        "\n\n[b]Reisegefährte[/b]\n"
        + "Noch %d gemeinsame Etappen, bevor dieses Pokémon seine eigene Reise fortsetzt."
    ) % remaining
