extends "res://scripts/battle_demo_three_action_effects.gd"

# Combat-lab presentation/mobile layer:
# - Battle protocol sits on the left; enemy cards move toward the center.
# - Native translucent move tooltips are replaced by the solid battle-log info strip.
# - Desktop: hovering previews move information, one click executes.
# - Touchscreen: first tap previews, second tap on the same move executes.
# - Action feedback is 25% shorter than the previous 2.50 second timing.

const SHORT_ACTION_FEEDBACK_SECONDS: float = 1.875
const ENEMY_COLUMN_X: float = 226.0
const PLAYER_COLUMN_X: float = 438.0

var _touch_preview_move_id: String = ""


func _build_battle(root: Control) -> void:
    super._build_battle(root)

    var protocol_panel: PanelContainer = battle_panel.get_node_or_null("BattleProtocol") as PanelContainer
    if protocol_panel != null:
        protocol_panel.position = Vector2(8.0, 10.0)
        protocol_panel.size = Vector2(206.0, 204.0)

    # The existing battle-log area doubles as a fixed, opaque move-info strip.
    # This avoids floating translucent tooltips and works identically with mouse,
    # keyboard focus and touch input.
    if log_label != null:
        log_label.add_theme_stylebox_override(
            "normal",
            _panel(Color("08110f"), Color("d8c65e"), 5, 4.0)
        )
        log_label.add_theme_font_size_override("normal_font_size", 9)
        log_label.add_theme_font_size_override("bold_font_size", 9)
        log_label.scroll_active = false


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    var positions: Array = _positions_for_count(team.size())
    for index: int in range(team.size()):
        var combatant: Dictionary = team[index]
        var card: Control = _make_card(combatant, enemy)
        card.position = Vector2(ENEMY_COLUMN_X if enemy else PLAYER_COLUMN_X, float(positions[index]))
        area.add_child(card)


func _prompt_player(actor: Dictionary) -> void:
    paused = true
    selected_actor = actor
    _touch_preview_move_id = ""
    _clear_actions()
    _set_log(
        "[b]" + _actor_name(actor) + "[/b] ist bereit. "
        + "Maus: über Attacke = Info · Mobil: 1× Info, 2× Ausführen."
    )

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

            # Do not use Godot's floating tooltip here: it is hard to read over
            # the battle and has no touch equivalent.
            button.tooltip_text = ""
            button.mouse_entered.connect(_preview_move.bind(move_id, move, false))
            button.focus_entered.connect(_preview_move.bind(move_id, move, false))

            if DisplayServer.is_touchscreen_available():
                button.pressed.connect(_touch_move_pressed.bind(move_id, move))
            else:
                button.pressed.connect(_choose_move.bind(move_id))
            action_grid.add_child(button)

    var wait_button: Button = Button.new()
    wait_button.text = "⏳ Warten"
    wait_button.custom_minimum_size = Vector2(145, 31)
    wait_button.tooltip_text = ""
    wait_button.mouse_entered.connect(_preview_wait)
    wait_button.focus_entered.connect(_preview_wait)
    wait_button.pressed.connect(_choose_wait)
    action_grid.add_child(wait_button)

    _refresh_cards()


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    if log_label == null:
        return

    var ap: int = _ap_value(move)
    var move_type: String = str(move.get("type", "normal"))
    var category: String = str(move.get("category", "status"))
    var line_one: String = (
        "[b]" + _move_emoji(move_id, move) + " " + str(move.get("name", move_id)) + "[/b]"
        + " · " + _type_name(move_type)
        + " · " + _category_name(category)
        + " · AP " + str(ap)
        + " → ATB ×" + _decimal(_ap_cycle(ap), 2)
    )

    var details: Array[String] = []
    details.append("Ziel: " + _target_name(str(move.get("target", "enemy_highest_aggro"))))

    var effect_summary: String = _compact_effect_summary(move)
    effect_summary = effect_summary.replace("nächster ATB-Zyklus kürzer", "ATB-Zyklen kürzer")
    effect_summary = effect_summary.replace("nächster ATB-Zyklus länger", "ATB-Zyklen länger")
    if not effect_summary.is_empty():
        details.append(effect_summary)
    if _move_has_three_action_modifier(move):
        details.append("wirkt 3 eigene Aktionen")
    if touch_confirm:
        details.append("[b]noch einmal tippen = AUSFÜHREN[/b]")

    log_label.text = line_one + "\n" + " · ".join(details)


func _preview_wait() -> void:
    _touch_preview_move_id = ""
    if log_label != null:
        log_label.text = (
            "[b]⏳ Warten[/b] · keine Attacke\n"
            + "Aggro sinkt · der nächste eigene ATB-Zyklus wird kürzer."
        )


func _touch_move_pressed(move_id: String, move: Dictionary) -> void:
    if _touch_preview_move_id == move_id:
        _touch_preview_move_id = ""
        _choose_move(move_id)
        return

    _touch_preview_move_id = move_id
    _preview_move(move_id, move, true)


func _move_has_three_action_modifier(move: Dictionary) -> bool:
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false
    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var kind: String = str((mechanic_value as Dictionary).get("kind", ""))
        if TEMP_EFFECT_KINDS.has(kind):
            return true
    return false


func _execute_move(actor: Dictionary, move_id: String) -> void:
    super._execute_move(actor, move_id)

    # The parent still owns the full action-resolution pipeline. This earlier
    # release timer shortens only the readable feedback pause by exactly 25%.
    if battle_active:
        get_tree().create_timer(SHORT_ACTION_FEEDBACK_SECONDS).timeout.connect(_finish_action_feedback)


func _flash_combatant(combatant: Dictionary, color: Color) -> void:
    var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
    if not (ui_value is Dictionary):
        return
    var ui: Dictionary = ui_value
    var card: Control = ui.get("card") as Control
    if card == null:
        return

    card.modulate = Color.WHITE
    var tween: Tween = create_tween()
    tween.tween_property(card, "modulate", color, 0.135)
    tween.tween_interval(1.515)
    tween.tween_property(card, "modulate", Color.WHITE, 0.225)


func _spawn_feedback_label(combatant: Dictionary, text: String, color: Color) -> void:
    if battle_panel == null:
        return

    var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
    if not (ui_value is Dictionary):
        return
    var ui: Dictionary = ui_value
    var card: Control = ui.get("card") as Control
    if card == null:
        return

    var label: Label = Label.new()
    label.text = text
    label.position = card.global_position + Vector2(8.0, -19.0)
    label.z_index = 60
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color("18211f"))
    label.add_theme_constant_override("outline_size", 4)
    battle_panel.add_child(label)

    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(
        label,
        "position:y",
        label.position.y - FEEDBACK_RISE_PIXELS,
        SHORT_ACTION_FEEDBACK_SECONDS
    )
    tween.tween_property(label, "modulate:a", 0.0, 0.4125).set_delay(1.4625)
    tween.chain().tween_callback(label.queue_free)
