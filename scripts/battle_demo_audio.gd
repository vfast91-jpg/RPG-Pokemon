extends "res://scripts/battle_demo_vulpix_family.gd"

# Final battle audio layer. It deliberately sits above all mechanics so every
# valid move, including future species-specific moves, receives the same single
# attack cue without duplicating sound logic in individual attacks.

var _audio_result_announced: bool = false


func _start_battle() -> void:
    _audio_result_announced = false
    AudioManager.play_prepared_battle()
    super._start_battle()


func _execute_move(actor: Dictionary, move_id: String) -> void:
    # Disabled/invalid moves are not real executions and therefore stay silent.
    if not _vulpix_move_is_disabled(actor, move_id) and not _move_data(move_id).is_empty():
        AudioManager.play_attack_sfx()
    super._execute_move(actor, move_id)


func _check_end() -> void:
    if battle_active and not _audio_result_announced:
        var own_alive: bool = _audio_team_has_living_member(player_team)
        var enemy_alive: bool = _audio_team_has_living_member(enemy_team)
        if not own_alive or not enemy_alive:
            _audio_result_announced = true
            if own_alive and not enemy_alive:
                AudioManager.play_victory(AudioManager.current_battle_kind)
            else:
                AudioManager.stop_music()
    super._check_end()


func _audio_team_has_living_member(team_value: Array) -> bool:
    for combatant_value: Variant in team_value:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if bool(combatant.get("alive", false)) and int(combatant.get("hp", 0)) > 0:
            return true
    return false
