extends "res://scripts/battle_demo_move_order.gd"

# Final player-language layer.
# Technical multiplier/ATB vocabulary may remain inside the combat engine, but
# the visible UI explains timing and matchup changes in plain percentages.


func _prompt_player(actor: Dictionary) -> void:
    super._prompt_player(actor)

    # Parent layers create the wait button themselves. Sanitize every visible
    # tooltip afterwards so no inherited ATB wording slips through.
    if action_grid == null:
        return
    for child_value: Variant in action_grid.get_children():
        if child_value is Button:
            var button: Button = child_value
            button.tooltip_text = _player_text_cleanup(button.tooltip_text)


func _move_tooltip(move: Dictionary) -> String:
    var text: String = super._move_tooltip(move)
    var ap: int = _ap_value(move)
    var cycle: float = _ap_cycle(ap)

    # The inherited tooltip used a raw cycle multiplier, e.g. x1.45. Present
    # the exact same cost as a percentage change in time instead.
    text = text.replace(
        "AP %d → Aktionszyklus ×%s" % [ap, _decimal(cycle, 2)],
        "AP %d → Zeitkosten %s" % [ap, _signed_percent_delta(cycle)]
    )
    return _player_text_cleanup(text)


func _compact_effect_summary(move: Dictionary) -> String:
    var text: String = super._compact_effect_summary(move)
    text = text.replace("nächster Aktionszyklus kürzer", "schneller wieder bereit")
    text = text.replace("nächster Aktionszyklus länger", "später wieder bereit")
    return _player_text_cleanup(text)


func _compact_type_context(move: Dictionary, category: String, move_type: String) -> String:
    if selected_actor.is_empty():
        return ""

    var bits: Array[String] = []
    var actor_types: Array = _type_array(selected_actor.get("types", []))
    if actor_types.has(move_type):
        if category == "status":
            var status_bonus: float = TypeSystem.get_same_type_status_multiplier(
                move_type,
                actor_types
            )
            bits.append("eigener Typbonus: Statuswirkung " + _signed_percent_delta(status_bonus))
        else:
            var damage_bonus: float = TypeSystem.get_same_type_damage_multiplier(
                move_type,
                actor_types
            )
            bits.append("eigener Typbonus: Schaden " + _signed_percent_delta(damage_bonus))

    if category != "status":
        var current_targets: Array = _targets(
            selected_actor,
            str(move.get("target", "enemy_highest_aggro"))
        )
        if current_targets.size() == 1 and current_targets[0] is Dictionary:
            var target: Dictionary = current_targets[0]
            var defender_types: Array = _type_array(target.get("types", []))
            var multiplier: float = TypeSystem.get_multiplier(move_type, defender_types)
            if is_equal_approx(multiplier, 1.0):
                bits.append("gegen " + _actor_name(target) + ": normal")
            else:
                bits.append(
                    "gegen " + _actor_name(target) + ": Schaden "
                    + _signed_percent_delta(multiplier)
                    + " (" + _effectiveness_name(multiplier) + ")"
                )
        elif current_targets.size() > 1:
            bits.append("Typwirkung wird je Ziel berechnet")

    if bits.is_empty():
        return ""
    return "Matchup: " + " · ".join(bits)


func _player_text_cleanup(source: String) -> String:
    # Catch natural-language phrases before the parent's generic ATB replacement.
    var text: String = source
    text = text.replace(
        "nächster ATB-Zyklus wird kürzer",
        "danach schneller wieder bereit"
    )
    text = text.replace(
        "beschleunigt seinen nächsten ATB-Zyklus",
        "ist danach schneller wieder bereit"
    )
    text = super._player_text_cleanup(text)

    # Also clean older already-translated wording from previous presentation
    # layers. "Aktionszyklus" is still too abstract for the intended audience.
    text = text.replace("nächster Aktionszyklus kürzer", "schneller wieder bereit")
    text = text.replace("nächster Aktionszyklus länger", "später wieder bereit")
    text = text.replace(
        "Beschleunigt den eigenen Aktionszyklus stark.",
        "Der Anwender wird deutlich schneller wieder bereit."
    )
    return text
