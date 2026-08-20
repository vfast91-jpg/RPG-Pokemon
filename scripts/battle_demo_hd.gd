extends "res://scripts/battle_demo.gd"

# 640x360 layout layer: keeps the battle logic in battle_demo.gd and only
# uses the extra screen space for a roomier combat presentation.

func _build_battle(root: Control) -> void:
    battle_panel = Control.new()
    battle_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(battle_panel)

    var sky: ColorRect = ColorRect.new()
    sky.color = Color("8fc8c0")
    sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_panel.add_child(sky)

    var battle_area: Control = Control.new()
    battle_area.name = "BattleArea"
    battle_area.position = Vector2(4, 5)
    battle_area.size = Vector2(632, 216)
    battle_area.clip_contents = true
    battle_panel.add_child(battle_area)

    var command: PanelContainer = PanelContainer.new()
    command.anchor_top = 1.0
    command.anchor_right = 1.0
    command.anchor_bottom = 1.0
    command.offset_left = 8.0
    command.offset_top = -132.0
    command.offset_right = -8.0
    command.offset_bottom = -8.0
    command.add_theme_stylebox_override("panel", _panel(Color("15201fed"), Color("f5df78"), 7, 6.0))
    battle_panel.add_child(command)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 3)
    command.add_child(content)

    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.fit_content = false
    log_label.scroll_active = false
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_label.custom_minimum_size = Vector2(0, 32)
    log_label.add_theme_font_size_override("normal_font_size", 12)
    content.add_child(log_label)

    var action_scroll: ScrollContainer = ScrollContainer.new()
    action_scroll.custom_minimum_size = Vector2(0, 70)
    action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    action_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(action_scroll)

    action_grid = GridContainer.new()
    action_grid.columns = 4
    action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_grid.add_theme_constant_override("h_separation", 5)
    action_grid.add_theme_constant_override("v_separation", 5)
    action_scroll.add_child(action_grid)

    _build_info_overlay(battle_panel)
    battle_panel.visible = false


func _build_info_overlay(parent: Control) -> void:
    info_shade = ColorRect.new()
    info_shade.color = Color(0.0, 0.0, 0.0, 0.55)
    info_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    info_shade.mouse_filter = Control.MOUSE_FILTER_STOP
    info_shade.z_index = 20
    parent.add_child(info_shade)

    info_panel = PanelContainer.new()
    info_panel.position = Vector2(90, 25)
    info_panel.size = Vector2(460, 310)
    info_panel.z_index = 21
    info_panel.add_theme_stylebox_override("panel", _panel(Color("17211f"), Color("ffe46c"), 10, 10.0))
    parent.add_child(info_panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 6)
    info_panel.add_child(content)

    var header: HBoxContainer = HBoxContainer.new()
    content.add_child(header)

    info_title = Label.new()
    info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info_title.add_theme_font_size_override("font_size", 19)
    info_title.add_theme_color_override("font_color", Color("ffe46c"))
    header.add_child(info_title)

    var close_top: Button = Button.new()
    close_top.text = "×"
    close_top.custom_minimum_size = Vector2(34, 30)
    close_top.tooltip_text = "Schließen"
    close_top.pressed.connect(_hide_info)
    header.add_child(close_top)

    info_body = RichTextLabel.new()
    info_body.bbcode_enabled = true
    info_body.scroll_active = true
    info_body.custom_minimum_size = Vector2(0, 218)
    info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    info_body.add_theme_font_size_override("normal_font_size", 11)
    info_body.add_theme_font_size_override("bold_font_size", 11)
    content.add_child(info_body)

    var close_bottom: Button = Button.new()
    close_bottom.text = "SCHLIESSEN"
    close_bottom.custom_minimum_size = Vector2(140, 30)
    close_bottom.pressed.connect(_hide_info)
    content.add_child(close_bottom)

    info_shade.visible = false
    info_panel.visible = false


func _build_result(root: Control) -> void:
    result_panel = PanelContainer.new()
    result_panel.position = Vector2(185, 125)
    result_panel.size = Vector2(270, 110)
    result_panel.z_index = 30
    result_panel.add_theme_stylebox_override("panel", _panel(Color("18231ff5"), Color("ffe46c")))
    root.add_child(result_panel)

    result_title = Label.new()
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 26)
    result_panel.add_child(result_title)
    result_panel.visible = false


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    var positions: Array = _positions_for_count(team.size())
    for index: int in range(team.size()):
        var combatant: Dictionary = team[index]
        var card: Control = _make_card(combatant, enemy)
        card.position = Vector2(8.0 if enemy else 438.0, float(positions[index]))
        area.add_child(card)


func _positions_for_count(count: int) -> Array:
    match count:
        1:
            return [84.0]
        2:
            return [55.0, 113.0]
        3:
            return [26.0, 84.0, 142.0]
        _:
            return [4.0, 57.0, 110.0, 163.0]


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
            button.text = str(move.get("name", move_id)) + " · AP " + str(move.get("ap", 1))
            button.custom_minimum_size = Vector2(145, 31)
            button.tooltip_text = _move_tooltip(move)
            button.pressed.connect(_choose_move.bind(move_id))
            action_grid.add_child(button)

    var wait_button: Button = Button.new()
    wait_button.text = "Warten"
    wait_button.custom_minimum_size = Vector2(145, 31)
    wait_button.tooltip_text = "Aggro senken und schneller wieder bereit werden."
    wait_button.pressed.connect(_choose_wait)
    action_grid.add_child(wait_button)
