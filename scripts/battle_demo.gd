extends CanvasLayer

const DATA_PATH := "res://data/combat_lab_data.json"
const TEAM_MAX := 4
const LEVEL_MAX := 10

var data: Dictionary = {}
var species_ids: Array = []
var player_setup: Array = []
var enemy_setup: Array = []
var player_team: Array = []
var enemy_team: Array = []
var combatants: Array = []
var cards: Dictionary = {}
var selected_actor: Dictionary = {}
var battle_active := false
var paused := false

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
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Kampflabor-Daten fehlen: " + DATA_PATH)
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        data = parsed
        species_ids = data.get("species_order", [])

func _init_setup() -> void:
    var default_id := "pikachu" if species_ids.has("pikachu") else str(species_ids[0])
    player_setup = [{"species_id": default_id, "level": 5}]
    enemy_setup = [{"species_id": default_id, "level": 5}]

func open_config() -> void:
    battle_active = false
    paused = false
    selected_actor = {}
    visible = true
    config_panel.visible = true
    battle_panel.visible = false
    result_panel.visible = false
    _refresh_setup()

func open_battle_direct() -> void:
    _start_battle()

func close_demo() -> void:
    open_config()

func _panel(bg: Color, border: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(8)
    s.content_margin_left = 8
    s.content_margin_right = 8
    s.content_margin_top = 7
    s.content_margin_bottom = 7
    return s

func _bar(color: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.set_corner_radius_all(3)
    return s

func _build_ui() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var bg := ColorRect.new()
    bg.color = Color("101918")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)
    _build_config(root)
    _build_battle(root)
    _build_result(root)

func _build_config(root: Control) -> void:
    config_panel = PanelContainer.new()
    config_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    config_panel.offset_left = 14
    config_panel.offset_top = 14
    config_panel.offset_right = -14
    config_panel.offset_bottom = -14
    config_panel.add_theme_stylebox_override("panel", _panel(Color("18231f"), Color("e4c95d")))
    root.add_child(config_panel)
    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 7)
    config_panel.add_child(outer)
    var title := Label.new()
    title.text = "KAMPFLABOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color("ffe46c"))
    outer.add_child(title)
    var sub := Label.new()
    sub.text = "Pokémon wählen · Level 1–10 · 1–4 pro Seite"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    outer.add_child(sub)

    var counts := HBoxContainer.new()
    counts.alignment = BoxContainer.ALIGNMENT_CENTER
    counts.add_theme_constant_override("separation", 40)
    outer.add_child(counts)
    player_count = _count_picker("Eigenes Team", true)
    enemy_count = _count_picker("Gegnerteam", false)
    counts.add_child(player_count.get_parent())
    counts.add_child(enemy_count.get_parent())

    var teams := HBoxContainer.new()
    teams.size_flags_vertical = Control.SIZE_EXPAND_FILL
    teams.add_theme_constant_override("separation", 10)
    outer.add_child(teams)
    var left := _team_panel("DEIN TEAM")
    player_rows = left["rows"]
    teams.add_child(left["panel"])
    var right := _team_panel("GEGNER")
    enemy_rows = right["rows"]
    teams.add_child(right["panel"])

    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 10)
    outer.add_child(buttons)
    var random_btn := Button.new()
    random_btn.text = "ZUFALL"
    random_btn.custom_minimum_size = Vector2(120, 31)
    random_btn.pressed.connect(_randomize_setup)
    buttons.add_child(random_btn)
    var start := Button.new()
    start.text = "KAMPF STARTEN"
    start.custom_minimum_size = Vector2(190, 31)
    start.pressed.connect(_start_battle)
    buttons.add_child(start)

func _count_picker(text: String, own: bool) -> SpinBox:
    var box := VBoxContainer.new()
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(label)
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = TEAM_MAX
    spin.value = 1
    spin.custom_minimum_size = Vector2(120, 27)
    spin.value_changed.connect(_on_count_changed.bind(own))
    box.add_child(spin)
    return spin

func _team_panel(text: String) -> Dictionary:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", _panel(Color("0f1917"), Color("50685e")))
    var v := VBoxContainer.new()
    panel.add_child(v)
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(label)
    var rows := VBoxContainer.new()
    rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(rows)
    return {"panel": panel, "rows": rows}

func _on_count_changed(value: float, own: bool) -> void:
    var setup: Array = player_setup if own else enemy_setup
    var default_id := "pikachu" if species_ids.has("pikachu") else str(species_ids[0])
    while setup.size() < int(value):
        setup.append({"species_id": default_id, "level": 5})
    while setup.size() > int(value):
        setup.pop_back()
    _refresh_setup()

func _refresh_setup() -> void:
    if player_rows == null:
        return
    _fill_rows(player_rows, player_setup, true)
    _fill_rows(enemy_rows, enemy_setup, false)

func _fill_rows(box: VBoxContainer, setup: Array, own: bool) -> void:
    for child in box.get_children():
        child.queue_free()
    for i in range(setup.size()):
        var row := HBoxContainer.new()
        var slot := Label.new()
        slot.text = str(i + 1) + "."
        slot.custom_minimum_size = Vector2(20, 26)
        row.add_child(slot)
        var pick := OptionButton.new()
        pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        for sid in species_ids:
            pick.add_item(_species_name(str(sid)))
            pick.set_item_metadata(pick.item_count - 1, sid)
        for n in range(pick.item_count):
            if str(pick.get_item_metadata(n)) == str(setup[i]["species_id"]):
                pick.select(n)
                break
        pick.item_selected.connect(_species_changed.bind(own, i, pick))
        row.add_child(pick)
        var level := SpinBox.new()
        level.min_value = 1
        level.max_value = LEVEL_MAX
        level.value = int(setup[i]["level"])
        level.custom_minimum_size = Vector2(68, 26)
        level.value_changed.connect(_level_changed.bind(own, i))
        row.add_child(level)
        box.add_child(row)

func _species_changed(_n: int, own: bool, index: int, pick: OptionButton) -> void:
    var setup: Array = player_setup if own else enemy_setup
    setup[index]["species_id"] = str(pick.get_item_metadata(pick.selected))

func _level_changed(value: float, own: bool, index: int) -> void:
    var setup: Array = player_setup if own else enemy_setup
    setup[index]["level"] = clampi(int(value), 1, LEVEL_MAX)

func _randomize_setup() -> void:
    var pc := randi_range(1, TEAM_MAX)
    var ec := randi_range(1, TEAM_MAX)
    player_setup.clear()
    enemy_setup.clear()
    for _i in range(pc):
        player_setup.append({"species_id": str(species_ids.pick_random()), "level": randi_range(1, LEVEL_MAX)})
    for _i in range(ec):
        enemy_setup.append({"species_id": str(species_ids.pick_random()), "level": randi_range(1, LEVEL_MAX)})
    player_count.value = pc
    enemy_count.value = ec
    _refresh_setup()

func _build_battle(root: Control) -> void:
    battle_panel = Control.new()
    battle_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(battle_panel)
    var sky := ColorRect.new()
    sky.color = Color("8fc8c0")
    sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_panel.add_child(sky)
    var area := Control.new()
    area.name = "BattleArea"
    area.position = Vector2(0, 30)
    area.size = Vector2(480, 180)
    battle_panel.add_child(area)
    var command := PanelContainer.new()
    command.anchor_top = 1
    command.anchor_right = 1
    command.anchor_bottom = 1
    command.offset_left = 10
    command.offset_top = -105
    command.offset_right = -10
    command.offset_bottom = -10
    command.add_theme_stylebox_override("panel", _panel(Color("15201fed"), Color("f5df78")))
    battle_panel.add_child(command)
    var v := VBoxContainer.new()
    command.add_child(v)
    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.fit_content = true
    log_label.custom_minimum_size = Vector2(430, 31)
    v.add_child(log_label)
    action_box = HBoxContainer.new()
    action_box.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_child(action_box)
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
    var area := battle_panel.get_node("BattleArea") as Control
    for child in area.get_children():
        child.queue_free()
    for i in range(player_setup.size()):
        var c := _make_combatant("player", i, player_setup[i])
        player_team.append(c)
        combatants.append(c)
    for i in range(enemy_setup.size()):
        var c := _make_combatant("enemy", i, enemy_setup[i])
        enemy_team.append(c)
        combatants.append(c)
    _layout_team(area, enemy_team, true)
    _layout_team(area, player_team, false)
    _refresh_cards()
    _set_log("Der Testkampf beginnt.")
    _clear_actions()

func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var sid := str(setup["species_id"])
    var level := clampi(int(setup["level"]), 1, LEVEL_MAX)
    var species: Dictionary = data.get("species", {}).get(sid, {})
    var base: Dictionary = species.get("base_stats", {})
    var max_hp := int(floor(2.0 * float(base.get("hp", 35)) * level / 100.0)) + level + 10
    return {
        "id": side + "_" + str(index), "side": side, "index": index, "species_id": sid,
        "name": str(species.get("name", sid)), "types": species.get("types", []), "level": level,
        "max_hp": max_hp, "hp": max_hp,
        "attack": int(floor(2.0 * float(base.get("attack", 40)) * level / 100.0)) + 5,
        "defense": int(floor(2.0 * float(base.get("defense", 40)) * level / 100.0)) + 5,
        "special": int(floor(2.0 * float(base.get("special", 40)) * level / 100.0)) + 5,
        "speed": int(floor(2.0 * float(base.get("speed", 40)) * level / 100.0)) + 5,
        "moves": _moves_for_level(species, level), "atb": 0.0, "cycle": 1.0,
        "aggro": 10.0 + level * 2.0, "alive": true, "paralyzed": false,
        "attack_mult": 1.0, "defense_mult": 1.0, "accuracy_mult": 1.0, "next_cycle": 1.0
    }

func _moves_for_level(species: Dictionary, level: int) -> Array:
    var result: Array = []
    for entry in species.get("learnset", []):
        if int(entry.get("level", 1)) <= level:
            for move_id in entry.get("moves", []):
                if not result.has(move_id):
                    result.append(move_id)
    return result

func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    var ys := _ys(team.size())
    for i in range(team.size()):
        var card := _make_card(team[i], enemy)
        card.position = Vector2(16 if enemy else 294, ys[i])
        area.add_child(card)

func _ys(count: int) -> Array:
    if count == 1: return [58]
    if count == 2: return [28, 96]
    if count == 3: return [5, 58, 111]
    return [-2, 40, 82, 124]

func _make_card(c: Dictionary, enemy: bool) -> Control:
    var card := PanelContainer.new()
    card.size = Vector2(170, 46)
    card.custom_minimum_size = card.size
    card.add_theme_stylebox_override("panel", _panel(Color("f8f1dce8"), Color("34443d")))
    var h := HBoxContainer.new()
    card.add_child(h)
    var tex_box := TextureRect.new()
    tex_box.custom_minimum_size = Vector2(42, 42)
    tex_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tex_box.flip_h = not enemy
    tex_box.texture = _species_texture(str(c["name"]))
    h.add_child(tex_box)
    var v := VBoxContainer.new()
    h.add_child(v)
    var name := Label.new()
    name.text = str(c["name"]) + " Lv." + str(c["level"])
    name.add_theme_font_size_override("font_size", 10)
    v.add_child(name)
    var hp := ProgressBar.new()
    hp.max_value = c["max_hp"]
    hp.value = c["hp"]
    hp.show_percentage = false
    hp.custom_minimum_size = Vector2(110, 8)
    hp.add_theme_stylebox_override("background", _bar(Color("c8c8c2")))
    hp.add_theme_stylebox_override("fill", _bar(Color("55b85a")))
    v.add_child(hp)
    var atb := ProgressBar.new()
    atb.max_value = 100
    atb.show_percentage = false
    atb.custom_minimum_size = Vector2(110, 6)
    atb.add_theme_stylebox_override("background", _bar(Color("b5b5aa")))
    atb.add_theme_stylebox_override("fill", _bar(Color("42aef5")))
    v.add_child(atb)
    var status := Label.new()
    status.add_theme_font_size_override("font_size", 8)
    v.add_child(status)
    cards[str(c["id"])] = {"card": card, "hp": hp, "atb": atb, "status": status}
    return card

func _species_texture(display_name: String):
    for folder in ["res://assets/", "res://assets/monsters/"]:
        for ext in ["png", "webp", "jpg", "jpeg", "svg"]:
            var path := folder + display_name + "." + ext
            if ResourceLoader.exists(path):
                return load(path)
    return null

func _process(delta: float) -> void:
    if not battle_active or paused:
        return
    var ready: Dictionary = {}
    var best_speed := -1.0
    for c in combatants:
        if not bool(c["alive"]): continue
        var speed := float(c["speed"]) * (0.5 if bool(c["paralyzed"]) else 1.0)
        c["atb"] = minf(100.0, float(c["atb"]) + delta * (12.0 + speed * 0.62) / float(c["cycle"]))
        if float(c["atb"]) >= 100.0 and speed > best_speed:
            ready = c
            best_speed = speed
    _refresh_cards()
    if ready.is_empty(): return
    if str(ready["side"]) == "player": _prompt_player(ready)
    else: _enemy_act(ready)

func _prompt_player(actor: Dictionary) -> void:
    paused = true
    selected_actor = actor
    _clear_actions()
    _set_log("[b]" + _actor_name(actor) + "[/b] ist bereit.")
    for move_id in actor["moves"]:
        var move: Dictionary = data.get("moves", {}).get(str(move_id), {})
        var b := Button.new()
        b.text = str(move.get("name", move_id)) + " · AP " + str(move.get("ap", 1))
        b.pressed.connect(_choose_move.bind(str(move_id)))
        action_box.add_child(b)
    var wait := Button.new()
    wait.text = "Warten"
    wait.pressed.connect(_choose_wait)
    action_box.add_child(wait)

func _clear_actions() -> void:
    if action_box == null: return
    for child in action_box.get_children(): child.queue_free()

func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty(): return
    var actor := selected_actor
    selected_actor = {}
    paused = false
    _clear_actions()
    _execute_move(actor, move_id)

func _choose_wait() -> void:
    if selected_actor.is_empty(): return
    var actor := selected_actor
    selected_actor = {}
    paused = false
    _clear_actions()
    actor["aggro"] = float(actor["aggro"]) * 0.55
    actor["atb"] = 0.0
    actor["cycle"] = 0.70
    _set_log(_actor_name(actor) + " wartet.")

func _enemy_act(actor: Dictionary) -> void:
    var moves: Array = actor["moves"]
    if moves.is_empty():
        actor["atb"] = 0.0
        return
    _execute_move(actor, str(moves.pick_random()))

func _execute_move(actor: Dictionary, move_id: String) -> void:
    if bool(actor["paralyzed"]) and randf() < 0.25:
        actor["atb"] = 0.0
        actor["cycle"] = 1.0
        _set_log(_actor_name(actor) + " ist paralysiert und kann nicht handeln.")
        return
    var move: Dictionary = data.get("moves", {}).get(move_id, {})
    actor["atb"] = 0.0
    actor["cycle"] = _ap_cycle(int(move.get("ap", 1))) * float(actor.get("next_cycle", 1.0))
    actor["next_cycle"] = 1.0
    var accuracy = move.get("accuracy", null)
    if accuracy != null and randf() > float(accuracy) * float(actor["accuracy_mult"]) / 100.0:
        actor["accuracy_mult"] = 1.0
        actor["cycle"] *= 0.85
        _set_log(_actor_name(actor) + " verfehlt mit " + str(move.get("name", move_id)) + ".")
        return
    actor["accuracy_mult"] = 1.0
    var targets := _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    var total_effect := 0.0
    var total_damage := 0
    for target in targets:
        var damaged := false
        for mechanic in move.get("mechanics", []):
            var kind := str(mechanic.get("kind", ""))
            if kind == "damage":
                var damage := _damage(actor, target, int(move.get("power", 0)), str(move.get("type", "normal")))
                target["hp"] = maxi(0, int(target["hp"]) - damage)
                total_damage += damage
                damaged = true
                if int(target["hp"]) <= 0: target["alive"] = false
            else:
                total_effect += _effect(actor, target, mechanic)
        if damaged:
            target["aggro"] = float(target["aggro"]) * 0.5
    actor["aggro"] = float(actor["aggro"]) + total_damage + total_effect
    _set_log(_actor_name(actor) + " nutzt [b]" + str(move.get("name", move_id)) + "[/b]" + (" → " + str(total_damage) + " Schaden." if total_damage > 0 else "."))
    _refresh_cards()
    _check_end()

func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == "self": return [actor]
    if rule == "all_enemies": return _living_opponents(actor)
    var target := _highest_aggro(actor)
    return [] if target.is_empty() else [target]

func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind := str(mechanic.get("kind", ""))
    var pct := float(actor["special"]) / 100.0
    var m := float(mechanic.get("multiplier_from_special", 1.0))
    if kind == "status":
        if randf() <= float(mechanic.get("chance", 1.0)):
            if str(mechanic.get("status", "")) == "paralysis": target["paralyzed"] = true
            return 3.0
    elif kind == "outgoing_damage_mod":
        target["attack_mult"] = clampf(1.0 + pct * m, 0.25, 2.5)
        return absf(pct * m) * 10.0
    elif kind == "incoming_damage_mod":
        target["defense_mult"] = clampf(1.0 - pct * m, 0.25, 2.5)
        return absf(pct * m) * 10.0
    elif kind == "accuracy_mod":
        target["accuracy_mult"] = clampf(1.0 + pct * m, 0.2, 1.0)
        return absf(pct * m) * 8.0
    elif kind == "atb_cycle_mod":
        target["next_cycle"] = clampf(1.0 + pct * m, 0.45, 2.5)
        return absf(pct * m) * 8.0
    elif kind == "atb_knockback" and randf() <= float(mechanic.get("chance", 1.0)):
        target["atb"] = maxf(0.0, float(target["atb"]) - 25.0)
        return 3.0
    return 0.0

func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String) -> int:
    if power <= 0: return 0
    var raw := (((2.0 * float(actor["level"]) / 5.0 + 2.0) * power * float(actor["attack"]) * float(actor["attack_mult"]) / maxf(1.0, float(target["defense"]))) / 50.0) + 2.0
    raw /= maxf(0.25, float(target["defense_mult"]))
    actor["attack_mult"] = 1.0
    target["defense_mult"] = 1.0
    return maxi(1, int(round(raw * randf_range(0.88, 1.0) * _type_effect(move_type, target["types"]))))

func _type_effect(move_type: String, target_types: Array) -> float:
    var chart := {
        "fire":{"grass":2.0,"bug":2.0,"fire":0.5,"water":0.5},
        "water":{"fire":2.0,"water":0.5,"grass":0.5},
        "electric":{"water":2.0,"flying":2.0,"electric":0.5,"grass":0.5},
        "grass":{"water":2.0,"fire":0.5,"grass":0.5,"poison":0.5,"flying":0.5,"bug":0.5},
        "bug":{"grass":2.0,"fire":0.5,"poison":0.5,"flying":0.5},
        "poison":{"grass":2.0,"poison":0.5},
        "ground":{"electric":2.0,"poison":2.0,"grass":0.5,"bug":0.5,"flying":0.0},
        "flying":{"grass":2.0,"bug":2.0,"electric":0.5},
        "dark":{}
    }
    var result := 1.0
    var row: Dictionary = chart.get(move_type, {})
    for t in target_types: result *= float(row.get(str(t), 1.0))
    return result

func _ap_cycle(ap: int) -> float:
    return float(data.get("rules", {}).get("ap_cycle_multiplier", {}).get(str(ap), 1.0))

func _living_opponents(actor: Dictionary) -> Array:
    var source: Array = enemy_team if str(actor["side"]) == "player" else player_team
    var result: Array = []
    for c in source:
        if bool(c["alive"]): result.append(c)
    return result

func _highest_aggro(actor: Dictionary) -> Dictionary:
    var choices := _living_opponents(actor)
    if choices.is_empty(): return {}
    var best: Dictionary = choices[0]
    for c in choices:
        if float(c["aggro"]) > float(best["aggro"]) or (is_equal_approx(float(c["aggro"]), float(best["aggro"])) and int(c["index"]) < int(best["index"])):
            best = c
    return best

func _refresh_cards() -> void:
    for c in combatants:
        var ui: Dictionary = cards.get(str(c["id"]), {})
        if ui.is_empty(): continue
        ui["hp"].value = float(c["hp"])
        ui["atb"].value = float(c["atb"])
        var status := "Aggro %.1f" % float(c["aggro"])
        if bool(c["paralyzed"]): status += " · PAR"
        ui["status"].text = status
        ui["card"].modulate.a = 1.0 if bool(c["alive"]) else 0.25

func _check_end() -> void:
    var own_alive := false
    var enemy_alive := false
    for c in player_team:
        if bool(c["alive"]): own_alive = true
    for c in enemy_team:
        if bool(c["alive"]): enemy_alive = true
    if own_alive and enemy_alive: return
    battle_active = false
    paused = false
    _clear_actions()
    result_title.text = "SIEG!" if own_alive else "NIEDERLAGE"
    result_panel.visible = true
    await get_tree().create_timer(1.25).timeout
    open_config()

func _species_name(sid: String) -> String:
    return str(data.get("species", {}).get(sid, {}).get("name", sid))

func _actor_name(c: Dictionary) -> String:
    return str(c["name"]) + " Lv." + str(c["level"])

func _set_log(text: String) -> void:
    if log_label != null: log_label.text = text
