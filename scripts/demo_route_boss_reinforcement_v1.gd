extends "res://scripts/demo_route_clean_stage_header_v1.gd"

# Standard special-boss phase contract.
#
# Only the ordinary single Boss from "Besondere Begegnung" receives this
# reinforcement phase. Milestone double bosses (20/40/60/80) and the endgame
# superboss gauntlet (91-100) stay separate encounter categories.
#
# Reinforcements copy the boss species verbatim and use exactly the highest
# player-team level as their BASE level. Species and level stay independent, so
# an underleveled evolved boss species is never reverse-evolved for this special
# spawn. The global route difficulty is applied afterwards to every enemy,
# including these reinforcements.

const BossReinforcementRules = preload("res://scripts/route_boss_rules.gd")

# Regular script variables are intentionally used here: RunSaveManager stores
# them automatically together with the rest of the active adventure.
var route_difficulty_key: String = "normal"
var route_difficulty_level_offset: int = 0


func set_route_difficulty(difficulty_key: String, level_offset: int) -> void:
    route_difficulty_key = difficulty_key
    route_difficulty_level_offset = clampi(level_offset, -2, 4)


func _enemy_party_for_stage(current_stage: int) -> Array:
    return _apply_route_difficulty(super._enemy_party_for_stage(current_stage))


func _active_event_choice(kind: String, current_stage: int) -> Dictionary:
    var choice: Dictionary = super._active_event_choice(kind, current_stage)
    if kind != EVENT_RARE or not _stage_uses_standard_boss_reinforcements(current_stage):
        return choice

    var reinforcement: Dictionary = BossReinforcementRules.standard_reinforcement_profile()
    if not bool(reinforcement.get("enabled", true)):
        return choice

    var count: int = maxi(1, int(reinforcement.get("count", 2)))
    choice["hint"] = (
        "Boss mit doppelten KP auf dem höchsten eigenen Level +5. "
        + "Beim Wechsel auf die zweite KP-Leiste ruft er %d gleichartige Verstärkungen "
        + "auf deinem höchsten Teamlevel. Der gewählte Schwierigkeitsgrad skaliert alle Gegner. "
        + "Sieg gibt normale Etappen-EP und danach eine Fundstelle."
    ) % count
    return choice


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    var decorated_party: Array = enemy_party.duplicate(true)
    if kind == EVENT_RARE:
        decorated_party = _decorate_standard_boss_reinforcement_contract(decorated_party)
    decorated_party = _apply_route_difficulty(decorated_party)
    super._start_special_battle(kind, decorated_party, heading)


func _apply_route_difficulty(enemy_party: Array) -> Array:
    var result: Array = enemy_party.duplicate(true)
    for index: int in range(result.size()):
        var enemy_value: Variant = result[index]
        if not (enemy_value is Dictionary):
            continue

        var enemy: Dictionary = enemy_value as Dictionary
        # Special battles are saved after this adjustment and may later re-enter
        # this method on resume. Separate markers prevent both double-scaling and
        # missing the reinforcement level if that contract is added afterwards.
        if not bool(enemy.get("_route_difficulty_level_applied", false)):
            enemy["level"] = maxi(
                1,
                int(enemy.get("level", 1)) + route_difficulty_level_offset
            )
            enemy["_route_difficulty_level_applied"] = true

        if (
            enemy.has("boss_reinforcement_level")
            and not bool(enemy.get("_route_difficulty_reinforcement_applied", false))
        ):
            enemy["boss_reinforcement_level"] = maxi(
                1,
                int(enemy.get("boss_reinforcement_level", 1)) + route_difficulty_level_offset
            )
            enemy["_route_difficulty_reinforcement_applied"] = true

        result[index] = enemy

    return result


func _decorate_standard_boss_reinforcement_contract(enemy_party: Array) -> Array:
    var result: Array = enemy_party.duplicate(true)
    if result.size() != 1 or not _stage_uses_standard_boss_reinforcements(stage):
        return result

    var source_value: Variant = result[0]
    if not (source_value is Dictionary):
        return result
    var source: Dictionary = source_value as Dictionary
    if not bool(source.get("boss", false)):
        return result
    if bool(source.get("milestone_double_boss", false)):
        return result

    var reinforcement: Dictionary = BossReinforcementRules.standard_reinforcement_profile()
    if not bool(reinforcement.get("enabled", true)):
        return result

    var boss_species_id: String = str(source.get("species_id", ""))
    if boss_species_id.is_empty():
        return result

    source["boss_reinforcement_enabled"] = true
    source["boss_reinforcement_count"] = clampi(int(reinforcement.get("count", 2)), 1, 3)
    source["boss_reinforcement_species_id"] = boss_species_id
    source["boss_reinforcement_level"] = BossReinforcementRules.reinforcement_level_for_player_max(
        _highest_team_level()
    )
    source["boss_reinforcement_hp_multiplier"] = maxf(
        1.0,
        float(reinforcement.get("hp_multiplier", 1.0))
    )
    source["boss_reinforcement_start_atb"] = clampf(
        float(reinforcement.get("start_atb_percent", 0.0)),
        0.0,
        100.0
    )
    source["boss_reinforcement_trigger_remaining_bars"] = maxi(
        1,
        int(reinforcement.get("trigger_remaining_bars", 1))
    )
    source["boss_reinforcement_species_mode"] = "same_as_boss"
    source["boss_reinforcement_level_mode"] = "player_max"
    result[0] = source
    return result


func _stage_uses_standard_boss_reinforcements(current_stage: int) -> bool:
    if current_stage <= 10:
        return false
    if current_stage >= ENDGAME_STAGE_START:
        return false
    if _is_milestone_double_boss_stage(current_stage):
        return false
    return true
