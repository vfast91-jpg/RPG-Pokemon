extends "res://scripts/battle_demo_route_vitamins_v1.gd"

const StartAggroRules = preload("res://scripts/battle/start_aggro_rules.gd")

# Final start-Aggro layer.
# Start threat is based on both level and the species' five Timeflow base stats:
# HP + Attack + Defense + Status (internal: special) + Speed.
# Individual runtime stat changes, vitamins and temporary modifiers deliberately
# do not alter this initial species-strength contribution.
#
# Audio hooks also live here instead of in another child script. The battle
# inheritance chain is already very deep; keeping audio in this established
# layer avoids adding another superclass hop just for presentation.

var _audio_result_announced: bool = false


func _start_battle() -> void:
    _audio_result_announced = false
    AudioManager.play_prepared_battle()
    super._start_battle()


func _execute_move(actor: Dictionary, move_id: String) -> void:
    # Only real move executions get the shared attack cue. Invalid move ids stay
    # silent; species-specific blockers may return before reaching this layer.
    if not _move_data(move_id).is_empty():
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


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    var species: Dictionary = {}
    var species_all_value: Variant = data.get("species", {})
    if species_all_value is Dictionary:
        var species_value: Variant = (species_all_value as Dictionary).get(
            str(combatant.get("species_id", setup.get("species_id", ""))),
            {}
        )
        if species_value is Dictionary:
            species = species_value

    combatant["aggro"] = StartAggroRules.calculate(
        species,
        int(combatant.get("level", setup.get("level", 1)))
    )
    return combatant