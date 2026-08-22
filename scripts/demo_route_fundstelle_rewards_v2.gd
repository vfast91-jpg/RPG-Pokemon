extends "res://scripts/demo_route_cleanup_v1.gd"

# Active Fundstelle reward layout:
# - 3 compatible TMs (unchanged)
# - 1 stage-scaled healing item (Trank -> stronger variants, unchanged)
# - 1 Beleber
# - 1 random viable vitamin
#
# Items are used immediately and are never stored.


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == EVENT_TM:
            choice["label"] = "🎁 Fundstelle"
            choice["hint"] = "Wähle genau eine Belohnung: 3 passende TMs, 1 Heilitem, 1 Beleber oder 1 zufälliges Vitamin."
    return choices


func _show_fundstelle_options() -> void:
    # The inherited layer already shuffles viable vitamins. Keep only the first
    # shuffled offer so the former second vitamin slot becomes the Beleber slot.
    if _fundstelle_vitamin_offers.size() > 1:
        _fundstelle_vitamin_offers.resize(1)

    super._show_fundstelle_options()

    event_label.text = (
        "[b]🎁 Fundstelle[/b]\n"
        + "Wähle genau [b]eine[/b] Belohnung. Heilitems und Beleber werden sofort benutzt; "
        + "Vitamine verbessern dauerhaft genau ein Pokémon."
    )

    var revive_button := Button.new()
    revive_button.text = "✨ Beleber · 50 % KP"
    revive_button.custom_minimum_size = Vector2(0, 27)
    revive_button.tooltip_text = (
        "Belebt genau ein kampfunfähiges Team-Pokémon mit 50 % seiner maximalen KP wieder. "
        + "Das Item wird nicht eingelagert."
    )
    revive_button.pressed.connect(_choose_revive)

    # Parent order is TM(s), healing item, vitamin(s), optional info label.
    # Insert Beleber directly after the healing item so the three item slots are
    # always: Heilitem -> Beleber -> Vitamin.
    var insert_index: int = capture_actions.get_child_count()
    for index: int in range(capture_actions.get_child_count()):
        var child: Node = capture_actions.get_child(index)
        if child is Button and str((child as Button).text).begins_with("🧪 "):
            insert_index = index + 1
            break

    capture_actions.add_child(revive_button)
    capture_actions.move_child(revive_button, insert_index)


func _choose_revive() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    event_label.text = "[b]✨ Beleber[/b]\nWelches kampfunfähige Pokémon möchtest du wiederbeleben?"

    var recipient_count: int = 0
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) > 0:
            continue

        recipient_count += 1
        var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
        var button := Button.new()
        button.text = "%s · 0/%d KP" % [str(member.get("name", "Pokémon")), max_hp]
        button.custom_minimum_size = Vector2(0, 27)
        button.pressed.connect(_apply_revive.bind(index))
        capture_actions.add_child(button)

    if recipient_count == 0:
        event_label.text += "\nEs gibt derzeit kein kampfunfähiges Ziel für den Beleber."

    var back_button := Button.new()
    back_button.text = "ZURÜCK ZUR FUNDSTELLE"
    back_button.pressed.connect(_show_fundstelle_options)
    capture_actions.add_child(back_button)


func _apply_revive(team_index: int) -> void:
    if team_index < 0 or team_index >= team.size():
        _show_fundstelle_options()
        return

    var member_value: Variant = team[team_index]
    if not (member_value is Dictionary):
        _show_fundstelle_options()
        return

    var member: Dictionary = member_value
    if int(member.get("hp", 0)) > 0:
        _choose_revive()
        return

    var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
    var revived_hp: int = _revive_hp_amount(max_hp)
    member["hp"] = revived_hp
    team[team_index] = member

    _fundstelle_active = false
    _clear_container(capture_actions)
    continue_button.visible = true
    event_label.text = (
        "[b]🎁 Fundstelle · Beleber benutzt[/b]\n%s ist wieder kampffähig und hat jetzt %d/%d KP."
        % [str(member.get("name", "Pokémon")), revived_hp, max_hp]
    )
    _refresh_team_panel()


func _revive_hp_amount(max_hp: int) -> int:
    return maxi(1, int(maxi(1, max_hp) / 2.0))
