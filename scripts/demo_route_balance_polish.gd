extends "res://scripts/demo_route_levelup_hardmode.gd"

# Demo-route balance polish:
# - Capture level rises with route stage instead of staying fixed at level 3.
# - Enemy count is rolled independently from player team size.
# - Difficulty reacts to average living-team level, so a fresh capture does not
#   instantly double the enemy level budget.
# - Early stages strongly prefer smaller encounters; 1-4 enemies become
#   increasingly common later and consecutive stages avoid repeating the same
#   enemy count when possible.

const CAPTURE_LEVEL_BY_STAGE: Array[int] = [3, 3, 4, 4, 5, 5, 6, 7, 8, 9]
const BASE_ENEMY_LEVEL_BY_STAGE: Array[int] = [3, 3, 4, 4, 5, 5, 6, 7, 8, 9]

var _last_enemy_count: int = 0


func start_route() -> void:
    _last_enemy_count = 0
    super.start_route()


func _capture_level_for_stage(current_stage: int) -> int:
    return CAPTURE_LEVEL_BY_STAGE[clampi(current_stage - 1, 0, CAPTURE_LEVEL_BY_STAGE.size() - 1)]


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    var capture_level: int = _capture_level_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == "catch":
            choice["hint"] = "Du erhältst ein zufälliges Pokémon auf Level %d." % capture_level
    return choices


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


func _enemy_party_for_stage(current_stage: int) -> Array:
    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        return []

    var living_level_sum: int = 0
    var living_count: int = 0
    for member_value: Variant in team:
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue
        living_level_sum += maxi(1, int(member.get("level", 1)))
        living_count += 1

    var average_team_level: float = (
        float(living_level_sum) / float(living_count)
        if living_count > 0
        else 1.0
    )

    var baseline_level: int = BASE_ENEMY_LEVEL_BY_STAGE[
        clampi(current_stage - 1, 0, BASE_ENEMY_LEVEL_BY_STAGE.size() - 1)
    ]
    var adaptive_factor: float = 0.55 + float(current_stage) * 0.03
    var adaptive_level: int = maxi(1, int(round(average_team_level * adaptive_factor)))
    var center_level: int = maxi(baseline_level, adaptive_level)
    center_level = mini(center_level, current_stage + 3)

    var enemy_count: int = _roll_enemy_count(current_stage)
    var early_group_penalty: int = 1 if current_stage <= 2 and enemy_count >= 2 else 0
    var max_enemy_level: int = current_stage + 4

    var result: Array = []
    for _index: int in range(enemy_count):
        var level_variation: int = randi_range(-1, 1)
        var enemy_level: int = clampi(
            center_level + level_variation - early_group_penalty,
            1,
            max_enemy_level
        )
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
        # All four encounter sizes are possible from here, but large groups
        # remain rare while the team is still developing.
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

    # Anti-streak protection makes the promised 1-4 variation actually visible
    # during normal play instead of allowing long runs of identical 2-Pokémon
    # encounters purely by chance.
    if desired == _last_enemy_count:
        if current_stage <= 2:
            desired = 2 if desired == 1 else 1
        else:
            var alternatives: Array[int] = [1, 2, 3, 4]
            alternatives.erase(desired)
            desired = alternatives.pick_random()

    _last_enemy_count = desired
    return desired
