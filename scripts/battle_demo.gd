extends CanvasLayer

const DATA_PATH: String = "res://data/combat_lab_data.json"
const TEAM_MAX: int = 4
const LEVEL_MAX: int = 10

var data: Dictionary = {}
var species_ids: Array = []
var player_setup: Array = []
var enemy_setup: Array = []
var player_team: Array = []
var enemy_team: Array = []
var combatants: Array = []
var cards: Dictionary = {}
var selected_actor: Dictionary = {}
var battle_active: bool = false
var paused: bool = false

var config_panel: PanelContainer
var battle_panel: Control
var result_panel: PanelContainer
var result_title: Label
var player_count: SpinBox
var enemy_count: SpinBox
var player_rows: VBoxContainer
var enemy_rows: VBoxContainer
var action_box: HBoxContainer
var log_label: RichTextLabel


func _ready() -> void:
    layer = 50
    randomize()
    _load_data()
    _init_setup()
    _build_ui()
    open_config()


func _load_data() -> void:
    var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Kampflabor-Daten fehlen: " + DATA_PATH)
        return

    var parsed = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Kampflabor-Daten konnten nicht gelesen werden.")
        return

    data = parsed
    _inject_pichu_data()

    var order_value = data.get("species_order", [])
    if order_value is Array:
        species_ids = order_value.duplicate()


func _inject_pichu_data() -> void:
    var species_value = data.get("species", {})
    if not (species_value is Dictionary):
        return
    var species: Dictionary = species_value

    species.erase("pikachu")
    species["pichu"] = {
        "id": "pichu",
        "name": "Pichu",
        "types": ["electric"],
        "base_stats": {
            "hp": 20,
            "attack": 38,
            "defense": 28,
            "special": 33,
            "speed": 60
        },
        "learnset": [
            {"level": 1, "moves": ["tail_whip", "thunder_shock"]},
            {"level": 4, "moves": ["play_nice"]},
            {"level": 8, "moves": ["sweet_kiss"]}
        ]
    }
    data["species"] = species

    var moves_value = data.get("moves", {})
    if moves_value is Dictionary:
        var moves: Dictionary = moves_value
        moves["thunder_shock"] = {
            "id": "thunder_shock",
            "name": "Donnerschock",
            "type": "electric",
            "category": "special",
            "power": 40,
            "accuracy": 100,
            "ap": 3,
            "target": "enemy_highest_aggro",
            "area": false,
            "priority": 0,
            "opening": false,
            "mechanics": [
                {"kind": "damage"},
                {"kind": "status", "status": "paralysis", "chance": 0.10}
            ]
        }
        moves["play_nice"] = {
            "id": "play_nice",
            "name": "Kameradschaft",
            "type": "normal",
            "category": "status",
            "power": null,
            "accuracy": null,
            "ap": 5,
            "target": "enemy_highest_aggro",
            "area": false,
            "priority": 0,
            "opening": false,
            "mechanics": [
                {
                    "kind": "outgoing_damage_mod",
                    "scope": "enemy_highest_aggro",
                    "multiplier_from_special": -1.0,
                    "uses_special_percent": true,
                    "duration": "next_damage"
                }
            ]
        }
        moves["sweet_kiss"] = {
            "id": "sweet_kiss",
            "name": "Bitterkuss",
            "type": "fairy",
            "category": "status",
            "power": null,
            "accuracy": 75,
            "ap": 7,
            "target": "enemy_highest_aggro",
            "area": false,
            "priority": 0,
            "opening": false,
            "mechanics": [
                {"kind": "status", "status": "confusion", "chance": 1.0}
            ]
        }
        data["moves"] = moves

    var old_order = data.get("species_order", [])
    var new_order: Array = []
    if old_order is Array:
        for sid_value in old_order:
            var sid: String = str(sid_value)
            if sid != "pikachu":
                new_order.append(sid)
    if not new_order.has("pichu"):
        new_order.append("pichu")
    data["species_order"] = new_order


func _init_setup() -> void:
    var default_id: String = "pichu"
    if not species_ids.has(default_id) and not species_ids.is_empty():
        default_id = str(species_ids[0])
    player_setup = [{"species_id": default_id, "level": 5}]
    enemy_setup = [{"species_id": default_id, "level": 5}]


func open_config() -> void:
    battle_active = false
    paused = false
    selected_actor = {}
    visible = true
    if config_panel != null:
        config_panel.visible = true
    if battle_panel != null:
        battle_panel.visible = false
    if result_panel != null:
        result_panel.visible = false
    _refresh_setup()


func open_battle_direct() -> void:
    _start_battle()


func close_demo() -> void:
    open_config()


func _panel(bg: Color, border: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    return style


func _bar(color: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(3)
    return style


func _build_ui() -> void:
    var root: Control = Control.new()
    root.name = "CombatLabRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)

    var bg: ColorRect = ColorRect.new()
    bg.color = Color("101918")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)

    _build_config(root)
    _build_battle(root)
    _build_result(root)


func _build_config(root: Control) -> void:
    config_panel = PanelContainer.new()
    config_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    config_panel.offset_left = 14.0
    config_panel.offset_top = 14.0
    config_panel.offset_right = -14.0
    config_panel.offset_bottom = -14.0
    config_panel.add_theme_stylebox_override("panel", _panel(Color("18231f"), Color("e4c95d")))
    root.add_child(config_panel)

    var outer: VBoxContainer = VBoxContainer.new()
    outer.add_theme_constant_override("separation", 7)
    config_panel.add_child(outer)

    var title: Label = Label.new()
    title.text = "KAMPFLABOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color("ffe46c"))
    outer.add_child(title)

    var subtitle: Label = Label.new()
    subtitle.text = "Pokémon wählen · Level 1–10 · 1–4 pro Seite"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    outer.add_child(subtitle)

    var counts: HBoxContainer = HBoxContainer.new()
    counts.alignment = BoxContainer.ALIGNMENT_CENTER
    counts.add_theme_constant_override("separation", 40)
    outer.add_child(counts)

    player_count = _count_picker("Eigenes Team", true)
    enemy_count = _count_picker("Gegnerteam", false)
    counts.add_child(player_count.get_parent())
    counts.add_child(enemy_count.get_parent())

    var teams: HBoxContainer = HBoxContainer.new()
    teams.size_flags_vertical = Control.SIZE_EXPAND_FILL
    teams.add_theme_constant_override("separation", 10)
    outer.add_child(teams)

    var left: Dictionary = _team_panel("DEIN TEAM")
    player_rows = left["rows"] as VBoxContainer
    teams.add_child(left["panel"] as Control)

    var right: Dictionary = _team_panel("GEGNER")
    enemy_rows = right["rows"] as VBoxContainer
    teams.add_child(right["panel"] as Control)

    var buttons: HBoxContainer = HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 10)
    outer.add_child(buttons)

    var random_button: Button = Button.new()
    random_button.text = "ZUFALL"
    random_button.custom_minimum_size = Vector2(120, 31)
    random_button.pressed.connect(_randomize_setup)
    buttons.add_child(random_button)

    var start_button: Button = Button.new()
    start_button.text = "KAMPF STARTEN"
    start_button.custom_minimum_size = Vector2(190, 31)
    start_button.pressed.connect(_start_battle)
    buttons.add_child(start_button)


func _count_picker(text: String, own: bool) -> SpinBox:
    var box: VBoxContainer = VBoxContainer.new()
    var label: Label = Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(label)

    var spin: SpinBox = SpinBox.new()
    spin.min_value = 1.0
    spin.max_value = float(TEAM_MAX)
    spin.value = 1.0
    spin.custom_minimum_size = Vector2(120, 27)
    spin.value_changed.connect(_on_count_changed.bind(own))
    box.add_child(spin)
    return spin


func _team_panel(text: String) -> Dictionary:
    var panel: PanelContainer = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", _panel(Color("0f1917"), Color("50685e")))

    var content: VBoxContainer = VBoxContainer.new()
    panel.add_child(content)

    var label: Label = Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(label)

    var rows: VBoxContainer = VBoxContainer.new()
    rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(rows)
    return {"panel": panel, "rows": rows}


func _on_count_changed(value: float, own: bool) -> void:
    var setup: Array = player_setup if own else enemy_setup
    var default_id: String = "pichu" if species_ids.has("pichu") else str(species_ids[0])

    while setup.size() < int(value):
        setup.append({"species_id": default_id, "level": 5})
    while setup.size() > int(value):
        setup.pop_back()
    _refresh_setup()


func _refresh_setup() -> void:
    if player_rows == null or enemy_rows == null:
        return
    _fill_rows(player_rows, player_setup, true)
    _fill_rows(enemy_rows, enemy_setup, false)


func _fill_rows(box: VBoxContainer, setup: Array, own: bool) -> void:
    for child in box.get_children():
        child.queue_free()

    for index in range(setup.size()):
        var row: HBoxContainer = HBoxContainer.new()
        row.add_theme_constant_override("separation", 4)

        var slot: Label = Label.new()
        slot.text = str(index + 1) + "."
        slot.custom_minimum_size = Vector2(20, 26)
        row.add_child(slot)

        var picker: OptionButton = OptionButton.new()
        picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        for sid_value in species_ids:
            var sid: String = str(sid_value)
            picker.add_item(_species_name(sid))
            picker.set_item_metadata(picker.item_count - 1, sid)

        for item_index in range(picker.item_count):
            if str(picker.get_item_metadata(item_index)) == str(setup[index]["species_id"]):
                picker.select(item_index)
                break

        picker.item_selected.connect(_species_changed.bind(own, index, picker))
        row.add_child(picker)

        var level: SpinBox = SpinBox.new()
        level.min_value = 1.0
        level.max_value = float(LEVEL_MAX)
        level.value = float(setup[index]["level"])
        level.custom_minimum_size = Vector2(68, 26)
        level.value_changed.connect(_level_changed.bind(own, index))
        row.add_child(level)

        box.add_child(row)


func _species_changed(_item_index: int, own: bool, index: int, picker: OptionButton) -> void:
    var setup: Array = player_setup if own else enemy_setup
    if index >= setup.size():
        return
    setup[index]["species_id"] = str(picker.get_item_metadata(picker.selected))


func _level_changed(value: float, own: bool, index: int) -> void:
    var setup: Array = player_setup if own else enemy_setup
    if index >= setup.size():
        return
    setup[index]["level"] = clampi(int(value), 1, LEVEL_MAX)


func _randomize_setup() -> void:
    if species_ids.is_empty():
        return

    var player_amount: int = randi_range(1, TEAM_MAX)
    var enemy_amount: int = randi_range(1, TEAM_MAX)
    player_setup.clear()
    enemy_setup.clear()

    for _index in range(player_amount):
        player_setup.append({
            "species_id": str(species_ids.pick_random()),
            "level": randi_range(1, LEVEL_MAX)
        })

    for _index in range(enemy_amount):
        enemy_setup.append({
            "species_id": str(species_ids.pick_random()),
            "level": randi_range(1, LEVEL_MAX)
        })

    player_count.set_value_no_signal(float(player_amount))
    enemy_count.set_value_no_signal(float(enemy_amount))
    _refresh_setup()


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
    battle_area.position = Vector2(0, 30)
    battle_area.size = Vector2(480, 180)
    battle_panel.add_child(battle_area)

    var command: PanelContainer = PanelContainer.new()
    command.anchor_top = 1.0
    command.anchor_right = 1.0
    command.anchor_bottom = 1.0
    command.offset_left = 10.0
    command.offset_top = -105.0
    command.offset_right = -10.0
    command.offset_bottom = -10.0
    command.add_theme_stylebox_override("panel", _panel(Color("15201fed"), Color("f5df78")))
    battle_panel.add_child(command)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 3)
    command.add_child(content)

    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.fit_content = true
    log_label.custom_minimum_size = Vector2(430, 31)
    content.add_child(log_label)

    action_box = HBoxContainer.new()
    action_box.alignment = BoxContainer.ALIGNMENT_CENTER
    action_box.add_theme_constant_override("separation", 5)
    content.add_child(action_box)

    battle_panel.visible = false


func _build_result(root: Control) -> void:
    result_panel = PanelContainer.new()
    result_panel.position = Vector2(120, 105)
    result_panel.size = Vector2(240, 110)
    result_panel.add_theme_stylebox_override("panel", _panel(Color("18231ff5"), Color("ffe46c")))
    root.add_child(result_panel)

    result_title = Label.new()
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 25)
    result_panel.add_child(result_title)
    result_panel.visible = false


func _start_battle() -> void:
    if species_ids.is_empty():
        return

    config_panel.visible = false
    result_panel.visible = false
    battle_panel.visible = true
    battle_active = true
    paused = false
    selected_actor = {}
    player_team.clear()
    enemy_team.clear()
    combatants.clear()
    cards.clear()

    var area: Control = battle_panel.get_node("BattleArea") as Control
    for child in area.get_children():
        child.queue_free()

    for index in range(player_setup.size()):
        var player_combatant: Dictionary = _make_combatant("player", index, player_setup[index])
        player_team.append(player_combatant)
        combatants.append(player_combatant)

    for index in range(enemy_setup.size()):
        var enemy_combatant: Dictionary = _make_combatant("enemy", index, enemy_setup[index])
        enemy_team.append(enemy_combatant)
        combatants.append(enemy_combatant)

    _layout_team(area, enemy_team, true)
    _layout_team(area, player_team, false)
    _refresh_cards()
    _set_log("Der Testkampf beginnt.")
    _clear_actions()


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var sid: String = str(setup.get("species_id", "pichu"))
    var level: int = clampi(int(setup.get("level", 1)), 1, LEVEL_MAX)

    var species_all = data.get("species", {})
    var species: Dictionary = {}
    if species_all is Dictionary:
        var species_value = species_all.get(sid, {})
        if species_value is Dictionary:
            species = species_value

    var base_stats = species.get("base_stats", {})
    var hp_base: float = 35.0
    var attack_base: float = 40.0
    var defense_base: float = 40.0
    var special_base: float = 40.0
    var speed_base: float = 40.0
    if base_stats is Dictionary:
        hp_base = float(base_stats.get("hp", 35))
        attack_base = float(base_stats.get("attack", 40))
        defense_base = float(base_stats.get("defense", 40))
        special_base = float(base_stats.get("special", 40))
        speed_base = float(base_stats.get("speed", 40))

    var max_hp: int = int(floor(2.0 * hp_base * float(level) / 100.0)) + level + 10
    var types_value = species.get("types", [])
    var types: Array = types_value.duplicate() if types_value is Array else []

    return {
        "id": side + "_" + str(index),
        "side": side,
        "index": index,
        "species_id": sid,
        "name": str(species.get("name", sid)),
        "types": types,
        "level": level,
        "max_hp": max_hp,
        "hp": max_hp,
        "attack": int(floor(2.0 * attack_base * float(level) / 100.0)) + 5,
        "defense": int(floor(2.0 * defense_base * float(level) / 100.0)) + 5,
        "special": int(floor(2.0 * special_base * float(level) / 100.0)) + 5,
        "speed": int(floor(2.0 * speed_base * float(level) / 100.0)) + 5,
        "moves": _moves_for_level(species, level),
        "atb": 0.0,
        "cycle": 1.0,
        "aggro": 10.0 + float(level) * 2.0,
        "alive": true,
        "paralyzed": false,
        "confused_turns": 0,
        "attack_mult": 1.0,
        "defense_mult": 1.0,
        "accuracy_mult": 1.0,
        "next_cycle": 1.0
    }


func _moves_for_level(species: Dictionary, level: int) -> Array:
    var result: Array = []
    var learnset_value = species.get("learnset", [])
    if not (learnset_value is Array):
        return result

    for entry_value in learnset_value:
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        if int(entry.get("level", 1)) > level:
            continue
        var moves_value = entry.get("moves", [])
        if not (moves_value is Array):
            continue
        for move_value in moves_value:
            var move_id: String = str(move_value)
            if not result.has(move_id):
                result.append(move_id)
    return result


func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    var positions: Array = _positions_for_count(team.size())
    for index in range(team.size()):
        var combatant: Dictionary = team[index]
        var card: Control = _make_card(combatant, enemy)
        card.position = Vector2(16.0 if enemy else 294.0, float(positions[index]))
        area.add_child(card)


func _positions_for_count(count: int) -> Array:
    match count:
        1:
            return [58.0]
        2:
            return [28.0, 96.0]
        3:
            return [5.0, 58.0, 111.0]
        _:
            return [-2.0, 40.0, 82.0, 124.0]


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: PanelContainer = PanelContainer.new()
    card.size = Vector2(170, 46)
    card.custom_minimum_size = Vector2(170, 46)
    card.add_theme_stylebox_override("panel", _panel(Color("f8f1dce8"), Color("34443d")))

    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    card.add_child(row)

    var texture_box: TextureRect = TextureRect.new()
    texture_box.custom_minimum_size = Vector2(42, 42)
    texture_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_box.flip_h = not enemy
    texture_box.texture = _species_texture(str(combatant.get("name", "")))
    row.add_child(texture_box)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 0)
    row.add_child(content)

    var name_label: Label = Label.new()
    name_label.text = str(combatant.get("name", "Pokémon")) + " Lv." + str(combatant.get("level", 1))
    name_label.add_theme_font_size_override("font_size", 10)
    name_label.add_theme_color_override("font_color", Color("26322e"))
    content.add_child(name_label)

    var hp_bar: ProgressBar = ProgressBar.new()
    hp_bar.max_value = float(combatant.get("max_hp", 1))
    hp_bar.value = float(combatant.get("hp", 0))
    hp_bar.show_percentage = false
    hp_bar.custom_minimum_size = Vector2(110, 8)
    hp_bar.add_theme_stylebox_override("background", _bar(Color("c8c8c2")))
    hp_bar.add_theme_stylebox_override("fill", _bar(Color("55b85a")))
    content.add_child(hp_bar)

    var atb_bar: ProgressBar = ProgressBar.new()
    atb_bar.max_value = 100.0
    atb_bar.value = 0.0
    atb_bar.show_percentage = false
    atb_bar.custom_minimum_size = Vector2(110, 6)
    atb_bar.add_theme_stylebox_override("background", _bar(Color("b5b5aa")))
    atb_bar.add_theme_stylebox_override("fill", _bar(Color("42aef5")))
    content.add_child(atb_bar)

    var status: Label = Label.new()
    status.add_theme_font_size_override("font_size", 8)
    status.add_theme_color_override("font_color", Color("59605c"))
    content.add_child(status)

    cards[str(combatant.get("id", ""))] = {
        "card": card,
        "hp": hp_bar,
        "atb": atb_bar,
        "status": status
    }
    return card


func _species_texture(display_name: String) -> Texture2D:
    for folder_value in ["res://assets/", "res://assets/monsters/"]:
        var folder: String = str(folder_value)
        for extension_value in ["png", "webp", "jpg", "jpeg", "svg"]:
            var extension: String = str(extension_value)
            var path: String = folder + display_name + "." + extension
            if ResourceLoader.exists(path):
                var texture: Texture2D = load(path) as Texture2D
                if texture != null:
                    return texture
    return null


func _process(delta: float) -> void:
    if not battle_active or paused:
        return

    var ready_actor: Dictionary = {}
    var best_speed: float = -1.0

    for combatant_value in combatants:
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)):
            continue

        var effective_speed: float = float(combatant.get("speed", 10))
        if bool(combatant.get("paralyzed", false)):
            effective_speed *= 0.5

        var cycle: float = maxf(0.01, float(combatant.get("cycle", 1.0)))
        var gain: float = delta * (12.0 + effective_speed * 0.62) / cycle
        combatant["atb"] = minf(100.0, float(combatant.get("atb", 0.0)) + gain)

        if float(combatant.get("atb", 0.0)) >= 100.0 and effective_speed > best_speed:
            ready_actor = combatant
            best_speed = effective_speed

    _refresh_cards()
    if ready_actor.is_empty():
        return

    if str(ready_actor.get("side", "")) == "player":
        _prompt_player(ready_actor)
    else:
        _enemy_act(ready_actor)


func _prompt_player(actor: Dictionary) -> void:
    paused = true
    selected_actor = actor
    _clear_actions()
    _set_log("[b]" + _actor_name(actor) + "[/b] ist bereit.")

    var moves_all = data.get("moves", {})
    var actor_moves = actor.get("moves", [])
    if actor_moves is Array and moves_all is Dictionary:
        for move_value in actor_moves:
            var move_id: String = str(move_value)
            var move_value_data = moves_all.get(move_id, {})
            var move: Dictionary = move_value_data if move_value_data is Dictionary else {}
            var button: Button = Button.new()
            button.text = str(move.get("name", move_id)) + " · AP " + str(move.get("ap", 1))
            button.pressed.connect(_choose_move.bind(move_id))
            action_box.add_child(button)

    var wait_button: Button = Button.new()
    wait_button.text = "Warten"
    wait_button.pressed.connect(_choose_wait)
    action_box.add_child(wait_button)


func _clear_actions() -> void:
    if action_box == null:
        return
    for child in action_box.get_children():
        child.queue_free()


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    var actor: Dictionary = selected_actor
    selected_actor = {}
    paused = false
    _clear_actions()
    _execute_move(actor, move_id)


func _choose_wait() -> void:
    if selected_actor.is_empty():
        return
    var actor: Dictionary = selected_actor
    selected_actor = {}
    paused = false
    _clear_actions()
    actor["aggro"] = float(actor.get("aggro", 0.0)) * 0.55
    actor["atb"] = 0.0
    actor["cycle"] = 0.70
    _set_log(_actor_name(actor) + " wartet.")


func _enemy_act(actor: Dictionary) -> void:
    var moves_value = actor.get("moves", [])
    if not (moves_value is Array) or moves_value.is_empty():
        actor["atb"] = 0.0
        return
    _execute_move(actor, str(moves_value.pick_random()))


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    var confused_turns: int = int(actor.get("confused_turns", 0))
    if confused_turns > 0:
        actor["confused_turns"] = confused_turns - 1
        if randf() < 0.33:
            actor["atb"] = 0.0
            actor["cycle"] = 1.0
            var confusion_damage: int = _damage(actor, actor, 40, "typeless", "physical")
            actor["hp"] = maxi(0, int(actor.get("hp", 0)) - confusion_damage)
            if int(actor.get("hp", 0)) <= 0:
                actor["alive"] = false
            _set_log(_actor_name(actor) + " ist verwirrt und verletzt sich selbst → " + str(confusion_damage) + " Schaden.")
            _refresh_cards()
            _check_end()
            return

    if bool(actor.get("paralyzed", false)) and randf() < 0.25:
        actor["atb"] = 0.0
        actor["cycle"] = 1.0
        _set_log(_actor_name(actor) + " ist paralysiert und kann nicht handeln.")
        _refresh_cards()
        return

    var moves_all = data.get("moves", {})
    if not (moves_all is Dictionary):
        return
    var move_value = moves_all.get(move_id, {})
    if not (move_value is Dictionary):
        return
    var move: Dictionary = move_value

    actor["atb"] = 0.0
    actor["cycle"] = _ap_cycle(int(move.get("ap", 1))) * float(actor.get("next_cycle", 1.0))
    actor["next_cycle"] = 1.0

    var accuracy = move.get("accuracy", null)
    if accuracy != null:
        var hit_chance: float = float(accuracy) * float(actor.get("accuracy_mult", 1.0)) / 100.0
        if randf() > hit_chance:
            actor["accuracy_mult"] = 1.0
            actor["cycle"] = float(actor.get("cycle", 1.0)) * 0.85
            _set_log(_actor_name(actor) + " verfehlt mit " + str(move.get("name", move_id)) + ".")
            _refresh_cards()
            return
    actor["accuracy_mult"] = 1.0

    var targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    var total_effect: float = 0.0
    var total_damage: int = 0

    for target_value in targets:
        var target: Dictionary = target_value
        var damaged: bool = false
        var mechanics_value = move.get("mechanics", [])
        if not (mechanics_value is Array):
            continue

        for mechanic_value in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            var mechanic: Dictionary = mechanic_value
            var kind: String = str(mechanic.get("kind", ""))

            if kind == "damage":
                var damage: int = _damage(
                    actor,
                    target,
                    int(move.get("power", 0)),
                    str(move.get("type", "normal")),
                    str(move.get("category", "physical"))
                )
                target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
                total_damage += damage
                damaged = true
                if int(target.get("hp", 0)) <= 0:
                    target["alive"] = false
            else:
                total_effect += _effect(actor, target, mechanic)

        if damaged:
            target["aggro"] = float(target.get("aggro", 0.0)) * 0.5

    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(total_damage) + total_effect
    var log_text: String = _actor_name(actor) + " nutzt [b]" + str(move.get("name", move_id)) + "[/b]"
    if total_damage > 0:
        log_text += " → " + str(total_damage) + " Schaden."
    else:
        log_text += "."
    _set_log(log_text)
    _refresh_cards()
    _check_end()


func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == "self":
        return [actor]
    if rule == "all_enemies":
        return _living_opponents(actor)
    var target: Dictionary = _highest_aggro(actor)
    if target.is_empty():
        return []
    return [target]


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    var special_percent: float = float(actor.get("special", 0)) / 100.0
    var multiplier: float = float(mechanic.get("multiplier_from_special", 1.0))

    if kind == "status":
        if randf() <= float(mechanic.get("chance", 1.0)):
            var status_name: String = str(mechanic.get("status", ""))
            if status_name == "paralysis":
                target["paralyzed"] = true
            elif status_name == "confusion":
                target["confused_turns"] = randi_range(1, 4)
            return 3.0

    elif kind == "outgoing_damage_mod":
        target["attack_mult"] = clampf(1.0 + special_percent * multiplier, 0.25, 2.5)
        return absf(special_percent * multiplier) * 10.0

    elif kind == "incoming_damage_mod":
        target["defense_mult"] = clampf(1.0 - special_percent * multiplier, 0.25, 2.5)
        return absf(special_percent * multiplier) * 10.0

    elif kind == "accuracy_mod":
        target["accuracy_mult"] = clampf(1.0 + special_percent * multiplier, 0.2, 1.0)
        return absf(special_percent * multiplier) * 8.0

    elif kind == "atb_cycle_mod":
        target["next_cycle"] = clampf(1.0 + special_percent * multiplier, 0.45, 2.5)
        return absf(special_percent * multiplier) * 8.0

    elif kind == "atb_knockback":
        if randf() <= float(mechanic.get("chance", 1.0)):
            var amount: float = float(mechanic.get("amount", 0.25)) * 100.0
            target["atb"] = maxf(0.0, float(target.get("atb", 0.0)) - amount)
            return 3.0

    return 0.0


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    if power <= 0:
        return 0

    var offensive_stat: float = float(actor.get("attack", 10))
    if category == "special":
        offensive_stat = float(actor.get("special", 10))

    var raw: float = (
        ((2.0 * float(actor.get("level", 1)) / 5.0 + 2.0)
        * float(power)
        * offensive_stat
        * float(actor.get("attack_mult", 1.0))
        / maxf(1.0, float(target.get("defense", 10))))
        / 50.0
    ) + 2.0

    raw /= maxf(0.25, float(target.get("defense_mult", 1.0)))
    actor["attack_mult"] = 1.0
    target["defense_mult"] = 1.0

    var effectiveness: float = _type_effect(move_type, target.get("types", []))
    return maxi(1, int(round(raw * randf_range(0.88, 1.0) * effectiveness)))


func _type_effect(move_type: String, target_types_value) -> float:
    var chart: Dictionary = {
        "fire": {"grass": 2.0, "bug": 2.0, "fire": 0.5, "water": 0.5},
        "water": {"fire": 2.0, "water": 0.5, "grass": 0.5},
        "electric": {"water": 2.0, "flying": 2.0, "electric": 0.5, "grass": 0.5},
        "grass": {"water": 2.0, "fire": 0.5, "grass": 0.5, "poison": 0.5, "flying": 0.5, "bug": 0.5},
        "bug": {"grass": 2.0, "fire": 0.5, "poison": 0.5, "flying": 0.5},
        "poison": {"grass": 2.0, "poison": 0.5},
        "ground": {"electric": 2.0, "poison": 2.0, "grass": 0.5, "bug": 0.5, "flying": 0.0},
        "flying": {"grass": 2.0, "bug": 2.0, "electric": 0.5},
        "dark": {},
        "fairy": {}
    }

    var result: float = 1.0
    var row_value = chart.get(move_type, {})
    if not (row_value is Dictionary) or not (target_types_value is Array):
        return result
    var row: Dictionary = row_value

    for type_value in target_types_value:
        result *= float(row.get(str(type_value), 1.0))
    return result


func _ap_cycle(ap: int) -> float:
    var rules_value = data.get("rules", {})
    if not (rules_value is Dictionary):
        return 1.0
    var cycle_value = rules_value.get("ap_cycle_multiplier", {})
    if not (cycle_value is Dictionary):
        return 1.0
    return float(cycle_value.get(str(ap), 1.0))


func _living_opponents(actor: Dictionary) -> Array:
    var source: Array = enemy_team if str(actor.get("side", "")) == "player" else player_team
    var result: Array = []
    for candidate_value in source:
        var candidate: Dictionary = candidate_value
        if bool(candidate.get("alive", false)):
            result.append(candidate)
    return result


func _highest_aggro(actor: Dictionary) -> Dictionary:
    var choices: Array = _living_opponents(actor)
    if choices.is_empty():
        return {}

    var best: Dictionary = choices[0]
    for candidate_value in choices:
        var candidate: Dictionary = candidate_value
        var candidate_aggro: float = float(candidate.get("aggro", 0.0))
        var best_aggro: float = float(best.get("aggro", 0.0))
        if candidate_aggro > best_aggro:
            best = candidate
        elif is_equal_approx(candidate_aggro, best_aggro) and int(candidate.get("index", 0)) < int(best.get("index", 0)):
            best = candidate
    return best


func _refresh_cards() -> void:
    for combatant_value in combatants:
        var combatant: Dictionary = combatant_value
        var ui_value = cards.get(str(combatant.get("id", "")), {})
        if not (ui_value is Dictionary) or ui_value.is_empty():
            continue
        var ui: Dictionary = ui_value

        var hp_bar: ProgressBar = ui["hp"] as ProgressBar
        var atb_bar: ProgressBar = ui["atb"] as ProgressBar
        var status_label: Label = ui["status"] as Label
        var card: Control = ui["card"] as Control

        hp_bar.value = float(combatant.get("hp", 0))
        atb_bar.value = float(combatant.get("atb", 0.0))

        var status_text: String = "Aggro %.1f" % float(combatant.get("aggro", 0.0))
        if bool(combatant.get("paralyzed", false)):
            status_text += " · PAR"
        var confused_turns: int = int(combatant.get("confused_turns", 0))
        if confused_turns > 0:
            status_text += " · VERW " + str(confused_turns)
        status_label.text = status_text
        card.modulate.a = 1.0 if bool(combatant.get("alive", false)) else 0.25


func _check_end() -> void:
    var own_alive: bool = false
    var enemy_alive: bool = false

    for combatant_value in player_team:
        var combatant: Dictionary = combatant_value
        if bool(combatant.get("alive", false)):
            own_alive = true
            break

    for combatant_value in enemy_team:
        var combatant: Dictionary = combatant_value
        if bool(combatant.get("alive", false)):
            enemy_alive = true
            break

    if own_alive and enemy_alive:
        return

    battle_active = false
    paused = false
    selected_actor = {}
    _clear_actions()
    result_title.text = "SIEG!" if own_alive else "NIEDERLAGE"
    result_panel.visible = true

    await get_tree().create_timer(1.25).timeout
    open_config()


func _species_name(sid: String) -> String:
    var species_value = data.get("species", {})
    if species_value is Dictionary:
        var entry_value = species_value.get(sid, {})
        if entry_value is Dictionary:
            return str(entry_value.get("name", sid))
    return sid


func _actor_name(combatant: Dictionary) -> String:
    return str(combatant.get("name", "Pokémon")) + " Lv." + str(combatant.get("level", 1))


func _set_log(text: String) -> void:
    if log_label != null:
        log_label.text = text
