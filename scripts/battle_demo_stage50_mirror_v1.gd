extends "res://scripts/battle_demo_gen2_moves_v23_v1.gd"

# Wiederkehrender sichtbarer Ditto-Spiegelkampf auf Etappe 30/50/70/90.
#
# Der Route-Layer liefert echte Ditto-Gegner plus eine rein encounter-lokale
# Slot-Markierung. Dieser Battle-Layer unterdrueckt fuer genau diese Kaempfe die
# erste Runde-0-Erzeugung, sperrt Eingaben, laesst die Dittos kurz unverwandelt
# sichtbar und wendet danach die bereits zentrale Wandler-Implementierung auf
# Ditto N -> Spieler-Slot N an. Anschliessend wird Runde 0 aus den verwandelten
# Kampfprofilen neu aufgebaut und der normale Kampf uebernimmt vollstaendig.

const STAGE50_MIRROR_MARKER: String = "stage50_mirror"
const STAGE50_MIRROR_TARGET_SLOT: String = "stage50_mirror_target_slot"
const STAGE50_MIRROR_STAGE_KEY: String = "stage50_mirror_stage"
const STAGE50_MIRROR_DITTO_REVEAL_SECONDS: float = 0.50
const STAGE50_MIRROR_TRANSFORM_STEP_SECONDS: float = 0.42
const STAGE50_MIRROR_FINAL_HOLD_SECONDS: float = 0.24

var _stage50_mirror_setup_in_progress: bool = false
var _stage50_mirror_target_slots: Array[int] = []
var _stage50_mirror_intro_serial: int = 0
var _stage50_mirror_input_blocker: Control
var _stage50_mirror_stage: int = 50


func start_route_battle_party(team_state: Array, enemy_party: Array) -> void:
    _stage50_mirror_intro_serial += 1
    var serial: int = _stage50_mirror_intro_serial
    _stage50_remove_input_blocker()

    _stage50_mirror_target_slots = _stage50_extract_target_slots(enemy_party)
    _stage50_mirror_setup_in_progress = not _stage50_mirror_target_slots.is_empty()
    _stage50_mirror_stage = _stage50_extract_mirror_stage(enemy_party)

    super.start_route_battle_party(team_state, enemy_party)

    if (
        not _stage50_mirror_setup_in_progress
        or not battle_active
        or not route_mode
        or enemy_team.is_empty()
        or player_team.is_empty()
    ):
        _stage50_mirror_setup_in_progress = false
        _stage50_mirror_target_slots.clear()
        return

    # This happens synchronously before control returns to the player. Normal
    # Timeflow therefore cannot advance between battle construction and blocker.
    paused = true
    _stage50_install_input_blocker()
    _set_log(
        "[b]ETAPPE %d · SPIEGELKAMPF[/b]\n" % _stage50_mirror_stage
        + "Die gegnerischen Ditto richten sich auf dein Team aus …"
    )
    call_deferred("_stage50_run_mirror_intro", serial)


func _begin_opening_phase() -> void:
    if _stage50_mirror_setup_in_progress:
        # Runde 0 must be derived from the transformed move sets, never from
        # Ditto's original move set. Keep the battle fully frozen until then.
        opening_phase_active = false
        paused = true
        selected_actor = {}
        _opening_player_candidates.clear()
        _opening_enemy_candidates.clear()
        _opening_player_index = 0
        _opening_choices.clear()
        _clear_actions()
        return
    super._begin_opening_phase()


func _stage50_extract_target_slots(enemy_party: Array) -> Array[int]:
    if enemy_party.is_empty():
        return []

    var slots: Array[int] = []
    for enemy_value: Variant in enemy_party:
        if not (enemy_value is Dictionary):
            return []
        var enemy: Dictionary = enemy_value as Dictionary
        if not bool(enemy.get(STAGE50_MIRROR_MARKER, false)):
            return []
        slots.append(maxi(0, int(enemy.get(STAGE50_MIRROR_TARGET_SLOT, slots.size()))))
    return slots


func _stage50_extract_mirror_stage(enemy_party: Array) -> int:
    for enemy_value: Variant in enemy_party:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value as Dictionary
        if bool(enemy.get(STAGE50_MIRROR_MARKER, false)):
            return maxi(1, int(enemy.get(STAGE50_MIRROR_STAGE_KEY, 50)))
    return 50


func _stage50_install_input_blocker() -> void:
    _stage50_remove_input_blocker()
    if battle_panel == null:
        return

    var blocker := ColorRect.new()
    blocker.name = "MirrorBattleInputBlocker"
    blocker.color = Color(0.0, 0.0, 0.0, 0.0)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker.z_index = 1000
    battle_panel.add_child(blocker)
    _stage50_mirror_input_blocker = blocker


func _stage50_remove_input_blocker() -> void:
    if _stage50_mirror_input_blocker == null:
        return
    if is_instance_valid(_stage50_mirror_input_blocker):
        _stage50_mirror_input_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _stage50_mirror_input_blocker.queue_free()
    _stage50_mirror_input_blocker = null


func _stage50_run_mirror_intro(serial: int) -> void:
    await get_tree().create_timer(STAGE50_MIRROR_DITTO_REVEAL_SECONDS).timeout
    if not _stage50_mirror_intro_is_current(serial):
        return

    if not has_method("_ditto_apply_transform"):
        push_error(
            "Etappe %d: Zentrale Ditto/Wandler-Funktion fehlt im aktiven Battle-Stack."
            % _stage50_mirror_stage
        )
        _stage50_finish_mirror_intro(serial, false)
        return

    var pair_count: int = mini(enemy_team.size(), _stage50_mirror_target_slots.size())
    for enemy_index: int in range(pair_count):
        if not _stage50_mirror_intro_is_current(serial):
            return

        var target_slot: int = _stage50_mirror_target_slots[enemy_index]
        if target_slot < 0 or target_slot >= player_team.size():
            continue

        var enemy_value: Variant = enemy_team[enemy_index]
        var target_value: Variant = player_team[target_slot]
        if not (enemy_value is Dictionary) or not (target_value is Dictionary):
            continue

        var ditto: Dictionary = enemy_value as Dictionary
        var target: Dictionary = target_value as Dictionary

        # The central Wandler implementation correctly rejects K.O. targets in
        # ordinary combat. Mirror milestones copy team slots before combat,
        # including a travelling K.O. slot. Temporarily expose only the target's
        # alive flag so the same copy routine can read its battle profile; restore
        # the real K.O. state immediately afterwards.
        var target_alive_before: bool = bool(target.get("alive", false))
        if not target_alive_before:
            target["alive"] = true

        call("_ditto_apply_transform", ditto, target)

        if not target_alive_before:
            target["alive"] = false

        _refresh_cards()
        _set_log(
            "[b]WANDLER[/b] · Ditto %d spiegelt %s."
            % [enemy_index + 1, str(target.get("name", "Pokémon"))]
        )

        if enemy_index + 1 < pair_count:
            await get_tree().create_timer(STAGE50_MIRROR_TRANSFORM_STEP_SECONDS).timeout

    await get_tree().create_timer(STAGE50_MIRROR_FINAL_HOLD_SECONDS).timeout
    if not _stage50_mirror_intro_is_current(serial):
        return
    _stage50_finish_mirror_intro(serial, true)


func _stage50_mirror_intro_is_current(serial: int) -> bool:
    return (
        serial == _stage50_mirror_intro_serial
        and _stage50_mirror_setup_in_progress
        and battle_active
        and route_mode
    )


func _stage50_finish_mirror_intro(serial: int, transformed: bool) -> void:
    if serial != _stage50_mirror_intro_serial:
        return

    _stage50_remove_input_blocker()
    _stage50_mirror_setup_in_progress = false
    _stage50_mirror_target_slots.clear()

    # Discard any provisional opening state and rebuild it from the now copied
    # move sets. If nobody has a Runde-0 move, _begin_opening_phase() leaves the
    # normal ATB battle unpaused; otherwise it opens the established UI/AI flow.
    opening_phase_active = false
    paused = false
    selected_actor = {}
    _opening_player_candidates.clear()
    _opening_enemy_candidates.clear()
    _opening_player_index = 0
    _opening_choices.clear()
    _clear_actions()

    if transformed:
        _set_log(
            "[b]Der Spiegelkampf beginnt.[/b] Die Ditto behalten ihr eigenes "
            + "Level und ihre eigenen KP; ihre Kampfform stammt von deinem Team."
        )
    else:
        _set_log(
            "[b]Etappe %d[/b] konnte Wandler nicht vorbereiten. " % _stage50_mirror_stage
            + "Der Kampf wird ohne automatische Spiegelung fortgesetzt."
        )

    _begin_opening_phase()
