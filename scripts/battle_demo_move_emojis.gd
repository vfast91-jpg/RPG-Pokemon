extends "res://scripts/battle_demo_ui_feedback.gd"

# Function-first move icons for faster visual decisions in the combat lab.
# Existing moves get an individually chosen emoji; future moves use the
# mechanic-aware fallback below.
#
# The same emoji is also used as lightweight battle animation. Damaging moves
# launch it as damage is resolved; status/self moves use the resolved target
# list after the move succeeded. This keeps misses, paralysis and confusion
# from showing a misleading attack animation.

const MOVE_EMOJIS: Dictionary = {
    "tackle": "💥",
    "scratch": "🗡️",
    "growl": "📣",
    "tail_whip": "💫",
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

const MOVE_EMOJI_SIZE: Vector2 = Vector2(44.0, 44.0)
const MOVE_EMOJI_FONT_SIZE: int = 31
const MOVE_EMOJI_TRAVEL_SECONDS: float = 0.34
const MOVE_EMOJI_SELF_RISE: float = 30.0

var _visual_move_id: String = ""
var _visual_move: Dictionary = {}
var _visual_animated_targets: Dictionary = {}


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


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    var candidate_targets: Array = []
    var charge_preparation: bool = _is_charge_preparation(move)

    if not move.is_empty() and bool(actor.get("alive", false)):
        # A real charge preparation has no interaction with the locked enemy
        # yet. Animate at the user instead of sending a misleading projectile
        # toward the current Aggro target. Derived move layers can still shape
        # this preparation further (Fly rises; Dig intentionally shows none).
        if charge_preparation:
            candidate_targets = [actor]
        else:
            candidate_targets = _targets(actor, str(move.get("target", "enemy_highest_aggro")))

    _visual_move_id = move_id
    _visual_move = move
    _visual_animated_targets.clear()

    super._execute_move(actor, move_id)

    # Damaging moves normally animate from _damage(), just before damage is
    # calculated. This fallback covers status moves, buffs and charge
    # preparations without duplicating the combat logic.
    if not move.is_empty() and _move_was_resolved(move_id, move):
        for target_value: Variant in candidate_targets:
            if target_value is Dictionary:
                _animate_move_emoji_once(actor, target_value as Dictionary, move_id, move)

    _visual_move_id = ""
    _visual_move = {}
    _visual_animated_targets.clear()


func _is_charge_preparation(move: Dictionary) -> bool:
    if move.is_empty():
        return false

    var runtime_value: Variant = move.get("runtime", {})
    if not (runtime_value is Dictionary):
        return false
    var runtime: Dictionary = runtime_value
    if not bool(runtime.get("charge_then_fire", false)):
        return false

    # The canonical action-sequence layer temporarily strips damage, accuracy
    # and mechanics only for the first (preparation) action. A charged shot –
    # including Solar Beam in sun, where preparation is skipped – keeps its
    # actual payload and therefore must still animate toward the real target.
    var mechanics_value: Variant = move.get("mechanics", [])
    var mechanics_empty: bool = (
        not (mechanics_value is Array)
        or (mechanics_value as Array).is_empty()
    )
    return (
        move.get("power", null) == null
        and move.get("accuracy", null) == null
        and mechanics_empty
    )


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    # Confusion self-damage is typeless and therefore deliberately fails this
    # match. Periodic damage happens after _visual_move_id has been cleared.
    if (
        not _visual_move_id.is_empty()
        and not _visual_move.is_empty()
        and move_type == str(_visual_move.get("type", ""))
        and category == str(_visual_move.get("category", ""))
    ):
        _animate_move_emoji_once(actor, target, _visual_move_id, _visual_move)

    return super._damage(actor, target, power, move_type, category)


func _move_was_resolved(move_id: String, move: Dictionary) -> bool:
    if log_label == null:
        return false
    var resolved_log: String = log_label.get_parsed_text().strip_edges()
    var move_name: String = str(move.get("name", move_id))
    return resolved_log.contains("nutzt") and resolved_log.contains(move_name)


func _animate_move_emoji_once(
    actor: Dictionary,
    target: Dictionary,
    move_id: String,
    move: Dictionary
) -> void:
    if battle_panel == null:
        return

    var target_key: String = str(target.get("id", ""))
    if target_key.is_empty() or _visual_animated_targets.has(target_key):
        return

    var actor_card: Control = _combatant_card(actor)
    var target_card: Control = _combatant_card(target)
    if actor_card == null or target_card == null:
        return

    _visual_animated_targets[target_key] = true

    var emoji_label: Label = Label.new()
    emoji_label.text = _move_emoji(move_id, move)
    emoji_label.size = MOVE_EMOJI_SIZE
    emoji_label.custom_minimum_size = MOVE_EMOJI_SIZE
    emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    emoji_label.add_theme_font_size_override("font_size", MOVE_EMOJI_FONT_SIZE)
    emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    emoji_label.z_index = 200
    emoji_label.pivot_offset = MOVE_EMOJI_SIZE * 0.5
    battle_panel.add_child(emoji_label)

    var start_center: Vector2 = actor_card.get_global_rect().get_center()
    var target_center: Vector2 = target_card.get_global_rect().get_center()
    emoji_label.global_position = start_center - MOVE_EMOJI_SIZE * 0.5
    emoji_label.scale = Vector2(0.78, 0.78)

    var same_target: bool = str(actor.get("id", "")) == target_key
    if same_target:
        _animate_self_emoji(emoji_label, start_center)
    else:
        _animate_travel_emoji(emoji_label, start_center, target_center)


func _combatant_card(combatant: Dictionary) -> Control:
    var entry_value: Variant = cards.get(str(combatant.get("id", "")), {})
    if not (entry_value is Dictionary):
        return null
    var entry: Dictionary = entry_value
    var card_value: Variant = entry.get("card", null)
    return card_value as Control if card_value is Control else null


func _animate_travel_emoji(label: Label, start_center: Vector2, target_center: Vector2) -> void:
    var half_size: Vector2 = MOVE_EMOJI_SIZE * 0.5
    var start_pos: Vector2 = start_center - half_size
    var target_pos: Vector2 = target_center - half_size
    var arc_height: float = minf(28.0, 14.0 + start_center.distance_to(target_center) * 0.05)
    var mid_pos: Vector2 = (start_pos + target_pos) * 0.5 + Vector2(0.0, -arc_height)

    label.global_position = start_pos
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2.ONE, 0.07)
    tween.parallel().tween_property(label, "global_position", mid_pos, MOVE_EMOJI_TRAVEL_SECONDS * 0.45)
    tween.tween_property(label, "global_position", target_pos, MOVE_EMOJI_TRAVEL_SECONDS * 0.55).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(label, "scale", Vector2(1.38, 1.38), MOVE_EMOJI_TRAVEL_SECONDS * 0.55)
    tween.tween_property(label, "scale", Vector2(0.92, 0.92), 0.10)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.10)
    tween.finished.connect(label.queue_free)


func _animate_self_emoji(label: Label, center: Vector2) -> void:
    var half_size: Vector2 = MOVE_EMOJI_SIZE * 0.5
    var home_pos: Vector2 = center - half_size
    var rise_pos: Vector2 = home_pos + Vector2(0.0, -MOVE_EMOJI_SELF_RISE)

    label.global_position = home_pos
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "global_position", rise_pos, 0.17)
    tween.parallel().tween_property(label, "scale", Vector2(1.22, 1.22), 0.17)
    tween.tween_property(label, "global_position", home_pos, 0.15).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(label, "scale", Vector2(1.42, 1.42), 0.15)
    tween.tween_property(label, "scale", Vector2(0.92, 0.92), 0.10)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.10)
    tween.finished.connect(label.queue_free)


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
