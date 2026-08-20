extends "res://scripts/demo_route_levelup_hardmode.gd"

# Demo-route balance polish:
# - Capture level rises with route stage instead of staying fixed at level 3.
# - Encounter level uses the route stage as its baseline and compensates for
#   action economy: 1 enemy +5, 2 enemies +2, 3 enemies +/-0, 4 enemies -2.
# - Enemy count is rolled independently and varies from 1 to 4.
# - Early stages strongly prefer smaller encounters; larger groups become more
#   common later without letting repeated two-enemy fights dominate every run.
# - Every Pokémon that entered a stage battle receives XP after a victory,
#   even if it was knocked out during that battle.
# - Full-team replacement choices stay inside the route panel and can scroll.

const CAPTURE_LEVEL_BY_STAGE: Array[int] = [3, 3, 4, 4, 5, 5, 6, 7, 8, 9]
const ENEMY_LEVEL_BY_STAGE: Array[int] = [2, 3, 3, 4, 4, 5, 6, 7, 8, 9]

var _last_enemy_count: int = 0
var _battle_participant_indices: Array[int] = []


func start_route() -> void:
    _last_enemy_count = 0
    _battle_participant_indices.clear()
    super.start_route()


func _capture_level_for_stage(current_stage: int) -> int:
    return CAPTURE_LEVEL_BY_STAGE[clampi(current_stage - 1, 0, CAPTURE_LEVEL_BY_STAGE.size() - 1)]


func _enemy_level_for_stage(current_stage: int) -> int:
    return ENEMY_LEVEL_BY_STAGE[clampi(current_stage - 1, 0, ENEMY_LEVEL_BY_STAGE.size() - 1)]


func _enemy_level_for_encounter(current_stage: int, enemy_count: int) -> int:
    # The stage number is the neutral reference for a three-enemy encounter.
    # Fewer enemies receive extra levels to compensate for having fewer turns;
    # four enemies lose levels because four independent action bars are already
    # a substantial tactical advantage.
    var level_modifier: int = 0
    match clampi(enemy_count, 1, 4):
        1:
            level_modifier = 5
        2:
            level_modifier = 2
        3:
            level_modifier = 0
        4:
            level_modifier = -2

    return maxi(1, current_stage + level_modifier)


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    var capture_level: int = _capture_level_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == "catch":
            choice["hint"] = "Du erhältst ein zufälliges Pokémon auf Level %d." % capture_level
    return choices


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    # Once a new stage starts, its three path choices must be visible again.
    path_box.visible = true


func _choose_path(choice: Dictionary) -> void:
    super._choose_path(choice)
    # Keeping the already-selected path buttons on screen consumed roughly
    # three extra button rows. With a full four-Pokémon team that pushed the
    # replacement list and the bottom team card below the viewport, making it
    # look as if a Pokémon had disappeared. Hide the spent choices instead.
    path_box.visible = false


func _begin_capture_event() -> void:
    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        event_label.text = "An dieser Fangstelle taucht heute kein Pokémon auf."
        continue_button.visible = true
        return

    var capture_level: int = _capture_level_for_stage(stage)
    var sid: String = str(ids.pick_random())
    pending_capture = battle_demo.route_new_member(sid, capture_level)
    var name: String = str(pending_capture.get("name", battle_demo.route_species_name(sid)))

    if team.size() < ROUTE_TEAM_MAX:
        team.append(pending_capture)
        pending_capture = {}
        event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen und deinem Team hinzugefügt." % [name, capture_level]
        continue_button.visible = true
        _refresh_team_panel()
        return

    event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen. Dein Team mit vier Pokémon ist voll. Möchtest du es einlagern oder ein Team-Pokémon ersetzen?" % [name, capture_level]

    var store_button := Button.new()
    store_button.text = "EINLAGERN"
    store_button.pressed.connect(_store_pending_capture)
    capture_actions.add_child(store_button)

    var replace_button := Button.new()
    replace_button.text = "TEAM-POKÉMON ERSETZEN"
    replace_button.pressed.connect(_show_replace_choices)
    capture_actions.add_child(replace_button)


func _show_replace_choices() -> void:
    _clear_container(capture_actions)

    var prompt := Label.new()
    prompt.text = "Welches Pokémon soll ins Lager?"
    prompt.add_theme_font_size_override("font_size", 9)
    capture_actions.add_child(prompt)

    var choices_scroll := ScrollContainer.new()
    choices_scroll.custom_minimum_size = Vector2(0, 78)
    choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    capture_actions.add_child(choices_scroll)

    var choices_box := VBoxContainer.new()
    choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices_box.add_theme_constant_override("separation", 2)
    choices_scroll.add_child(choices_box)

    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        var button := Button.new()
        button.text = "%d. %s Lv.%d" % [index + 1, str(member.get("name", "Pokémon")), int(member.get("level", 1))]
        button.custom_minimum_size = Vector2(0, 24)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_replace_team_member.bind(index))
        choices_box.add_child(button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.pressed.connect(_begin_capture_event_again)
    capture_actions.add_child(back_button)


func _start_stage_battle() -> void:
    _battle_participant_indices.clear()
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if member_value is Dictionary and int((member_value as Dictionary).get("hp", 0)) > 0:
            _battle_participant_indices.append(index)

    super._start_stage_battle()


func _award_experience(amount: int) -> Array[String]:
    # The inherited level-up implementation skips Pokémon at 0 KP. A Pokémon
    # that entered this battle still deserves XP even if it fainted during it.
    # Temporarily mark only those fainted participants as eligible, run the
    # normal XP/level-up pipeline, then restore their fainted KP state.
    var fainted_participants: Array[Dictionary] = []

    for index: int in _battle_participant_indices:
        if index < 0 or index >= team.size():
            continue
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            fainted_participants.append({
                "index": index,
                "hp": int(member.get("hp", 0))
            })
            member["hp"] = 1

    var messages: Array[String] = super._award_experience(amount)

    for restore_value: Dictionary in fainted_participants:
        var index: int = int(restore_value.get("index", -1))
        if index < 0 or index >= team.size():
            continue
        var member_value: Variant = team[index]
        if member_value is Dictionary:
            var restored_member: Dictionary = member_value
            restored_member["hp"] = int(restore_value.get("hp", 0))

    _battle_participant_indices.clear()
    _refresh_team_panel()
    return messages


func _enemy_party_for_stage(current_stage: int) -> Array:
    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        return []

    var enemy_count: int = _roll_enemy_count(current_stage)
    var enemy_level: int = _enemy_level_for_encounter(current_stage, enemy_count)
    var result: Array = []

    for _index: int in range(enemy_count):
        result.append({
            "species_id": str(ids.pick_random()),
            "level": enemy_level
        })

    return result


func _roll_enemy_count(current_stage: int) -> int:
    var roll: float = randf()
    var desired: int = 1

    if current_stage <= 2:
        # Gentle opening: usually one opponent, occasionally two.
        desired = 1 if roll < 0.72 else 2
    elif current_stage <= 4:
        # All four encounter sizes become possible, but 3-4 are still uncommon.
        if roll < 0.35:
            desired = 1
        elif roll < 0.80:
            desired = 2
        elif roll < 0.97:
            desired = 3
        else:
            desired = 4
    elif current_stage <= 7:
        if roll < 0.20:
            desired = 1
        elif roll < 0.55:
            desired = 2
        elif roll < 0.85:
            desired = 3
        else:
            desired = 4
    else:
        if roll < 0.10:
            desired = 1
        elif roll < 0.35:
            desired = 2
        elif roll < 0.70:
            desired = 3
        else:
            desired = 4

    # Prevent long streaks of the same encounter size while keeping early
    # difficulty gentle. A repeat only moves one step up/down instead of
    # rerolling into a surprise four-Pokémon fight.
    if desired == _last_enemy_count:
        if current_stage <= 2:
            desired = 2 if desired == 1 else 1
        elif desired <= 1:
            desired = 2
        elif desired >= 4:
            desired = 3
        else:
            desired += 1 if randf() < 0.5 else -1

    _last_enemy_count = desired
    return desired
