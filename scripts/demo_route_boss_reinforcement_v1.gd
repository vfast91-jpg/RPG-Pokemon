extends "res://scripts/demo_route_clean_stage_header_v1.gd"

# Standard special-boss phase contract.
#
# Only the ordinary single Boss from "Besondere Begegnung" receives this
# reinforcement phase. Milestone double bosses (20/40/60/80) and the endgame
# superboss gauntlet (91-100) stay separate encounter categories.
#
# The boss species is copied verbatim into the reinforcement contract. This is
# deliberate: lowering the reinforcement level must never reverse-evolve the
# species (e.g. a Glutexo boss still calls Glutexo, not Glumanda).

const BossReinforcementRules = preload("res://scripts/route_boss_rules.gd")


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
        + "auf deinem höchsten Teamlevel. Sieg gibt normale Etappen-EP und danach eine Fundstelle."
    ) % count
    return choice


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    var decorated_party: Array = enemy_party.duplicate(true)
    if kind == EVENT_RARE:
        decorated_party = _decorate_standard_boss_reinforcement_contract(decorated_party)
    super._start_special_battle(kind, decorated_party, heading)


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
    source["boss_reinforcement_level"] = maxi(1, _highest_team_level())
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
    if current_stage >= ENDGAME_STAGE_START:
        return false
    if _is_milestone_double_boss_stage(current_stage):
        return false
    return true
