extends "res://scripts/battle_demo_rattata_family.gd"

# Route-result reentrancy guard + visible victory handoff.
#
# Victory is deliberately split into two moments:
# - battle resolution locks gameplay immediately when the last opponent falls;
# - the visible victory beat starts only after the current action feedback has
#   actually left the scene, followed by a short quiet beat.
#
# This keeps the final attack/K.o. presentation readable instead of covering it
# with the SIEG panel. The top-level audio bridge observes
# `battle_end_presentation_ready`, so the victory jingle starts together with the
# visible SIEG moment rather than when `battle_active` first becomes false.
#
# Route victory still emits `route_battle_finished` before BattleDemo is hidden.
# The established 0.65 s route settle window therefore remains useful, but is now
# included inside the three-second visible victory hold instead of extending it.

const VICTORY_QUIET_BEAT_SECONDS: float = 0.25
const VICTORY_RESULT_SECONDS: float = 3.0
const ROUTE_VICTORY_HANDOFF_HOLD_SECONDS: float = 0.65
const ROUTE_VICTORY_PRE_HANDOFF_SECONDS: float = (
    VICTORY_RESULT_SECONDS - ROUTE_VICTORY_HANDOFF_HOLD_SECONDS
)

var _route_result_resolution_pending: bool = false
var _standard_victory_resolution_pending: bool = false
var _battle_presentation_generation: int = 0
var _active_battle_feedback_labels: int = 0

# Public presentation gate read by main_audio.gd. `battle_active == false` means
# gameplay is already locked; this flag means the final visual presentation is
# finished and the major victory cue/result may begin.
var battle_end_presentation_ready: bool = false


func _start_battle() -> void:
    _battle_presentation_generation += 1
    _active_battle_feedback_labels = 0
    _standard_victory_resolution_pending = false
    battle_end_presentation_ready = false
    super._start_battle()


func start_route_battle(team_state: Array, enemy_species_id: String, enemy_level: int) -> void:
    _route_result_resolution_pending = false
    super.start_route_battle(team_state, enemy_species_id, enemy_level)


func start_route_battle_party(team_state: Array, enemy_party: Array) -> void:
    _route_result_resolution_pending = false
    super.start_route_battle_party(team_state, enemy_party)


func _route_begin_wave() -> void:
    _route_result_resolution_pending = false
    super._route_begin_wave()


func _spawn_feedback_label(combatant: Dictionary, text: String, color: Color) -> void:
    # Track the actual lifetime of transient battle-feedback labels. Their tween
    # is the longest part of the established action presentation (2.5 s), so
    # waiting for tree_exited also guarantees the shorter move-emoji animation
    # has completed. This avoids guessing an attack-animation duration here.
    var previous_children: Dictionary = {}
    if battle_panel != null:
        for child: Node in battle_panel.get_children():
            previous_children[child.get_instance_id()] = true

    super._spawn_feedback_label(combatant, text, color)

    if battle_panel == null:
        return

    var generation: int = _battle_presentation_generation
    for child: Node in battle_panel.get_children():
        if previous_children.has(child.get_instance_id()):
            continue
        if not (child is Label):
            continue
        _active_battle_feedback_labels += 1
        child.tree_exited.connect(_on_battle_feedback_label_exited.bind(generation), CONNECT_ONE_SHOT)


func _on_battle_feedback_label_exited(generation: int) -> void:
    # A stale label from an older battle must never decrement the counter of a
    # newly started battle.
    if generation != _battle_presentation_generation:
        return
    _active_battle_feedback_labels = maxi(0, _active_battle_feedback_labels - 1)


func _check_end() -> void:
    var own_alive: bool = _battle_end_team_has_living_member(player_team)
    var enemy_alive: bool = _battle_end_team_has_living_member(enemy_team)

    if own_alive and enemy_alive:
        return

    if route_mode:
        if _route_result_resolution_pending:
            return

        # Set this BEFORE any asynchronous result delay starts. Duplicate
        # `_check_end()` calls during the presentation are ignored.
        _route_result_resolution_pending = true

        # Preserve the established route rule: once the enemy side is empty,
        # this encounter is a route victory. Reserve/defeat continue through the
        # mature inherited route handler unchanged.
        if not enemy_alive:
            _resolve_route_victory_with_visible_handoff()
            return

        super._check_end()
        return

    # Normal/lab victories use the same presentation ordering without changing
    # the existing defeat path.
    if own_alive and not enemy_alive:
        if _standard_victory_resolution_pending:
            return
        _standard_victory_resolution_pending = true
        _resolve_standard_victory_outro()
        return

    super._check_end()


func _battle_end_team_has_living_member(team: Array) -> bool:
    for combatant_value: Variant in team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if bool(combatant.get("alive", false)) and int(combatant.get("hp", 0)) > 0:
            return true
    return false


func _lock_battle_for_victory() -> void:
    # Logical battle end happens immediately. No new ATB tick, player input or
    # AI action may begin while the final presentation is still finishing.
    battle_active = false
    paused = false
    selected_actor = {}
    _force_hide_info()
    _clear_actions()
    battle_end_presentation_ready = false
    if result_panel != null:
        result_panel.visible = false


func _wait_for_battle_presentation(generation: int) -> void:
    # Give deferred feedback from the resolving move one frame to enter the tree
    # before deciding whether presentation is idle.
    await get_tree().process_frame

    while (
        generation == _battle_presentation_generation
        and _active_battle_feedback_labels > 0
    ):
        await get_tree().process_frame

    # Require one clean frame after the last tracked label exits. This catches
    # feedback that was itself queued by a deferred combat callback.
    if generation == _battle_presentation_generation:
        await get_tree().process_frame


func _show_victory_result() -> void:
    if result_panel == null or result_title == null:
        return
    result_title.text = "SIEG!"
    result_panel.visible = true
    # Set the audio gate only after the panel is visible, so picture and music
    # begin as one reward beat (within the audio bridge's 50 ms poll interval).
    battle_end_presentation_ready = true


func _resolve_standard_victory_outro() -> void:
    var generation: int = _battle_presentation_generation
    _lock_battle_for_victory()

    await _wait_for_battle_presentation(generation)
    if generation != _battle_presentation_generation:
        return

    await get_tree().create_timer(VICTORY_QUIET_BEAT_SECONDS).timeout
    if generation != _battle_presentation_generation:
        return

    _show_victory_result()
    await get_tree().create_timer(VICTORY_RESULT_SECONDS).timeout
    if generation != _battle_presentation_generation:
        return

    open_config()


func _resolve_route_victory_with_visible_handoff() -> void:
    var generation: int = _battle_presentation_generation
    _lock_battle_for_victory()
    _route_store_current_state()

    await _wait_for_battle_presentation(generation)
    if generation != _battle_presentation_generation:
        return

    await get_tree().create_timer(VICTORY_QUIET_BEAT_SECONDS).timeout
    if generation != _battle_presentation_generation:
        return

    _show_victory_result()

    # Hold most of the three-second victory beat before starting the route-side
    # settle work. The final 0.65 s run in parallel while BattleDemo remains
    # visible, preserving the existing no-grey-screen handoff.
    await get_tree().create_timer(ROUTE_VICTORY_PRE_HANDOFF_SECONDS).timeout
    if generation != _battle_presentation_generation:
        return

    route_mode = false
    route_battle_finished.emit(true, _route_team_state.duplicate(true))

    await get_tree().create_timer(ROUTE_VICTORY_HANDOFF_HOLD_SECONDS).timeout
    if generation != _battle_presentation_generation:
        return

    result_panel.visible = false
    battle_panel.visible = false
    visible = false
