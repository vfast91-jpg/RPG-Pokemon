extends "res://scripts/battle_demo_zf_status_v1.gd"

# Pay Day is a move-owned, immediate item purchase. It deliberately reuses the
# active route's Fundstelle healing resolver instead of duplicating stage rules.

var _zf_pending_pay_day_actor_id: String = ""


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) == "zf_pay_day":
        if _zf_actual_damage(target) > 0:
            _zf_pending_pay_day_actor_id = str(actor.get("id", ""))
        return 0.0
    return super._effect(actor, target, mechanic)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    _zf_pending_pay_day_actor_id = ""
    super._execute_move(actor, move_id)

    if (
        move_id != "pay_day"
        or not battle_active
        or _zf_pending_pay_day_actor_id != str(actor.get("id", ""))
    ):
        _zf_pending_pay_day_actor_id = ""
        return

    _zf_pending_pay_day_actor_id = ""
    if str(actor.get("side", "")) == "player":
        _zf_open_pay_day_reward(actor)
    else:
        _zf_apply_pay_day_ai(actor)


func _zf_open_pay_day_reward(actor: Dictionary) -> void:
    var living: Array = _zf_team_members_by_alive(actor, true)
    var fainted: Array = _zf_team_members_by_alive(actor, false)
    if living.is_empty() and fainted.is_empty():
        return

    var choose_revive: bool = not fainted.is_empty() and randf() < 0.5
    paused = true
    selected_actor = {}
    _clear_actions()

    if choose_revive:
        _set_log("🪙 Zahltag kauft einen Beleber. Wähle das Ziel.")
        for candidate_value: Variant in fainted:
            if not (candidate_value is Dictionary):
                continue
            var candidate: Dictionary = candidate_value
            var button := Button.new()
            button.text = "✨ " + _actor_name(candidate)
            button.custom_minimum_size = Vector2(135, 29)
            button.pressed.connect(
                _zf_pay_day_apply_revive.bind(actor, str(candidate.get("id", "")))
            )
            action_grid.add_child(button)
        return

    var item: Dictionary = _zf_stage_healing_item()
    _set_log(
        "🪙 Zahltag kauft %s. Wähle das Ziel."
        % str(item.get("name", "Trank"))
    )
    for candidate_value: Variant in living:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        var button := Button.new()
        button.text = "🧪 " + _actor_name(candidate)
        button.custom_minimum_size = Vector2(135, 29)
        button.pressed.connect(
            _zf_pay_day_apply_heal.bind(
                actor,
                str(candidate.get("id", "")),
                item.duplicate(true)
            )
        )
        action_grid.add_child(button)


func _zf_apply_pay_day_ai(actor: Dictionary) -> void:
    var living: Array = _zf_team_members_by_alive(actor, true)
    var fainted: Array = _zf_team_members_by_alive(actor, false)
    if not fainted.is_empty() and randf() < 0.5:
        var revive_value: Variant = fainted.pick_random()
        if revive_value is Dictionary:
            _zf_pay_day_revive_now(actor, revive_value as Dictionary)
        return
    if living.is_empty():
        return

    var damaged: Array = []
    for candidate_value: Variant in living:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            if int(candidate.get("hp", 0)) < int(candidate.get("max_hp", 1)):
                damaged.append(candidate)
    var heal_value: Variant = (
        damaged.pick_random() if not damaged.is_empty() else living.pick_random()
    )
    if heal_value is Dictionary:
        _zf_pay_day_heal_now(actor, heal_value as Dictionary, _zf_stage_healing_item())


func _zf_pay_day_apply_heal(
    actor: Dictionary,
    target_id: String,
    item: Dictionary
) -> void:
    var target: Dictionary = _zf_find_combatant(target_id)
    if not target.is_empty() and bool(target.get("alive", false)):
        _zf_pay_day_heal_now(actor, target, item)
    _zf_finish_pay_day_choice()


func _zf_pay_day_apply_revive(actor: Dictionary, target_id: String) -> void:
    var target: Dictionary = _zf_find_combatant(target_id)
    if not target.is_empty() and not bool(target.get("alive", false)):
        _zf_pay_day_revive_now(actor, target)
    _zf_finish_pay_day_choice()


func _zf_pay_day_heal_now(
    actor: Dictionary,
    target: Dictionary,
    item: Dictionary
) -> void:
    var old_hp: int = maxi(0, int(target.get("hp", 0)))
    var max_hp: int = maxi(1, int(target.get("max_hp", 1)))
    var amount: int = int(item.get("amount", 0))
    var new_hp: int = max_hp if amount < 0 else mini(max_hp, old_hp + maxi(0, amount))
    var healed: int = maxi(0, new_hp - old_hp)
    target["hp"] = new_hp
    if healed > 0:
        actor["aggro"] = float(actor.get("aggro", 0.0)) + float(healed)
        _spawn_feedback_label(target, "🧪 +" + str(healed) + " KP", Color("9be59f"))
    _set_log(
        "🪙 Zahltag: %s erhält %s."
        % [_actor_name(target), str(item.get("name", "Trank"))]
    )


func _zf_pay_day_revive_now(actor: Dictionary, target: Dictionary) -> void:
    var max_hp: int = maxi(1, int(target.get("max_hp", 1)))
    var revived_hp: int = _zf_revive_hp_amount(max_hp)
    target["hp"] = revived_hp
    target["alive"] = true
    target["atb"] = 0.0
    target["cycle"] = 1.0
    _zf_alive_snapshot[str(target.get("id", ""))] = true
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(revived_hp)
    _spawn_feedback_label(target, "✨ BELEBT · " + str(revived_hp) + " KP", Color("9be59f"))
    _set_log("🪙 Zahltag: " + _actor_name(target) + " wird mit Beleber wiederbelebt.")


func _zf_finish_pay_day_choice() -> void:
    paused = false
    _clear_actions()
    _refresh_cards()
    _check_end()


func _zf_team_members_by_alive(actor: Dictionary, alive_value: bool) -> Array:
    var result: Array = []
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if bool(candidate.get("alive", false)) == alive_value:
            result.append(candidate)
    return result


func _zf_route_node() -> Node:
    var parent: Node = get_parent()
    if parent == null:
        return null
    return parent.get_node_or_null("DemoRoute")


func _zf_stage_healing_item() -> Dictionary:
    var route: Node = _zf_route_node()
    if route != null and route.has_method("_healing_item_for_stage"):
        var stage_value: Variant = route.get("stage")
        var stage_number: int = maxi(1, int(stage_value))
        var resolved: Variant = route.call("_healing_item_for_stage", stage_number)
        if resolved is Dictionary:
            return (resolved as Dictionary).duplicate(true)

    # Combat-lab fallback mirrors the active Fundstelle tiers. Route play uses
    # the resolver above, so there is one authoritative route rule in practice.
    var stage_number: int = 1
    if route != null:
        stage_number = maxi(1, int(route.get("stage")))
    if stage_number <= 20:
        return {"id":"potion", "name":"Trank", "amount":20}
    if stage_number <= 40:
        return {"id":"super_potion", "name":"Supertrank", "amount":50}
    if stage_number <= 60:
        return {"id":"hyper_potion", "name":"Hypertrank", "amount":120}
    return {"id":"max_potion", "name":"Top-Trank", "amount":-1}


func _zf_revive_hp_amount(max_hp: int) -> int:
    var route: Node = _zf_route_node()
    if route != null and route.has_method("_revive_hp_amount"):
        return maxi(1, int(route.call("_revive_hp_amount", maxi(1, max_hp))))
    return maxi(1, int(float(maxi(1, max_hp)) * 0.5))
