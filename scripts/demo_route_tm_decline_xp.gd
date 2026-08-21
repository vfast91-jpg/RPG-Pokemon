extends "res://scripts/demo_route_stage_button_polish.gd"

# Final demo-route reward polish:
# Players may decline an offered TM selection and take the same next-battle
# +25% next-level XP reward that is already used when a full-team capture is
# declined.

const TM_DECLINE_XP_MULTIPLIER: float = 1.25


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == "item":
            choice["hint"] = (
                "Wähle eine kompatible TM und weise sie einem Pokémon zu – oder lehne die Auswahl ab "
                + "und erhalte nach dem nächsten Sieg +25% Level-EP."
            )
    return choices


func _show_tm_offer_buttons() -> void:
    super._show_tm_offer_buttons()
    if capture_actions == null:
        return

    event_label.text = (
        "[b]💿 TM-Fundstelle[/b]\n"
        + "Wähle eine der angebotenen TMs. Wenn dir keine davon gefällt, kannst du die Auswahl ablehnen "
        + "und stattdessen beim nächsten Sieg +25% Level-EP erhalten."
    )

    var decline_button := Button.new()
    decline_button.text = "KEINE TM · +25% EP"
    decline_button.custom_minimum_size = Vector2(0, 28)
    decline_button.tooltip_text = (
        "Es wird keine TM vergeben. Nach dem unmittelbar folgenden Sieg erhält jedes kampffähige "
        + "Team-Pokémon Bonus-EP in Höhe von 25% seiner vollständigen EP-Anforderung bis zum nächsten Level."
    )
    decline_button.pressed.connect(_decline_tm_reward)
    capture_actions.add_child(decline_button)


func _decline_tm_reward() -> void:
    stage_xp_multiplier = maxf(stage_xp_multiplier, TM_DECLINE_XP_MULTIPLIER)
    _active_tm_offers.clear()
    _clear_container(capture_actions)
    event_label.text = (
        "[b]Keine TM gewählt.[/b]\n"
        + "Als Ausgleich erhält jedes kampffähige Team-Pokémon nach dem unmittelbar folgenden Sieg "
        + "[b]Bonus-EP in Höhe von 25% seiner vollständigen EP-Anforderung bis zum nächsten Level[/b]."
    )
    continue_button.visible = true
    _refresh_team_panel()
