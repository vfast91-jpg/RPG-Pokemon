extends "res://scripts/battle_demo_lab_family_refresh_v1.gd"

# Presentation fix for simultaneous route bosses. The established route-boss
# layer already applies boss HP and visuals to every enemy marked as a boss; this
# top layer only corrects the battle log when two bosses are present together.


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not route_mode or enemy_team.is_empty():
        return

    var boss_count: int = 0
    var milestone_double_boss: bool = false
    var count: int = mini(enemy_team.size(), _route_enemy_party.size())
    for index: int in range(count):
        var source_value: Variant = _route_enemy_party[index]
        if not (source_value is Dictionary):
            continue
        var source: Dictionary = source_value as Dictionary
        if bool(source.get("boss", false)):
            boss_count += 1
        if bool(source.get("milestone_double_boss", false)):
            milestone_double_boss = true

    if milestone_double_boss and boss_count >= 2:
        _set_log(
            "👑 Doppelboss! Zwei Boss-Pokémon stehen dir gleichzeitig gegenüber – beide mit zwei vollständigen KP-Leisten."
        )
