extends "res://scripts/battle_demo_layout_mobile.gd"

# Combat-lab readability/opening-phase layer:
# - KP are shown numerically on every HP bar.
# - Active statuses and temporary modifiers carry visible emoji/icons.
# - Opening-capable moves are offered in a real Runde-0 phase before ATB starts.
# - Player opening choices are collected first; enemy choices remain hidden.
# - Opening actions are resolved by Speed before normal ATB begins.

const OPENING_BATTLE_SETTLE_SECONDS: float = 0.75

var opening_phase_active: bool = false
var _opening_player_candidates: Array = []
var _opening_enemy_candidates: Array = []
var _opening_player_index: int = 0
var _opening_choices: Array = []


func _process(delta: float) -> void:
    # During Runde 0 no normal ATB bar may advance, even while action feedback
    # timers briefly release the normal pause flag.
    if opening_phase_active:
        return
    super._process(delta)


func _start_battle() -> void:
    super._start_battle()
    if not battle_active:
        return
    _begin_opening_phase()


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: Control = super._make_card(combatant, enemy)
    card.custom_minimum_size.y = 48.0
    card.size.y = 48.0

    var combatant_id: String = str(combatant.get("id", ""))
    var ui_value: Variant = cards.get(combatant_id, {})
    if not (ui_value is Dictionary):
        return card
    var ui: Dictionary = ui_value

    var hp_bar: ProgressBar = ui.get("hp") as ProgressBar
    if hp_bar != null:
        hp_bar.custom_minimum_size.y = 10.0

        var hp_text: Label = Label.new()
        hp_text.name = "HPText"
        hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hp_text.add_theme_font_size_override("font_size", 7)
        hp_text.add_theme_color_override("font_color", Color("ffffff"))
        hp_text.add_theme_color_override("font_outline_color", Color("17211f"))
        hp_text.add_theme_constant_override("outline_size", 2)
        hp_bar.add_child(hp_text)

        ui["hp_text"] = hp_text
        cards[combatant_id] = ui

    return card


func _refresh_cards() -> void:
    super._refresh_cards()

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var hp_text: Label = ui.get("hp_text") as Label
        if hp_text != null:
            hp_text.text = (
                "KP " + str(combatant.get("hp", 0))
                + "/" + str(combatant.get("max_hp", 0))
            )


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var base_tokens: Array[String] = super._status_tokens(combatant)
    var tokens: Array[String] = []

    for token: String in base_tokens:
        if token == "ZIEL":
            tokens.append("🎯 ZIEL")
        elif token == "PAR":
            tokens.append("⚡ PAR")
        elif token.begins_with("VERW"):
            tokens.append("💫 " + token)
        elif token.begins_with("ANG+"):
            tokens.append("💪 " + token)
        elif token.begins_with("ANG-"):
            tokens.append("📉 " + token)
        elif token.begins_with("DEF+"):
            tokens.append("🛡️ " + token)
        elif token.begins_with("DEF-"):
            tokens.append("💔 " + token)
        elif token.begins_with("GEN+"):
            tokens.append("👁️ " + token)
        elif token.begins_with("GEN-"):
            tokens.append("🌫️ " + token)
        elif token.begins_with("ATB+"):
            tokens.append("⏩ " + token)
        elif token.begins_with("ATB-"):
            tokens.append("🐌 " + token)
        else:
            tokens.append("✨ " + token)

    return tokens


func _begin_opening_phase() -> void:
    _opening_player_candidates = _opening_candidates(player_team)
    _opening_enemy_candidates = _opening_candidates(enemy_team)
    _opening_player_index = 0
    _opening_choices.clear()

    if _opening_player_candidates.is_empty() and _opening_enemy_candidates.is_empty():
        return

    opening_phase_active = true
    paused = true
    selected_actor = {}
    _clear_actions()
    _append_protocol_system("RUNDE 0 · Eröffnungsphase beginnt")
    _prompt_next_opening_actor()


func _opening_candidates(team: Array) -> Array:
    var result: Array = []
    for combatant_value: Variant in team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)):
            continue
        if not _opening_moves(combatant).is_empty():
            result.append(combatant)
    return result


func _opening_moves(actor: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var moves_all: Variant = data.get("moves", {})
    var actor_moves: Variant = actor.get("moves", [])
    if not (moves_all is Dictionary) or not (actor_moves is Array):
        return result

    for move_value: Variant in actor_moves:
        var move_id: String = str(move_value)
        var move_value_data: Variant = moves_all.get(move_id, {})
        if not (move_value_data is Dictionary):
            continue
        var move: Dictionary = move_value_data
        if bool(move.get("opening", false)) or bool(move.get("opening_phase", false)):
            result.append(move_id)
    return result


func _prompt_next_opening_actor() -> void:
    while _opening_player_index < _opening_player_candidates.size():
        var actor_value: Variant = _opening_player_candidates[_opening_player_index]
        if actor_value is Dictionary and bool((actor_value as Dictionary).get("alive", false)):
            var actor: Dictionary = actor_value
            var opening_moves: Array[String] = _opening_moves(actor)
            if not opening_moves.is_empty():
                _show_opening_choice(actor, opening_moves)
                return
        _opening_player_index += 1

    _collect_enemy_opening_choices()
    _resolve_opening_phase()


func _show_opening_choice(actor: Dictionary, opening_moves: Array[String]) -> void:
    _clear_actions()
    _touch_preview_move_id = ""
    _set_log(
        "[b]RUNDE 0[/b] · " + _actor_name(actor)
        + " darf eine Eröffnungsattacke wählen. Gegnerentscheidungen bleiben verborgen."
    )

    var moves_all: Variant = data.get("moves", {})
    if moves_all is Dictionary:
        for move_id: String in opening_moves:
            var move_value: Variant = moves_all.get(move_id, {})
            if not (move_value is Dictionary):
                continue
            var move: Dictionary = move_value
            var button: Button = Button.new()
            button.text = "⚡ " + str(move.get("name", move_id)) + " · RUNDE 0"
            button.custom_minimum_size = Vector2(165, 31)
            button.tooltip_text = ""
            button.mouse_entered.connect(_preview_move.bind(move_id, move, false))
            button.focus_entered.connect(_preview_move.bind(move_id, move, false))

            if DisplayServer.is_touchscreen_available():
                button.pressed.connect(_touch_opening_move_pressed.bind(actor, move_id, move))
            else:
                button.pressed.connect(_choose_opening_move.bind(actor, move_id))
            action_grid.add_child(button)

    var skip_button: Button = Button.new()
    skip_button.text = "⏭ Keine Eröffnungsaktion"
    skip_button.custom_minimum_size = Vector2(165, 31)
    skip_button.tooltip_text = ""
    skip_button.pressed.connect(_skip_opening_move)
    action_grid.add_child(skip_button)


func _touch_opening_move_pressed(actor: Dictionary, move_id: String, move: Dictionary) -> void:
    if _touch_preview_move_id == move_id:
        _touch_preview_move_id = ""
        _choose_opening_move(actor, move_id)
        return
    _touch_preview_move_id = move_id
    _preview_move(move_id, move, true)


func _choose_opening_move(actor: Dictionary, move_id: String) -> void:
    _opening_choices.append({"actor": actor, "move_id": move_id})
    _opening_player_index += 1
    _touch_preview_move_id = ""
    _prompt_next_opening_actor()


func _skip_opening_move() -> void:
    _opening_player_index += 1
    _touch_preview_move_id = ""
    _prompt_next_opening_actor()


func _collect_enemy_opening_choices() -> void:
    # AI policy for the current combat lab: if an enemy has at least one legal
    # opening move, it uses one. The player never sees this choice beforehand.
    for actor_value: Variant in _opening_enemy_candidates:
        if not (actor_value is Dictionary):
            continue
        var actor: Dictionary = actor_value
        if not bool(actor.get("alive", false)):
            continue
        var moves: Array[String] = _opening_moves(actor)
        if moves.is_empty():
            continue
        _opening_choices.append({"actor": actor, "move_id": str(moves.pick_random())})


func _resolve_opening_phase() -> void:
    _clear_actions()

    _opening_choices.sort_custom(
        func(a: Variant, b: Variant) -> bool:
            if not (a is Dictionary) or not (b is Dictionary):
                return false
            var actor_a: Dictionary = (a as Dictionary).get("actor", {})
            var actor_b: Dictionary = (b as Dictionary).get("actor", {})
            var speed_a: float = float(actor_a.get("speed", 0))
            var speed_b: float = float(actor_b.get("speed", 0))
            if not is_equal_approx(speed_a, speed_b):
                return speed_a > speed_b
            var index_a: int = int(actor_a.get("index", 0))
            var index_b: int = int(actor_b.get("index", 0))
            if index_a != index_b:
                return index_a < index_b
            return str(actor_a.get("side", "")) == "player"
    )

    _resolve_opening_actions_async()


func _resolve_opening_actions_async() -> void:
    if _opening_choices.is_empty():
        _finish_opening_phase()
        return

    # Runde 0 used to fire on the same frame in which the battle appeared.
    # Keep the combat paused briefly so the battle scene and battle music have a
    # perceptible entrance before the first priority/opening move resolves.
    paused = true
    _set_log("[b]Kampf beginnt![/b] Runde 0 wird vorbereitet.")
    await get_tree().create_timer(OPENING_BATTLE_SETTLE_SECONDS).timeout
    if not battle_active:
        return

    for choice_value: Variant in _opening_choices:
        if not battle_active:
            return
        if not (choice_value is Dictionary):
            continue
        var choice: Dictionary = choice_value
        var actor_value: Variant = choice.get("actor", {})
        if not (actor_value is Dictionary):
            continue
        var actor: Dictionary = actor_value
        if not bool(actor.get("alive", false)):
            continue

        var move_id: String = str(choice.get("move_id", ""))
        if move_id.is_empty():
            continue

        paused = true
        _set_log(
            "[b]RUNDE 0[/b] · " + _actor_name(actor)
            + " setzt " + str(_move_data(move_id).get("name", move_id)) + " ein."
        )
        super._execute_move(actor, move_id)
        await get_tree().create_timer(SHORT_ACTION_FEEDBACK_SECONDS).timeout
        if not battle_active:
            return
        paused = true

    _finish_opening_phase()


func _finish_opening_phase() -> void:
    opening_phase_active = false
    paused = false
    selected_actor = {}
    _opening_choices.clear()
    _opening_player_candidates.clear()
    _opening_enemy_candidates.clear()
    _clear_actions()
    _set_log("[b]Runde 0 beendet.[/b] Die normalen ATB-Leisten starten jetzt.")
    _append_protocol_system("RUNDE 0 beendet · normales ATB startet")
    _refresh_cards()
