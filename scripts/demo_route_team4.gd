extends "res://scripts/demo_route.gd"

# Current route rule: the player's travelling team contains at most four Pokémon.
# Extra captures can still be stored or swapped into one of those four slots.
const ROUTE_TEAM_MAX: int = 4


func _begin_capture_event() -> void:
    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        event_label.text = "An dieser Fangstelle taucht heute kein Pokémon auf."
        continue_button.visible = true
        return

    var sid: String = str(ids.pick_random())
    pending_capture = battle_demo.route_new_member(sid, CAPTURE_LEVEL)
    var name: String = str(pending_capture.get("name", battle_demo.route_species_name(sid)))

    if team.size() < ROUTE_TEAM_MAX:
        team.append(pending_capture)
        pending_capture = {}
        event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen und deinem Team hinzugefügt." % [name, CAPTURE_LEVEL]
        continue_button.visible = true
        _refresh_team_panel()
        return

    event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen. Dein Team mit vier Pokémon ist voll. Möchtest du es einlagern oder ein Team-Pokémon ersetzen?" % [name, CAPTURE_LEVEL]

    var store_button := Button.new()
    store_button.text = "EINLAGERN"
    store_button.pressed.connect(_store_pending_capture)
    capture_actions.add_child(store_button)

    var replace_button := Button.new()
    replace_button.text = "TEAM-POKÉMON ERSETZEN"
    replace_button.pressed.connect(_show_replace_choices)
    capture_actions.add_child(replace_button)
