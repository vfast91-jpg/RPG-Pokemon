extends "res://scripts/battle_demo_squirtle_family.gd"

# Raupy -> Safcon -> Smettbo Gate-1 runtime integration.
# Reuses the central Timeflow systems for targeting, temporary modifiers,
# drain healing, flinch, Status soft-caps and Aggro wherever possible.

const CFAM_MANUAL_TARGET_MOVES: Array[String] = ["skill_swap", "pollen_puff"]
const CFAM_ECHO_POWERS: Array[int] = [40, 80, 120, 160, 200]
const CFAM_TIMED_STAT_KINDS: Array[String] = [
    "outgoing_damage_mod", "incoming_damage_mod", "accuracy_mod", "atb_cycle_mod"
]
const CFAM_SUMMARIES: Dictionary = {
    "electroweb": "alle Gegner · Genauigkeit je Ziel · Treffer: Geschwindigkeit ↓ (Statuswert) · 3 Zielaktionen",
    "iron_defense": "eigene Verteidigung stark ↑ (Statuswert) · 3 eigene Aktionen",
    "thief": "Schaden · heilt 50 % des tatsächlich verursachten KP-Schadens",
    "snore": "nur im Schlaf · Schaden · 30 % Zurückschrecken: aktuelle Zeitleiste auf 0 %",
    "attract": "3 Zielaktionen: Statuswert-basierte Chance auf Aktionsausfall · kein 50-%-Deckel",
    "u_turn": "Schaden · erfolgreicher Treffer setzt eigene Aggro auf 0",
    "echoed_voice": "teamweite Kette: Stärke 40 → 80 → 120 → 160 → 200 · 3 Teamaktionen Zeit",
    "draining_kiss": "Schaden · heilt 75 % des tatsächlich verursachten KP-Schadens",
    "psychic": "Schaden · 10 %: Verteidigung ↓ (Statuswert) · 3 Zielaktionen",
    "baton_pass": "alle temporären Attributsänderungen auf gewählten Verbündeten übertragen · Restdauer bleibt · eigene Aggro auf 0",
    "shadow_ball": "Schaden · 20 %: Verteidigung ↓ (Statuswert) · 3 Zielaktionen",
    "skill_swap": "temporäre positive und negative Attributsänderungen mit Ziel tauschen · Restdauer bleibt",
    "pollen_puff": "Gegner: Stärke 90 · Verbündeter: heilt 50 % Max-KP · keine Statuswert-Skalierung",
    "synthesis": "heilt 50 % der eigenen Max-KP · keine Statuswert-Skalierung",
    "roost": "heilt 50 % der eigenen Max-KP · Flug-Typ bis zur nächsten eigenen Aktion entfernt"
}

var _cfam_active_move_id: String = ""
var _cfam_selected_target_id: String = ""
var _cfam_pending_target_move_id: String = ""
var _cfam_pending_target_actor: Dictionary = {}
var _cfam_action_depth: int = 0
var _cfam_echo_used_this_action: bool = false
var _cfam_echo_used_index: int = 0
var _cfam_echo_state: Dictionary = {
    "player": {"next_index": 0, "remaining": 0},
    "enemy": {"next_index": 0, "remaining": 0}
}


func _start_battle() -> void:
    _cfam_reset_battle_state()
    super._start_battle()


func _cfam_reset_battle_state() -> void:
    _cfam_selected_target_id = ""
    _cfam_pending_target_move_id = ""
    _cfam_pending_target_actor = {}
    _cfam_action_depth = 0
    _cfam_echo_used_this_action = false
    _cfam_echo_used_index = 0
    _cfam_echo_state = {
        "player": {"next_index": 0, "remaining": 0},
        "enemy": {"next_index": 0, "remaining": 0}
    }


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["cfam_attract"] = {}
    return combatant


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return

    var actor: Dictionary = selected_actor
    if move_id == "snore" and str(actor.get("major_status", "")) != "sleep":
        _set_log("[b]Schnarcher[/b] kann nur im Schlaf eingesetzt werden.")
        _spawn_feedback_label(actor, "💤 NUR IM SCHLAF", Color("c8b9e8"))
        return

    if not CFAM_MANUAL_TARGET_MOVES.has(move_id):
        super._choose_move(move_id)
        return

    var choices: Array = _cfam_manual_target_choices(actor)
    if choices.size() <= 1:
        _cfam_selected_target_id = (
            str((choices[0] as Dictionary).get("id", "")) if choices.size() == 1 else ""
        )
        super._choose_move(move_id)
        return

    _cfam_pending_target_move_id = move_id
    _cfam_pending_target_actor = actor
    _clear_actions()
    _set_log(
        "[b]" + str(_move_data(move_id).get("name", move_id))
        + "[/b]: Ziel wählen."
    )

    for target_value: Variant in choices:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var same_side: bool = str(target.get("side", "")) == str(actor.get("side", ""))
        var button := Button.new()
        button.text = (
            ("🤝 Verbündeter: " if same_side else "🎯 Gegner: ")
            + _actor_name(target)
        )
        if move_id == "pollen_puff":
            button.tooltip_text = (
                "Heilt 50 % der Max-KP." if same_side
                else "Greift diesen Gegner mit Stärke 90 an."
            )
        else:
            button.tooltip_text = "Temporäre Attributsänderungen mit diesem Pokémon tauschen."
        button.pressed.connect(_cfam_choose_manual_target.bind(str(target.get("id", ""))))
        action_grid.add_child(button)

    var back := Button.new()
    back.text = "↩ Zurück"
    back.pressed.connect(_cfam_cancel_manual_target)
    action_grid.add_child(back)


func _cfam_choose_manual_target(target_id: String) -> void:
    if _cfam_pending_target_actor.is_empty() or _cfam_pending_target_move_id.is_empty():
        return
    _cfam_selected_target_id = target_id
    selected_actor = _cfam_pending_target_actor
    var move_id: String = _cfam_pending_target_move_id
    _cfam_pending_target_actor = {}
    _cfam_pending_target_move_id = ""
    super._choose_move(move_id)


func _cfam_cancel_manual_target() -> void:
    if _cfam_pending_target_actor.is_empty():
        return
    var actor: Dictionary = _cfam_pending_target_actor
    _cfam_pending_target_actor = {}
    _cfam_pending_target_move_id = ""
    _cfam_selected_target_id = ""
    _prompt_player(actor)


func _cfam_manual_target_choices(actor: Dictionary) -> Array:
    var result: Array = []
    var enemy: Dictionary = _highest_aggro(actor)
    if not enemy.is_empty():
        result.append(enemy)
    for ally_value: Variant in _bulba_living_other_allies(actor):
        if ally_value is Dictionary:
            result.append(ally_value)
    return result


func _targets(actor: Dictionary, rule: String) -> Array:
    if CFAM_MANUAL_TARGET_MOVES.has(_cfam_active_move_id) and not _cfam_selected_target_id.is_empty():
        var selected: Dictionary = _cfam_find_combatant(_cfam_selected_target_id)
        if not selected.is_empty() and bool(selected.get("alive", false)):
            return [selected]
    return super._targets(actor, rule)


func _enemy_act(actor: Dictionary) -> void:
    # Do not let the simple combat-lab AI select Schnarcher while awake.
    if str(actor.get("major_status", "")) != "sleep":
        var moves_value: Variant = actor.get("moves", [])
        if moves_value is Array and (moves_value as Array).has("snore"):
            var original: Array = (moves_value as Array).duplicate()
            var filtered: Array = []
            for move_value: Variant in original:
                if str(move_value) != "snore":
                    filtered.append(move_value)
            if not filtered.is_empty():
                actor["moves"] = filtered
                super._enemy_act(actor)
                actor["moves"] = original
                return
    super._enemy_act(actor)


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    super._choose_wait()
    if not actor.is_empty():
        _cfam_after_team_action(actor, false)
        _cfam_cleanup_attract(actor)


func _database_consume_recharge(actor: Dictionary) -> void:
    super._database_consume_recharge(actor)
    _cfam_after_team_action(actor, false)
    _cfam_cleanup_attract(actor)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    var outermost: bool = _cfam_action_depth == 0
    if outermost:
        _cfam_echo_used_this_action = false
        _cfam_echo_used_index = 0
        if _cfam_attract_blocks_action(actor):
            _cfam_consume_attract_block(actor, move_id)
            _cfam_after_team_action(actor, false)
            _cfam_cleanup_attract(actor)
            _cfam_selected_target_id = ""
            return

    _cfam_action_depth += 1
    if move_id == "snore":
        _cfam_execute_snore(actor)
    else:
        _cfam_execute_runtime_move(actor, move_id)
    _cfam_action_depth -= 1

    if outermost:
        _cfam_after_team_action(actor, _cfam_echo_used_this_action)
        _cfam_cleanup_attract(actor)
        _cfam_selected_target_id = ""


func _cfam_execute_snore(actor: Dictionary) -> void:
    var sleep_left: int = maxi(0, int(actor.get("db_sleep_actions", 0)))
    if str(actor.get("major_status", "")) != "sleep" or sleep_left <= 0:
        _cfam_execute_failed_move(actor, "snore", "💤 NUR IM SCHLAF")
        return

    actor["major_status"] = ""
    actor["db_sleep_actions"] = 0
    _cfam_execute_runtime_move(actor, "snore")

    if not bool(actor.get("alive", false)):
        return
    if not str(actor.get("major_status", "")).is_empty():
        return

    var remaining: int = maxi(0, sleep_left - 1)
    if remaining > 0:
        actor["major_status"] = "sleep"
        actor["db_sleep_actions"] = remaining
        _spawn_feedback_label(actor, "💤 SCHLAF · " + str(remaining), Color("c8b9e8"))
    else:
        _spawn_feedback_label(actor, "✨ WACHT AUF", Color("f0e7a6"))


func _cfam_execute_failed_move(actor: Dictionary, move_id: String, feedback: String) -> void:
    var source: Dictionary = _move_data(move_id)
    if source.is_empty():
        return
    var failed: Dictionary = source.duplicate(true)
    failed["power"] = null
    failed["accuracy"] = null
    failed["mechanics"] = []
    failed["effects"] = []
    data["moves"][move_id] = failed
    super._execute_move(actor, move_id)
    data["moves"][move_id] = source
    _spawn_feedback_label(actor, feedback, Color("c8b9e8"))


func _cfam_execute_runtime_move(actor: Dictionary, move_id: String) -> void:
    var source: Dictionary = _move_data(move_id)
    if source.is_empty():
        super._execute_move(actor, move_id)
        return

    var working: Dictionary = source.duplicate(true)
    var runtime_value: Variant = source.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    _cfam_active_move_id = move_id

    if bool(runtime.get("timeflow_echoed_voice", false)):
        var echo_index: int = _cfam_echo_index(str(actor.get("side", "")))
        working["power"] = CFAM_ECHO_POWERS[echo_index]
        _cfam_echo_used_index = echo_index

    if move_id == "pollen_puff":
        var selected: Dictionary = _cfam_find_combatant(_cfam_selected_target_id)
        if (
            not selected.is_empty()
            and str(selected.get("side", "")) == str(actor.get("side", ""))
        ):
            working["power"] = null
            working["accuracy"] = null
            working["category"] = "status"
            working["mechanics"] = []
            working["effects"] = []

    if bool(runtime.get("timeflow_per_target_accuracy", false)):
        var initial_targets: Array = _targets(actor, str(working.get("target", "all_enemies")))
        _sf_prepare_per_target_accuracy(actor, working, initial_targets)

    data["moves"][move_id] = working
    var snapshots: Dictionary = _cfam_snapshot_targets(actor, working)

    super._execute_move(actor, move_id)

    var attempted: bool = _database_move_was_attempted(move_id)
    var hit_success: bool = _cfam_any_hit(snapshots)
    var actual_damage: int = _cfam_actual_hp_damage(snapshots)

    if attempted and bool(runtime.get("timeflow_echoed_voice", false)):
        _cfam_echo_used_this_action = true

    var drain_fraction: float = float(runtime.get("timeflow_drain_fraction", 0.0))
    if actual_damage > 0 and drain_fraction > 0.0:
        _bulba_apply_drain_heal(actor, actual_damage, drain_fraction)

    if hit_success and bool(runtime.get("timeflow_aggro_reset_on_hit", false)):
        actor["aggro"] = 0.0
        _spawn_feedback_label(actor, "🔄 AGGRO → 0", Color("b9d7ff"))

    var custom_success: bool = false
    if attempted and move_id == "attract":
        custom_success = _cfam_apply_attract(actor, snapshots)
    elif attempted and move_id == "baton_pass":
        custom_success = _cfam_transfer_modifiers(actor, snapshots)
    elif attempted and move_id == "skill_swap":
        custom_success = _cfam_swap_modifiers(actor, snapshots)
    elif attempted and move_id == "pollen_puff":
        custom_success = _cfam_finish_pollen_puff(actor, snapshots)

    if custom_success and bool(runtime.get("timeflow_user_aggro_zero_on_success", false)):
        actor["aggro"] = 0.0
        _spawn_feedback_label(actor, "🔁 AGGRO → 0", Color("b9d7ff"))

    data["moves"][move_id] = source
    _cfam_active_move_id = ""
    _refresh_cards()


func _cfam_snapshot_targets(actor: Dictionary, move: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for target_value: Variant in _targets(actor, str(move.get("target", "enemy_highest_aggro"))):
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        result[str(target.get("id", ""))] = {
            "target": target,
            "hp": int(target.get("hp", 0)),
            "substitute_hp": int(target.get("db_substitute_hp", 0)),
            "protective_guard": bool(target.get("protective_guard", false))
        }
    return result


func _cfam_first_snapshot_target(snapshots: Dictionary) -> Dictionary:
    for entry_value: Variant in snapshots.values():
        if entry_value is Dictionary:
            var target_value: Variant = (entry_value as Dictionary).get("target", {})
            if target_value is Dictionary:
                return target_value as Dictionary
    return {}


func _cfam_any_hit(snapshots: Dictionary) -> bool:
    for entry_value: Variant in snapshots.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var target_value: Variant = entry.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if int(target.get("hp", 0)) < int(entry.get("hp", 0)):
            return true
        if int(target.get("db_substitute_hp", 0)) < int(entry.get("substitute_hp", 0)):
            return true
    return false


func _cfam_actual_hp_damage(snapshots: Dictionary) -> int:
    var total: int = 0
    for entry_value: Variant in snapshots.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var target_value: Variant = entry.get("target", {})
        if target_value is Dictionary:
            total += maxi(
                0,
                int(entry.get("hp", 0)) - int((target_value as Dictionary).get("hp", 0))
            )
    return total


func _cfam_hostile_custom_blocked(
    actor: Dictionary,
    target: Dictionary,
    mechanic_kind: String
) -> bool:
    if str(actor.get("side", "")) == str(target.get("side", "")):
        return false
    if _tm_guard_blocks(actor, target):
        return true
    if _bulba_substitute_blocks_effect(actor, target, {"kind": mechanic_kind}):
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return true
    return false


func _cfam_apply_attract(actor: Dictionary, snapshots: Dictionary) -> bool:
    var target: Dictionary = _cfam_first_snapshot_target(snapshots)
    if target.is_empty() or not bool(target.get("alive", false)):
        return false
    if _cfam_hostile_custom_blocked(actor, target, "status"):
        return false

    var chance: float = _status_ratio(float(actor.get("special", 0.0)))
    target["cfam_attract"] = {
        "chance": chance,
        "source_name": _actor_name(actor),
        "expires_after_action": int(target.get("action_serial", 0)) + 3
    }
    actor["aggro"] = (
        float(actor.get("aggro", 0.0))
        + _hp_scaled_aggro(target, 0.10, 3) * chance
    )
    _spawn_feedback_label(
        target,
        "💘 BETÖRT · %.0f%% · 3 AKTIONEN" % (chance * 100.0),
        Color("f1a8d3")
    )
    return true


func _cfam_attract_blocks_action(actor: Dictionary) -> bool:
    if not _cfam_attract_active(actor):
        return false
    var effect: Dictionary = actor.get("cfam_attract", {})
    return randf() < clampf(float(effect.get("chance", 0.0)), 0.0, 0.999999)


func _cfam_attract_active(actor: Dictionary) -> bool:
    var value: Variant = actor.get("cfam_attract", {})
    if not (value is Dictionary) or (value as Dictionary).is_empty():
        return false
    var effect: Dictionary = value
    if int(actor.get("action_serial", 0)) >= int(effect.get("expires_after_action", 0)):
        actor["cfam_attract"] = {}
        return false
    return true


func _cfam_cleanup_attract(actor: Dictionary) -> void:
    _cfam_attract_active(actor)


func _cfam_consume_attract_block(actor: Dictionary, move_id: String) -> void:
    var selected_move: Dictionary = _move_data(move_id)
    var ap: int = maxi(1, int(selected_move.get("ap", 1)))
    var fake_id: String = "__timeflow_attract_block"
    var previous: Variant = data["moves"].get(fake_id, null)
    data["moves"][fake_id] = {
        "id": fake_id,
        "name": "Betört",
        "description": "Das Pokémon ist betört und kann diese Aktion nicht handeln.",
        "emoji": "💘",
        "type": "normal",
        "category": "status",
        "power": null,
        "accuracy": null,
        "ap": ap,
        "target": "self",
        "area": false,
        "contact": false,
        "priority": 0,
        "opening": false,
        "mechanics": []
    }
    super._execute_move(actor, fake_id)
    if previous == null:
        data["moves"].erase(fake_id)
    else:
        data["moves"][fake_id] = previous
    _set_log(_actor_name(actor) + " ist betört und kann nicht handeln.")
    _spawn_feedback_label(actor, "💘 AKTION VERLOREN", Color("f1a8d3"))


func _cfam_transfer_modifiers(actor: Dictionary, snapshots: Dictionary) -> bool:
    var target: Dictionary = _cfam_first_snapshot_target(snapshots)
    if target.is_empty() or str(target.get("side", "")) != str(actor.get("side", "")):
        return false
    if str(target.get("id", "")) == str(actor.get("id", "")):
        return false

    var transferred: Array = _cfam_rebase_modifier_set(actor, target)
    var existing_value: Variant = target.get("timed_modifiers", [])
    var combined: Array = existing_value.duplicate(true) if existing_value is Array else []
    for modifier_value: Variant in transferred:
        combined.append(modifier_value)
    target["timed_modifiers"] = combined
    actor["timed_modifiers"] = []

    _spawn_feedback_label(
        target,
        "🔁 " + str(transferred.size()) + " EFFEKT(E) ÜBERTRAGEN",
        Color("b9d7ff")
    )
    return true


func _cfam_swap_modifiers(actor: Dictionary, snapshots: Dictionary) -> bool:
    var target: Dictionary = _cfam_first_snapshot_target(snapshots)
    if target.is_empty() or str(target.get("id", "")) == str(actor.get("id", "")):
        return false
    if _cfam_hostile_custom_blocked(actor, target, "status"):
        return false

    var actor_to_target: Array = _cfam_rebase_modifier_set(actor, target)
    var target_to_actor: Array = _cfam_rebase_modifier_set(target, actor)
    var effect_aggro: float = _all_timed_modifier_aggro(actor) + _all_timed_modifier_aggro(target)

    actor["timed_modifiers"] = target_to_actor
    target["timed_modifiers"] = actor_to_target
    actor["aggro"] = float(actor.get("aggro", 0.0)) + effect_aggro

    _spawn_feedback_label(actor, "🔀 EFFEKTE GETAUSCHT", Color("c8b9e8"))
    _spawn_feedback_label(target, "🔀 EFFEKTE GETAUSCHT", Color("c8b9e8"))
    return true


func _cfam_rebase_modifier_set(source: Dictionary, target: Dictionary) -> Array:
    var result: Array = []
    var value: Variant = source.get("timed_modifiers", [])
    if not (value is Array):
        return result

    var source_action: int = int(source.get("action_serial", 0))
    var target_action: int = int(target.get("action_serial", 0))
    for modifier_value: Variant in value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if not CFAM_TIMED_STAT_KINDS.has(str(modifier.get("kind", ""))):
            continue
        var remaining: int = maxi(
            0,
            int(modifier.get("expires_after_action", source_action)) - source_action
        )
        if remaining <= 0:
            continue
        var moved: Dictionary = modifier.duplicate(true)
        moved["expires_after_action"] = target_action + remaining
        result.append(moved)
    return result


func _cfam_finish_pollen_puff(actor: Dictionary, snapshots: Dictionary) -> bool:
    var target: Dictionary = _cfam_first_snapshot_target(snapshots)
    if target.is_empty():
        return false
    if str(target.get("side", "")) != str(actor.get("side", "")):
        return false
    if str(target.get("id", "")) == str(actor.get("id", "")):
        return false

    var missing: int = maxi(
        0,
        int(target.get("max_hp", 1)) - int(target.get("hp", 0))
    )
    if missing <= 0:
        _spawn_feedback_label(target, "💚 KP BEREITS VOLL", Color("8fe39b"))
        return true
    var requested: int = maxi(
        1,
        int(round(float(target.get("max_hp", 1)) * 0.50))
    )
    var healed: int = mini(missing, requested)
    target["hp"] = int(target.get("hp", 0)) + healed
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(healed)
    _spawn_feedback_label(target, "🌼 +" + str(healed) + " KP", Color("8fe39b"))
    return true


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if (
        str(mechanic.get("kind", "")) == "db_heal_self"
        and mechanic.has("fraction_max_hp")
    ):
        return _cfam_heal_fraction_max_hp(actor, float(mechanic.get("fraction_max_hp", 0.5)))
    return super._effect(actor, target, mechanic)


func _cfam_heal_fraction_max_hp(actor: Dictionary, fraction: float) -> float:
    var missing: int = maxi(
        0,
        int(actor.get("max_hp", 1)) - int(actor.get("hp", 0))
    )
    if missing <= 0:
        return 0.0
    var requested: int = maxi(
        1,
        int(round(float(actor.get("max_hp", 1)) * clampf(fraction, 0.0, 1.0)))
    )
    var healed: int = mini(missing, requested)
    actor["hp"] = int(actor.get("hp", 0)) + healed
    _spawn_feedback_label(actor, "💚 +" + str(healed) + " KP", Color("8fe39b"))
    return float(healed)


func _cfam_echo_index(side: String) -> int:
    var state_value: Variant = _cfam_echo_state.get(side, {})
    if not (state_value is Dictionary):
        return 0
    var state: Dictionary = state_value as Dictionary
    if int(state.get("remaining", 0)) <= 0:
        return 0
    return clampi(int(state.get("next_index", 0)), 0, CFAM_ECHO_POWERS.size() - 1)


func _cfam_after_team_action(actor: Dictionary, echoed_voice_used: bool) -> void:
    var side: String = str(actor.get("side", ""))
    if not _cfam_echo_state.has(side):
        return
    var state_value: Variant = _cfam_echo_state[side]
    if not (state_value is Dictionary):
        return
    var state: Dictionary = state_value as Dictionary

    if echoed_voice_used:
        state["next_index"] = mini(CFAM_ECHO_POWERS.size() - 1, _cfam_echo_used_index + 1)
        state["remaining"] = 3
    elif int(state.get("remaining", 0)) > 0:
        state["remaining"] = maxi(0, int(state.get("remaining", 0)) - 1)
        if int(state.get("remaining", 0)) <= 0:
            state["next_index"] = 0

    _cfam_echo_state[side] = state


func _cfam_find_combatant(combatant_id: String) -> Dictionary:
    if combatant_id.is_empty():
        return {}
    for value: Variant in combatants:
        if value is Dictionary and str((value as Dictionary).get("id", "")) == combatant_id:
            return value as Dictionary
    return {}


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if CFAM_SUMMARIES.has(move_id):
        return str(CFAM_SUMMARIES[move_id])
    return super._compact_effect_summary(move)


func _move_tooltip(move: Dictionary) -> String:
    var text: String = super._move_tooltip(move)
    var move_id: String = str(move.get("id", ""))
    if not CFAM_SUMMARIES.has(move_id):
        return text
    var summary: String = str(CFAM_SUMMARIES[move_id])
    if not text.contains(summary):
        text = text.strip_edges() + "\nEffekt: " + summary
    return _final_attack_text(text)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if _cfam_attract_active(combatant):
        tokens.append("💘 BETÖRT")
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var detail: String = super._detail_info(combatant)
    if not _cfam_attract_active(combatant):
        return detail
    var effect: Dictionary = combatant.get("cfam_attract", {})
    var remaining: int = maxi(
        0,
        int(effect.get("expires_after_action", 0))
        - int(combatant.get("action_serial", 0))
    )
    detail += (
        "\n\n💘 Anziehung: %.0f %% Aktionsausfall · noch %d eigene Aktion(en)"
        % [float(effect.get("chance", 0.0)) * 100.0, remaining]
    )
    return detail
