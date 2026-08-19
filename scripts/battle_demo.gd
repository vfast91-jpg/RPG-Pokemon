extends CanvasLayer

const DATA_PATH := "res://data/PIKACHU_DEMO_ALL_IN_ONE.json"
const PIKACHU_TEXTURE := preload("res://assets/Pikachu.png")

var data: Dictionary = {}
var player_levels: Array[int] = [15]
var enemy_levels: Array[int] = [15]
var battle_active := false
var paused_for_player := false
var selected_actor: Dictionary = {}
var player_team: Array = []
var enemy_team: Array = []
var combatants: Array = []
var config_panel: PanelContainer
var battle_panel: Control
var result_panel: PanelContainer
var team_controls: Dictionary = {}
var move_buttons: Array[Button] = []
var log_label: RichTextLabel
var config_rows: VBoxContainer
var result_title: Label
var result_text: Label
var player_count_spin: SpinBox
var enemy_count_spin: SpinBox

func _ready() -> void:
    layer = 50
    _load_data()
    _build_ui()
    visible = false
    set_process(true)

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
    visible = false

func _load_data() -> void:
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Pikachu-Demodaten fehlen: " + DATA_PATH)
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        data = parsed
    else:
        push_error("Pikachu-Demodaten konnten nicht gelesen werden.")

func _build_ui() -> void:
    var root := Control.new()
    root.name = "BattleDemoRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.size = Vector2(480, 320)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)

    var shade := ColorRect.new()
    shade.color = Color(0.035, 0.055, 0.06, 0.97)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shade)

    _build_config(root)
    _build_battle(root)
    _build_result(root)

func _make_panel(bg: Color, border: Color, radius := 8) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 6
    style.content_margin_bottom = 6
    return style

func _build_config(root: Control) -> void:
    config_panel = PanelContainer.new()
    config_panel.position = Vector2(30, 18)
    config_panel.size = Vector2(420, 284)
    config_panel.add_theme_stylebox_override("panel", _make_panel(Color("18231f"), Color("e4c95d"), 10))
    root.add_child(config_panel)

    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 5)
    config_panel.add_child(v)

    var title := Label.new()
    title.text = "PIKACHU-KAMPFLABOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color("ffe46c"))
    v.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Lege Teams und Level fest. Danach sprichst du das Pikachu im Gras an."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size", 11)
    v.add_child(subtitle)

    var counts := HBoxContainer.new()
    counts.alignment = BoxContainer.ALIGNMENT_CENTER
    counts.add_theme_constant_override("separation", 18)
    v.add_child(counts)

    var own_box := VBoxContainer.new()
    var own_label := Label.new()
    own_label.text = "Eigene Pikachus"
    own_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    own_box.add_child(own_label)
    player_count_spin = SpinBox.new()
    player_count_spin.min_value = 1
    player_count_spin.max_value = 4
    player_count_spin.value = 1
    player_count_spin.custom_minimum_size = Vector2(100, 26)
    player_count_spin.value_changed.connect(func(value): _resize_levels(player_levels, int(value)); _refresh_config_rows())
    own_box.add_child(player_count_spin)
    counts.add_child(own_box)

    var wild_box := VBoxContainer.new()
    var wild_label := Label.new()
    wild_label.text = "Wilde Pikachus"
    wild_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wild_box.add_child(wild_label)
    enemy_count_spin = SpinBox.new()
    enemy_count_spin.min_value = 1
    enemy_count_spin.max_value = 4
    enemy_count_spin.value = 1
    enemy_count_spin.custom_minimum_size = Vector2(100, 26)
    enemy_count_spin.value_changed.connect(func(value): _resize_levels(enemy_levels, int(value)); _refresh_config_rows())
    wild_box.add_child(enemy_count_spin)
    counts.add_child(wild_box)

    config_rows = VBoxContainer.new()
    config_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(config_rows)

    var presets := HBoxContainer.new()
    presets.alignment = BoxContainer.ALIGNMENT_CENTER
    presets.add_theme_constant_override("separation", 6)
    v.add_child(presets)
    var equal_btn := Button.new()
    equal_btn.text = "4v4 · Lv.15"
    equal_btn.pressed.connect(func(): _apply_preset([15,15,15,15], [15,15,15,15]))
    presets.add_child(equal_btn)
    var mixed_btn := Button.new()
    mixed_btn.text = "4v4 · 5/15/30/50"
    mixed_btn.pressed.connect(func(): _apply_preset([5,15,30,50], [5,15,30,50]))
    presets.add_child(mixed_btn)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 8)
    v.add_child(actions)
    var test_btn := Button.new()
    test_btn.text = "KAMPF JETZT TESTEN"
    test_btn.custom_minimum_size = Vector2(190, 30)
    test_btn.pressed.connect(_start_battle)
    actions.add_child(test_btn)
    var close_btn := Button.new()
    close_btn.text = "Zurück"
    close_btn.pressed.connect(close_demo)
    actions.add_child(close_btn)

func _refresh_config_rows() -> void:
    if config_rows == null:
        return
    for child in config_rows.get_children():
        child.queue_free()
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 28)
    var a := Label.new(); a.text = "EIGENES TEAM"; a.custom_minimum_size = Vector2(170, 20); a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var b := Label.new(); b.text = "WILDES TEAM"; b.custom_minimum_size = Vector2(170, 20); b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(a); header.add_child(b); config_rows.add_child(header)
    for i in range(max(player_levels.size(), enemy_levels.size())):
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 28)
        row.add_child(_make_level_editor(player_levels, i, true))
        row.add_child(_make_level_editor(enemy_levels, i, false))
        config_rows.add_child(row)

func _make_level_editor(levels: Array[int], index: int, is_player: bool) -> Control:
    var holder := HBoxContainer.new()
    holder.custom_minimum_size = Vector2(170, 27)
    if index >= levels.size():
        var blank := Control.new(); blank.custom_minimum_size = Vector2(170, 27); return blank
    var label := Label.new()
    label.text = ("P" if is_player else "W") + str(index + 1) + "  Level"
    label.custom_minimum_size = Vector2(78, 25)
    holder.add_child(label)
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = 100
    spin.value = levels[index]
    spin.custom_minimum_size = Vector2(82, 25)
    spin.value_changed.connect(func(value): levels[index] = int(value))
    holder.add_child(spin)
    return holder

func _resize_levels(levels: Array[int], count: int) -> void:
    while levels.size() < count:
        levels.append(15)
    while levels.size() > count:
        levels.pop_back()

func _apply_preset(players: Array, enemies: Array) -> void:
    player_levels.clear(); enemy_levels.clear()
    for x in players: player_levels.append(int(x))
    for x in enemies: enemy_levels.append(int(x))
    player_count_spin.value = player_levels.size()
    enemy_count_spin.value = enemy_levels.size()
    _refresh_config_rows()

func _build_battle(root: Control) -> void:
    battle_panel = Control.new()
    battle_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_panel.size = Vector2(480, 320)
    root.add_child(battle_panel)

    var sky := ColorRect.new(); sky.color = Color("8fc8c0"); sky.position = Vector2(0,0); sky.size = Vector2(480,190); battle_panel.add_child(sky)
    var ground := ColorRect.new(); ground.color = Color("b8d47a"); ground.position = Vector2(0,190); ground.size = Vector2(480,130); battle_panel.add_child(ground)
    var stripe := ColorRect.new(); stripe.color = Color("769a58"); stripe.position = Vector2(0,185); stripe.size = Vector2(480,8); battle_panel.add_child(stripe)

    var header_panel := PanelContainer.new(); header_panel.position = Vector2(12,8); header_panel.size = Vector2(456,34); header_panel.add_theme_stylebox_override("panel", _make_panel(Color("172624e8"), Color("fff1a2"), 7)); battle_panel.add_child(header_panel)
    var header := Label.new(); header.text = "PIKACHU · DEMOKAMPF     ATB-KAMPFLABOR"; header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; header.add_theme_color_override("font_color", Color("fff1a2")); header_panel.add_child(header)

    var battle_area := Control.new(); battle_area.name = "BattleArea"; battle_area.position = Vector2(0,42); battle_area.size = Vector2(480,184); battle_panel.add_child(battle_area)

    var command := PanelContainer.new(); command.position = Vector2(10,226); command.size = Vector2(460,84); command.add_theme_stylebox_override("panel", _make_panel(Color("15201fed"), Color("f5df78"), 7)); battle_panel.add_child(command)
    var command_v := VBoxContainer.new(); command_v.add_theme_constant_override("separation", 3); command.add_child(command_v)
    log_label = RichTextLabel.new(); log_label.bbcode_enabled = true; log_label.fit_content = true; log_label.scroll_active = false; log_label.custom_minimum_size = Vector2(430,27); log_label.add_theme_font_size_override("normal_font_size", 11); command_v.add_child(log_label)
    var buttons := HBoxContainer.new(); buttons.alignment = BoxContainer.ALIGNMENT_CENTER; buttons.add_theme_constant_override("separation", 6); command_v.add_child(buttons)
    for move_id in ["nuzzle", "quick_attack", "growl"]:
        var btn := Button.new(); btn.custom_minimum_size = Vector2(132,30); btn.disabled = true; btn.pressed.connect(func(): _player_choose_move(move_id)); buttons.add_child(btn); move_buttons.append(btn)
    var exit_btn := Button.new(); exit_btn.text = "Abbruch"; exit_btn.custom_minimum_size = Vector2(72,30); exit_btn.pressed.connect(close_demo); buttons.add_child(exit_btn)
    battle_panel.visible = false

func _build_result(root: Control) -> void:
    result_panel = PanelContainer.new()
    result_panel.position = Vector2(90,80)
    result_panel.size = Vector2(300,160)
    result_panel.add_theme_stylebox_override("panel", _make_panel(Color("18231ff5"), Color("ffe46c"), 12))
    root.add_child(result_panel)
    var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 10); result_panel.add_child(v)
    result_title = Label.new(); result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result_title.add_theme_font_size_override("font_size", 26); result_title.add_theme_color_override("font_color", Color("ffe46c")); v.add_child(result_title)
    result_text = Label.new(); result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(result_text)
    var buttons := HBoxContainer.new(); buttons.alignment = BoxContainer.ALIGNMENT_CENTER; buttons.add_theme_constant_override("separation", 8); v.add_child(buttons)
    var retry := Button.new(); retry.text = "Nochmal"; retry.pressed.connect(_start_battle); buttons.add_child(retry)
    var config := Button.new(); config.text = "Setup ändern"; config.pressed.connect(open_config); buttons.add_child(config)
    var leave := Button.new(); leave.text = "Zurück zur Route"; leave.pressed.connect(close_demo); buttons.add_child(leave)
    result_panel.visible = false

func _start_battle() -> void:
    visible = true
    config_panel.visible = false
    result_panel.visible = false
    battle_panel.visible = true
    battle_active = true
    paused_for_player = false
    player_team.clear(); enemy_team.clear(); combatants.clear(); team_controls.clear()
    var area := battle_panel.get_node("BattleArea") as Control
    for child in area.get_children(): child.queue_free()
    for i in range(player_levels.size()):
        var c := _make_combatant("player", i, player_levels[i]); player_team.append(c); combatants.append(c)
    for i in range(enemy_levels.size()):
        var c := _make_combatant("enemy", i, enemy_levels[i]); enemy_team.append(c); combatants.append(c)
    _layout_team(area, player_team, false)
    _layout_team(area, enemy_team, true)
    _set_log("Der Pikachu-Testkampf beginnt! ATB-Leisten füllen sich automatisch.")
    _disable_move_buttons()

func _make_combatant(side: String, index: int, level: int) -> Dictionary:
    var base: Dictionary = data.get("species", {}).get("pikachu", {}).get("base_stats", {"hp":35,"attack":53,"defense":47,"special":55,"speed":90})
    var max_hp := int(floor((2.0 * float(base.get("hp",35)) * level) / 100.0)) + level + 10
    return {
        "id": side + "_" + str(index), "side": side, "index": index, "level": level,
        "max_hp": max_hp, "hp": max_hp,
        "attack": int(floor((2.0 * float(base.get("attack",53)) * level) / 100.0)) + 5,
        "defense": int(floor((2.0 * float(base.get("defense",47)) * level) / 100.0)) + 5,
        "speed": int(floor((2.0 * float(base.get("speed",90)) * level) / 100.0)) + 5,
        "attack_stage": 0, "paralyzed": false, "atb": randf_range(0.0, 26.0), "cycle_mult": 1.0, "alive": true,
        "aggro": randf_range(0.0, 2.0)
    }

func _layout_team(area: Control, team: Array, enemy: bool) -> void:
    var ys := _positions_for_count(team.size())
    for i in range(team.size()):
        var c: Dictionary = team[i]
        var card := _create_combatant_card(c, enemy)
        var x := 292.0 if enemy else 18.0
        card.position = Vector2(x, ys[i])
        area.add_child(card)
        team_controls[c["id"]] = card

func _positions_for_count(count: int) -> Array:
    match count:
        1: return [54.0]
        2: return [20.0, 91.0]
        3: return [4.0, 59.0, 114.0]
        _: return [-3.0, 40.0, 83.0, 126.0]

func _create_combatant_card(c: Dictionary, enemy: bool) -> Control:
    var card := PanelContainer.new(); card.custom_minimum_size = Vector2(170,48); card.size = Vector2(170,48); card.add_theme_stylebox_override("panel", _make_panel(Color("f8f1dce8"), Color("34443d"), 5))
    var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 4); card.add_child(h)
    var sprite := TextureRect.new(); sprite.texture = PIKACHU_TEXTURE; sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; sprite.custom_minimum_size = Vector2(42,42); sprite.flip_h = enemy; h.add_child(sprite)
    var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); h.add_child(v)
    var name := Label.new(); name.name = "Name"; name.text = ("Wildes " if enemy else "") + "Pikachu  Lv." + str(c["level"]); name.add_theme_color_override("font_color", Color("26322e")); name.add_theme_font_size_override("font_size", 10); v.add_child(name)
    var hp := ProgressBar.new(); hp.name = "HP"; hp.max_value = c["max_hp"]; hp.value = c["hp"]; hp.show_percentage = false; hp.custom_minimum_size = Vector2(112,9); v.add_child(hp)
    var hptext := Label.new(); hptext.name = "HPText"; hptext.text = str(c["hp"]) + "/" + str(c["max_hp"]) + " KP"; hptext.add_theme_color_override("font_color", Color("34443d")); hptext.add_theme_font_size_override("font_size", 8); v.add_child(hptext)
    var atb := ProgressBar.new(); atb.name = "ATB"; atb.max_value = 100; atb.value = c["atb"]; atb.show_percentage = false; atb.custom_minimum_size = Vector2(112,6); v.add_child(atb)
    var status := Label.new(); status.name = "Status"; status.text = ""; status.add_theme_color_override("font_color", Color("7a4d00")); status.add_theme_font_size_override("font_size", 8); v.add_child(status)
    return card

func _process(delta: float) -> void:
    if not battle_active or paused_for_player:
        return
    for c in combatants:
        if not c.get("alive", false): continue
        var speed := float(c.get("speed", 10)) * (0.5 if c.get("paralyzed", false) else 1.0)
        c["atb"] = min(100.0, float(c["atb"]) + delta * (12.0 + speed * 0.62) / float(c.get("cycle_mult",1.0)))
        _refresh_card(c)
    var ready := combatants.filter(func(x): return x.get("alive",false) and float(x.get("atb",0.0)) >= 100.0)
    if ready.is_empty(): return
    ready.sort_custom(func(a,b): return float(a.get("speed",0)) > float(b.get("speed",0)))
    var actor: Dictionary = ready[0]
    if actor["side"] == "player":
        _prompt_player(actor)
    else:
        _enemy_act(actor)

func _prompt_player(actor: Dictionary) -> void:
    paused_for_player = true
    selected_actor = actor
    _set_log("[b]Pikachu Lv." + str(actor["level"]) + "[/b] ist bereit. Wähle eine Attacke.")
    var ids := ["nuzzle", "quick_attack", "growl"]
    for i in range(move_buttons.size()):
        var move: Dictionary = data.get("moves", {}).get(ids[i], {})
        move_buttons[i].text = str(move.get("name", ids[i])) + "  AP " + str(move.get("ap_cost",1))
        move_buttons[i].disabled = false

func _disable_move_buttons() -> void:
    for btn in move_buttons:
        btn.disabled = true

func _player_choose_move(move_id: String) -> void:
    if not paused_for_player or selected_actor.is_empty(): return
    _disable_move_buttons()
    paused_for_player = false
    _execute_move(selected_actor, move_id)
    selected_actor = {}

func _enemy_act(actor: Dictionary) -> void:
    var roll := randf()
    var move_id := "nuzzle" if roll < 0.4 else ("quick_attack" if roll < 0.75 else "growl")
    _execute_move(actor, move_id)

func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not actor.get("alive", false): return
    if actor.get("paralyzed", false) and randf() < 0.25:
        actor["atb"] = 0.0; actor["cycle_mult"] = 1.0
        _set_log("Pikachu Lv." + str(actor["level"]) + " ist paralysiert und kann sich nicht bewegen!")
        _refresh_card(actor)
        return
    var move: Dictionary = data.get("moves", {}).get(move_id, {})
    actor["atb"] = 0.0
    actor["cycle_mult"] = float(data.get("rules", {}).get("ap_costs_demo", {}).get("demo_atb_cycle_multiplier", {}).get(str(move.get("ap_cost",1)), 1.0))
    if move_id == "growl":
        var targets := _living_opponents(actor)
        for target in targets:
            target["attack_stage"] = max(-6, int(target.get("attack_stage",0)) - 1)
            target["aggro"] = float(target.get("aggro",0.0)) + 3.0
            _refresh_card(target)
            _pulse_card(target, Color("80b6ff"))
        _set_log(_actor_name(actor) + " setzt [b]Heuler[/b] ein. Angriff aller Gegner sinkt!")
    else:
        var target := _highest_aggro_target(actor)
        if target.is_empty(): return
        var damage := _calculate_damage(actor, target, int(move.get("power",20)))
        target["hp"] = max(0, int(target["hp"]) - damage)
        target["aggro"] = float(target.get("aggro",0.0)) + damage
        if move_id == "nuzzle" and int(target["hp"]) > 0:
            target["paralyzed"] = true
        _animate_attack(actor, target, move_id)
        _set_log(_actor_name(actor) + " nutzt [b]" + str(move.get("name", move_id)) + "[/b] → " + str(damage) + " Schaden" + (" + Paralyse!" if move_id == "nuzzle" and int(target["hp"]) > 0 else "."))
        if int(target["hp"]) <= 0:
            target["alive"] = false
            target["atb"] = 0.0
    _refresh_card(actor)
    for c in combatants: _refresh_card(c)
    _check_battle_end()

func _calculate_damage(actor: Dictionary, target: Dictionary, power: int) -> int:
    var stage := int(actor.get("attack_stage",0))
    var mult := float(data.get("rules", {}).get("stat_stages", {}).get("multipliers", {}).get(str(stage), 1.0))
    var attack := float(actor.get("attack",10)) * mult
    var defense := max(1.0, float(target.get("defense",10)))
    var level := float(actor.get("level",1))
    var raw := (((2.0 * level / 5.0 + 2.0) * float(power) * attack / defense) / 50.0) + 2.0
    return max(1, int(round(raw * randf_range(0.88, 1.0))))

func _living_opponents(actor: Dictionary) -> Array:
    var team := enemy_team if actor["side"] == "player" else player_team
    return team.filter(func(x): return x.get("alive",false))

func _highest_aggro_target(actor: Dictionary) -> Dictionary:
    var choices := _living_opponents(actor)
    if choices.is_empty(): return {}
    choices.sort_custom(func(a,b): return float(a.get("aggro",0.0)) > float(b.get("aggro",0.0)))
    return choices[0]

func _actor_name(c: Dictionary) -> String:
    return ("Wildes Pikachu" if c["side"] == "enemy" else "Pikachu") + " Lv." + str(c["level"])

func _refresh_card(c: Dictionary) -> void:
    var card = team_controls.get(c.get("id",""))
    if card == null: return
    var hp := card.get_node("HBoxContainer/VBoxContainer/HP") as ProgressBar
    var hptext := card.get_node("HBoxContainer/VBoxContainer/HPText") as Label
    var atb := card.get_node("HBoxContainer/VBoxContainer/ATB") as ProgressBar
    var status := card.get_node("HBoxContainer/VBoxContainer/Status") as Label
    hp.value = c["hp"]; hptext.text = str(c["hp"]) + "/" + str(c["max_hp"]) + " KP"; atb.value = c["atb"]
    status.text = ("PAR  " if c.get("paralyzed",false) else "") + (("ANG " + str(c.get("attack_stage",0))) if int(c.get("attack_stage",0)) != 0 else "")
    card.modulate.a = 1.0 if c.get("alive",false) else 0.28

func _animate_attack(actor: Dictionary, target: Dictionary, move_id: String) -> void:
    var a = team_controls.get(actor.get("id","")); var t = team_controls.get(target.get("id",""))
    if a != null:
        var origin: Vector2 = a.position
        var shift := Vector2(14 if actor["side"] == "player" else -14, 0)
        var tw := create_tween(); tw.tween_property(a, "position", origin + shift, 0.08); tw.tween_property(a, "position", origin, 0.12)
    if t != null:
        _pulse_card(t, Color("fff36c") if move_id == "nuzzle" else Color("ffffff"))
        var origin_t: Vector2 = t.position
        var tw2 := create_tween(); tw2.tween_property(t, "position", origin_t + Vector2(3,0), 0.04); tw2.tween_property(t, "position", origin_t - Vector2(3,0), 0.04); tw2.tween_property(t, "position", origin_t, 0.04)

func _pulse_card(card: CanvasItem, color: Color) -> void:
    var tw := create_tween(); tw.tween_property(card, "modulate", color, 0.06); tw.tween_property(card, "modulate", Color.WHITE, 0.16)

func _set_log(text: String) -> void:
    if log_label != null: log_label.text = text

func _check_battle_end() -> void:
    var players_alive := player_team.any(func(x): return x.get("alive",false))
    var enemies_alive := enemy_team.any(func(x): return x.get("alive",false))
    if players_alive and enemies_alive: return
    battle_active = false; paused_for_player = false; _disable_move_buttons()
    result_panel.visible = true
    if players_alive:
        result_title.text = "SIEG!"
        result_text.text = "Alle wilden Pikachus wurden besiegt. Du kannst den Kampf sofort wiederholen oder das Setup ändern."
    else:
        result_title.text = "NIEDERLAGE"
        result_text.text = "Dein Team ist kampfunfähig. Kein Absturz: Du kannst direkt neu testen oder zur Route zurückkehren."
