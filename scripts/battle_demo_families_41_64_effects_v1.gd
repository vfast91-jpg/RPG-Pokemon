extends "res://scripts/battle_demo_families_41_64_registry_v1.gd"

# Effect layer for the V22 family batch.
# Existing central mechanics (freeze, burn, flinch, timed modifiers, status
# blocking, heal block) are reused instead of duplicated.


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    match kind:
        "f64_torment":
            return _f64_torment(actor, target)
        "f64_silver_wind":
            return _f64_silver_wind(actor, target, mechanic)
        "f64_stone_axe":
            return _f64_stone_axe(actor, target)
        "f64_freeze_on_damage":
            return _f64_freeze_on_damage(actor, target, mechanic)
        "f64_lovely_kiss":
            return _f64_lovely_kiss(actor, target)
        "f64_recycle":
            return _f64_recycle(actor, target)
        "f64_burn_on_damage":
            return _f40_burn_on_damage(actor, target, mechanic)
        "f64_flinch_on_damage":
            return _zf_flinch(target, mechanic)
        "f64_break_team_barriers":
            return _f64_break_team_barriers(actor, target)
        "f64_mist":
            return _f64_mist(actor, target)
        "f64_transform":
            return _f64_transform(actor, target)
        "f64_wish":
            return _f64_wish(actor)
        "f64_morning_sun":
            return _f64_morning_sun(actor)
        "f64_guard_split":
            return _f64_guard_split(actor, target)
        "f64_conversion":
            return _f64_conversion(actor)
        "f64_conversion_2":
            return _f64_conversion_2(actor, target)
        "f64_draco_meteor_down":
            return _f64_draco_meteor_down(actor, target)
        _:
            return super._effect(actor, target, mechanic)


func _f64_torment(_actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0

    var current: int = int(target.get("action_serial", 0))
    var old_expiry: int = int(target.get("f64_torment_expires_serial", -1))
    var old_remaining: int = maxi(0, old_expiry - current)
    target["f64_torment_expires_serial"] = current + 3

    _spawn_feedback_label(target, "💢 FOLTERKNECHT · 3 AKTIONEN", Color("d7b0cf"))
    var newly_controlled_actions: int = maxi(0, 3 - old_remaining)
    return (
        float(target.get("max_hp", 1))
        * F30_STATUS_CONTROL_HP_FRACTION
        * float(newly_controlled_actions)
    )


func _f64_silver_wind(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > clampf(float(mechanic.get("chance", 0.10)), 0.0, 1.0):
        return 0.0

    var total: float = 0.0
    total += _f30_apply_exact_modifier(
        actor, actor, "outgoing_damage_mod", 1.0, "Silberhauch"
    )
    total += _f30_apply_exact_modifier(
        actor, actor, "incoming_damage_mod", 1.0, "Silberhauch"
    )
    total += _f30_apply_exact_modifier(
        actor, actor, "atb_cycle_mod", -1.0, "Silberhauch"
    )
    _spawn_feedback_label(actor, "✨ ANGRIFF · VERTEIDIGUNG · TEMPO ↑", Color("d9e8c1"))
    return total


func _f64_stone_axe(actor: Dictionary, target: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    var side: String = str(target.get("side", ""))
    if side.is_empty() or _f64_stealth_rock_by_side.has(side):
        return 0.0

    _f64_stealth_rock_by_side[side] = {
        "source_id": str(actor.get("id", ""))
    }
    _spawn_feedback_label(target, "🪨 TARNSTEINE", Color("d6c5ae"))
    return 0.0


func _f64_freeze_on_damage(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > clampf(float(mechanic.get("chance", 0.10)), 0.0, 1.0):
        return 0.0
    return _zf_apply_status_direct(actor, target, "freeze", 1.0)


func _f64_lovely_kiss(_actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0
    if (
        not str(target.get("major_status", "")).is_empty()
        or _database_status_is_blocked(target, "sleep")
    ):
        return 0.0

    var actions: int = randi_range(1, 3)
    target["major_status"] = "sleep"
    target["db_sleep_actions"] = actions
    _spawn_feedback_label(target, "💋💤 SCHLAF · " + str(actions) + " AKTIONEN", Color("d8c4ee"))
    return (
        float(target.get("max_hp", 1))
        * F30_STATUS_CONTROL_HP_FRACTION
        * float(actions)
    )


func _f64_recycle(actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0
    if _f40_heal_block_active(target):
        _f40_heal_block_feedback(target)
        return 0.0

    var count: int = maxi(1, _f64_living_team_count(str(actor.get("side", ""))))
    var area_factor: float = 1.0
    match count:
        2:
            area_factor = 0.75
        3:
            area_factor = 0.60
        _:
            if count >= 4:
                area_factor = 0.50

    var max_hp: int = maxi(1, int(target.get("max_hp", 1)))
    var missing: int = maxi(0, max_hp - int(target.get("hp", 0)))
    if missing <= 0:
        return 0.0

    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var requested: int = maxi(1, int(round(float(max_hp) * ratio * area_factor)))
    var healed: int = mini(missing, requested)
    target["hp"] = int(target.get("hp", 0)) + healed
    _spawn_feedback_label(target, "♻️ +" + str(healed) + " KP", Color("9fe2ac"))
    return float(healed)


func _f64_break_team_barriers(_actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty():
        return 0.0
    var side: String = str(target.get("side", ""))
    if side.is_empty():
        return 0.0

    var removed_any: bool = false
    var screen_names: Array[String] = [
        "reflektor", "reflect", "lichtschild", "light screen",
        "auroraschleier", "aurora veil"
    ]

    for candidate_value: Variant in _team_for_side(side):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value

        for prefix: String in ["db_light_screen", "db_reflect", "db_aurora_veil"]:
            var source_key: String = prefix + "_source_id"
            if not str(candidate.get(source_key, "")).is_empty():
                removed_any = true
            candidate[source_key] = ""
            candidate[prefix + "_reduction"] = 0.0
            candidate[prefix + "_expires_source_action"] = -1

        var modifiers_value: Variant = candidate.get("timed_modifiers", [])
        if modifiers_value is Array:
            var kept: Array = []
            for modifier_value: Variant in modifiers_value:
                if not (modifier_value is Dictionary):
                    continue
                var modifier: Dictionary = modifier_value
                var source_move: String = str(modifier.get("source_move", "")).to_lower()
                if source_move in screen_names:
                    removed_any = true
                    continue
                kept.append(modifier)
            candidate["timed_modifiers"] = kept

    if removed_any:
        _spawn_feedback_label(target, "🐂 BARRIEREN ZERSTÖRT", Color("e7c5a4"))
    return 0.0


func _f64_mist(_actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0
    target["f64_mist_expires_serial"] = int(target.get("action_serial", 0)) + 3
    _spawn_feedback_label(target, "🌫️ WEISSNEBEL · 3 AKTIONEN", Color("d8e4ef"))
    return 0.0


func _f64_transform(actor: Dictionary, target: Dictionary) -> float:
    if actor.is_empty() or target.is_empty():
        return 0.0
    if bool(actor.get("f64_transformed", false)):
        _spawn_feedback_label(actor, "✖ BEREITS VERWANDELT", Color("d9a5a5"))
        return 0.0
    if bool(target.get("f64_transformed", false)):
        _spawn_feedback_label(target, "✖ VERWANDELTES ZIEL", Color("d9a5a5"))
        return 0.0
    if bool(target.get("bulba_substitute_active", false)):
        _spawn_feedback_label(target, "🪆 DELEGATOR BLOCKIERT", Color("d9c9a5"))
        return 0.0

    actor["types"] = _type_array(target.get("types", [])).duplicate()
    actor["attack"] = int(target.get("attack", actor.get("attack", 1)))
    actor["defense"] = int(target.get("defense", actor.get("defense", 1)))
    actor["special"] = int(target.get("special", actor.get("special", 1)))
    actor["speed"] = int(target.get("speed", actor.get("speed", 1)))

    var target_moves_value: Variant = target.get("moves", [])
    actor["moves"] = (
        (target_moves_value as Array).duplicate()
        if target_moves_value is Array
        else []
    )
    actor["timed_modifiers"] = _f64_copy_timed_modifiers(target, actor)
    actor["f64_transformed"] = true

    _spawn_feedback_label(actor, "🧬 WANDLER → " + _actor_name(target), Color("d3c7ef"))
    return 0.0


func _f64_copy_timed_modifiers(source: Dictionary, receiver: Dictionary) -> Array:
    var result: Array = []
    var modifiers_value: Variant = source.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return result

    var source_serial: int = int(source.get("action_serial", 0))
    var receiver_serial: int = int(receiver.get("action_serial", 0))
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = (modifier_value as Dictionary).duplicate(true)
        var remaining: int = maxi(
            0,
            int(modifier.get("expires_after_action", source_serial)) - source_serial
        )
        if remaining <= 0:
            continue
        modifier["expires_after_action"] = receiver_serial + remaining
        result.append(modifier)
    return result


func _f64_wish(actor: Dictionary) -> float:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return 0.0
    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var ratio: float = clampf(
        1.5 * _status_ratio(float(actor.get("special", 0.0))),
        0.0,
        1.0
    )
    actor["f64_wish_pending"] = true
    actor["f64_wish_trigger_serial"] = int(actor.get("action_serial", 0))
    actor["f64_wish_amount"] = maxi(1, int(round(float(max_hp) * ratio)))
    _spawn_feedback_label(actor, "🌠 WUNSCH VORBEREITET", Color("f1df9f"))
    return 0.0


func _f64_morning_sun(actor: Dictionary) -> float:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return 0.0
    if _f40_heal_block_active(actor):
        _f40_heal_block_feedback(actor)
        return 0.0

    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var missing: int = maxi(0, max_hp - int(actor.get("hp", 0)))
    if missing <= 0:
        return 0.0

    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    var requested: int = maxi(
        1,
        int(round(float(max_hp) * ratio * _f64_weather_heal_multiplier()))
    )
    var healed: int = mini(missing, requested)
    actor["hp"] = int(actor.get("hp", 0)) + healed
    _spawn_feedback_label(actor, "🌅 +" + str(healed) + " KP", Color("f0d99a"))
    return float(healed)


func _f64_weather_heal_multiplier() -> float:
    if not battle_weather.is_active():
        return 1.0
    match battle_weather.current_id():
        "sun":
            return 4.0 / 3.0
        "rain", "sandstorm", "snow", "hail":
            return 0.5
        _:
            return 1.0


func _f64_guard_split(actor: Dictionary, target: Dictionary) -> float:
    if actor.is_empty() or target.is_empty() or not bool(target.get("alive", false)):
        return 0.0

    var actor_base: int = _f64_guard_base_defense(actor)
    var target_base: int = _f64_guard_base_defense(target)
    if actor_base == target_base:
        _spawn_feedback_label(target, "⚖️ KEINE ÄNDERUNG", Color("d8d2e5"))
        return 0.0

    var shared: int = maxi(1, int(round((float(actor_base) + float(target_base)) / 2.0)))
    _f64_apply_guard_split_value(actor, actor_base, shared)
    _f64_apply_guard_split_value(target, target_base, shared)
    _spawn_feedback_label(actor, "⚖️ VERTEIDIGUNG = " + str(shared), Color("d8d2e5"))
    _spawn_feedback_label(target, "⚖️ VERTEIDIGUNG = " + str(shared), Color("d8d2e5"))
    return 0.0


func _f64_apply_guard_split_value(
    combatant: Dictionary,
    original_base: int,
    shared: int
) -> void:
    combatant["f64_guard_split_active"] = true
    combatant["f64_guard_split_original_defense"] = original_base
    combatant["f64_guard_split_expires_serial"] = int(combatant.get("action_serial", 0)) + 3
    combatant["defense"] = shared


func _f64_conversion(actor: Dictionary) -> float:
    var chosen: String = _f64_take_conversion_type_choice(actor)
    if chosen.is_empty():
        _spawn_feedback_label(actor, "✖ KEIN NEUER TYP", Color("d9a5a5"))
        return 0.0
    actor["types"] = [chosen]
    _spawn_feedback_label(actor, "🔄 TYP → " + _type_name(chosen), Color("c8d9ef"))
    return 0.0


func _f64_conversion_2(actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0

    var last_type: String = str(target.get("f64_last_used_move_type", ""))
    if last_type.is_empty():
        _spawn_feedback_label(target, "✖ KEINE LETZTE ATTACKE", Color("d9a5a5"))
        return 0.0

    var options: Array[String] = _f64_resistant_types(last_type, actor)
    if options.is_empty():
        _spawn_feedback_label(actor, "✖ KEIN GÜLTIGER TYP", Color("d9a5a5"))
        return 0.0

    var chosen: String = options.pick_random()
    actor["types"] = [chosen]
    _spawn_feedback_label(actor, "🔁 TYP → " + _type_name(chosen), Color("c8d9ef"))
    return 0.0


func _f64_draco_meteor_down(actor: Dictionary, target: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    _f30_apply_exact_modifier(
        actor,
        actor,
        "outgoing_damage_mod",
        -2.0,
        "Draco Meteor"
    )
    _spawn_feedback_label(actor, "☄️ ANGRIFF ↓↓ · 3 AKTIONEN", Color("d9b0a4"))
    return 0.0


func _f30_apply_exact_modifier(
    source: Dictionary,
    target: Dictionary,
    kind: String,
    signed_weight: float,
    source_name: String
) -> float:
    if (
        _f64_mist_active(target)
        and str(source.get("id", "")) != str(target.get("id", ""))
        and _f64_signed_modifier_is_harmful(kind, signed_weight)
    ):
        _spawn_feedback_label(target, "🌫️ WEISSNEBEL BLOCKIERT", Color("d8e4ef"))
        return 0.0
    return super._f30_apply_exact_modifier(
        source, target, kind, signed_weight, source_name
    )


func _add_timed_modifier(
    target: Dictionary,
    kind: String,
    multiplier: float,
    source_move: String,
    source_actor: String
) -> void:
    if (
        _f64_mist_active(target)
        and source_actor != _actor_name(target)
        and _f64_multiplier_is_harmful(kind, multiplier)
    ):
        _spawn_feedback_label(target, "🌫️ WEISSNEBEL BLOCKIERT", Color("d8e4ef"))
        return
    super._add_timed_modifier(target, kind, multiplier, source_move, source_actor)


func _f64_signed_modifier_is_harmful(kind: String, signed_weight: float) -> bool:
    match kind:
        "outgoing_damage_mod", "incoming_damage_mod", "accuracy_mod":
            return signed_weight < 0.0
        "atb_cycle_mod":
            return signed_weight > 0.0
        _:
            return false


func _f64_multiplier_is_harmful(kind: String, multiplier: float) -> bool:
    match kind:
        "outgoing_damage_mod", "accuracy_mod":
            return multiplier < 1.0
        "incoming_damage_mod", "atb_cycle_mod":
            return multiplier > 1.0
        _:
            return false
