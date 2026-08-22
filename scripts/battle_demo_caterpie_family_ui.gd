extends "res://scripts/battle_demo_caterpie_family.gd"

# Small presentation bridge for the first additional single-ally move after
# Helping Hand. The older shared selector is mechanically generic but its label
# still says "Rechte Hand". Keep that legacy path untouched and present Baton
# Pass with its own correct player-facing wording here.

func _choose_move(move_id: String) -> void:
    if move_id != "baton_pass":
        super._choose_move(move_id)
        return
    if selected_actor.is_empty():
        return

    var actor: Dictionary = selected_actor
    var allies: Array = _bulba_living_other_allies(actor)
    if allies.is_empty():
        _set_log("[b]Stafette[/b]: Kein aktiver Verbündeter als Ziel verfügbar.")
        _spawn_feedback_label(actor, "🔁 KEIN VERBÜNDETER", Color("b9d7ff"))
        return
    if allies.size() == 1:
        _bulba_selected_ally_id = str((allies[0] as Dictionary).get("id", ""))
        # Let the inherited single-ally path execute normally; with one ally it
        # does not open its old hard-coded selection menu.
        super._choose_move(move_id)
        return

    _bulba_pending_ally_move_id = move_id
    _bulba_pending_ally_actor = actor
    _clear_actions()
    _set_log("[b]Stafette[/b]: Verbündetes Pokémon wählen.")
    for ally_value: Variant in allies:
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        var button := Button.new()
        button.text = "🔁 " + _actor_name(ally)
        button.tooltip_text = "Temporäre positive und negative Attributsänderungen auf dieses Pokémon übertragen"
        button.pressed.connect(_bulba_choose_ally_target.bind(str(ally.get("id", ""))))
        action_grid.add_child(button)
