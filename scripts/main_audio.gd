extends "res://scripts/main_logo.gd"

# Top-level audio bridge.
# Audio deliberately observes the BattleDemo node from the main scene instead of
# living inside the already deep Pokemon/battle inheritance chain.

const AUDIO_POLL_SECONDS: float = 0.05
const BATTLE_END_CUE_DELAY_SECONDS: float = 0.55

var _audio_poll_timer: Timer
var _audio_battle_was_active: bool = false
var _audio_action_serials: Dictionary = {}
var _audio_alive_states: Dictionary = {}
var _audio_battle_session: int = 0


func _ready() -> void:
    super._ready()
    AudioManager.play_main_menu()

    _audio_battle_was_active = _audio_battle_is_active()
    _audio_snapshot_action_serials()
    _audio_snapshot_alive_states()

    _audio_poll_timer = Timer.new()
    _audio_poll_timer.name = "BattleAudioPollTimer"
    _audio_poll_timer.wait_time = AUDIO_POLL_SECONDS
    _audio_poll_timer.one_shot = false
    _audio_poll_timer.timeout.connect(_audio_poll_battle)
    add_child(_audio_poll_timer)
    _audio_poll_timer.start()


func _show_main_menu() -> void:
    super._show_main_menu()
    AudioManager.play_main_menu()


func _audio_poll_battle() -> void:
    if battle_demo == null:
        return

    var active: bool = _audio_battle_is_active()

    if active and not _audio_battle_was_active:
        _audio_battle_session += 1
        _audio_snapshot_action_serials()
        _audio_snapshot_alive_states()
        AudioManager.play_prepared_battle()

    # Poll once more on the frame after battle_active falls to false. The attack
    # that caused the final K.o. can update action/alive state immediately before
    # the battle runtime closes, and its Whoosh/K.o. cues must not be missed.
    if active or _audio_battle_was_active:
        _audio_poll_attack_actions()
        _audio_poll_faint_states()

    if not active and _audio_battle_was_active:
        _audio_handle_battle_end(_audio_battle_session)

    _audio_battle_was_active = active


func _audio_battle_is_active() -> bool:
    if battle_demo == null:
        return false
    return bool(battle_demo.get("battle_active"))


func _audio_combatants() -> Array:
    if battle_demo == null:
        return []
    var value: Variant = battle_demo.get("combatants")
    return value if value is Array else []


func _audio_snapshot_action_serials() -> void:
    _audio_action_serials.clear()
    for combatant_value: Variant in _audio_combatants():
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        if combatant_id.is_empty():
            continue
        _audio_action_serials[combatant_id] = int(combatant.get("action_serial", 0))


func _audio_snapshot_alive_states() -> void:
    _audio_alive_states.clear()
    for combatant_value: Variant in _audio_combatants():
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        if combatant_id.is_empty():
            continue
        _audio_alive_states[combatant_id] = _audio_combatant_is_alive(combatant)


func _audio_poll_attack_actions() -> void:
    for combatant_value: Variant in _audio_combatants():
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        if combatant_id.is_empty():
            continue

        var current_serial: int = int(combatant.get("action_serial", 0))
        var previous_serial: int = int(_audio_action_serials.get(combatant_id, current_serial))
        _audio_action_serials[combatant_id] = current_serial
        if current_serial <= previous_serial:
            continue

        # Waiting/failed pseudo-actions do not get the attack cue. The central
        # battle runtime records genuine move attempts in db_last_move.
        var last_move_id: String = str(combatant.get("db_last_move", ""))
        if last_move_id.is_empty() or last_move_id.begins_with("__"):
            continue
        AudioManager.play_attack_sfx()


func _audio_poll_faint_states() -> void:
    for combatant_value: Variant in _audio_combatants():
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        if combatant_id.is_empty():
            continue

        var alive_now: bool = _audio_combatant_is_alive(combatant)
        if not _audio_alive_states.has(combatant_id):
            _audio_alive_states[combatant_id] = alive_now
            continue

        var alive_before: bool = bool(_audio_alive_states.get(combatant_id, alive_now))
        _audio_alive_states[combatant_id] = alive_now
        if alive_before and not alive_now:
            AudioManager.play_faint_sfx()


func _audio_handle_battle_end(session: int) -> void:
    var player_value: Variant = battle_demo.get("player_team")
    var enemy_value: Variant = battle_demo.get("enemy_team")
    var player_team_value: Array = player_value if player_value is Array else []
    var enemy_team_value: Array = enemy_value if enemy_value is Array else []

    var own_alive: bool = _audio_team_has_living_member(player_team_value)
    var enemy_alive: bool = _audio_team_has_living_member(enemy_team_value)

    # Route battles can briefly set battle_active=false while a living reserve is
    # being brought in. That is a wave transition, not a player defeat.
    if not own_alive and enemy_alive and _audio_route_has_living_reserve():
        return

    # Let the K.o. effect breathe before the major victory/defeat cue takes over.
    await get_tree().create_timer(BATTLE_END_CUE_DELAY_SECONDS).timeout
    if session != _audio_battle_session or _audio_battle_is_active():
        return

    if own_alive and not enemy_alive:
        AudioManager.play_victory(AudioManager.current_battle_kind)
    elif not own_alive:
        AudioManager.play_defeat()


func _audio_route_has_living_reserve() -> bool:
    if battle_demo == null or not bool(battle_demo.get("route_mode")):
        return false
    var route_team_value: Variant = battle_demo.get("_route_team_state")
    if not (route_team_value is Array):
        return false
    for member_value: Variant in route_team_value:
        if member_value is Dictionary and int((member_value as Dictionary).get("hp", 0)) > 0:
            return true
    return false


func _audio_team_has_living_member(team_value: Array) -> bool:
    for combatant_value: Variant in team_value:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if _audio_combatant_is_alive(combatant):
            return true
    return false


func _audio_combatant_is_alive(combatant: Dictionary) -> bool:
    return bool(combatant.get("alive", false)) and int(combatant.get("hp", 0)) > 0
