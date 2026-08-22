extends "res://scripts/demo_route_fundstelle_rewards_v2.gd"

# Top-level route audio layer. Music follows the combat-run structure rather
# than pretending the route is an exploration map.
#
# Provisional intensity curve selected from the user's current candidates:
#  1-30  Fight Area
# 31-60  Team Galactic HQ
# 61-80  Victory Road
# 81-90  Spear Pillar
# This mapping is centralized in AudioManager and can be changed without
# touching any route mechanics.

const AUDIO_FINAL_STAGE: int = 90


func start_route() -> void:
    super.start_route()
    AudioManager.play_route(stage)


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    AudioManager.play_route(stage)


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
    super._on_route_battle_finished(victory, updated_team)
    if victory:
        # The victory cue owns the battle-result moment. Once control actually
        # returns to the route UI, the current route phase takes over again.
        AudioManager.play_route(stage)
    else:
        AudioManager.stop_music()


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
        AudioManager.play_item_obtained()


func _apply_vitamin(team_index: int, vitamin: Dictionary) -> void:
    var reward_active: bool = _fundstelle_active
    super._apply_vitamin(team_index, vitamin)
    if reward_active and not _fundstelle_active:
        AudioManager.play_item_obtained()


func _apply_revive(team_index: int) -> void:
    var reward_active: bool = _fundstelle_active
    super._apply_revive(team_index)
    if reward_active and not _fundstelle_active:
        AudioManager.play_item_obtained()
