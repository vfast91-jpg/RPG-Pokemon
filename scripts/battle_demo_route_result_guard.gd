extends "res://scripts/battle_demo_rattata_family.gd"

# Route-result reentrancy guard + visible victory handoff.
#
# The inherited route end handler deliberately keeps `route_mode` active while
# the short SIEG/RESERVE/NIEDERLAGE result delay is shown. During that await,
# multiple gameplay callbacks can reach `_check_end()` again and start another
# copy of the same asynchronous route resolution. Each copy would later emit
# `route_battle_finished`, causing one victory to be processed more than once.
#
# Victory has one additional presentation requirement: the route layer waits
# 0.65 seconds after `route_battle_finished` before XP/level-up/route music
# continue. Previously BattleDemo hid itself before emitting that signal, so the
# same 0.65 seconds exposed the empty viewport as a grey screen. We now emit the
# result while the SIEG panel and battlefield are still visible, keep them on
# screen for that existing settle window, and only then hide BattleDemo. The
# total timing stays the same; only the grey gap becomes a visible victory beat.

const ROUTE_VICTORY_RESULT_SECONDS: float = 0.75
const ROUTE_VICTORY_HANDOFF_HOLD_SECONDS: float = 0.65

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

    # Set this BEFORE any asynchronous result delay starts. Duplicate
    # `_check_end()` calls during the presentation are ignored.
    _route_result_resolution_pending = true

    # Only victory needs the custom handoff. Reserve and defeat keep the mature
    # inherited behavior unchanged.
    if not enemy_alive:
        _resolve_route_victory_with_visible_handoff()
        return

    super._check_end()


func _resolve_route_victory_with_visible_handoff() -> void:
    battle_active = false
    paused = false
    selected_actor = {}
    _force_hide_info()
    _clear_actions()
    _route_store_current_state()

    result_title.text = "SIEG!"
    result_panel.visible = true

    # Keep the established first victory beat. The top-level audio bridge starts
    # the victory music after 0.55 s, so the player already hears it here.
    await get_tree().create_timer(ROUTE_VICTORY_RESULT_SECONDS).timeout

    # Start the route-side 0.65 s settle timer while BattleDemo is STILL visible.
    # Route handlers therefore prepare the return in parallel instead of leaving
    # an empty grey viewport between battle and route.
    route_mode = false
    route_battle_finished.emit(true, _route_team_state.duplicate(true))

    # Reuse the old settle duration as an explicit victory hold on the battlefield.
    # The SIEG panel remains visible while the victory music gets its moment.
    await get_tree().create_timer(ROUTE_VICTORY_HANDOFF_HOLD_SECONDS).timeout

    result_panel.visible = false
    battle_panel.visible = false
    visible = false
