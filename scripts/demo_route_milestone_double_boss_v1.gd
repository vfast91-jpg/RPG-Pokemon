extends "res://scripts/demo_route_endgame_v1.gd"

# Route milestone layer:
# - Stages 20, 40, 60 and 80 always use two standard bosses as the stage battle.
# - The optional Besondere Begegnung is removed from those stages because the
#   mandatory stage fight already provides the boss encounter.
# - Milestone bosses reuse the existing standard boss profile and the normal
#   route victory / XP / stage progression flow.

const MilestoneBossRules = preload("res://scripts/route_boss_rules.gd")
const MILESTONE_DOUBLE_BOSS_STAGES: Array[int] = [20, 40, 60, 80]
const MILESTONE_DOUBLE_BOSS_COUNT: int = 2


func _is_milestone_double_boss_stage(current_stage: int) -> bool:
    return MILESTONE_DOUBLE_BOSS_STAGES.has(current_stage)


func _route_event_pool_for_stage(current_stage: int) -> Array[String]:
    var pool: Array[String] = super._route_event_pool_for_stage(current_stage)
    if _is_milestone_double_boss_stage(current_stage):
        pool.erase(EVENT_RARE)
    return pool


func _enemy_party_for_stage(current_stage: int) -> Array:
    if not _is_milestone_double_boss_stage(current_stage):
        return super._enemy_party_for_stage(current_stage)
    return _milestone_double_boss_party(current_stage)


func _milestone_double_boss_party(current_stage: int) -> Array:
    if battle_demo == null:
        return []

    var profile: Dictionary = MilestoneBossRules.standard_boss_profile()
    var level_offset: int = int(profile.get("level_offset", 5))
    var boss_level: int = maxi(1, _highest_team_level() + level_offset)
    var candidates: Array = _standard_combat_candidates(
        battle_demo.route_species_ids_for_level(boss_level)
    )

    if candidates.is_empty():
        push_error(
            "Demo-Route: Keine vollständig spielbare nicht-legendäre Spezies für Doppelboss-Etappe %d auf Level %d verfügbar."
            % [current_stage, boss_level]
        )
        return []

    var party: Array = []
    for _index: int in range(MILESTONE_DOUBLE_BOSS_COUNT):
        party.append({
            "species_id": _weighted_encounter_species(candidates),
            "level": boss_level,
            "boss": true,
            "hp_multiplier": maxf(1.0, float(profile.get("hp_multiplier", 2.0))),
            "hp_bars": maxi(1, int(profile.get("hp_bars", 2))),
            "milestone_double_boss": true
        })
    return party
