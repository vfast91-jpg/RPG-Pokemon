extends "res://scripts/battle_demo_caterpie_family_ui.gd"

# Route-result reentrancy guard.
#
# The inherited route end handler deliberately keeps `route_mode` active while
# the short SIEG/RESERVE/NIEDERLAGE result delay is shown. During that await,
# multiple gameplay callbacks can reach `_check_end()` again and start another
# copy of the same asynchronous route resolution. Each copy would later emit
# `route_battle_finished`, causing one victory to be processed more than once.
#
# Keep the established presentation delay, but allow only one route resolution
# coroutine per wave. A reserve wave resets the guard through `_route_begin_wave`.

var _route_result_resolution_pending: bool = false


func start_route_battle(team_state: Array, enemy_species_id: String, enemy_level: int) -> void:
    _route_result_resolution_pending = false
    super.start_route_battle(team_state, enemy_species_id, enemy_level)


func start_route_battle_party(team_state: Array, enemy_party: Array) -> void:
    _route_result_resolution_pending = false
    super.start_route_battle_party(team_state, enemy_party)


func _route_begin_wave() -> void:
    _route_result_resolution_pending = false
    super._route_begin_wave()


func _check_end() -> void:
    if not route_mode:
        super._check_end()
        return

    if _route_result_resolution_pending:
        return

    var own_alive: bool = false
    var enemy_alive: bool = false

    for combatant_value: Variant in player_team:
        if combatant_value is Dictionary and bool((combatant_value as Dictionary).get("alive", false)):
            own_alive = true
            break

    for combatant_value: Variant in enemy_team:
        if combatant_value is Dictionary and bool((combatant_value as Dictionary).get("alive", false)):
            enemy_alive = true
            break

    if own_alive and enemy_alive:
        return

    # Set this BEFORE the inherited asynchronous result delay starts. Any
    # duplicate `_check_end()` calls during that delay are ignored.
    _route_result_resolution_pending = true
    super._check_end()
