extends "res://scripts/demo_route_campfire_v1.gd"

# UI regression guard for the Reisegefaehrten capture choice.
# The underlying capture button was renamed from "INS TEAM AUFNEHMEN" to
# "ALS REISEGEFAEHRTEN AUFNEHMEN". The older polish layer still recognizes
# only the former wording, so the current button otherwise loses its card style.


func _polish_capture_action_buttons() -> void:
    super._polish_capture_action_buttons()

    if capture_actions == null or pending_capture.is_empty():
        return

    var capture_name: String = str(pending_capture.get("name", "Pokemon"))
    for child: Node in capture_actions.get_children():
        if not (child is Button):
            continue

        var button := child as Button
        if button.text != "ALS REISEGEFÄHRTEN AUFNEHMEN":
            continue

        button.text = (
            "➕  ALS REISEGEFÄHRTEN AUFNEHMEN\n"
            + "%s schließt sich dir an" % capture_name
        )
        _style_route_decision_button(button, true)
