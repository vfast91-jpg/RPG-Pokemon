extends "res://scripts/demo_route_no_storage.gd"

# XP reward correction:
# A +25% route reward is based on the complete XP requirement for each
# individual Pokémon's next level. It is NOT 25% of the battle reward and NOT
# 25% of the Pokémon's current XP progress.

const NEXT_LEVEL_XP_BONUS_FRACTION: float = 0.25


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == "battle":
            choice["hint"] = (
                "Keine Hilfe vor dem Kampf. Bei einem Sieg erhält jedes kampffähige Pokémon "
                + "Bonus-EP in Höhe von 25% seiner vollständigen EP-Anforderung bis zum nächsten Level."
            )
    return choices


func _choose_path(choice: Dictionary) -> void:
    super._choose_path(choice)
    if str(choice.get("kind", "")) != "battle":
        return

    event_label.text = (
        "[b]Direkter Pfad[/b]\nDu gehst ohne Unterstützung in den Kampf. "
        + "Bei einem Sieg erhält jedes kampffähige Pokémon zusätzlich [b]25% der vollständigen "
        + "EP-Anforderung bis zu seinem nächsten Level[/b]."
    )


func _begin_capture_event() -> void:
    super._begin_capture_event()
    # If the capture was accepted automatically, pending_capture has already
    # been cleared. A remaining capture therefore means the four-Pokémon team
    # is full and the player still has to choose.
    if pending_capture.is_empty():
        return

    var name: String = str(pending_capture.get("name", "Pokémon"))
    var level: int = maxi(1, int(pending_capture.get("level", 1)))
    event_label.text = (
        "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen. Dein Team mit vier Pokémon ist voll. "
        + "Möchtest du ein Team-Pokémon ersetzen oder den Fang nicht aufnehmen? Beim Nicht-Aufnehmen "
        + "erhält jedes kampffähige Team-Pokémon im nächsten Etappenkampf Bonus-EP in Höhe von "
        + "25%% seiner vollständigen EP-Anforderung bis zum nächsten Level."
    ) % [name, level]


func _show_full_team_capture_actions() -> void:
    super._show_full_team_capture_actions()
    if capture_actions == null:
        return

    for child: Node in capture_actions.get_children():
        if child is Button and (child as Button).text.contains("+25% EP"):
            (child as Button).tooltip_text = (
                "Das gefangene Pokémon wird nicht ins Team aufgenommen. Nach dem nächsten Sieg erhält "
                + "jedes kampffähige Team-Pokémon Bonus-EP in Höhe von 25% seiner vollständigen "
                + "EP-Anforderung bis zum nächsten Level."
            )


func _decline_pending_capture() -> void:
    if pending_capture.is_empty():
        return

    var name: String = str(pending_capture.get("name", "Pokémon"))
    super._decline_pending_capture()
    event_label.text = (
        "[b]%s wird nicht ins Team aufgenommen.[/b]\n"
        + "Als Ausgleich erhält jedes kampffähige Team-Pokémon nach dem unmittelbar folgenden Sieg "
        + "[b]Bonus-EP in Höhe von 25%% seiner vollständigen EP-Anforderung bis zum nächsten Level[/b]."
    ) % name


func _begin_capture_event_again() -> void:
    super._begin_capture_event_again()
    if pending_capture.is_empty():
        return

    var name: String = str(pending_capture.get("name", "Pokémon"))
    var level: int = maxi(1, int(pending_capture.get("level", 1)))
    event_label.text = (
        "[b]Fangwiese[/b]\n%s Lv.%d wartet auf deine Entscheidung: Team-Pokémon ersetzen oder nicht "
        + "aufnehmen und beim nächsten Sieg 25%% der vollständigen EP-Anforderung bis zum nächsten "
        + "Level als Bonus-EP erhalten?"
    ) % [name, level]


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    var adjusted_team: Array = updated_team.duplicate(true)
    var bonus_fraction: float = maxf(0.0, stage_xp_multiplier - 1.0)
    var bonus_lines: Array[String] = []

    if victory and bonus_fraction > 0.0:
        # Apply the per-Pokémon progress bonus before the inherited XP award.
        # Then neutralize the old battle-XP multiplier so the parent only adds
        # the normal battle reward. Its existing level-up/evolution flow can
        # process the combined XP normally.
        bonus_lines = _apply_next_level_progress_bonus(adjusted_team, bonus_fraction)
        stage_xp_multiplier = 1.0

    super._on_route_battle_finished(victory, adjusted_team)

    if not victory or bonus_lines.is_empty() or event_label == null:
        return

    var percent: int = int(round(bonus_fraction * 100.0))
    event_label.text += (
        "\n\n[b]+%d%% Bonus-EP[/b] – berechnet aus der vollständigen EP-Anforderung bis zum nächsten "
        + "Level, nicht aus dem aktuellen EP-Stand und nicht aus den Kampf-EP:\n%s"
    ) % [percent, "\n".join(bonus_lines)]
    last_route_message = event_label.text


func _apply_next_level_progress_bonus(members: Array, bonus_fraction: float) -> Array[String]:
    var messages: Array[String] = []
    if bonus_fraction <= 0.0:
        return messages

    var percent: int = int(round(bonus_fraction * 100.0))
    for member_value: Variant in members:
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue

        var level: int = maxi(1, int(member.get("level", 1)))
        var required_xp: int = _xp_needed(level)
        var bonus_xp: int = maxi(1, int(round(float(required_xp) * bonus_fraction)))
        member["xp"] = int(member.get("xp", 0)) + bonus_xp

        messages.append(
            "%s: +%d EP (%d%% von %d EP)"
            % [str(member.get("name", "Pokémon")), bonus_xp, percent, required_xp]
        )

    return messages
