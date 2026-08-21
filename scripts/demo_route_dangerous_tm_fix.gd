extends "res://scripts/demo_route_special_events.gd"

# Hotfix for the promised Dangerous Path TM reward.
#
# A Dangerous Path must never be offered when the current team cannot receive
# any remaining TM. The TM selection is also resolved before battle XP is
# awarded, so a level-up cannot make the promised reward disappear.

var _dangerous_pending_xp: int = 0


func start_route() -> void:
    _dangerous_pending_xp = 0
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    _dangerous_pending_xp = 0
    super._show_stage_choices(message)


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    if _dangerous_tm_reward_available():
        return choices

    # Do not advertise a reward the current team cannot actually receive.
    # Replace a rolled Dangerous Path with another unique secondary event.
    var used_kinds: Array[String] = []
    for choice: Dictionary in choices:
        var kind: String = str(choice.get("kind", ""))
        if kind != EVENT_DANGEROUS and not used_kinds.has(kind):
            used_kinds.append(kind)

    for index: int in range(choices.size()):
        if str(choices[index].get("kind", "")) != EVENT_DANGEROUS:
            continue

        var replacements: Array[String] = SECONDARY_EVENT_POOL.duplicate()
        replacements.erase(EVENT_DANGEROUS)
        for used_kind: String in used_kinds:
            replacements.erase(used_kind)
        replacements.shuffle()

        if replacements.is_empty():
            choices[index] = _special_event_choice(EVENT_DIRECT, current_stage)
            if not used_kinds.has(EVENT_DIRECT):
                used_kinds.append(EVENT_DIRECT)
        else:
            var replacement: String = replacements[0]
            choices[index] = _special_event_choice(replacement, current_stage)
            used_kinds.append(replacement)

    return choices


func _dangerous_tm_reward_available() -> bool:
    return not _eligible_tm_entries().is_empty()


func _begin_dangerous_path() -> void:
    # Defensive re-check in case this function is ever called outside the
    # freshly generated path-choice flow.
    if not _dangerous_tm_reward_available():
        event_label.text = (
            "[b]⚠️ Gefährlicher Pfad[/b]\n"
            + "Für dein aktuelles Team ist gerade keine noch lernbare kompatible TM verfügbar. "
            + "Der Gefährliche Pfad wird deshalb nicht gestartet, weil seine versprochene Belohnung "
            + "sonst nicht vergeben werden könnte."
        )
        _add_cancel_special_event_button()
        return

    super._begin_dangerous_path()


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    if _active_special_battle != EVENT_DANGEROUS:
        super._on_route_battle_finished(victory, updated_team)
        return

    _active_special_battle = ""
    team = updated_team.duplicate(true)
    visible = true

    if not victory:
        _dangerous_pending_xp = 0
        _finish_run(false, "Dein Team wurde auf Etappe %d besiegt." % stage)
        return

    # Keep XP pending until after the TM has been chosen. TM compatibility does
    # not depend on current HP, so the set that made the path eligible before
    # battle is still available here. Awarding XP first could cause a level-up
    # to teach the same move naturally and remove the last valid TM candidate.
    _dangerous_pending_xp = 20 + stage * 12
    _dangerous_tm_reward_pending = true
    _dangerous_battle_summary = (
        "[b]⚠️ Gefährlicher Pfad bezwungen![/b]\n"
        + "Wähle jetzt deine versprochene TM-Belohnung. Danach erhält dein Team [b]+%d EP[/b]."
    ) % _dangerous_pending_xp
    last_route_message = _dangerous_battle_summary

    # This must produce a real selection. If it ever does not, the defensive
    # availability checks above have caught a new regression elsewhere.
    _begin_tm_event()


func _prepare_dangerous_reward_finish(reward_text: String) -> void:
    continue_button.visible = false
    _clear_container(capture_actions)
    event_label.text = reward_text

    var finish_button := Button.new()
    finish_button.text = "EP ERHALTEN · WEITER ZUR NÄCHSTEN ETAPPE"
    finish_button.custom_minimum_size = Vector2(0, 30)
    finish_button.pressed.connect(_finish_dangerous_reward.bind(reward_text))
    capture_actions.add_child(finish_button)


func _finish_dangerous_reward(reward_text: String) -> void:
    var gained_xp: int = maxi(0, _dangerous_pending_xp)
    _dangerous_pending_xp = 0

    var level_messages: Array[String] = []
    if gained_xp > 0:
        level_messages = _award_experience(gained_xp)

    var summary: String = "[b]⚠️ Gefährlicher Pfad bezwungen![/b] · +%d EP" % gained_xp
    if not reward_text.is_empty():
        summary += "\n\n" + reward_text
    if not level_messages.is_empty():
        summary += "\n" + "\n".join(level_messages)

    _dangerous_tm_reward_pending = false
    _dangerous_battle_summary = ""
    _complete_special_stage(summary)
