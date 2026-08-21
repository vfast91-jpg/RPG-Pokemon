extends "res://scripts/demo_route_species_xp.gd"

# Training-place risk/reward layer.
# The selected Pokemon still receives its guaranteed pre-battle level-up,
# but the effort costs 15% of its NEW maximum HP before the stage battle.
# Training exhaustion can never knock a living Pokemon out; at least 1 HP remains.

const TRAINING_HP_COST_FRACTION: float = 0.15


func _training_hp_cost_for_max_hp(max_hp: int) -> int:
    return maxi(
        1,
        int(round(float(maxi(1, max_hp)) * TRAINING_HP_COST_FRACTION))
    )


func _training_hp_after_cost(current_hp: int, max_hp: int) -> int:
    if current_hp <= 0:
        return 0
    return maxi(1, current_hp - _training_hp_cost_for_max_hp(max_hp))


func _begin_training_event() -> void:
    super._begin_training_event()

    event_label.text = (
        "[b]🏋️ Trainingsplatz[/b]\n"
        + "Wähle genau ein Pokémon. Es erhält EP in Höhe seiner vollständigen aktuellen "
        + "EP-Anforderung – ein Level-Aufstieg ist garantiert. Das Training kostet danach "
        + "[b]15% seiner neuen Max-KP[/b] (mindestens 1 KP bleibt). Anschließend folgt wie "
        + "gewohnt der reguläre Etappenkampf."
    )

    if capture_actions == null:
        return

    for child: Node in capture_actions.get_children():
        if child is Button:
            var button := child as Button
            button.tooltip_text += (
                "\nTrainingserschöpfung: Nach dem Levelaufstieg verliert dieses Pokémon "
                + "15% seiner neuen Max-KP. Es kann dadurch nicht kampfunfähig werden."
            )


func _train_team_member(team_index: int) -> void:
    if team_index < 0 or team_index >= team.size():
        return

    super._train_team_member(team_index)

    if team_index < 0 or team_index >= team.size():
        return
    var member_value: Variant = team[team_index]
    if not (member_value is Dictionary):
        return

    var member: Dictionary = member_value
    var current_hp: int = int(member.get("hp", 0))
    var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
    var hp_after: int = _training_hp_after_cost(current_hp, max_hp)
    var actual_loss: int = maxi(0, current_hp - hp_after)
    member["hp"] = hp_after

    var name: String = str(member.get("name", "Pokémon"))
    var exhaustion_line: String
    if current_hp <= 0:
        exhaustion_line = (
            "[b]💢 Trainingserschöpfung:[/b] %s bleibt kampfunfähig; es werden keine "
            + "zusätzlichen KP abgezogen."
        ) % name
    else:
        exhaustion_line = (
            "[b]💢 Trainingserschöpfung:[/b] %s verliert [b]%d KP[/b] "
            + "(15%% der neuen Max-KP) und geht mit [b]%d/%d KP[/b] in den Etappenkampf."
        ) % [name, actual_loss, hp_after, max_hp]

    event_label.text += "\n\n" + exhaustion_line
    last_route_message = event_label.text
    _refresh_team_panel()
