extends CanvasLayer

const DATA_PATH := "res://data/battle_lab_v2.json"
const MAX_TEAM := 4
const LEVEL_MIN := 1
const LEVEL_MAX := 10

var data: Dictionary = {}
var species_ids: Array[String] = []
var player_setup: Array[Dictionary] = []
var enemy_setup: Array[Dictionary] = []
var battle_active := false
var paused_for_player := false
var selected_actor: Dictionary = {}
var opening_queue: Array[Dictionary] = []
var opening_player_index := 0
var opening_choices: Array[Dictionary] = []
var opening_enemy_choices: Array[Dictionary] = []
var player_team: Array[Dictionary] = []
var enemy_team: Array[Dictionary] = []
var combatants: Array[Dictionary] = []
var combatant_by_id: Dictionary = {}
var team_controls: Dictionary = {}
var root: Control
var config_panel: PanelContainer
var battle_panel: Control
var result_panel: PanelContainer
var config_rows: VBoxContainer
var player_count_spin: SpinBox
var enemy_count_spin: SpinBox
var action_buttons: GridContainer
var log_label: RichTextLabel
var result_title: Label
var result_text: Label
var opening_hint: Label

func _ready() -> void:
    layer = 10
    randomize()
    _load_data()
    _init_setup()
    _build_ui()
    open_config()

func _load_data() -> void:
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Kampflabor-Daten fehlen: %s" % DATA_PATH)
        return
    var parsed := JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Kampflabor-Daten sind ungültig.")
        return
    data = parsed
    species_ids.clear()
    var species: Dictionary = data.get("species", {})
    for species_id in species.keys():
        species_ids.append(str(species_id))
    species_ids.sort_custom(_sort_species_by_name)

func _sort_species_by_name(a: String, b: String) -> bool:
    return _species_name(a).naturalnocasecmp_to(_species_name(b)) < 0

func _init_setup() -> void:
    player_setup = [{"species_id": _default_species(), "level": 5}]
    enemy_setup = [{"species_id": _default_species(), "level": 5}]

func _default_species() -> String:
    return species_ids[0] if not species_ids.is_empty() else ""

func open_config() -> void:
    battle_active = false
    paused_for_player = false
    selected_actor = {}
    opening_queue.clear()
    opening_choices.clear()
    opening_enemy_choices.clear()
    config_panel.visible = true
    battle_panel.visible = false
    result_panel.visible = false
    _refresh_config_rows()

func _build_ui() -> void:
    root = Control.new()
    root.name = "BattleLabRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var background := ColorRect.new()
    background.color = Color("101718")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(background)
    _build_config(root)
    _build_battle(root)
    _build_result(root)

func _make_panel(bg: Color, border: Color, radius := 8) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    return style

func _make_bar_style(color: Color, radius := 3) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    return style

func _build_config(parent: Control) -> void:
    config_panel = PanelContainer.new()
    config_panel.position = Vector2(18, 12)
    config_panel.size = Vector2(444, 296)
    config_panel.add_theme_stylebox_override("panel", _make_panel(Color("182321"), Color("e6cb68"), 10))
    parent.add_child(config_panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 5)
    config_panel.add_child(v)
    var title := Label.new()
    title.text = "POKÉMON · KAMPFLABOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color("ffe888"))
    v.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "Teams wählen · Level 1–10 · bis zu 4 gegen 4"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 11)
    v.add_child(subtitle)
    var counts := HBoxContainer.new()
    counts.alignment = BoxContainer.ALIGNMENT_CENTER
    counts.add_theme_constant_override("separation", 54)
    v.add_child(counts)
    player_count_spin = _make_count_editor("DEIN TEAM", true)
    counts.add_child(player_count_spin.get_parent())
    enemy_count_spin = _make_count_editor("GEGNER", false)
    counts.add_child(enemy_count_spin.get_parent())
    config_rows = VBoxContainer.new()
    config_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
    config_rows.add_theme_constant_override("separation", 2)
    v.add_child(config_rows)
    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 8)
    v.add_child(actions)
    var random_btn := Button.new()
    random_btn.text = "ZUFALL"
    random_btn.custom_minimum_size = Vector2(118, 30)
    random_btn.pressed.connect(_randomize_setup)
    actions.add_child(random_btn)
    var start_btn := Button.new()
    start_btn.text = "KAMPF STARTEN"
    start_btn.custom_minimum_size = Vector2(190, 30)
    start_btn.pressed.connect(_start_battle)
    actions.add_child(start_btn)

func _make_count_editor(label_text: String, is_player: bool) -> SpinBox:
    var box := VBoxContainer.new()
    var label := Label.new()
    label.text = label_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 10)
    box.add_child(label)
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = MAX_TEAM
    spin.step = 1
    spin.value = 1
    spin.custom_minimum_size = Vector2(92, 25)
    if is_player:
        spin.value_changed.connect(_on_player_count_changed)
    else:
        spin.value_changed.connect(_on_enemy_count_changed)
    box.add_child(spin)
    return spin

func _on_player_count_changed(value: float) -> void:
    _resize_setup(player_setup, int(value))
    _refresh_config_rows()

func _on_enemy_count_changed(value: float) -> void:
    _resize_setup(enemy_setup, int(value))
    _refresh_config_rows()

func _resize_setup(setup: Array[Dictionary], count: int) -> void:
    while setup.size() < count:
        setup.append({"species_id": _default_species(), "level": 5})
    while setup.size() > count:
        setup.pop_back()

func _refresh_config_rows() -> void:
    if config_rows == null:
        return
    for child in config_rows.get_children():
        child.queue_free()
    var header := HBoxContainer.new()
    header.alignment = BoxContainer.ALIGNMENT_CENTER
    header.add_theme_constant_override("separation", 12)
    for text in ["DEIN TEAM", "GEGNERTEAM"]:
        var h := Label.new()
        h.text = text
        h.custom_minimum_size = Vector2(202, 18)
        h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        h.add_theme_color_override("font_color", Color("d9e4dc"))
        header.add_child(h)
    config_rows.add_child(header)
    var rows := maxi(player_setup.size(), enemy_setup.size())
    for index in range(rows):
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 12)
        row.add_child(_make_slot_editor(index, true))
        row.add_child(_make_slot_editor(index, false))
        config_rows.add_child(row)

func _make_slot_editor(index: int, is_player: bool) -> Control:
    var holder := HBoxContainer.new()
    holder.custom_minimum_size = Vector2(202, 35)
    var setup := player_setup if is_player else enemy_setup
    if index >= setup.size():
        return holder
    var slot: Dictionary = setup[index]
    var number := Label.new()
    number.text = str(index + 1) + "."
    number.custom_minimum_size = Vector2(17, 26)
    holder.add_child(number)
    var selector := OptionButton.new()
    selector.custom_minimum_size = Vector2(112, 27)
    var selected_index := 0
    for i in range(species_ids.size()):
        var species_id := species_ids[i]
        selector.add_item(_species_name(species_id))
        selector.set_item_metadata(i, species_id)
        if species_id == str(slot.get("species_id", "")):
            selected_index = i
    selector.select(selected_index)
    selector.item_selected.connect(_on_species_changed.bind(is_player, index, selector))
    holder.add_child(selector)
    var level := SpinBox.new()
    level.min_value = LEVEL_MIN
    level.max_value = LEVEL_MAX
    level.step = 1
    level.value = int(slot.get("level", 5))
    level.prefix = "Lv. "
    level.custom_minimum_size = Vector2(68, 27)
    level.value_changed.connect(_on_level_changed.bind(is_player, index))
    holder.add_child(level)
    return holder

func _on_species_changed(item_index: int, is_player: bool, index: int, selector: OptionButton) -> void:
    var species_id := str(selector.get_item_metadata(item_index))
    var setup := player_setup if is_player else enemy_setup
    if index < setup.size():
        setup[index]["species_id"] = species_id

func _on_level_changed(value: float, is_player: bool, index: int) -> void:
    var setup := player_setup if is_player else enemy_setup
    if index < setup.size():
        setup[index]["level"] = int(value)

func _randomize_setup() -> void:
    var p_count := randi_range(1, MAX_TEAM)
    var e_count := randi_range(1, MAX_TEAM)
    player_setup.clear()
    enemy_setup.clear()
    for i in range(p_count):
        player_setup.append(_random_slot())
    for i in range(e_count):
        enemy_setup.append(_random_slot())
    player_count_spin.value = p_count
    enemy_count_spin.value = e_count
    _refresh_config_rows()

func _random_slot() -> Dictionary:
    return {"species_id": species_ids[randi_range(0, species_ids.size() - 1)], "level": randi_range(LEVEL_MIN, LEVEL_MAX)}

func _build_battle(parent: Control) -> void:
    battle_panel = Control.new()
    battle_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(battle_panel)
    var sky := ColorRect.new()
    sky.color = Color("9bcfcb")
    sky.position = Vector2.ZERO
    sky.size = Vector2(480, 205)
    battle_panel.add_child(sky)
    var ground := ColorRect.new()
    ground.color = Color("b8d47a")
    ground.position = Vector2(0, 205)
    ground.size = Vector2(480, 115)
    battle_panel.add_child(ground)
    var header_panel := PanelContainer.new()
    header_panel.position = Vector2(10, 7)
    header_panel.size = Vector2(460, 32)
    header_panel.add_theme_stylebox_override("panel", _make_panel(Color("172624e8"), Color("fff1a2"), 7))
    battle_panel.add_child(header_panel)
    var header := Label.new()
    header.text = "KAMPFLABOR · ATB / AGGRO"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color", Color("fff1a2"))
    header_panel.add_child(header)
    var area := Control.new()
    area.name = "BattleArea"
    area.position = Vector2(0, 41)
    area.size = Vector2(480, 174)
    battle_panel.add_child(area)
    var command := PanelContainer.new()
    command.position = Vector2(8, 216)
    command.size = Vector2(464, 96)
    command.add_theme_stylebox_override("panel", _make_panel(Color("15201ff3"), Color("f5df78"), 7))
    battle_panel.add_child(command)
    var command_v := VBoxContainer.new()
    command_v.add_theme_constant_override("separation", 3)
    command.add_child(command_v)
    opening_hint = Label.new()
    opening_hint.text = ""
    opening_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opening_hint.add_theme_font_size_override("font_size", 9)
    opening_hint.add_theme_color_override("font_color", Color("ffdd73"))
    command_v.add_child(opening_hint)
    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.fit_content = true
    log_label.scroll_active = false
    log_label.custom_minimum_size = Vector2(438, 27)
    log_label.add_theme_font_size_override("normal_font_size", 10)
    command_v.add_child(log_label)
    action_buttons = GridContainer.new()
    action_buttons.columns = 3
    action_buttons.add_theme_constant_override("h_separation", 4)
    action_buttons.add_theme_constant_override("v_separation", 2)
    command_v.add_child(action_buttons)
    battle_panel.visible = false

func _build_result(parent: Control) -> void:
    result_panel = PanelContainer.new()
    result_panel.position = Vector2(82, 78)
    result_panel.size = Vector2(316, 164)
    result_panel.add_theme_stylebox_override("panel", _make_panel(Color("18231ff8"), Color("ffe46c"), 12))
    parent.add_child(result_panel)
    var v := VBoxContainer.new()
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
    var back := Button.new()
    back.text = "ZURÜCK ZUM SETUP"
    back.custom_minimum_size = Vector2(190, 32)
    back.pressed.connect(open_config)
    v.add_child(back)
    result_panel.visible = false

func _start_battle() -> void:
    config_panel.visible = false
    result_panel.visible = false
    battle_panel.visible = true
    battle_active = false
    paused_for_player = false
    selected_actor = {}
    player_team.clear()
    enemy_team.clear()
    combatants.clear()
    combatant_by_id.clear()
    team_controls.clear()
    opening_choices.clear()
    opening_enemy_choices.clear()
    var area := battle_panel.get_node("BattleArea") as Control
    for child in area.get_children():
        child.queue_free()
    for i in range(player_setup.size()):
        var c := _make_combatant("player", i, player_setup[i])
        player_team.append(c)
        combatants.append(c)
        combatant_by_id[c["id"]] = c
    for i in range(enemy_setup.size()):
        var c := _make_combatant("enemy", i, enemy_setup[i])
        enemy_team.append(c)
        combatants.append(c)
        combatant_by_id[c["id"]] = c
    _layout_team(area, enemy_team, true)
    _layout_team(area, player_team, false)
    _refresh_all_cards()
    _prepare_opening_phase()

func _make_combatant(side: String, index: int, slot: Dictionary) -> Dictionary:
    var species_id := str(slot.get("species_id", _default_species()))
    var level := clampi(int(slot.get("level", 5)), LEVEL_MIN, LEVEL_MAX)
    var species := _species_data(species_id)
    var base: Dictionary = species.get("base_stats", {})
    var hp := int(floor((2.0 * float(base.get("hp", 1)) * level) / 100.0)) + level + 10
    var attack := int(floor((2.0 * float(base.get("attack", 1)) * level) / 100.0)) + 5
    var defense := int(floor((2.0 * float(base.get("defense", 1)) * level) / 100.0)) + 5
    var special := int(floor((2.0 * float(base.get("special", 1)) * level) / 100.0)) + 5
    var speed := int(floor((2.0 * float(base.get("speed", 1)) * level) / 100.0)) + 5
    var start_aggro := round(20.0 + 2.0 * level + float(species.get("rpg_base_stat_total", 0)) / 10.0)
    return {"id": "%s_%d" % [side, index], "side": side, "index": index, "species_id": species_id, "name": _species_name(species_id), "level": level, "types": species.get("types", []), "max_hp": hp, "hp": hp, "attack": attack, "defense": defense, "special": special, "speed": speed, "atb": 0.0, "cycle_mult": 1.0, "alive": true, "aggro": start_aggro, "major_status": "", "confusion_turns": 0, "next_outgoing_mult": 1.0, "next_incoming_mult": 1.0, "next_accuracy_mult": 1.0, "next_cycle_factor": 1.0, "focus_crit_bonus": 0.0, "seeded_by": "", "binding_turns": 0, "damaged_since_last_action": false, "opening_used": false}

func _prepare_opening_phase() -> void:
    opening_queue.clear()
    for actor in player_team:
        if not _opening_moves_for(actor).is_empty():
            opening_queue.append(actor)
    for actor in enemy_team:
        var options := _opening_moves_for(actor)
        if not options.is_empty() and randf() < 0.5:
            opening_enemy_choices.append({"actor": actor, "move_id": options.pick_random()})
    opening_player_index = 0
    if opening_queue.is_empty():
        _resolve_opening_phase()
    else:
        _prompt_next_opening_choice()

func _prompt_next_opening_choice() -> void:
    if opening_player_index >= opening_queue.size():
        _resolve_opening_phase()
        return
    var actor: Dictionary = opening_queue[opening_player_index]
    selected_actor = actor
    paused_for_player = true
    opening_hint.text = "RUNDE 0 · freiwillige Eröffnungsattacke"
    _set_log("[b]%s Lv.%d[/b]: Eröffnungsattacke einsetzen?" % [actor["name"], actor["level"]])
    _clear_action_buttons()
    for move_id in _opening_moves_for(actor):
        _add_action_button(_move_label(move_id), _choose_opening_move.bind(move_id))
    _add_action_button("Überspringen", _skip_opening_move)

func _choose_opening_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    opening_choices.append({"actor": selected_actor, "move_id": move_id})
    selected_actor = {}
    paused_for_player = false
    opening_player_index += 1
    _prompt_next_opening_choice()

func _skip_opening_move() -> void:
    selected_actor = {}
    paused_for_player = false
    opening_player_index += 1
    _prompt_next_opening_choice()

func _resolve_opening_phase() -> void:
    var all_choices: Array[Dictionary] = []
    all_choices.append_array(opening_choices)
    all_choices.append_array(opening_enemy_choices)
    all_choices.sort_custom(_sort_opening_actions)
    for choice in all_choices:
        var actor: Dictionary = choice["actor"]
        if bool(actor.get("alive", false)) and not _living_opponents(actor).is_empty():
            actor["opening_used"] = true
            _execute_move(actor, str(choice["move_id"]), true)
            actor["atb"] = -100.0
    opening_hint.text = ""
    _clear_action_buttons()
    if not _check_battle_end():
        battle_active = true
        _set_log("Runde 0 beendet. Der normale ATB-Kampf beginnt.")

func _sort_opening_actions(a: Dictionary, b: Dictionary) -> bool:
    return _effective_speed(a["actor"]) > _effective_speed(b["actor"])

func _process(delta: float) -> void:
    if not battle_active or paused_for_player:
        return
    var ready_actor: Dictionary = {}
    var best_speed := -1.0
    for combatant in combatants:
        if not bool(combatant.get("alive", false)):
            continue
        var speed := _effective_speed(combatant)
        var cycle := maxf(0.05, float(combatant.get("cycle_mult", 1.0)) * float(combatant.get("next_cycle_factor", 1.0)))
        var gain := delta * (12.0 + speed * 0.62) / cycle
        combatant["atb"] = minf(100.0, float(combatant.get("atb", 0.0)) + gain)
        if float(combatant["atb"]) >= 100.0 and speed > best_speed:
            ready_actor = combatant
            best_speed = speed
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
    _set_log("[b]%s Lv.%d[/b] ist bereit. Wähle eine Aktion." % [actor["name"], actor["level"]])
    _clear_action_buttons()
    for move_id in _normal_moves_for(actor):
        _add_action_button(_move_label(move_id), _on_move_pressed.bind(move_id))
    _add_action_button("Warten", _on_wait_pressed)

func _on_move_pressed(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    var actor := selected_actor
    selected_actor = {}
    paused_for_player = false
    _clear_action_buttons()
    _execute_move(actor, move_id)

func _on_wait_pressed() -> void:
    if selected_actor.is_empty():
        return
    var actor := selected_actor
    selected_actor = {}
    paused_for_player = false
    _clear_action_buttons()
    actor["aggro"] = float(actor.get("aggro", 0.0)) * float(_rules().get("wait_aggro_multiplier", 0.65))
    actor["atb"] = float(_rules().get("wait_atb_start_pct", 35.0))
    actor["cycle_mult"] = 1.0
    actor["next_cycle_factor"] = 1.0
    _after_action_attempt(actor)
    _set_log("%s wartet, baut Aggro ab und startet den nächsten ATB-Zyklus bei 35%%." % _actor_name(actor))
    _refresh_all_cards()
    _check_battle_end()

func _enemy_act(actor: Dictionary) -> void:
    var moves := _normal_moves_for(actor)
    if moves.is_empty() or randf() < 0.08:
        actor["aggro"] = float(actor.get("aggro", 0.0)) * float(_rules().get("wait_aggro_multiplier", 0.65))
        actor["atb"] = float(_rules().get("wait_atb_start_pct", 35.0))
        actor["cycle_mult"] = 1.0
        actor["next_cycle_factor"] = 1.0
        _after_action_attempt(actor)
        _set_log("%s wartet." % _actor_name(actor))
        _check_battle_end()
        return
    _execute_move(actor, str(moves.pick_random()))

func _execute_move(actor: Dictionary, move_id: String, opening := false) -> void:
    if not bool(actor.get("alive", false)):
        return
    var move := _move_data(move_id)
    if move.is_empty():
        return
    if not opening:
        if str(actor.get("major_status", "")) == "paralysis" and randf() < 0.25:
            _finish_action_timing(actor, move, false)
            _after_action_attempt(actor)
            _set_log("%s ist paralysiert und kann sich nicht bewegen!" % _actor_name(actor))
            _refresh_all_cards()
            _check_battle_end()
            return
        if int(actor.get("confusion_turns", 0)) > 0:
            var self_hit := randf() < (1.0 / 3.0)
            actor["confusion_turns"] = maxi(0, int(actor["confusion_turns"]) - 1)
            if self_hit:
                var self_damage := _calculate_damage(actor, actor, 40, "physical", "typeless", false, 1.0)
                _deal_damage(actor, actor, self_damage, false)
                _finish_action_timing(actor, move, false)
                _after_action_attempt(actor)
                _set_log("%s verletzt sich vor Verwirrung selbst und erleidet %d Schaden!" % [_actor_name(actor), self_damage])
                _refresh_all_cards()
                _check_battle_end()
                return
    var targets := _targets_for_move(actor, move)
    if targets.is_empty():
        return
    var any_hit := false
    var total_damage := 0
    for target in targets:
        if not bool(target.get("alive", false)):
            continue
        if not _check_accuracy(actor, move):
            continue
        any_hit = true
        var target_was_alive := bool(target.get("alive", false))
        var effects: Array = move.get("effects", [])
        for effect in effects:
            if not (effect is Dictionary):
                continue
            var kind := str(effect.get("kind", ""))
            match kind:
                "damage":
                    var power := int(move.get("power", 0))
                    if bool(effect.get("double_if_target_damaged_since_own_action", false)) and bool(target.get("damaged_since_last_action", false)):
                        power *= 2
                    var damage := _calculate_damage(actor, target, power, str(move.get("category", "physical")), str(move.get("type", "normal")), true, 1.0)
                    total_damage += _deal_damage(actor, target, damage, true)
                "major_status":
                    if target_was_alive and bool(target.get("alive", false)) and randf() <= float(effect.get("chance", 1.0)):
                        _apply_major_status(actor, target, str(effect.get("status", "")))
                "confusion":
                    if int(target.get("confusion_turns", 0)) <= 0:
                        target["confusion_turns"] = randi_range(int(effect.get("turns_min", 1)), int(effect.get("turns_max", 4)))
                        actor["aggro"] = float(actor.get("aggro", 0.0)) + 30.0
                "outgoing_damage_reduction_next":
                    target["next_outgoing_mult"] = minf(float(target.get("next_outgoing_mult", 1.0)), maxf(0.05, 1.0 - float(actor.get("special", 0)) * float(effect.get("scale_special_pct", 1.0)) / 100.0))
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + 8.0
                "outgoing_damage_increase_next":
                    target["next_outgoing_mult"] = maxf(float(target.get("next_outgoing_mult", 1.0)), 1.0 + float(actor.get("special", 0)) * float(effect.get("scale_special_pct", 1.0)) / 100.0)
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + 8.0
                "incoming_damage_increase_next":
                    target["next_incoming_mult"] = maxf(float(target.get("next_incoming_mult", 1.0)), 1.0 + float(actor.get("special", 0)) * float(effect.get("scale_special_pct", 1.0)) / 100.0)
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + 8.0
                "incoming_damage_reduction_next":
                    target["next_incoming_mult"] = minf(float(target.get("next_incoming_mult", 1.0)), maxf(0.05, 1.0 - float(actor.get("special", 0)) * float(effect.get("scale_special_pct", 1.0)) / 100.0))
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + 8.0
                "accuracy_reduction_next":
                    target["next_accuracy_mult"] = minf(float(target.get("next_accuracy_mult", 1.0)), maxf(0.05, 1.0 - float(actor.get("special", 0)) * float(effect.get("scale_special_pct", 1.0)) / 100.0))
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + 8.0
                "atb_cycle_increase_next":
                    target["cycle_mult"] = float(target.get("cycle_mult", 1.0)) * (1.0 + float(actor.get("special", 0)) * float(effect.get("scale_special_pct", 1.0)) / 100.0)
                    actor["aggro"] = float(actor.get("aggro", 0.0)) + 8.0
                "atb_cycle_reduction_next":
                    actor["next_cycle_factor"] = minf(float(actor.get("next_cycle_factor", 1.0)), maxf(0.1, 1.0 - float(actor.get("special", 0)) * float(effect.get("scale_special_pct", 1.0)) / 100.0))
                "focus_energy":
                    actor["focus_crit_bonus"] = minf(float(actor.get("special", 0)), 25.0) / 100.0
                "atb_knockback":
                    if randf() <= float(effect.get("chance", 1.0)):
                        target["atb"] = maxf(0.0, float(target.get("atb", 0.0)) - float(effect.get("amount_pct", 25.0)))
                "seed":
                    if str(target.get("seeded_by", "")).is_empty() and not _has_type(target, "grass"):
                        target["seeded_by"] = str(actor["id"])
                        actor["aggro"] = float(actor.get("aggro", 0.0)) + 12.0
                "binding":
                    if int(target.get("binding_turns", 0)) <= 0:
                        target["binding_turns"] = randi_range(int(effect.get("turns_min", 4)), int(effect.get("turns_max", 5)))
                        actor["aggro"] = float(actor.get("aggro", 0.0)) + 12.0
                "cleanse_self":
                    for effect_name in effect.get("effects", []):
                        if str(effect_name) == "seeded":
                            actor["seeded_by"] = ""
                        if str(effect_name) == "binding":
                            actor["binding_turns"] = 0
        if str(move.get("target", "")) == "enemy_highest_aggro" and str(move.get("category", "")) != "status":
            target["aggro"] = float(target.get("aggro", 0.0)) * float(_rules().get("aggro_after_targeted_offense_multiplier", 0.5))
    if opening:
        actor["cycle_mult"] = _ap_multiplier(move)
    elif any_hit:
        _finish_action_timing(actor, move, true)
        _after_action_attempt(actor)
    else:
        _finish_action_timing(actor, move, false)
        _after_action_attempt(actor)
    if any_hit:
        var extra := " · %d Schaden" % total_damage if total_damage > 0 else ""
        _set_log("%s nutzt [b]%s[/b]%s." % [_actor_name(actor), str(move.get("name", move_id)), extra])
    else:
        _set_log("%s nutzt [b]%s[/b], aber die Attacke verfehlt." % [_actor_name(actor), str(move.get("name", move_id))])
    _refresh_all_cards()
    _check_battle_end()

func _finish_action_timing(actor: Dictionary, move: Dictionary, hit: bool) -> void:
    actor["cycle_mult"] = _ap_multiplier(move) * float(actor.get("next_cycle_factor", 1.0))
    actor["next_cycle_factor"] = 1.0
    actor["atb"] = 0.0 if hit else float(_rules().get("miss_atb_start_pct", 20.0))

func _after_action_attempt(actor: Dictionary) -> void:
    if not bool(actor.get("alive", false)):
        return
    var status := str(actor.get("major_status", ""))
    if status == "burn":
        _deal_residual(actor, maxi(1, int(floor(float(actor["max_hp"]) / 16.0))))
    elif status == "poison":
        _deal_residual(actor, maxi(1, int(floor(float(actor["max_hp"]) / 8.0))))
    if bool(actor.get("alive", false)) and not str(actor.get("seeded_by", "")).is_empty():
        var amount := maxi(1, int(floor(float(actor["max_hp"]) / 8.0)))
        var actual := _deal_residual(actor, amount)
        var source_id := str(actor.get("seeded_by", ""))
        if combatant_by_id.has(source_id):
            var source: Dictionary = combatant_by_id[source_id]
            if bool(source.get("alive", false)):
                source["hp"] = mini(int(source["max_hp"]), int(source["hp"]) + actual)
    if bool(actor.get("alive", false)) and int(actor.get("binding_turns", 0)) > 0:
        _deal_residual(actor, maxi(1, int(floor(float(actor["max_hp"]) / 8.0))))
        actor["binding_turns"] = maxi(0, int(actor["binding_turns"]) - 1)
    actor["damaged_since_last_action"] = false

func _deal_residual(target: Dictionary, amount: int) -> int:
    var before := int(target.get("hp", 0))
    target["hp"] = maxi(0, before - amount)
    var actual := before - int(target["hp"])
    if int(target["hp"]) <= 0:
        target["alive"] = false
        target["atb"] = 0.0
    return actual

func _deal_damage(actor: Dictionary, target: Dictionary, amount: int, generate_aggro: bool) -> int:
    var before := int(target.get("hp", 0))
    target["hp"] = maxi(0, before - amount)
    var actual := before - int(target["hp"])
    if actual > 0:
        target["damaged_since_last_action"] = true
        if generate_aggro and str(actor.get("id", "")) != str(target.get("id", "")):
            actor["aggro"] = float(actor.get("aggro", 0.0)) + actual
    if int(target["hp"]) <= 0:
        target["alive"] = false
        target["atb"] = 0.0
    return actual

func _calculate_damage(actor: Dictionary, target: Dictionary, power: int, category: String, move_type: String, allow_crit: bool, move_mult: float) -> int:
    var attack_value := maxf(1.0, float(actor.get("attack", 1)))
    var defense_value := maxf(1.0, float(target.get("defense", 1)))
    var level := float(actor.get("level", 1))
    var raw := floor(((((2.0 * level / 5.0) + 2.0) * power * attack_value / defense_value) / 50.0) + 2.0)
    var result := float(raw) * move_mult
    if category == "physical" and str(actor.get("major_status", "")) == "burn":
        result *= 0.5
    result *= float(actor.get("next_outgoing_mult", 1.0))
    result *= float(target.get("next_incoming_mult", 1.0))
    actor["next_outgoing_mult"] = 1.0
    target["next_incoming_mult"] = 1.0
    if move_type != "typeless":
        result *= TypeSystem.get_multiplier(move_type, target.get("types", []))
    if allow_crit:
        var crit_chance := float(_rules().get("crit_base_chance", 0.05)) + float(actor.get("focus_crit_bonus", 0.0))
        if randf() < crit_chance:
            result *= float(_rules().get("crit_multiplier", 1.5))
    return maxi(1, int(floor(result)))

func _check_accuracy(actor: Dictionary, move: Dictionary) -> bool:
    if bool(move.get("bypass_accuracy", false)) or move.get("accuracy", null) == null:
        return true
    var multiplier := float(actor.get("next_accuracy_mult", 1.0))
    actor["next_accuracy_mult"] = 1.0
    var chance := clampf(float(move.get("accuracy", 100)) * multiplier, 0.0, 100.0)
    return randf() * 100.0 < chance

func _apply_major_status(actor: Dictionary, target: Dictionary, status: String) -> bool:
    if not str(target.get("major_status", "")).is_empty():
        return false
    if status == "paralysis" and _has_type(target, "electric"):
        return false
    if status == "burn" and _has_type(target, "fire"):
        return false
    if status == "poison" and (_has_type(target, "poison") or _has_type(target, "steel")):
        return false
    target["major_status"] = status
    var aggro_values := {"poison": 20.0, "burn": 25.0, "paralysis": 30.0}
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(aggro_values.get(status, 10.0))
    return true

func _targets_for_move(actor: Dictionary, move: Dictionary) -> Array[Dictionary]:
    var target_kind := str(move.get("target", "enemy_highest_aggro"))
    if target_kind == "self":
        return [actor]
    if target_kind == "all_enemies":
        return _living_opponents(actor)
    var target := _highest_aggro_target(actor)
    return [] if target.is_empty() else [target]

func _normal_moves_for(actor: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for move_id in _learned_move_ids(actor):
        var move := _move_data(move_id)
        if bool(move.get("normal_battle_available", true)) and not bool(move.get("opening_only", false)):
            result.append(move_id)
    return result

func _opening_moves_for(actor: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for move_id in _learned_move_ids(actor):
        var move := _move_data(move_id)
        if bool(move.get("opening_only", false)):
            result.append(move_id)
    return result

func _learned_move_ids(actor: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var species := _species_data(str(actor.get("species_id", "")))
    for entry in species.get("learnset", []):
        if entry is Array and entry.size() >= 2 and int(entry[0]) <= int(actor.get("level", 1)):
            result.append(str(entry[1]))
    return result

func _effective_speed(actor: Dictionary) -> float:
    var speed := float(actor.get("speed", 1))
    if str(actor.get("major_status", "")) == "paralysis":
        speed *= 0.5
    return speed

func _highest_aggro_target(actor: Dictionary) -> Dictionary:
    var choices := _living_opponents(actor)
    if choices.is_empty():
        return {}
    var best: Dictionary = choices[0]
    for candidate in choices:
        var candidate_aggro := float(candidate.get("aggro", 0.0))
        var best_aggro := float(best.get("aggro", 0.0))
        if candidate_aggro > best_aggro or (is_equal_approx(candidate_aggro, best_aggro) and int(candidate.get("index", 0)) < int(best.get("index", 0))):
            best = candidate
    return best

func _living_opponents(actor: Dictionary) -> Array[Dictionary]:
    var source := enemy_team if str(actor.get("side", "")) == "player" else player_team
    var result: Array[Dictionary] = []
    for candidate in source:
        if bool(candidate.get("alive", false)):
            result.append(candidate)
    return result

func _has_type(actor: Dictionary, type_id: String) -> bool:
    for t in actor.get("types", []):
        if str(t) == type_id:
            return true
    return false

func _ap_multiplier(move: Dictionary) -> float:
    var curve: Dictionary = _rules().get("ap_cycle_multiplier", {})
    return float(curve.get(str(int(move.get("ap_cost", 1))), 1.0))

func _layout_team(area: Control, team: Array[Dictionary], enemy: bool) -> void:
    var positions := _positions_for_count(team.size())
    for i in range(team.size()):
        var card := _create_combatant_card(team[i], enemy)
        card.position = Vector2(14 if enemy else 292, positions[i])
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
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(174, 47)
    card.size = Vector2(174, 47)
    card.add_theme_stylebox_override("panel", _make_panel(Color("f8f1dce8"), Color("34443d"), 5))
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 4)
    card.add_child(h)
    var sprite := TextureRect.new()
    var texture := _load_species_texture(str(combatant["name"]))
    if texture != null:
        sprite.texture = texture
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.custom_minimum_size = Vector2(43, 43)
    sprite.flip_h = not enemy
    h.add_child(sprite)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 0)
    h.add_child(v)
    var name_label := Label.new()
    name_label.text = ("Gegner · " if enemy else "") + str(combatant["name"]) + "  Lv." + str(combatant["level"])
    name_label.add_theme_color_override("font_color", Color("26322e"))
    name_label.add_theme_font_size_override("font_size", 9)
    v.add_child(name_label)
    var hp_bar := ProgressBar.new()
    hp_bar.max_value = float(combatant["max_hp"])
    hp_bar.value = float(combatant["hp"])
    hp_bar.show_percentage = false
    hp_bar.custom_minimum_size = Vector2(115, 8)
    hp_bar.add_theme_stylebox_override("background", _make_bar_style(Color("c8c8c2")))
    hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("55b85a")))
    v.add_child(hp_bar)
    var hp_text := Label.new()
    hp_text.add_theme_color_override("font_color", Color("34443d"))
    hp_text.add_theme_font_size_override("font_size", 8)
    v.add_child(hp_text)
    var atb := ProgressBar.new()
    atb.min_value = -100.0
    atb.max_value = 100.0
    atb.show_percentage = false
    atb.custom_minimum_size = Vector2(115, 6)
    atb.add_theme_stylebox_override("background", _make_bar_style(Color("b5b5aa"), 3))
    atb.add_theme_stylebox_override("fill", _make_bar_style(Color("42aef5"), 3))
    v.add_child(atb)
    var status := Label.new()
    status.add_theme_font_size_override("font_size", 7)
    v.add_child(status)
    team_controls[str(combatant["id"])] = {"card": card, "hp": hp_bar, "hp_text": hp_text, "atb": atb, "status": status}
    return card

func _load_species_texture(display_name: String) -> Texture2D:
    var roots := ["res://assets/", "res://assets/monsters/", "res://assets/pokemon/"]
    var exts := [".png", ".webp", ".jpg", ".jpeg", ".svg"]
    for root_path in roots:
        for ext in exts:
            var path := root_path + display_name + ext
            if ResourceLoader.exists(path):
                var resource := load(path)
                if resource is Texture2D:
                    return resource
    return null

func _refresh_all_cards() -> void:
    for combatant in combatants:
        _refresh_card(combatant)

func _refresh_card(combatant: Dictionary) -> void:
    var ui: Dictionary = team_controls.get(str(combatant.get("id", "")), {})
    if ui.is_empty():
        return
    var hp_bar := ui["hp"] as ProgressBar
    var hp_text := ui["hp_text"] as Label
    var atb := ui["atb"] as ProgressBar
    var status := ui["status"] as Label
    var card := ui["card"] as Control
    hp_bar.value = float(combatant["hp"])
    hp_text.text = "%d/%d KP" % [combatant["hp"], combatant["max_hp"]]
    atb.value = float(combatant["atb"])
    var ratio := float(combatant["hp"]) / maxf(1.0, float(combatant["max_hp"]))
    hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("d94c4c") if ratio <= 0.25 else (Color("e0bd45") if ratio <= 0.5 else Color("55b85a"))))
    var pieces: Array[String] = ["Aggro %.0f" % float(combatant.get("aggro", 0.0))]
    var major := str(combatant.get("major_status", ""))
    if not major.is_empty():
        pieces.append(major.to_upper())
    if int(combatant.get("confusion_turns", 0)) > 0:
        pieces.append("VERWIRRT")
    if not str(combatant.get("seeded_by", "")).is_empty():
        pieces.append("SAMEN")
    if int(combatant.get("binding_turns", 0)) > 0:
        pieces.append("WICKEL")
    if _is_highest_aggro(combatant):
        pieces[0] = "ZIEL · " + pieces[0]
        status.add_theme_color_override("font_color", Color("b54d22"))
    else:
        status.add_theme_color_override("font_color", Color("59605c"))
    status.text = " · ".join(pieces)
    card.modulate.a = 1.0 if bool(combatant.get("alive", false)) else 0.28

func _is_highest_aggro(combatant: Dictionary) -> bool:
    if not bool(combatant.get("alive", false)):
        return false
    var team := player_team if str(combatant.get("side", "")) == "player" else enemy_team
    var best: Dictionary = {}
    for candidate in team:
        if not bool(candidate.get("alive", false)):
            continue
        if best.is_empty() or float(candidate.get("aggro", 0.0)) > float(best.get("aggro", 0.0)) or (is_equal_approx(float(candidate.get("aggro", 0.0)), float(best.get("aggro", 0.0))) and int(candidate.get("index", 0)) < int(best.get("index", 0))):
            best = candidate
    return not best.is_empty() and str(best["id"]) == str(combatant["id"])

func _check_battle_end() -> bool:
    var players_alive := false
    var enemies_alive := false
    for combatant in player_team:
        if bool(combatant.get("alive", false)):
            players_alive = true
            break
    for combatant in enemy_team:
        if bool(combatant.get("alive", false)):
            enemies_alive = true
            break
    if players_alive and enemies_alive:
        return false
    battle_active = false
    paused_for_player = false
    selected_actor = {}
    _clear_action_buttons()
    result_panel.visible = true
    if players_alive:
        result_title.text = "SIEG!"
        result_text.text = "Der Testkampf ist beendet."
    else:
        result_title.text = "NIEDERLAGE"
        result_text.text = "Dein Team ist kampfunfähig."
    return true

func _clear_action_buttons() -> void:
    if action_buttons == null:
        return
    for child in action_buttons.get_children():
        child.queue_free()

func _add_action_button(text: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(142, 27)
    button.pressed.connect(callback)
    action_buttons.add_child(button)

func _move_label(move_id: String) -> String:
    var move := _move_data(move_id)
    return "%s · AP%d" % [str(move.get("name", move_id)), int(move.get("ap_cost", 1))]

func _set_log(text: String) -> void:
    if log_label != null:
        log_label.text = text

func _actor_name(actor: Dictionary) -> String:
    return "%s Lv.%d" % [str(actor.get("name", "Pokémon")), int(actor.get("level", 1))]

func _species_data(species_id: String) -> Dictionary:
    return data.get("species", {}).get(species_id, {})

func _species_name(species_id: String) -> String:
    return str(_species_data(species_id).get("display_name", species_id))

func _move_data(move_id: String) -> Dictionary:
    return data.get("moves", {}).get(move_id, {})

func _rules() -> Dictionary:
    return data.get("rules", {})
