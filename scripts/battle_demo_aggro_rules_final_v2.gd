extends "res://scripts/battle_demo_accuracy_null_guard_v1.gd"

# Final active Aggro contract.
#
# The inherited combat stack remains responsible for move behavior. This layer
# observes the state transition of each resolved effect and replaces legacy
# effect-Aggro with the central, level-scaled value. Direct damage, healing,
# status mechanics and target selection are not changed here.

const AggroRulesCore = preload("res://scripts/battle/aggro_rules.gd")
const AreaDamageRulesCore = preload("res://scripts/battle/area_damage_rules.gd")

const ZERO_CAST_AGGRO_KINDS: Array[String] = [
    "seed",
    "binding",
    "weather",
    "db_toxic_spikes",
    "db_spikes",
    "db_stealth_rock",
    "db_electric_terrain",
    "db_psychic_terrain",
    "db_grassy_terrain"
]
const CORE_STATUS_KINDS: Array[String] = ["status", "db_status"]
const CORE_ATB_KINDS: Array[String] = ["atb_knockback", "flinch"]

var _aggro_effect_depth: int = 0
var _aggro_move_context: Dictionary = {}
var _aggro_active_actor: Dictionary = {}
var _aggro_choice_bypass: bool = false
var _aggro_front_combo_actor_id: String = ""
var _aggro_front_combo_move_id: String = ""


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var previous_context: Dictionary = _aggro_move_context
    var previous_actor: Dictionary = _aggro_active_actor
    _aggro_move_context = _move_data(move_id)
    _aggro_active_actor = actor

    var combo_requested: bool = (
        str(actor.get("id", "")) == _aggro_front_combo_actor_id
        and move_id == _aggro_front_combo_move_id
    )
    var aggro_before_move: float = float(actor.get("aggro", 0.0))

    super._execute_move(actor, move_id)

    # A complete miss has no combat effect and therefore must never inherit an
    # Aggro side effect from one of the many older, move-specific runtime
    # layers. The resolved outcome is assigned by the central move-result layer
    # below us, after all special move hooks have finished.
    if str(actor.get("tf_last_move_outcome", "")) == "miss":
        actor["aggro"] = aggro_before_move
        _refresh_cards()

    if combo_requested and _database_move_was_attempted(move_id):
        var after_defense: float = float(actor.get("aggro", 0.0))
        actor["aggro"] = maxf(1.0, after_defense * 2.0)
        _set_log(
            _actor_name(actor) + " verstärkt sich und geht nach vorne: Aggro %.0f → %.0f → %.0f."
            % [aggro_before_move, after_defense, float(actor.get("aggro", 0.0))]
        )
        _refresh_cards()

    if combo_requested:
        _aggro_front_combo_actor_id = ""
        _aggro_front_combo_move_id = ""
    _aggro_move_context = previous_context
    _aggro_active_actor = previous_actor


func _status_effect_aggro(kind: String, multiplier: float) -> float:
    # Older specialist hooks call this helper outside _effect(). Keep their
    # real multiplier, but value it with the final B × delta × 3 × 0.50 rule.
    if _aggro_active_actor.is_empty():
        return super._status_effect_aggro(kind, multiplier)
    var performance: float = multiplier
    if kind in ["incoming_damage_mod", "atb_cycle_mod"]:
        performance = 1.0 / maxf(0.0001, multiplier)
    return (
        AggroRulesCore.level_basis(_aggro_active_actor)
        * absf(performance - 1.0)
        * 3.0
        * AggroRulesCore.MODIFIER_ACTION_WEIGHT
    )


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    # Nested chance/wrapper mechanics call _effect again. Only the outer call
    # snapshots and values the complete resulting transition, preventing both
    # double valuation and double spread scaling.
    if _aggro_effect_depth > 0:
        return super._effect(actor, target, mechanic)

    _aggro_effect_depth += 1
    var before: Dictionary = _aggro_combat_snapshots()
    var legacy_aggro: float = super._effect(actor, target, mechanic)
    var after: Dictionary = _aggro_combat_snapshots()
    _aggro_effect_depth -= 1

    var valuation: Dictionary = _aggro_transition_value(
        actor,
        mechanic,
        before,
        after
    )
    var spread: float = _aggro_effect_spread_multiplier(actor)
    if bool(valuation.get("handled", false)):
        # Actual hostile HP damage has already passed through the central damage
        # scaler. All non-damage effect value uses the same table exactly once.
        return (
            float(valuation.get("damage", 0.0))
            + float(valuation.get("scalable", 0.0)) * spread
        )
    if _aggro_is_free_placement_kind(str(mechanic.get("kind", ""))):
        return 0.0
    if legacy_aggro > 0.0:
        # Several older specialist moves still report +3/+4/+5 from their own
        # implementation. The number is used only as a success signal; the
        # award itself is replaced by the central level-scaled utility value.
        return AggroRulesCore.utility_effect(target) * spread
    return 0.0


func _aggro_transition_value(
    actor: Dictionary,
    mechanic: Dictionary,
    before: Dictionary,
    after: Dictionary
) -> Dictionary:
    var kind: String = str(mechanic.get("kind", ""))
    var handled: bool = (
        kind in ZERO_CAST_AGGRO_KINDS
        or kind in CORE_STATUS_KINDS
        or kind in CORE_ATB_KINDS
        or kind in AggroRulesCore.MODIFIER_KINDS
        or kind in [
            "db_chance_mechanic", "db_team_modifier", "db_on_ko_modifier",
            "db_stockpile", "db_team_cleanse", "db_team_immunity",
            "db_clear_all_temporary_modifiers", "db_cleanse_positive_modifiers",
            "db_heal_self", "db_swallow", "db_equalize_hp",
            "db_fraction_hp_damage", "db_spit_up"
        ]
    )
    var damage_aggro: float = 0.0
    var scalable_aggro: float = 0.0
    var actor_side: String = str(actor.get("side", ""))

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        var before_state_value: Variant = before.get(combatant_id, {})
        var after_state_value: Variant = after.get(combatant_id, {})
        if not (before_state_value is Dictionary) or not (after_state_value is Dictionary):
            continue
        var before_state: Dictionary = before_state_value
        var after_state: Dictionary = after_state_value
        var allied: bool = str(combatant.get("side", "")) == actor_side

        var hp_before: int = int(before_state.get("hp", 0))
        var hp_after: int = int(after_state.get("hp", 0))
        if hp_after < hp_before and not allied:
            damage_aggro += float(hp_before - hp_after)
            handled = true
        elif hp_after > hp_before and allied:
            scalable_aggro += float(hp_after - hp_before)
            handled = true

        var modifier_aggro: float = AggroRulesCore.modifier_transition(
            combatant,
            int(after_state.get("action_serial", 0)),
            before_state.get("timed_modifiers", []),
            after_state.get("timed_modifiers", []),
            allied
        )
        if modifier_aggro > 0.0:
            scalable_aggro += modifier_aggro
            handled = true

        var before_status: String = _aggro_snapshot_status(before_state)
        var after_status: String = _aggro_snapshot_status(after_state)
        if not allied and not after_status.is_empty():
            var added_status_actions: int = _aggro_added_status_actions(
                after_status,
                before_state,
                after_state
            )
            if before_status != after_status or added_status_actions > 0:
                scalable_aggro += AggroRulesCore.status_application(
                    combatant,
                    after_status,
                    added_status_actions
                )
                handled = true

        if allied and not before_status.is_empty() and before_status != after_status:
            scalable_aggro += AggroRulesCore.status_cleanse(
                combatant,
                before_status,
                _aggro_remaining_status_actions(before_status, before_state)
            )
            handled = true

        var before_confusion: int = int(before_state.get("confused_turns", 0))
        var after_confusion: int = int(after_state.get("confused_turns", 0))
        if not allied and after_confusion > before_confusion:
            scalable_aggro += AggroRulesCore.status_application(
                combatant,
                "confusion",
                after_confusion - before_confusion
            )
            handled = true
        elif allied and before_confusion > 0 and after_confusion == 0:
            scalable_aggro += AggroRulesCore.status_cleanse(
                combatant,
                "confusion",
                before_confusion
            )
            handled = true

        var removed_atb: float = maxf(
            0.0,
            float(before_state.get("atb", 0.0)) - float(after_state.get("atb", 0.0))
        )
        if not allied and removed_atb > 0.0:
            scalable_aggro += AggroRulesCore.direct_atb_removal(combatant, removed_atb)
            handled = true

        var immunity_aggro: float = AggroRulesCore.status_protection_transition(
            combatant,
            int(after_state.get("action_serial", 0)),
            before_state.get("db_status_immunities", []),
            after_state.get("db_status_immunities", [])
        )
        if allied and immunity_aggro > 0.0:
            scalable_aggro += immunity_aggro
            handled = true

    if kind in ZERO_CAST_AGGRO_KINDS:
        # Placement itself is free; later real damage/healing is credited by its
        # owner. No legacy placement award may leak through.
        damage_aggro = 0.0
        scalable_aggro = 0.0

    return {
        "handled": handled,
        "damage": damage_aggro,
        "scalable": scalable_aggro
    }


func _aggro_combat_snapshots() -> Dictionary:
    var result: Dictionary = {}
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        result[str(combatant.get("id", ""))] = {
            "hp": int(combatant.get("hp", 0)),
            "atb": float(combatant.get("atb", 0.0)),
            "action_serial": int(combatant.get("action_serial", 0)),
            "major_status": str(combatant.get("major_status", "")),
            "paralyzed": bool(combatant.get("paralyzed", false)),
            "confused_turns": maxi(0, int(combatant.get("confused_turns", 0))),
            "db_sleep_actions": maxi(0, int(combatant.get("db_sleep_actions", 0))),
            "zf_freeze_actions": maxi(0, int(combatant.get("zf_freeze_actions", 0))),
            "timed_modifiers": _aggro_duplicate_array(combatant.get("timed_modifiers", [])),
            "db_status_immunities": _aggro_duplicate_array(combatant.get("db_status_immunities", []))
        }
    return result


func _aggro_duplicate_array(value: Variant) -> Array:
    return (value as Array).duplicate(true) if value is Array else []


func _aggro_snapshot_status(snapshot: Dictionary) -> String:
    var major: String = str(snapshot.get("major_status", ""))
    if major == "toxic":
        return "bad_poison"
    if not major.is_empty():
        return major
    return "paralysis" if bool(snapshot.get("paralyzed", false)) else ""


func _aggro_added_status_actions(
    status_id: String,
    before_state: Dictionary,
    after_state: Dictionary
) -> int:
    match status_id:
        "sleep":
            return maxi(
                0,
                int(after_state.get("db_sleep_actions", 0))
                - int(before_state.get("db_sleep_actions", 0))
            )
        "freeze":
            return maxi(
                0,
                int(after_state.get("zf_freeze_actions", 0))
                - int(before_state.get("zf_freeze_actions", 0))
            )
    # Fixed-duration statuses such as paralysis, poison and burn receive their
    # value through the status transition itself. Returning one here would make
    # an unchanged reapplication look like a newly added action.
    return 0


func _aggro_remaining_status_actions(status_id: String, state: Dictionary) -> int:
    match status_id:
        "sleep":
            return maxi(0, int(state.get("db_sleep_actions", 0)))
        "freeze":
            return maxi(0, int(state.get("zf_freeze_actions", 0)))
    return 1


func _aggro_effect_spread_multiplier(actor: Dictionary) -> float:
    var move: Dictionary = _aggro_move_context
    if move.is_empty():
        move = _area_damage_active_move()
    if move.is_empty() or not AreaDamageRulesCore.move_uses_central_scaling(move):
        return 1.0
    return _area_damage_multiplier_for_resolution(actor, move)


func _aggro_is_free_placement_kind(kind: String) -> bool:
    if kind in ZERO_CAST_AGGRO_KINDS:
        return true
    var normalized: String = kind.to_lower()
    return (
        normalized.contains("weather")
        or normalized.contains("terrain")
        or normalized.contains("trick_room")
        or normalized.contains("spikes")
        or normalized.contains("stealth_rock")
        or normalized.contains("sticky_web")
    )


func _choose_move(move_id: String) -> void:
    if (
        not _aggro_choice_bypass
        and not selected_actor.is_empty()
        and _aggro_is_defensive_self_boost(_move_data(move_id))
    ):
        _aggro_show_defense_front_choice(selected_actor, move_id)
        return
    super._choose_move(move_id)


func _aggro_show_defense_front_choice(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    var current: float = float(actor.get("aggro", 0.0))
    var estimated_gain: float = _aggro_estimated_defense_gain(actor, move)
    var after_boost: float = current + estimated_gain

    _clear_actions()
    _set_log(
        "[b]%s[/b]\nAggro voraussichtlich: %.0f → %.0f; mit VORNE! danach → %.0f."
        % [str(move.get("name", move_id)), current, after_boost, maxf(1.0, after_boost * 2.0)]
    )

    var boost_only := Button.new()
    boost_only.text = "Nur verstärken"
    boost_only.custom_minimum_size = Vector2(176, 36)
    boost_only.pressed.connect(_aggro_choose_defense_only.bind(move_id))
    action_grid.add_child(boost_only)
    _style_action_button(boost_only, str(move.get("type", "typeless")), true)

    var boost_front := Button.new()
    boost_front.text = "🛡 Verstärken und nach vorne"
    boost_front.custom_minimum_size = Vector2(176, 36)
    boost_front.pressed.connect(_aggro_choose_defense_front.bind(move_id))
    action_grid.add_child(boost_front)
    _style_action_button(boost_front, "typeless", true)


func _aggro_choose_defense_only(move_id: String) -> void:
    _aggro_choice_bypass = true
    _choose_move(move_id)
    _aggro_choice_bypass = false


func _aggro_choose_defense_front(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    _aggro_front_combo_actor_id = str(selected_actor.get("id", ""))
    _aggro_front_combo_move_id = move_id
    _aggro_choice_bypass = true
    _choose_move(move_id)
    _aggro_choice_bypass = false


func _aggro_is_defensive_self_boost(move: Dictionary) -> bool:
    if move.is_empty() or str(move.get("target", "")) != "self":
        return false
    if move.get("power", null) != null:
        return false
    for list_key: String in ["mechanics", "effects"]:
        var entries_value: Variant = move.get(list_key, [])
        if not (entries_value is Array):
            continue
        for entry_value: Variant in entries_value:
            if not (entry_value is Dictionary):
                continue
            var entry: Dictionary = entry_value
            if (
                str(entry.get("kind", "")) == "incoming_damage_mod"
                and float(entry.get("multiplier_from_special", 0.0)) < 0.0
            ):
                return true
    return false


func _aggro_estimated_defense_gain(actor: Dictionary, move: Dictionary) -> float:
    var before: Array = _aggro_duplicate_array(actor.get("timed_modifiers", []))
    var after: Array = before.duplicate(true)
    var old_move_type: String = _active_move_type
    _active_move_type = str(move.get("type", "normal"))
    for mechanic_value: Variant in move.get("mechanics", []):
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        if str(mechanic.get("kind", "")) != "incoming_damage_mod":
            continue
        if float(mechanic.get("multiplier_from_special", 0.0)) >= 0.0:
            continue
        var duration: int = maxi(1, int(mechanic.get("duration_actions", 3)))
        after.append({
            "kind": "incoming_damage_mod",
            "multiplier": _status_modifier_multiplier(
                actor,
                mechanic,
                "incoming_damage_mod"
            ),
            "expires_after_action": int(actor.get("action_serial", 0)) + duration
        })
    _active_move_type = old_move_type
    return AggroRulesCore.modifier_transition(
        actor,
        int(actor.get("action_serial", 0)),
        before,
        after,
        true
    )
