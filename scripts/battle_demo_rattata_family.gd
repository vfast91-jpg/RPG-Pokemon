extends "res://scripts/battle_demo_pidgey_family.gd"

# Rattfratz -> Rattikarl V4 runtime integration.
# Schockwelle uses the existing accuracy=null always-hit path, Ladestrahl uses
# the existing central post-hit self-attack-buff runtime, and Stärke is standard
# damage. Only Verhöhner needs a new generic move-category lock state.

const MoveCategoryLock = preload("res://scripts/battle/move_category_lock.gd")


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    MoveCategoryLock.ensure_state(combatant)
    return combatant


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return
    var move: Dictionary = _move_data(move_id)
    var category: String = str(move.get("category", ""))
    if MoveCategoryLock.blocks(selected_actor, category):
        var remaining: int = MoveCategoryLock.remaining_actions(selected_actor, category)
        _set_log(
            _actor_name(selected_actor)
            + " ist verhöhnt und kann keine Statusattacke einsetzen."
        )
        _spawn_feedback_label(
            selected_actor,
            "😏 VERHÖHNT · " + str(remaining),
            Color("e3b8cf")
        )
        return
    super._choose_move(move_id)


func _enemy_act(actor: Dictionary) -> void:
    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        super._enemy_act(actor)
        return

    var original: Array = (moves_value as Array).duplicate()
    var allowed: Array = []
    for move_value: Variant in original:
        var move_id: String = str(move_value)
        var move: Dictionary = _move_data(move_id)
        if move.is_empty():
            continue
        if not MoveCategoryLock.blocks(actor, str(move.get("category", ""))):
            allowed.append(move_id)

    if allowed.is_empty() and not original.is_empty():
        # Reuse the complete central wait path so action_serial, periodic effects,
        # Aggro reduction and all later wait semantics remain consistent.
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
    if str(mechanic.get("kind", "")) != "db_block_move_category":
        return super._effect(actor, target, mechanic)

    if not bool(target.get("alive", false)):
        return 0.0
    if _bulba_substitute_blocks_effect(actor, target, mechanic):
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return 0.0

    var category: String = str(mechanic.get("category", ""))
    var duration: int = maxi(0, int(mechanic.get("duration_actions", 0)))
    if category.is_empty() or duration <= 0:
        return 0.0

    MoveCategoryLock.apply(target, category, duration)
    _spawn_feedback_label(
        target,
        "😏 VERHÖHNT · " + str(duration) + " AKTIONEN",
        Color("e3b8cf")
    )
    return _hp_scaled_aggro(target, 0.10)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    super._execute_move(actor, move_id)
    MoveCategoryLock.prune(actor)


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    super._choose_wait()
    if not actor.is_empty():
        MoveCategoryLock.prune(actor)


func _database_consume_recharge(actor: Dictionary) -> void:
    super._database_consume_recharge(actor)
    MoveCategoryLock.prune(actor)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var remaining: int = MoveCategoryLock.remaining_actions(combatant, "status")
    if remaining > 0:
        tokens.append("VERH" + str(remaining))
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var text: String = super._detail_info(combatant)
    var remaining: int = MoveCategoryLock.remaining_actions(combatant, "status")
    if remaining <= 0:
        return text
    return (
        text
        + "\n\n[b]KONTROLLE[/b]\n• Verhöhnt: noch "
        + str(remaining)
        + " eigene Aktion(en); Statusattacken gesperrt."
    )


func _compact_effect_summary(move: Dictionary) -> String:
    match str(move.get("id", "")):
        "taunt":
            return "3 Zielaktionen: keine Statusattacken · Schadensattacken und Warten bleiben erlaubt"
        "shock_wave":
            return "Stärke 60 · trifft ohne normale Genauigkeitsprüfung"
        "charge_beam":
            return "Stärke 50 · 70 %: eigener Angriff ↑ (Statuswert) · 3 eigene Aktionen"
        "strength":
            return "Stärke 80 · zuverlässiger physischer Normal-Angriff"
    return super._compact_effect_summary(move)
