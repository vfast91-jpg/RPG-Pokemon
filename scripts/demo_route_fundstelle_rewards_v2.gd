extends "res://scripts/demo_route_cleanup_v1.gd"

# Active Fundstelle reward layout:
# - 3 compatible TMs (unchanged)
# - 1 stage-scaled healing item (Trank -> stronger variants, unchanged)
# - 1 Beleber
# - 1 random viable vitamin
#
# Items are used immediately and are never stored.
#
# Route audio is integrated here instead of through an extra inheritance layer.
# This keeps the already deep route script chain stable.

const AUDIO_FINAL_STAGE: int = 90
const POST_BATTLE_SETTLE_SECONDS: float = 0.65


func start_route() -> void:
    super.start_route()
    AudioManager.play_route(stage)


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    AudioManager.play_route(stage)


func _choose_path(choice: Dictionary) -> void:
    var is_heal_source: bool = str(choice.get("kind", "")) == EVENT_HEAL
    super._choose_path(choice)
    if is_heal_source:
        AudioManager.play_heal_sfx()


func _start_stage_battle() -> void:
    AudioManager.prepare_battle("final" if stage >= AUDIO_FINAL_STAGE else "normal")
    super._start_stage_battle()


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    var battle_kind: String = "normal"
    if stage >= AUDIO_FINAL_STAGE:
        battle_kind = "final"
    elif kind == EVENT_RARE:
        battle_kind = "boss"
    AudioManager.prepare_battle(battle_kind)
    super._start_special_battle(kind, enemy_party, heading)


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    # The battle result panel already stays visible briefly inside BattleDemo.
    # Give the victory cue one additional beat after that panel closes before XP,
    # level-up popups and route music begin. This prevents the whole post-battle
    # chain from firing almost on top of the final attack.
    if victory:
        await get_tree().create_timer(POST_BATTLE_SETTLE_SECONDS).timeout

    super._on_route_battle_finished(victory, updated_team)
    if victory:
        AudioManager.play_route(stage)
    # On defeat the top-level audio bridge owns the Lose stinger. Do not stop
    # the music channel here, otherwise that cue would be cut off almost at once.


func _show_next_levelup_popup() -> void:
    super._show_next_levelup_popup()
    if _levelup_overlay != null and _levelup_overlay.visible:
        AudioManager.play_level_up()


func _show_next_evolution_popup() -> void:
    super._show_next_evolution_popup()
    if _evolution_overlay != null and _evolution_overlay.visible:
        AudioManager.play_evolution_success()


func _accept_pending_capture() -> void:
    var can_accept: bool = not pending_capture.is_empty() and team.size() < ROUTE_TEAM_MAX
    super._accept_pending_capture()
    if can_accept and pending_capture.is_empty():
        AudioManager.play_pokemon_obtained()


func _replace_team_member(index: int) -> void:
    var had_capture: bool = not pending_capture.is_empty() and index >= 0 and index < team.size()
    super._replace_team_member(index)
    if had_capture and pending_capture.is_empty():
        AudioManager.play_pokemon_obtained()


func _assign_tm(entry: Dictionary, team_index: int) -> void:
    var reward_active: bool = _fundstelle_active or _boss_fundstelle_pending
    super._assign_tm(entry, team_index)
    if reward_active and continue_button != null and continue_button.visible:
        AudioManager.play_item_obtained()


func _apply_healing_item(team_index: int, item: Dictionary) -> void:
    var reward_active: bool = _fundstelle_active
    super._apply_healing_item(team_index, item)
    if reward_active and not _fundstelle_active:
        AudioManager.play_heal_sfx()


func _apply_vitamin(team_index: int, vitamin: Dictionary) -> void:
    var reward_active: bool = _fundstelle_active
    super._apply_vitamin(team_index, vitamin)
    if reward_active and not _fundstelle_active:
        AudioManager.play_item_obtained()


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == EVENT_TM:
            choice["label"] = "🎁 Fundstelle"
            choice["hint"] = "Wähle genau eine Belohnung: 3 passende TMs, 1 Heilitem, 1 Beleber oder 1 zufälliges Vitamin."
    return choices


func _show_fundstelle_options() -> void:
    # The inherited layer already shuffles viable vitamins. Keep only the first
    # shuffled offer so the former second vitamin slot becomes the Beleber slot.
    if _fundstelle_vitamin_offers.size() > 1:
        _fundstelle_vitamin_offers.resize(1)

    super._show_fundstelle_options()

    event_label.text = (
        "[b]🎁 Fundstelle[/b]\n"
        + "Wähle genau [b]eine[/b] Belohnung. Heilitems und Beleber werden sofort benutzt; "
        + "Vitamine verbessern dauerhaft genau ein Pokémon."
    )

    var revive_button := Button.new()
    revive_button.text = "✨ Beleber · 50 % KP"
    revive_button.custom_minimum_size = Vector2(0, 27)
    revive_button.tooltip_text = (
        "Belebt genau ein kampfunfähiges Team-Pokémon mit 50 % seiner maximalen KP wieder. "
        + "Das Item wird nicht eingelagert."
    )
    revive_button.pressed.connect(_choose_revive)

    # Parent order is TM(s), healing item, vitamin(s), optional info label.
    # Insert Beleber directly after the healing item so the three item slots are
    # always: Heilitem -> Beleber -> Vitamin.
    var insert_index: int = capture_actions.get_child_count()
    for index: int in range(capture_actions.get_child_count()):
        var child: Node = capture_actions.get_child(index)
        if child is Button and str((child as Button).text).begins_with("🧪 "):
            insert_index = index + 1
            break

    capture_actions.add_child(revive_button)
    capture_actions.move_child(revive_button, insert_index)
    _layout_fundstelle_rewards()


func _layout_fundstelle_rewards() -> void:
    # The Fundstelle always has at most six actual rewards. Present them as two
    # compact rows (3 TMs / heal + revive + vitamin) so every option is visible
    # immediately and the player never has to discover a hidden reward by scrolling.
    if capture_actions == null:
        return

    var reward_buttons: Array[Button] = []
    for child: Node in capture_actions.get_children():
        if child is Button:
            reward_buttons.append(child as Button)

    if reward_buttons.is_empty():
        return

    var grid := GridContainer.new()
    grid.name = "FundstelleRewardGrid"
    grid.columns = 3
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 5)

    for button: Button in reward_buttons:
        capture_actions.remove_child(button)

    capture_actions.add_child(grid)
    capture_actions.move_child(grid, 0)
    capture_actions.add_theme_constant_override("separation", 4)

    for button: Button in reward_buttons:
        button.custom_minimum_size = Vector2(0, 34)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 10)
        grid.add_child(button)

    # Reclaim a little of the unused explanatory-text space for the reward rows.
    # The text still fits comfortably; result/target screens remain scroll-safe.
    if event_label != null:
        event_label.custom_minimum_size.y = 48.0


func _choose_revive() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    event_label.text = "[b]✨ Beleber[/b]\nWelches kampfunfähige Pokémon möchtest du wiederbeleben?"

    var recipient_count: int = 0
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) > 0:
            continue

        recipient_count += 1
        var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
        var button := Button.new()
        button.text = "%s · 0/%d KP" % [str(member.get("name", "Pokémon")), max_hp]
        button.custom_minimum_size = Vector2(0, 27)
        button.pressed.connect(_apply_revive.bind(index))
        capture_actions.add_child(button)

    if recipient_count == 0:
        event_label.text += "\nEs gibt derzeit kein kampfunfähiges Ziel für den Beleber."

    var back_button := Button.new()
    back_button.text = "ZURÜCK ZUR FUNDSTELLE"
    back_button.pressed.connect(_show_fundstelle_options)
    capture_actions.add_child(back_button)


func _apply_revive(team_index: int) -> void:
    if team_index < 0 or team_index >= team.size():
        _show_fundstelle_options()
        return

    var member_value: Variant = team[team_index]
    if not (member_value is Dictionary):
        _show_fundstelle_options()
        return

    var member: Dictionary = member_value
    if int(member.get("hp", 0)) > 0:
        _choose_revive()
        return

    var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
    var revived_hp: int = _revive_hp_amount(max_hp)
    member["hp"] = revived_hp
    team[team_index] = member

    _fundstelle_active = false
    _clear_container(capture_actions)
    continue_button.visible = true
    event_label.text = (
        "[b]🎁 Fundstelle · Beleber benutzt[/b]\n%s ist wieder kampffähig und hat jetzt %d/%d KP."
        % [str(member.get("name", "Pokémon")), revived_hp, max_hp]
    )
    _refresh_team_panel()
    AudioManager.play_heal_sfx()


func _revive_hp_amount(max_hp: int) -> int:
    return maxi(1, int(maxi(1, max_hp) / 2.0))