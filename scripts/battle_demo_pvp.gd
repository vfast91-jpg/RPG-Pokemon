extends "res://scripts/battle_demo_move_contract.gd"

# Local hot-seat PvP layer. It deliberately reuses the complete current
# Timeflow battle stack and only replaces the controller for the enemy side
# while PvP is active.

signal pvp_request_main_menu

var pvp_mode: bool = false
var _pvp_opening_enemy_index: int = 0
var _pvp_collecting_enemy_opening: bool = false
var _pvp_handoff_overlay: Control


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    _build_pvp_handoff_overlay()


func _build_pvp_handoff_overlay() -> void:
    if battle_panel == null:
        return

    _pvp_handoff_overlay = Control.new()
    _pvp_handoff_overlay.name = "PvpOpeningHandoff"
    _pvp_handoff_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pvp_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _pvp_handoff_overlay.z_index = 400
    _pvp_handoff_overlay.visible = false
    battle_panel.add_child(_pvp_handoff_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 1.0)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _pvp_handoff_overlay.add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pvp_handoff_overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(360, 154)
    panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("172823"), Color("e0c95f"), 12, 12.0)
    )
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 9)
    panel.add_child(content)

    var title := Label.new()
    title.text = "CONTROLLER WEITERGEBEN"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color("ffe46f"))
    content.add_child(title)

    var text := Label.new()
    text.text = "Spieler 1 hat Runde 0 abgeschlossen.\nJetzt ist Spieler 2 mit den Eröffnungsentscheidungen dran."
    text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_theme_font_size_override("font_size", 11)
    text.add_theme_color_override("font_color", Color("d9e7e1"))
    content.add_child(text)

    var take_over := Button.new()
    take_over.text = "SPIELER 2 ÜBERNIMMT"
    take_over.custom_minimum_size = Vector2(210, 34)
    take_over.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    take_over.pressed.connect(_on_pvp_handoff_confirmed)
    content.add_child(take_over)


func pvp_catalog(level: int) -> Array:
    var result: Array = []
    var bounded_level: int = clampi(level, 1, 100)
    var species_value: Variant = data.get("species", {})
    if not (species_value is Dictionary):
        return result

    # PvP drafts one concrete form per family. Linear families resolve normally;
    # branching families get one random valid branch for this catalog build.
    # This keeps Eevee-like families from being weighted eight times just because
    # they have more possible endpoints.
    var added_species: Dictionary = {}
    for root_value: Variant in species_ids:
        var species_id: String = route_resolve_generated_species_for_level(
            str(root_value),
            bounded_level
        )
        if species_id.is_empty() or added_species.has(species_id):
            continue

        var combatant: Dictionary = _make_combatant(
            "player",
            0,
            {"species_id": species_id, "level": bounded_level}
        )
        var normal_moves: Array = _database_normal_battle_moves(combatant.get("moves", []))
        if normal_moves.is_empty():
            continue

        added_species[species_id] = true
        var types_value: Variant = combatant.get("types", [])
        var types: Array = types_value.duplicate() if types_value is Array else []
        result.append({
            "id": species_id,
            "name": str(combatant.get("name", species_id)),
            "types": types,
            "moves": _move_names(normal_moves),
            "stats": {
                "hp": int(combatant.get("max_hp", 1)),
                "attack": int(combatant.get("attack", 1)),
                "defense": int(combatant.get("defense", 1)),
                "status": int(combatant.get("special", 1)),
                "speed": int(combatant.get("speed", 1))
            }
        })

    result.sort_custom(
        func(a: Variant, b: Variant) -> bool:
            if not (a is Dictionary) or not (b is Dictionary):
                return false
            return str((a as Dictionary).get("name", "")) < str((b as Dictionary).get("name", ""))
    )
    return result


func _randomize_setup() -> void:
    if species_ids.is_empty():
        return

    var player_amount: int = randi_range(1, TEAM_MAX)
    var enemy_amount: int = randi_range(1, TEAM_MAX)
    player_setup.clear()
    enemy_setup.clear()

    for _index: int in range(player_amount):
        var level: int = randi_range(1, DATABASE_LEVEL_MAX)
        var root_id: String = str(species_ids.pick_random())
        var generated_id: String = route_resolve_generated_species_for_level(root_id, level)
        player_setup.append({
            "species_id": generated_id if not generated_id.is_empty() else root_id,
            "level": level
        })
    for _index: int in range(enemy_amount):
        var level: int = randi_range(1, DATABASE_LEVEL_MAX)
        var root_id: String = str(species_ids.pick_random())
        var generated_id: String = route_resolve_generated_species_for_level(root_id, level)
        enemy_setup.append({
            "species_id": generated_id if not generated_id.is_empty() else root_id,
            "level": level
        })

    player_count.set_value_no_signal(float(player_amount))
    enemy_count.set_value_no_signal(float(enemy_amount))
    _refresh_setup()


func pvp_species_texture(species_id: String) -> Texture2D:
    return _species_texture(_species_name(species_id))


func pvp_type_name(type_id: String) -> String:
    return _type_name(type_id)


func start_pvp_battle(player_ids: Array, enemy_ids: Array, level: int) -> bool:
    if player_ids.size() != TEAM_MAX or enemy_ids.size() != TEAM_MAX:
        push_warning("PvP braucht genau vier Pokémon pro Seite.")
        return false

    var bounded_level: int = clampi(level, 1, 100)
    pvp_mode = true
    route_mode = false
    _pvp_opening_enemy_index = 0
    _pvp_collecting_enemy_opening = false
    _hide_pvp_handoff()

    player_setup.clear()
    enemy_setup.clear()
    for species_id_value: Variant in player_ids:
        player_setup.append({
            "species_id": str(species_id_value),
            "level": bounded_level
        })
    for species_id_value: Variant in enemy_ids:
        enemy_setup.append({
            "species_id": str(species_id_value),
            "level": bounded_level
        })

    visible = true
    _start_battle()
    if not battle_active:
        pvp_mode = false
        return false

    if not opening_phase_active:
        _set_log(
            "[b]PLAYER VS PLAYER[/b] · Vier gegen vier auf Level %d. Spieler 1 beginnt auf der rechten Seite, Spieler 2 auf der linken."
            % bounded_level
        )
    return true


func cancel_pvp_mode() -> void:
    pvp_mode = false
    opening_phase_active = false
    battle_active = false
    paused = false
    selected_actor = {}
    _opening_choices.clear()
    _opening_player_candidates.clear()
    _opening_enemy_candidates.clear()
    _opening_player_index = 0
    _pvp_opening_enemy_index = 0
    _pvp_collecting_enemy_opening = false
    _hide_pvp_handoff()


func open_config() -> void:
    cancel_pvp_mode()
    super.open_config()


func _enemy_act(actor: Dictionary) -> void:
    if pvp_mode:
        _prompt_player(actor)
        return
    super._enemy_act(actor)


func _prompt_player(actor: Dictionary) -> void:
    super._prompt_player(actor)
    if not pvp_mode:
        return
    if not paused or selected_actor.is_empty():
        return
    if str(selected_actor.get("id", "")) != str(actor.get("id", "")):
        return

    var player_number: int = 1 if str(actor.get("side", "")) == "player" else 2
    _set_log(
        "[b]SPIELER %d[/b] · [b]%s[/b] ist bereit. Wähle eine Aktion."
        % [player_number, _actor_name(actor)]
    )


func _prompt_next_opening_actor() -> void:
    if not pvp_mode:
        super._prompt_next_opening_actor()
        return

    if _pvp_collecting_enemy_opening:
        _pvp_prompt_next_enemy_opening()
        return

    while _opening_player_index < _opening_player_candidates.size():
        var actor_value: Variant = _opening_player_candidates[_opening_player_index]
        if actor_value is Dictionary and bool((actor_value as Dictionary).get("alive", false)):
            var actor: Dictionary = actor_value
            var opening_moves: Array[String] = _opening_moves(actor)
            if not opening_moves.is_empty():
                _show_opening_choice(actor, opening_moves)
                return
        _opening_player_index += 1

    if _opening_enemy_candidates.is_empty():
        _resolve_opening_phase()
        return

    _pvp_opening_enemy_index = 0
    _pvp_collecting_enemy_opening = true
    paused = true
    selected_actor = {}
    _clear_actions()
    _show_pvp_handoff()


func _pvp_prompt_next_enemy_opening() -> void:
    while _pvp_opening_enemy_index < _opening_enemy_candidates.size():
        var actor_value: Variant = _opening_enemy_candidates[_pvp_opening_enemy_index]
        if actor_value is Dictionary and bool((actor_value as Dictionary).get("alive", false)):
            var actor: Dictionary = actor_value
            var opening_moves: Array[String] = _opening_moves(actor)
            if not opening_moves.is_empty():
                _show_opening_choice(actor, opening_moves)
                return
        _pvp_opening_enemy_index += 1

    _pvp_collecting_enemy_opening = false
    _resolve_opening_phase()


func _show_opening_choice(actor: Dictionary, opening_moves: Array[String]) -> void:
    super._show_opening_choice(actor, opening_moves)
    if not pvp_mode:
        return

    var player_number: int = 1 if str(actor.get("side", "")) == "player" else 2
    _set_log(
        "[b]SPIELER %d · RUNDE 0[/b] · %s darf eine Eröffnungsattacke wählen."
        % [player_number, _actor_name(actor)]
    )


func _choose_opening_move(actor: Dictionary, move_id: String) -> void:
    if pvp_mode and _pvp_collecting_enemy_opening:
        _opening_choices.append({"actor": actor, "move_id": move_id})
        _pvp_opening_enemy_index += 1
        _touch_preview_move_id = ""
        _pvp_prompt_next_enemy_opening()
        return
    super._choose_opening_move(actor, move_id)


func _skip_opening_move() -> void:
    if pvp_mode and _pvp_collecting_enemy_opening:
        _pvp_opening_enemy_index += 1
        _touch_preview_move_id = ""
        _pvp_prompt_next_enemy_opening()
        return
    super._skip_opening_move()


func _on_pvp_handoff_confirmed() -> void:
    if not pvp_mode or not _pvp_collecting_enemy_opening:
        return
    _hide_pvp_handoff()
    _pvp_prompt_next_enemy_opening()


func _show_pvp_handoff() -> void:
    if _pvp_handoff_overlay != null:
        _pvp_handoff_overlay.visible = true


func _hide_pvp_handoff() -> void:
    if _pvp_handoff_overlay != null:
        _pvp_handoff_overlay.visible = false


func _detail_info(combatant: Dictionary) -> String:
    var detail: String = super._detail_info(combatant)
    if not pvp_mode or not opening_phase_active:
        return detail

    # Runde 0 is the only hidden-information moment in local PvP. While one
    # player chooses an opening action, the other side's move list must not
    # reveal which Pokemon even owns an opening-capable move.
    var viewer_side: String = "enemy" if _pvp_collecting_enemy_opening else "player"
    if str(combatant.get("side", "")) == viewer_side:
        return detail

    var marker: String = "\n\n[b]VERFÜGBARE ATTACKEN[/b]"
    var marker_index: int = detail.find(marker)
    if marker_index < 0:
        return detail
    return (
        detail.substr(0, marker_index)
        + marker
        + "\n• In Runde 0 für den anderen Spieler verborgen"
    )


func _check_end() -> void:
    if not pvp_mode:
        super._check_end()
        return

    var player_one_alive: bool = false
    var player_two_alive: bool = false

    for combatant_value: Variant in player_team:
        if combatant_value is Dictionary and bool((combatant_value as Dictionary).get("alive", false)):
            player_one_alive = true
            break
    for combatant_value: Variant in enemy_team:
        if combatant_value is Dictionary and bool((combatant_value as Dictionary).get("alive", false)):
            player_two_alive = true
            break

    if player_one_alive and player_two_alive:
        return

    battle_active = false
    paused = false
    opening_phase_active = false
    selected_actor = {}
    _pvp_collecting_enemy_opening = false
    _hide_pvp_handoff()
    _force_hide_info()
    _clear_actions()

    if player_one_alive:
        result_title.text = "SPIELER 1 GEWINNT!"
    elif player_two_alive:
        result_title.text = "SPIELER 2 GEWINNT!"
    else:
        result_title.text = "UNENTSCHIEDEN"
    result_panel.visible = true

    await get_tree().create_timer(1.5).timeout
    if not pvp_mode:
        return

    result_panel.visible = false
    if battle_panel != null:
        battle_panel.visible = false
    visible = false
    pvp_mode = false
    pvp_request_main_menu.emit()


func _pvp_species_is_available_at_level(species_id: String, level: int) -> bool:
    var root_id: String = _database_family_root(species_id)
    if root_id.is_empty():
        return route_species_is_available(species_id)
    return route_generated_species_options_for_level(
        root_id,
        clampi(level, 1, 100)
    ).has(species_id)
