extends "res://scripts/battle_demo_ui_feedback.gd"

# Function-first move icons for faster visual decisions in the combat lab.
# Existing moves get an individually chosen emoji; future moves use the
# mechanic-aware fallback below.

const MOVE_EMOJIS: Dictionary = {
    "tackle": "💥",
    "scratch": "🗡️",
    "growl": "📣",
    "tail_whip": "💔",
    "vine_whip": "🌿",
    "growth": "🌱",
    "leech_seed": "🌱",
    "ember": "🔥",
    "smokescreen": "🌫️",
    "water_gun": "💦",
    "withdraw": "🛡️",
    "rapid_spin": "🌀",
    "string_shot": "🕸️",
    "bug_bite": "🦷",
    "poison_sting": "☠️",
    "sand_attack": "🌪️",
    "gust": "💨",
    "quick_attack": "⚡",
    "focus_energy": "🎯",
    "bite": "🦷",
    "peck": "🐦",
    "leer": "👁️",
    "assurance": "💢",
    "wrap": "🐍",
    "nuzzle": "⚡",
    "thunder_shock": "⚡",
    "play_nice": "🤝",
    "sweet_kiss": "💋"
}


func _prompt_player(actor: Dictionary) -> void:
    paused = true
    selected_actor = actor
    _clear_actions()
    _set_log("[b]" + _actor_name(actor) + "[/b] ist bereit. Wähle eine Aktion.")

    var moves_all: Variant = data.get("moves", {})
    var actor_moves: Variant = actor.get("moves", [])
    if actor_moves is Array and moves_all is Dictionary:
        for move_value: Variant in actor_moves:
            var move_id: String = str(move_value)
            var move_value_data: Variant = moves_all.get(move_id, {})
            var move: Dictionary = move_value_data if move_value_data is Dictionary else {}
            var button: Button = Button.new()
            button.text = _move_emoji(move_id, move) + " " + str(move.get("name", move_id)) + " · AP " + str(_ap_value(move))
            button.custom_minimum_size = Vector2(145, 31)
            button.tooltip_text = _move_tooltip(move)
            button.pressed.connect(_choose_move.bind(move_id))
            action_grid.add_child(button)

    var wait_button: Button = Button.new()
    wait_button.text = "⏳ Warten"
    wait_button.custom_minimum_size = Vector2(145, 31)
    wait_button.tooltip_text = "Warten · Aggro sinkt · nächster ATB-Zyklus wird kürzer."
    wait_button.pressed.connect(_choose_wait)
    action_grid.add_child(wait_button)

    _refresh_cards()


func _move_tooltip(move: Dictionary) -> String:
    var base_tooltip: String = super._move_tooltip(move)
    var move_id: String = str(move.get("id", ""))
    return _move_emoji(move_id, move) + " " + base_tooltip


func _move_emoji(move_id: String, move: Dictionary) -> String:
    if MOVE_EMOJIS.has(move_id):
        return str(MOVE_EMOJIS[move_id])

    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            var mechanic: Dictionary = mechanic_value
            var kind: String = str(mechanic.get("kind", ""))
            var multiplier: float = float(mechanic.get("multiplier_from_special", 0.0))

            match kind:
                "status":
                    match str(mechanic.get("status", "")):
                        "paralysis":
                            return "⚡"
                        "confusion":
                            return "💫"
                        "burn":
                            return "🔥"
                        "poison":
                            return "☠️"
                        _:
                            return "💫"
                "outgoing_damage_mod":
                    return "📉" if multiplier < 0.0 else "💪"
                "incoming_damage_mod":
                    return "🛡️" if multiplier < 0.0 else "💔"
                "accuracy_mod":
                    return "🌫️" if multiplier < 0.0 else "👁️"
                "atb_cycle_mod":
                    return "⏩" if multiplier < 0.0 else "⏳"
                "atb_knockback":
                    return "⏪"
                "cleanse_self":
                    return "✨"
                "seed":
                    return "🌱"
                "binding":
                    return "🪢"
                "critical_focus":
                    return "🎯"

    match str(move.get("category", "physical")):
        "physical":
            return "💥"
        "special":
            return "✨"
        "status":
            return "🔄"
        _:
            return "⭐"
