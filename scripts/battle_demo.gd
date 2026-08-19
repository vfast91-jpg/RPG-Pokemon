extends CanvasLayer

const DATA_PATH: String = "res://data/PIKACHU_DEMO_ALL_IN_ONE.json"
const PIKACHU_TEXTURE: Texture2D = preload("res://assets/Pikachu.png")
const MOVE_IDS: Array[String] = ["nuzzle", "quick_attack", "growl"]
const AGGRO_AFTER_HIT_MULTIPLIER: float = 0.5

var data: Dictionary = {}
var player_levels: Array[int] = [15]
var enemy_levels: Array[int] = [15]

var battle_active: bool = false
var paused_for_player: bool = false
var selected_actor: Dictionary = {}
var player_team: Array[Dictionary] = []
var enemy_team: Array[Dictionary] = []
var combatants: Array[Dictionary] = []
var team_controls: Dictionary = {}

var config_panel: PanelContainer
var battle_panel: Control
var result_panel: PanelContainer
var config_rows: VBoxContainer
var log_label: RichTextLabel
var result_title: Label
var result_text: Label
var player_count_spin: SpinBox
var enemy_count_spin: SpinBox
var move_buttons: Array[Button] = []

func _ready() -> void:
    layer = 50
    _load_data()
    _build_ui()
    visible = false

func open_config() -> void:
    visible = true
    battle_active = false
    paused_for_player = false
    config_panel.visible = true
    battle_panel.visible = false
    result_panel.visible = false
    _refresh_config_rows()

func open_battle_direct() -> void:
    visible = true
    _start_battle()

func close_demo() -> void:
    battle_active = false
    paused_for_player = false
    selected_actor = {}
    visible = false

func _load_data() -> void:
    var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Pikachu-Demodaten fehlen: " + DATA_PATH)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        data = parsed
    else:
        push_error("Pikachu-Demodaten konnten nicht gelesen werden.")

func _build_ui() -> void:
    var root: Control = Control.new()
    root.name = "BattleDemoRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.size = Vector2(480, 320)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)

    var shade: ColorRect = ColorRect.new()
    shade.color = Color(0.035, 0.055, 0.06, 0.97)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shade)

    _build_config(root)
    _build_battle(root)
    _build_result(root)

func _make_panel(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    return style

func _make_bar_style(color: Color, radius: int = 4) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    return style

func _build_config(root: Control) -> void:
    config_panel = PanelContainer.new()
    config_panel.position = Vector2(30, 18)
    config_panel.size = Vector2(420, 284)
    config_panel.add_theme_stylebox_override("panel", _make_panel(Color("18231f"), Color("e4c95d"), 10))
    root.add_child(config_panel)

    var v: VBoxContainer = VBoxContainer.new()
    v.add_theme_constant_override("separation", 5)
    config_panel.add_child(v)

    var title: Label = Label.new()
    title.text = "PIKACHU-KAMPFLABOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color("ffe46c"))
    v.add_child(title)

    var subtitle: Label = Label.new()
    subtitle.text = "Lege Teams und Level fest. Danach kannst du den Testkampf starten."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size", 11)
    v.add_child(subtitle)

    var counts: HBoxContainer = HBoxContainer.new()
    counts.alignment = BoxContainer.ALIGNMENT_CENTER
    counts.add_theme_constant_override("separation", 18)
    v.add_child(counts)

    var own_box: VBoxContainer = VBoxContainer.new()
    var own_label: Label = Label.new()
    own_label.text = "Eigene Pikachus"
    own_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    own_box.add_child(own_label)
    player_count_spin = SpinBox.new()
    player_count_spin.min_value = 1.0
    player_count_spin.max_value = 4.0
    player_count_spin.value = 1.0
    player_count_spin.custom_minimum_size = Vector2(100, 26)
    player_count_spin.value_changed.connect(_on_player_count_changed)
    own_box.add_child(player_count_spin)
    counts.add_child(own_box)

    var wild_box: VBoxContainer = VBoxContainer.new()
    var wild_label: Label = Label.new()
    wild_label.text = "Wilde Pikachus"
    wild_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wild_box.add_child(wild_label)
    enemy_count_spin = SpinBox.new()
    enemy_count_spin.min_value = 1.0
    enemy_count_spin.max_value = 4.0
    enemy_count_spin.value = 1.0
    enemy_count_spin.custom_minimum_size = Vector2(100, 26)
    enemy_count_spin.value_changed.connect(_on_enemy_count_changed)
    wild_box.add_child(enemy_count_spin)
    counts.add_child(wild_box)

    config_rows = VBoxContainer.new()
    config_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(config_rows)

    var presets: HBoxContainer = HBoxContainer.new()
    presets.alignment = BoxContainer.ALIGNMENT_CENTER
    presets.add_theme_constant_override("separation", 6)
    v.add_child(presets)

    var equal_btn: Button = Button.new()
    equal_btn.text = "4v4 · Lv.15"
    equal_btn.pressed.connect(_preset_equal)
    presets.add_child(equal_btn)

    var mixed_btn: Button = Button.new()
    mixed_btn.text = "4v4 · 5/15/30/50"
    mixed_btn.pressed.connect(_preset_mixed)
    presets.add_child(mixed_btn)

    var actions: HBoxContainer = HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 8)
    v.add_child(actions)

    var test_btn: Button = Button.new()
    test_btn.text = "KAMPF JETZT TESTEN"
    test_btn.custom_minimum_size = Vector2(190, 30)
    test_btn.pressed.connect(_start_battle)
    actions.add_child(test_btn)

    var close_btn: Button = Button.new()
    close_btn.text = "Zurück"
    close_btn.pressed.connect(close_demo)
    actions.add_child(close_btn)

func _on_player_count_changed(value: float) -> void:
    _resize_levels(player_levels, int(value))
    _refresh_config_rows()

func _on_enemy_count_changed(value: float) -> void:
    _resize_levels(enemy_levels, int(value))
    _refresh_config_rows()

func _resize_levels(levels: Array[int], count: int) -> void:
    while levels.size() < count:
        levels.append(15)
    while levels.size() > count:
        levels.pop_back()

func _preset_equal() -> void:
    _apply_preset([15, 15, 15, 15], [15, 15, 15, 15])

func _preset_mixed() -> void:
    _apply_preset([5, 15, 30, 50], [5, 15, 30, 50])

func _apply_preset(players: Array, enemies: Array) -> void:
    player_levels.clear()
    enemy_levels.clear()
    for value: Variant in players:
        player_levels.append(int(value))
    for value: Variant in enemies:
        enemy_levels.append(int(value))
    player_count_spin.value = float(player_levels.size())
    enemy_count_spin.value = float(enemy_levels.size())
    _refresh_config_rows()

func _refresh_config_rows() -> void:
    if config_rows == null:
        return

    for child: Node in config_rows.get_children():
        child.queue_free()

    var header: HBoxContainer = HBoxContainer.new()
    header.add_theme_constant_override("separation", 28)

    var own: Label = Label.new()
    own.text = "EIGENES TEAM"
    own.custom_minimum_size = Vector2(170, 20)
    own.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(own)

    var wild: Label = Label.new()
    wild.text = "WILDES TEAM"
    wild.custom_minimum_size = Vector2(170, 20)
    wild.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(wild)
    config_rows.add_child(header)

    var row_count: int = maxi(player_levels.size(), enemy_levels.size())
    for index: int in range(row_count):
        var row: HBoxContainer = HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 28)
        row.add_child(_make_level_editor(index, true))
        row.add_child(_make_level_editor(index, false))
        config_rows.add_child(row)

func _make_level_editor(index: int, is_player: bool) -> Control:
    var holder: HBoxContainer = HBoxContainer.new()
    holder.custom_minimum_size = Vector2(170, 27)

    var levels: Array[int] = player_levels if is_player else enemy_levels
    if index >= levels.size():
        var blank: Control = Control.new()
        blank.custom_minimum_size = Vector2(170, 27)
        return blank

    var label: Label = Label.new()
    label.text = ("P" if is_player else "W") + str(index + 1) + "  Level"
    label.custom_minimum_size = Vector2(78, 25)
    holder.add_child(label)

    var spin: SpinBox = SpinBox.new()
    spin.min_value = 1.0
    spin.max_value = 100.0
    spin.value = float(levels[index])
    spin.custom_minimum_size = Vector2(82, 25)
    spin.value_changed.connect(_on_level_changed.bind(is_player, index))
    holder.add_child(spin)
    return holder

func _on_level_changed(value: float, is_player: bool, index: int) -> void:
    if is_player:
        if index < player_levels.size():
            player_levels[index] = int(value)
    else:
        if index < enemy_levels.size():
            enemy_levels[index] = int(value)

func _build_battle(root: Control) -> void:
    battle_panel = Control.new()
    battle_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_panel.size = Vector2(480, 320)
    root.add_child(battle_panel)

    var sky: ColorRect = ColorRect.new()
    sky.color = Color("8fc8c0")
    sky.position = Vector2.ZERO
    sky.size = Vector2(480, 190)
    battle_panel.add_child(sky)

    var ground: ColorRect = ColorRect.new()
    ground.color = Color("b8d47a")
    ground.position = Vector2(0, 190)
    ground.size = Vector2(480, 130)
    battle_panel.add_child(ground)

    var stripe: ColorRect = ColorRect.new()
    stripe.color = Color("769a58")
    stripe.position = Vector2(0, 185)
    stripe.size = Vector2(480, 8)
    battle_panel.add_child(stripe)

    var header_panel: PanelContainer = PanelContainer.new()
    header_panel.position = Vector2(12, 8)
    header_panel.size = Vector2(456, 34)
    header_panel.add_theme_stylebox_override("panel", _make_panel(Color("172624e8"), Color("fff1a2"), 7))
    battle_panel.add_child(header_panel)

    var header: Label = Label.new()
    header.text = "PIKACHU · DEMOKAMPF     ATB-KAMPFLABOR"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color", Color("fff1a2"))
    header_panel.add_child(header)

    var battle_area: Control = Control.new()
    battle_area.name = "BattleArea"
    battle_area.position = Vector2(0, 42)
    battle_area.size = Vector2(480, 178)
    battle_panel.add_child(battle_area)

    var command: PanelContainer = PanelContainer.new()
    command.position = Vector2(10, 220)
    command.size = Vector2(460, 90)
    command.add_theme_stylebox_override("panel", _make_panel(Color("15201fed"), Color("f5df78"), 7))
    battle_panel.add_child(command)

    var command_v: VBoxContainer = VBoxContainer.new()
    command_v.add_theme_constant_override("separation", 3)
    command.add_child(command_v)

    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.fit_content = true
    log_label.scroll_active = false
    log_label.custom_minimum_size = Vector2(430, 31)
    log_label.add_theme_font_size_override("normal_font_size", 11)
    command_v.add_child(log_label)

    var buttons: HBoxContainer = HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 6)
    command_v.add_child(buttons)

    for move_id: String in MOVE_IDS:
        var btn: Button = Button.new()
        btn.custom_minimum_size = Vector2(118, 30)
        btn.disabled = true
        btn.pressed.connect(_on_move_pressed.bind(move_id))
        buttons.add_child(btn)
        move_buttons.append(btn)

    var exit_btn: Button = Button.new()
    exit_btn.text = "Abbruch"
    exit_btn.custom_minimum_size = Vector2(72, 30)
    exit_btn.pressed.connect(close_demo)
    buttons.add_child(exit_btn)

    battle_panel.visible = false

func _build_result(root: Control) -> void:
    result_panel = PanelContainer.new()
    result_panel.position = Vector2(90, 80)
    result_panel.size = Vector2(300, 160)
    result_panel.add_theme_stylebox_override("panel", _make_panel(Color("18231ff5"), Color("ffe46c"), 12))
    root.add_child(result_panel)

    var v: VBoxContainer = VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 10)
    result_panel.add_child(v)

    result_title = Label.new()
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 26)
    result_title.add_theme_color_override("font_color", Color("ffe46c"))
    v.add_child(result_title)

    result_text = Label.new()
    result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(result_text)

    var buttons: HBoxContainer = HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 8)
    v.add_child(buttons)

    var retry: Button = Button.new()
    retry.text = "Nochmal"
    retry.pressed.connect(_start_battle)
    buttons.add_child(retry)

    var config: Button = Button.new()
    config.text = "Setup ändern"
    config.pressed.connect(open_config)
    buttons.add_child(config)

    var leave: Button = Button.new()
    leave.text = "Zurück zur Route"
    leave.pressed.connect(close_demo)
    buttons.add_child(leave)

    result_panel.visible = false

func _start_battle() -> void:
    visible = true
    config_panel.visible = false
    result_panel.visible = false
    battle_panel.visible = true
    battle_active = true
    paused_for_player = false
    selected_actor = {}

    player_team.clear()
    enemy_team.clear()
    combatants.clear()
    team_controls.clear()

    var area: Control = battle_panel.get_node("BattleArea") as Control
    for child: Node in area.get_children():
        child.queue_free()

    for index: int in range(player_levels.size()):
        var player_combatant: Dictionary = _make_combatant("player", index, player_levels[index])
        player_team.append(player_combatant)
        combatants.append(player_combatant)

    for index: int in range(enemy_levels.size()):
        var enemy_combatant: Dictionary = _make_combatant("enemy", index, enemy_levels[index])
        enemy_team.append(enemy_combatant)
        combatants.append(enemy_combatant)

    # Gegner links, eigenes Team rechts.
    _layout_team(area, enemy_team, true)
    _layout_team(area, player_team, false)
    _refresh_all_cards()
    _set_log("Der Pikachu-Testkampf beginnt! Blau = ATB, Grün/Gelb/Rot = KP.")
    _disable_move_buttons()

func _make_combatant(side: String, index: int, level: int) -> Dictionary:
    var species_all: Dictionary = data.get("species", {})
    var pikachu: Dictionary = species_all.get("pikachu", {})
    var base: Dictionary = pikachu.get("base_stats", {"hp": 35, "attack": 53, "defense": 47, "special": 55, "speed": 90})
    var types: Dictionary = pikachu.get("types", {"primary": "electric", "secondary": null})

    var max_hp: int = int(floor((2.0 * float(base.get("hp", 35)) * float(level)) / 100.0)) + level + 10
    var attack: int = int(floor((2.0 * float(base.get("attack", 53)) * float(level)) / 100.0)) + 5
    var defense: int = int(floor((2.0 * float(base.get("defense", 47)) * float(level)) / 100.0)) + 5
    var speed: int = int(floor((2.0 * float(base.get("speed", 90)) * float(level)) / 100.0)) + 5

    # Für die Demo bewusst deterministisch: höheres Level startet mit mehr Bedrohung.
    var start_aggro: float = 10.0 + float(level) * 2.0

    return {
        "id": side + "_" + str(index),
        "side": side,
        "index": index,
        "level": level,
        "max_hp": max_hp,
        "hp": max_hp,
        "attack": attack,
        "defense": defense,
        "speed": speed,
        "type_primary": str(types.get("primary", "electric")),
        "type_secondary": types.get("secondary", null),
        "attack_stage": 0,
        "paralyzed": false,
        "atb": 0.0,
        "cycle_mult": 1.0,
        "alive": true,
        "aggro": start_aggro
    }

func _layout_team(area: Control, team: Array[Dictionary], enemy: bool) -> void:
    var positions: Array[float] = _positions_for_count(team.size())
    for index: int in range(team.size()):
        var combatant: Dictionary = team[index]
        var card: Control = _create_combatant_card(combatant, enemy)
        var x: float = 18.0 if enemy else 292.0
        card.position = Vector2(x, positions[index])
        area.add_child(card)

func _positions_for_count(count: int) -> Array[float]:
    match count:
        1:
            return [52.0]
        2:
            return [18.0, 88.0]
        3:
            return [1.0, 57.0, 113.0]
        _:
            return [-5.0, 38.0, 81.0, 124.0]

func _create_combatant_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: PanelContainer = PanelContainer.new()
    card.custom_minimum_size = Vector2(170, 48)
    card.size = Vector2(170, 48)
    card.add_theme_stylebox_override("panel", _make_panel(Color("f8f1dce8"), Color("34443d"), 5))

    var h: HBoxContainer = HBoxContainer.new()
    h.add_theme_constant_override("separation", 4)
    card.add_child(h)

    var sprite: TextureRect = TextureRect.new()
    sprite.texture = PIKACHU_TEXTURE
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.custom_minimum_size = Vector2(42, 42)
    # Das Originalbild schaut nach rechts. Gegner links schauen nach rechts,
    # das eigene Team rechts wird gespiegelt und schaut nach links.
    sprite.flip_h = not enemy
    h.add_child(sprite)

    var v: VBoxContainer = VBoxContainer.new()
    v.add_theme_constant_override("separation", 0)
    h.add_child(v)

    var name_label: Label = Label.new()
    name_label.text = ("Wildes " if enemy else "") + "Pikachu  Lv." + str(combatant["level"])
    name_label.add_theme_color_override("font_color", Color("26322e"))
    name_label.add_theme_font_size_override("font_size", 10)
    v.add_child(name_label)

    var hp_bar: ProgressBar = ProgressBar.new()
    hp_bar.max_value = float(combatant["max_hp"])
    hp_bar.value = float(combatant["hp"])
    hp_bar.show_percentage = false
    hp_bar.custom_minimum_size = Vector2(112, 9)
    hp_bar.add_theme_stylebox_override("background", _make_bar_style(Color("c8c8c2")))
    hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("55b85a")))
    v.add_child(hp_bar)

    var hp_text: Label = Label.new()
    hp_text.text = str(combatant["hp"]) + "/" + str(combatant["max_hp"]) + " KP"
    hp_text.add_theme_color_override("font_color", Color("34443d"))
    hp_text.add_theme_font_size_override("font_size", 8)
    v.add_child(hp_text)

    var atb_bar: ProgressBar = ProgressBar.new()
    atb_bar.max_value = 100.0
    atb_bar.value = float(combatant["atb"])
    atb_bar.show_percentage = false
    atb_bar.custom_minimum_size = Vector2(112, 6)
    atb_bar.add_theme_stylebox_override("background", _make_bar_style(Color("b5b5aa"), 3))
    atb_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("42aef5"), 3))
    v.add_child(atb_bar)

    var status: Label = Label.new()
    status.text = ""
    status.add_theme_color_override("font_color", Color("59605c"))
    status.add_theme_font_size_override("font_size", 8)
    v.add_child(status)

    team_controls[str(combatant["id"])] = {
        "card": card,
        "hp": hp_bar,
        "hp_text": hp_text,
        "atb": atb_bar,
        "status": status
    }
    return card

func _process(delta: float) -> void:
    if not battle_active or paused_for_player:
        return

    var ready_actor: Dictionary = {}
    var best_speed: float = -1.0

    for combatant: Dictionary in combatants:
        if not bool(combatant.get("alive", false)):
            continue

        var effective_speed: float = float(combatant.get("speed", 10))
        if bool(combatant.get("paralyzed", false)):
            effective_speed *= 0.5

        var cycle: float = maxf(0.01, float(combatant.get("cycle_mult", 1.0)))
        var gain: float = delta * (12.0 + effective_speed * 0.62) / cycle
        combatant["atb"] = minf(100.0, float(combatant.get("atb", 0.0)) + gain)

        if float(combatant["atb"]) >= 100.0 and effective_speed > best_speed:
            ready_actor = combatant
            best_speed = effective_speed

    _refresh_all_cards()

    if ready_actor.is_empty():
        return

    if str(ready_actor["side"]) == "player":
        _prompt_player(ready_actor)
    else:
        _enemy_act(ready_actor)

func _prompt_player(actor: Dictionary) -> void:
    paused_for_player = true
    selected_actor = actor
    _set_log("[b]Pikachu Lv." + str(actor["level"]) + "[/b] ist bereit. Wähle eine Attacke.")

    var moves: Dictionary = data.get("moves", {})
    for index: int in range(move_buttons.size()):
        var move_id: String = MOVE_IDS[index]
        var move: Dictionary = moves.get(move_id, {})
        move_buttons[index].text = str(move.get("name", move_id)) + "  AP " + str(int(move.get("ap_cost", 1)))
        move_buttons[index].disabled = false

func _disable_move_buttons() -> void:
    for button: Button in move_buttons:
        button.disabled = true

func _on_move_pressed(move_id: String) -> void:
    if not paused_for_player or selected_actor.is_empty():
        return

    _disable_move_buttons()
    paused_for_player = false
    var actor: Dictionary = selected_actor
    selected_actor = {}
    _execute_move(actor, move_id)

func _enemy_act(actor: Dictionary) -> void:
    var roll: float = randf()
    var move_id: String = "growl"
    if roll < 0.4:
        move_id = "nuzzle"
    elif roll < 0.75:
        move_id = "quick_attack"
    _execute_move(actor, move_id)

func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    if bool(actor.get("paralyzed", false)) and randf() < 0.25:
        actor["atb"] = 0.0
        actor["cycle_mult"] = 1.0
        _set_log(_actor_name(actor) + " ist paralysiert und kann sich nicht bewegen!")
        _refresh_all_cards()
        return

    var moves: Dictionary = data.get("moves", {})
    var move: Dictionary = moves.get(move_id, {})
    actor["atb"] = 0.0
    actor["cycle_mult"] = _cycle_multiplier_for_move(move)

    if move_id == "growl":
        var targets: Array[Dictionary] = _living_opponents(actor)
        for target: Dictionary in targets:
            target["attack_stage"] = maxi(-6, int(target.get("attack_stage", 0)) - 1)
            _pulse_combatant(target, Color("80b6ff"))
        actor["aggro"] = float(actor.get("aggro", 0.0)) + float(targets.size()) * 3.0
        _set_log(_actor_name(actor) + " setzt [b]Heuler[/b] ein. Angriff aller Gegner sinkt!")
    else:
        var target: Dictionary = _highest_aggro_target(actor)
        if target.is_empty():
            return

        var effectiveness: float = _type_effectiveness(str(move.get("type", "normal")), target)
        var damage: int = _calculate_damage(actor, target, int(move.get("power", 20)), effectiveness)
        target["hp"] = maxi(0, int(target["hp"]) - damage)

        # Aggro entsteht beim handelnden Pokémon aus der tatsächlichen Wirkung.
        actor["aggro"] = float(actor.get("aggro", 0.0)) + float(damage)

        var paralysis_applied: bool = false
        if move_id == "nuzzle" and int(target["hp"]) > 0:
            target["paralyzed"] = true
            paralysis_applied = true
            actor["aggro"] = float(actor.get("aggro", 0.0)) + 3.0

        # Nach einer aufgelösten offensiven Einzelzielaktion verliert das Ziel einen Teil seiner Aggro.
        target["aggro"] = maxf(0.0, float(target.get("aggro", 0.0)) * AGGRO_AFTER_HIT_MULTIPLIER)

        _animate_attack(actor, target, move_id)

        var feedback: String = _effectiveness_text(effectiveness)
        var status_feedback: String = " + Paralyse!" if paralysis_applied else ""
        var log_text: String = _actor_name(actor) + " nutzt [b]" + str(move.get("name", move_id)) + "[/b] → " + str(damage) + " Schaden."
        if not feedback.is_empty():
            log_text += " [b]" + feedback + "[/b]"
        log_text += status_feedback
        _set_log(log_text)

        if int(target["hp"]) <= 0:
            target["alive"] = false
            target["atb"] = 0.0

    _refresh_all_cards()
    _check_battle_end()

func _cycle_multiplier_for_move(move: Dictionary) -> float:
    var rules: Dictionary = data.get("rules", {})
    var ap_rules: Dictionary = rules.get("ap_costs_demo", {})
    var curve: Dictionary = ap_rules.get("demo_atb_cycle_multiplier", {})
    return float(curve.get(str(int(move.get("ap_cost", 1))), 1.0))

func _calculate_damage(actor: Dictionary, target: Dictionary, power: int, effectiveness: float) -> int:
    var stage: int = int(actor.get("attack_stage", 0))
    var rules: Dictionary = data.get("rules", {})
    var stage_rules: Dictionary = rules.get("stat_stages", {})
    var multipliers: Dictionary = stage_rules.get("multipliers", {})
    var stage_multiplier: float = float(multipliers.get(str(stage), 1.0))

    var attack_value: float = float(actor.get("attack", 10)) * stage_multiplier
    var defense_value: float = maxf(1.0, float(target.get("defense", 10)))
    var level_value: float = float(actor.get("level", 1))
    var raw: float = (((2.0 * level_value / 5.0 + 2.0) * float(power) * attack_value / defense_value) / 50.0) + 2.0
    var varied: float = raw * randf_range(0.88, 1.0) * effectiveness
    return maxi(1, int(round(varied)))

func _type_effectiveness(move_type: String, target: Dictionary) -> float:
    # Die Demo enthält derzeit ausschließlich Pikachu. Deshalb wird hier nur
    # die aktuell benötigte Typbeziehung abgebildet; das vollständige Typensystem
    # kann später zentral ersetzt werden.
    var primary: String = str(target.get("type_primary", ""))
    var secondary_variant: Variant = target.get("type_secondary", null)
    var multiplier: float = 1.0

    if move_type == "electric":
        if primary == "electric":
            multiplier *= 0.5
        if secondary_variant != null and str(secondary_variant) == "electric":
            multiplier *= 0.5

    return multiplier

func _effectiveness_text(effectiveness: float) -> String:
    if effectiveness <= 0.0:
        return "Keine Wirkung!"
    if effectiveness > 1.0:
        return "Sehr effektiv!"
    if effectiveness < 1.0:
        return "Nicht sehr effektiv."
    return ""

func _living_opponents(actor: Dictionary) -> Array[Dictionary]:
    var source_team: Array[Dictionary] = enemy_team if str(actor["side"]) == "player" else player_team
    var result: Array[Dictionary] = []
    for candidate: Dictionary in source_team:
        if bool(candidate.get("alive", false)):
            result.append(candidate)
    return result

func _highest_aggro_target(actor: Dictionary) -> Dictionary:
    var choices: Array[Dictionary] = _living_opponents(actor)
    if choices.is_empty():
        return {}

    var best: Dictionary = choices[0]
    for candidate: Dictionary in choices:
        var candidate_aggro: float = float(candidate.get("aggro", 0.0))
        var best_aggro: float = float(best.get("aggro", 0.0))
        if candidate_aggro > best_aggro:
            best = candidate
        elif is_equal_approx(candidate_aggro, best_aggro) and int(candidate.get("index", 0)) < int(best.get("index", 0)):
            best = candidate
    return best

func _highest_aggro_in_team(team: Array[Dictionary]) -> Dictionary:
    var best: Dictionary = {}
    for candidate: Dictionary in team:
        if not bool(candidate.get("alive", false)):
            continue
        if best.is_empty():
            best = candidate
            continue
        var candidate_aggro: float = float(candidate.get("aggro", 0.0))
        var best_aggro: float = float(best.get("aggro", 0.0))
        if candidate_aggro > best_aggro:
            best = candidate
        elif is_equal_approx(candidate_aggro, best_aggro) and int(candidate.get("index", 0)) < int(best.get("index", 0)):
            best = candidate
    return best

func _is_highest_aggro(combatant: Dictionary) -> bool:
    if not bool(combatant.get("alive", false)):
        return false
    var team: Array[Dictionary] = player_team if str(combatant.get("side", "")) == "player" else enemy_team
    var highest: Dictionary = _highest_aggro_in_team(team)
    return not highest.is_empty() and str(highest.get("id", "")) == str(combatant.get("id", ""))

func _actor_name(combatant: Dictionary) -> String:
    var prefix: String = "Wildes Pikachu" if str(combatant["side"]) == "enemy" else "Pikachu"
    return prefix + " Lv." + str(combatant["level"])

func _refresh_all_cards() -> void:
    for combatant: Dictionary in combatants:
        _refresh_card(combatant)

func _refresh_card(combatant: Dictionary) -> void:
    var id: String = str(combatant.get("id", ""))
    var ui: Dictionary = team_controls.get(id, {})
    if ui.is_empty():
        return

    var card: Control = ui.get("card") as Control
    var hp_bar: ProgressBar = ui.get("hp") as ProgressBar
    var hp_text: Label = ui.get("hp_text") as Label
    var atb_bar: ProgressBar = ui.get("atb") as ProgressBar
    var status: Label = ui.get("status") as Label

    hp_bar.value = float(combatant["hp"])
    hp_text.text = str(combatant["hp"]) + "/" + str(combatant["max_hp"]) + " KP"
    atb_bar.value = float(combatant["atb"])

    var hp_ratio: float = float(combatant["hp"]) / maxf(1.0, float(combatant["max_hp"]))
    if hp_ratio <= 0.25:
        hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("d94c4c")))
    elif hp_ratio <= 0.5:
        hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("e0bd45")))
    else:
        hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("55b85a")))

    var pieces: Array[String] = []
    var aggro_text: String = "AGGRO %.1f" % float(combatant.get("aggro", 0.0))
    if _is_highest_aggro(combatant):
        aggro_text = "ZIEL | " + aggro_text
        status.add_theme_color_override("font_color", Color("b54d22"))
    else:
        status.add_theme_color_override("font_color", Color("59605c"))
    pieces.append(aggro_text)

    if bool(combatant.get("paralyzed", false)):
        pieces.append("PAR")
    if int(combatant.get("attack_stage", 0)) != 0:
        pieces.append("ANG " + str(combatant.get("attack_stage", 0)))
    status.text = " · ".join(pieces)

    card.modulate.a = 1.0 if bool(combatant.get("alive", false)) else 0.28

func _animate_attack(actor: Dictionary, target: Dictionary, move_id: String) -> void:
    var actor_ui: Dictionary = team_controls.get(str(actor.get("id", "")), {})
    var target_ui: Dictionary = team_controls.get(str(target.get("id", "")), {})

    if not actor_ui.is_empty():
        var actor_card: Control = actor_ui.get("card") as Control
        var origin: Vector2 = actor_card.position
        var direction: float = -1.0 if str(actor["side"]) == "player" else 1.0
        var shift: Vector2 = Vector2(14.0 * direction, 0.0)
        var tween: Tween = create_tween()
        tween.tween_property(actor_card, "position", origin + shift, 0.08)
        tween.tween_property(actor_card, "position", origin, 0.12)

    if not target_ui.is_empty():
        var target_card: Control = target_ui.get("card") as Control
        var flash: Color = Color("fff36c") if move_id == "nuzzle" else Color("ffffff")
        _pulse_card(target_card, flash)
        var target_origin: Vector2 = target_card.position
        var shake: Tween = create_tween()
        shake.tween_property(target_card, "position", target_origin + Vector2(3, 0), 0.04)
        shake.tween_property(target_card, "position", target_origin - Vector2(3, 0), 0.04)
        shake.tween_property(target_card, "position", target_origin, 0.04)

func _pulse_combatant(combatant: Dictionary, color: Color) -> void:
    var ui: Dictionary = team_controls.get(str(combatant.get("id", "")), {})
    if ui.is_empty():
        return
    var card: Control = ui.get("card") as Control
    _pulse_card(card, color)

func _pulse_card(card: CanvasItem, color: Color) -> void:
    var tween: Tween = create_tween()
    tween.tween_property(card, "modulate", color, 0.06)
    tween.tween_property(card, "modulate", Color.WHITE, 0.16)

func _set_log(text: String) -> void:
    if log_label != null:
        log_label.text = text

func _check_battle_end() -> void:
    var players_alive: bool = false
    var enemies_alive: bool = false

    for combatant: Dictionary in player_team:
        if bool(combatant.get("alive", false)):
            players_alive = true
            break

    for combatant: Dictionary in enemy_team:
        if bool(combatant.get("alive", false)):
            enemies_alive = true
            break

    if players_alive and enemies_alive:
        return

    battle_active = false
    paused_for_player = false
    selected_actor = {}
    _disable_move_buttons()
    result_panel.visible = true

    if players_alive:
        result_title.text = "SIEG!"
        result_text.text = "Alle wilden Pikachus wurden besiegt. Du kannst sofort neu testen oder das Setup ändern."
    else:
        result_title.text = "NIEDERLAGE"
        result_text.text = "Dein Team ist kampfunfähig. Du kannst direkt neu testen oder zur Route zurückkehren."
