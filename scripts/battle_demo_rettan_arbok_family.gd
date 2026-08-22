extends "res://scripts/battle_demo_pidgey_family.gd"

# Rettan -> Arbok V4 TM runtime integration.
# The layer is intentionally generic: move-tag locks, temporary RPG-AP
# overrides and team-barrier clearing are reusable central mechanisms.

const MoveTagLock = preload("res://scripts/battle/move_tag_lock.gd")
const MoveApOverride = preload("res://scripts/battle/move_ap_override.gd")
const TeamBarrierState = preload("res://scripts/battle/team_barrier_state.gd")

var _tf_family_active_move_id: String = ""


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    MoveTagLock.ensure_state(combatant)
    MoveApOverride.ensure_state(combatant)
    combatant["tf_attribute_lowered_since_last_action"] = false
    combatant["tf_lash_out_armed"] = false
    combatant["tf_family_last_actual_damage"] = 0
    return combatant


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    var move: Dictionary = _move_data(move_id)
    if MoveTagLock.blocks_move(selected_actor, move):
        var remaining: int = MoveTagLock.remaining_actions(selected_actor, "sound")
        _set_log(_actor_name(selected_actor) + " kann unter Neck Strike keine Klangattacke einsetzen.")
        _spawn_feedback_label(
            selected_actor,
            "🔇 KLANG GESPERRT · " + str(remaining),
            Color("d9b0c8")
        )
        return
    super._choose_move(move_id)


func _rettan_arbok_allowed_moves(actor: Dictionary) -> Array:
    var result: Array = []
    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        return result
    for move_value: Variant in moves_value:
        var move_id: String = str(move_value)
        var move: Dictionary = _move_data(move_id)
        if move.is_empty():
            continue
        if not MoveTagLock.blocks_move(actor, move):
            result.append(move_id)
    return result


func _enemy_act(actor: Dictionary) -> void:
    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        super._enemy_act(actor)
        return

    var original: Array = (moves_value as Array).duplicate()
    var allowed: Array = _rettan_arbok_allowed_moves(actor)

    if allowed.is_empty() and not original.is_empty():
        selected_actor = actor
        _choose_wait()
        return

    if allowed.size() != original.size():
        actor["moves"] = allowed
        super._enemy_act(actor)
        actor["moves"] = original
        return
    super._enemy_act(actor)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    match kind:
        "db_move_ap_override":
            return _tf_apply_move_ap_override(actor, target, mechanic)
        "db_block_move_tag":
            return _tf_apply_move_tag_lock(actor, target, mechanic)
        "db_break_team_barriers":
            return _tf_break_team_barriers(actor, target)
        "db_drain_from_damage":
            return _tf_apply_drain(actor, mechanic)
        "db_pair_hp_average":
            return _tf_apply_pair_hp_average(actor, target, mechanic)

    var lowered_target: Dictionary = {}
    if _tf_is_attribute_lowering(mechanic):
        lowered_target = actor if str(mechanic.get("scope", "")) == "self" else target

    var effect_aggro: float = super._effect(actor, target, mechanic)
    if effect_aggro > 0.0 and not lowered_target.is_empty() and bool(lowered_target.get("alive", false)):
        lowered_target["tf_attribute_lowered_since_last_action"] = true
    return effect_aggro


func _tf_is_attribute_lowering(mechanic: Dictionary) -> bool:
    var kind: String = str(mechanic.get("kind", ""))
    var weight: float = float(mechanic.get("multiplier_from_special", 0.0))
    match kind:
        "outgoing_damage_mod":
            return weight < 0.0
        "incoming_damage_mod":
            return weight > 0.0
        "accuracy_mod":
            return weight < 0.0
        "atb_cycle_mod":
            return weight > 0.0
    return false


func _tf_apply_move_ap_override(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if not bool(target.get("alive", false)):
        return 0.0
    if _bulba_substitute_blocks_effect(actor, target, mechanic):
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return 0.0

    var fixed_ap: int = clampi(int(mechanic.get("ap", 8)), 1, 8)
    var duration: int = maxi(0, int(mechanic.get("duration_actions", 0)))
    if duration <= 0:
        return 0.0

    var old_remaining: int = MoveApOverride.remaining_actions(target)
    MoveApOverride.apply(target, fixed_ap, duration)
    var new_remaining: int = MoveApOverride.remaining_actions(target)
    var added_actions: int = maxi(0, new_remaining - old_remaining)

    _spawn_feedback_label(
        target,
        "👻 GROLL · " + str(new_remaining) + " AKTIONEN · " + str(fixed_ap) + " RPG-AP",
        Color("c9b6df")
    )
    return _hp_scaled_aggro(target, 0.10, added_actions) if added_actions > 0 else 0.0


func _tf_apply_move_tag_lock(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if not bool(target.get("alive", false)):
        return 0.0
    if _bulba_substitute_blocks_effect(actor, target, mechanic):
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return 0.0

    var tag: String = str(mechanic.get("tag", "")).strip_edges().to_lower()
    var duration: int = maxi(0, int(mechanic.get("duration_actions", 0)))
    if tag.is_empty() or duration <= 0:
        return 0.0

    var old_remaining: int = MoveTagLock.remaining_actions(target, tag)
    MoveTagLock.apply(target, tag, duration)
    var new_remaining: int = MoveTagLock.remaining_actions(target, tag)
    var added_actions: int = maxi(0, new_remaining - old_remaining)

    _spawn_feedback_label(
        target,
        "🔇 KLANG GESPERRT · " + str(new_remaining) + " AKTIONEN",
        Color("d9b0c8")
    )
    return _hp_scaled_aggro(target, 0.10, added_actions) if added_actions > 0 else 0.0


func _tf_break_team_barriers(actor: Dictionary, target: Dictionary) -> float:
    if not bool(target.get("alive", false)):
        return 0.0
    var broken_count: int = TeamBarrierState.break_opposing(actor, combatants)
    if broken_count > 0:
        _spawn_feedback_label(target, "🧠 TEAM-BARRIERE GEBROCHEN", Color("d9c4f0"))
        return 3.0
    return 0.0


func _tf_apply_drain(actor: Dictionary, mechanic: Dictionary) -> float:
    if not bool(actor.get("alive", false)):
        return 0.0
    var actual_damage: int = maxi(0, int(actor.get("tf_family_last_actual_damage", 0)))
    if actual_damage <= 0:
        return 0.0
    var fraction: float = clampf(float(mechanic.get("fraction", 0.0)), 0.0, 1.0)
    var requested: int = int(floor(float(actual_damage) * fraction))
    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    var healed: int = mini(missing, maxi(0, requested))
    if healed <= 0:
        return 0.0
    actor["hp"] = int(actor.get("hp", 0)) + healed
    _spawn_feedback_label(actor, "🩸 +" + str(healed) + " KP", Color("a9e6bd"))
    return float(healed)


func _tf_apply_pair_hp_average(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if not bool(actor.get("alive", false)) or not bool(target.get("alive", false)):
        return 0.0
    if _bulba_substitute_blocks_effect(actor, target, mechanic):
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return 0.0

    var actor_before: int = int(actor.get("hp", 0))
    var target_before: int = int(target.get("hp", 0))
    var shared_hp: int = int(floor(float(actor_before + target_before) / 2.0))
    var actor_after: int = mini(int(actor.get("max_hp", 1)), shared_hp)
    var target_after: int = mini(int(target.get("max_hp", 1)), shared_hp)

    actor["hp"] = actor_after
    target["hp"] = target_after

    var actor_heal: int = maxi(0, actor_after - actor_before)
    var target_damage: int = maxi(0, target_before - target_after)
    _spawn_feedback_label(actor, "⚖️ " + str(actor_after) + " KP", Color("d8d0b5"))
    _spawn_feedback_label(target, "⚖️ " + str(target_after) + " KP", Color("d8d0b5"))
    return float(actor_heal + target_damage)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var resolved_power: int = power
    if (
        _tf_family_active_move_id == "lash_out"
        and bool(actor.get("tf_lash_out_armed", false))
    ):
        resolved_power *= 2

    var dealt: int = super._damage(actor, target, resolved_power, move_type, category)
    if _tf_family_active_move_id == "leech_life" and dealt > 0:
        actor["tf_family_last_actual_damage"] = (
            int(actor.get("tf_family_last_actual_damage", 0)) + dealt
        )
    return dealt


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var original_move: Dictionary = _move_data(move_id).duplicate(true)
    var patched_ap: bool = false

    actor["tf_lash_out_armed"] = bool(actor.get("tf_attribute_lowered_since_last_action", false))
    actor["tf_attribute_lowered_since_last_action"] = false
    actor["tf_family_last_actual_damage"] = 0
    _tf_family_active_move_id = move_id

    if not original_move.is_empty() and MoveApOverride.remaining_actions(actor) > 0:
        var temporary_move: Dictionary = original_move.duplicate(true)
        var effective_ap: int = MoveApOverride.effective_ap(
            actor,
            int(original_move.get("ap", original_move.get("rpg_ap", 1)))
        )
        temporary_move["ap"] = effective_ap
        temporary_move["rpg_ap"] = effective_ap
        data["moves"][move_id] = temporary_move
        patched_ap = true

    super._execute_move(actor, move_id)

    if patched_ap:
        data["moves"][move_id] = original_move

    _tf_family_active_move_id = ""
    actor["tf_lash_out_armed"] = false
    actor["tf_family_last_actual_damage"] = 0
    MoveTagLock.prune(actor)
    MoveApOverride.prune(actor)


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    if not actor.is_empty():
        actor["tf_lash_out_armed"] = false
        actor["tf_attribute_lowered_since_last_action"] = false
    super._choose_wait()
    if not actor.is_empty():
        MoveTagLock.prune(actor)
        MoveApOverride.prune(actor)


func _database_consume_recharge(actor: Dictionary) -> void:
    actor["tf_lash_out_armed"] = false
    actor["tf_attribute_lowered_since_last_action"] = false
    super._database_consume_recharge(actor)
    MoveTagLock.prune(actor)
    MoveApOverride.prune(actor)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var sound_remaining: int = MoveTagLock.remaining_actions(combatant, "sound")
    if sound_remaining > 0:
        tokens.append("KLANG" + str(sound_remaining))
    var spite_remaining: int = MoveApOverride.remaining_actions(combatant)
    if spite_remaining > 0:
        tokens.append("GROLL" + str(spite_remaining))
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var text: String = super._detail_info(combatant)
    var sound_remaining: int = MoveTagLock.remaining_actions(combatant, "sound")
    var spite_remaining: int = MoveApOverride.remaining_actions(combatant)
    if sound_remaining <= 0 and spite_remaining <= 0:
        return text

    text += "\n\n[b]KONTROLLE[/b]"
    if sound_remaining > 0:
        text += (
            "\n• Klangattacken gesperrt: noch "
            + str(sound_remaining)
            + " eigene Aktion(en)."
        )
    if spite_remaining > 0:
        text += (
            "\n• Groll: noch "
            + str(spite_remaining)
            + " eigene Aktion(en); alle Attacken haben 8 RPG-AP."
        )
    return text


func _compact_effect_summary(move: Dictionary) -> String:
    match str(move.get("id", "")):
        "poison_tail":
            return "Stärke 50 · erhöhte Volltrefferchance · 10 % Vergiftung"
        "snarl":
            return "Alle Gegner · Angriff ↓ (Statuswert) · 3 eigene Zielaktionen"
        "psychic_fangs":
            return "Stärke 85 · zerstört gegnerische Team-Barrieren vor dem Schaden"
        "leech_life":
            return "Stärke 80 · heilt 50 % des tatsächlich verursachten Schadens"
        "spite":
            return "2 Zielaktionen: alle Attacken haben exakt 8 RPG-AP"
        "lash_out":
            return "Stärke 75 · 150 nach Attributsenkung seit der letzten eigenen Aktion"
        "scale_shot":
            return "2–5 Treffer · Geschwindigkeit ↑ · Verteidigung ↓ · 3 eigene Aktionen"
        "sludge_wave":
            return "Alle anderen aktiven Pokémon · 10 % Vergiftung pro getroffenem Ziel"
        "skitter_smack":
            return "Stärke 70 · Angriff des Ziels ↓ · 3 eigene Zielaktionen"
        "pain_split":
            return "Aktuelle KP von Anwender und Ziel möglichst gleichmäßig verteilen"
        "throat_chop":
            return "Stärke 80 · Klangattacken des Ziels 3 eigene Aktionen gesperrt"
    return super._compact_effect_summary(move)
