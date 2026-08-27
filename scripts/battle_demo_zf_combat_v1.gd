extends "res://scripts/battle_demo_zf_registry_v1.gd"

const ZF_StatusEffects = preload("res://scripts/battle/status_effect_runtime.gd")

# Combat mechanics for the Zubat -> Quapsel ten-family attack batch.
# Generic charge, multi-hit, crit, AP, status-softcap and ATB rules remain in
# the inherited central runtime; only genuinely new behavior lives here.

const ZF_FlinchRules = preload("res://scripts/battle/flinch_rules.gd")
const ZF_FAKE_OUT_ATB_PAUSE_SECONDS: float = 1.50

var _zf_active_move_id: String = ""
var _zf_hp_before: Dictionary = {}
var _zf_wonder_room_remaining: float = 0.0


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["zf_direct_hits_received"] = 0
    combatant["zf_ally_ko_since_action"] = false
    return combatant


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return
    _zf_prepare_auto_target(actor, move)

    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var retaliate_ready: bool = bool(actor.get("zf_ally_ko_since_action", false))
    actor["zf_ally_ko_since_action"] = false

    var original_move: Dictionary = move.duplicate(true)
    var dynamic_kind: String = str(runtime.get("zf_dynamic_power", ""))
    if dynamic_kind == "rage_fist":
        move = move.duplicate(true)
        move["power"] = mini(
            350,
            50 + 50 * maxi(0, int(actor.get("zf_direct_hits_received", 0)))
        )
        _zf_replace_runtime_move(move_id, move)
    elif dynamic_kind == "retaliate":
        move = move.duplicate(true)
        move["power"] = 140 if retaliate_ready else 70
        _zf_replace_runtime_move(move_id, move)

    _zf_refresh_nonstacking_modifiers(actor, move_id, move)
    _zf_active_move_id = move_id
    _zf_hp_before = _zf_snapshot_hp()

    super._execute_move(actor, move_id)

    if dynamic_kind == "rage_fist" or dynamic_kind == "retaliate":
        _zf_replace_runtime_move(move_id, original_move)

    _zf_active_move_id = ""
    _zf_hp_before.clear()
    _zf_selected_target_id = ""


func _zf_replace_runtime_move(move_id: String, move: Dictionary) -> void:
    var moves_value: Variant = data.get("moves", {})
    if moves_value is Dictionary:
        (moves_value as Dictionary)[move_id] = move
        data["moves"] = moves_value


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    var damage: int = 0

    if _zf_wonder_room_remaining > 0.0:
        if str(actor.get("id", "")) == str(target.get("id", "")):
            var old_attack: Variant = actor.get("attack", 1)
            var old_defense: Variant = actor.get("defense", 1)
            actor["attack"] = old_defense
            actor["defense"] = old_attack
            damage = super._damage(actor, target, power, move_type, category)
            actor["attack"] = old_attack
            actor["defense"] = old_defense
        else:
            var old_actor_attack: Variant = actor.get("attack", 1)
            var old_target_defense: Variant = target.get("defense", 1)
            actor["attack"] = actor.get("defense", old_actor_attack)
            target["defense"] = target.get("attack", old_target_defense)
            damage = super._damage(actor, target, power, move_type, category)
            actor["attack"] = old_actor_attack
            target["defense"] = old_target_defense
    else:
        damage = super._damage(actor, target, power, move_type, category)

    if damage > 0 and str(actor.get("id", "")) != str(target.get("id", "")):
        target["zf_direct_hits_received"] = (
            maxi(0, int(target.get("zf_direct_hits_received", 0))) + 1
        )
    return damage


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    match kind:
        "zf_drain":
            return _zf_drain(actor, target, mechanic)
        "zf_recoil":
            _zf_recoil(actor, target, mechanic)
            return 0.0
        "zf_flinch":
            return _zf_flinch(target, mechanic)
        "zf_bad_poison":
            return _zf_bad_poison(actor, target, mechanic)
        "zf_sleep":
            return _zf_sleep(target, mechanic)
        "zf_chance_bundle":
            return _zf_chance_bundle(actor, target, mechanic)
        "zf_cleanse_major":
            return _zf_cleanse_major(target)
        "zf_ohko":
            return _zf_ohko(actor, target)
        "zf_tri_status":
            return _zf_tri_status(actor, target, mechanic)
        "zf_opening_pause":
            return _zf_opening_pause(target)
        "zf_aggro_swap":
            return _zf_aggro_swap(actor, target)
        "zf_soak":
            return _zf_soak(target)
        "zf_fixed_level_damage":
            return _zf_fixed_level_damage(actor, target)
        "zf_belly_drum":
            return _zf_belly_drum(actor)
        "zf_chance_modifier":
            return _zf_chance_modifier(actor, target, mechanic)
        "zf_modifier_on_damage":
            return _zf_modifier_on_damage(actor, target, mechanic)
        "zf_atb_pause_on_damage":
            if _zf_actual_damage(target) <= 0:
                return 0.0
            return _tf_apply_atb_pause(actor, target)
        "zf_status_on_damage":
            return _zf_status_on_damage(actor, target, mechanic)
        _:
            return super._effect(actor, target, mechanic)


func _zf_snapshot_hp() -> Dictionary:
    var result: Dictionary = {}
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            result[str(candidate.get("id", ""))] = int(candidate.get("hp", 0))
    return result


func _zf_actual_damage(target: Dictionary) -> int:
    var target_id: String = str(target.get("id", ""))
    if target_id.is_empty() or not _zf_hp_before.has(target_id):
        return 0
    return maxi(
        0,
        int(_zf_hp_before.get(target_id, int(target.get("hp", 0))))
        - int(target.get("hp", 0))
    )


func _zf_drain(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var dealt: int = _zf_actual_damage(target)
    if dealt <= 0:
        return 0.0

    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    ratio *= maxf(0.0, float(mechanic.get("status_weight", 1.0)))
    ratio = clampf(ratio, 0.0, 1.0)

    var missing: int = maxi(
        0,
        int(actor.get("max_hp", 1)) - int(actor.get("hp", 0))
    )
    # Drain healing is a Status-scaled whole-KP effect. Reuse the central
    # positive-effect rounding rule so every genuinely positive result keeps
    # its intended minimum impact of 1 KP instead of being floored to zero.
    var heal: int = mini(
        missing,
        ZF_StatusEffects.positive_int(float(dealt) * ratio)
    )
    if heal <= 0:
        return 0.0

    actor["hp"] = int(actor.get("hp", 0)) + heal
    _spawn_feedback_label(actor, "🌿 +" + str(heal) + " KP", Color("9be59f"))
    return float(heal)


func _zf_recoil(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> void:
    var dealt: int = _zf_actual_damage(target)
    if dealt <= 0:
        return

    var recoil: int = maxi(
        1,
        int(floor(float(dealt) * maxf(0.0, float(mechanic.get("fraction", 0.0)))))
    )
    recoil = mini(recoil, int(actor.get("hp", 0)))
    actor["hp"] = maxi(0, int(actor.get("hp", 0)) - recoil)
    if int(actor.get("hp", 0)) <= 0:
        actor["alive"] = false
    _spawn_feedback_label(
        actor,
        "💥 −" + str(recoil) + " KP RÜCKSTOSS",
        Color("ffb5aa")
    )


func _zf_flinch(target: Dictionary, mechanic: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if not ZF_FlinchRules.apply(target, float(mechanic.get("chance", 0.0))):
        return 0.0
    _spawn_feedback_label(target, "💫 ZURÜCKGESCHRECKT", Color("ffe2a8"))
    return 4.0


func _zf_bad_poison(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > float(mechanic.get("chance", 1.0)):
        return 0.0
    # Giftzahn reuses exactly the central severe-poison implementation of Toxin.
    return _tf_apply_bad_poison(actor, target)


func _zf_sleep(target: Dictionary, mechanic: Dictionary) -> float:
    if randf() > float(mechanic.get("chance", 1.0)):
        return 0.0
    if (
        bool(mechanic.get("powder", false))
        and _type_array(target.get("types", [])).has("grass")
    ):
        _spawn_feedback_label(target, "🌿 PUDER-IMMUN", Color("b9d58d"))
        return 0.0
    if (
        not str(target.get("major_status", "")).is_empty()
        or _database_status_is_blocked(target, "sleep")
    ):
        return 0.0

    target["major_status"] = "sleep"
    target["db_sleep_actions"] = randi_range(1, 3)
    _spawn_feedback_label(target, "💤 SCHLAF", Color("c9c4ee"))
    return 40.0


func _zf_chance_bundle(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > float(mechanic.get("chance", 1.0)):
        return 0.0

    var modifiers_value: Variant = mechanic.get("modifiers", [])
    if not (modifiers_value is Array):
        return 0.0

    var total: float = 0.0
    for mod_value: Variant in modifiers_value:
        if not (mod_value is Dictionary):
            continue
        var mod: Dictionary = mod_value
        var kind: String = str(mod.get("kind", ""))
        var multiplier: float = _status_modifier_multiplier(
            actor,
            mod,
            kind,
            false,
            false
        )
        _add_timed_modifier(
            actor,
            kind,
            multiplier,
            str(_move_data(_zf_active_move_id).get("name", _zf_active_move_id)),
            _actor_name(actor)
        )
        total += _status_effect_aggro(kind, multiplier)

    _spawn_feedback_label(actor, "🌫️ ANG/DEF/GES ↑", Color("ccb9e8"))
    return total


func _zf_cleanse_major(target: Dictionary) -> float:
    var status_id: String = str(target.get("major_status", ""))
    if status_id.is_empty():
        return 0.0

    target["major_status"] = ""
    target["paralyzed"] = false
    target["db_sleep_actions"] = 0
    target["tf_bad_poison_stage"] = 0
    target["tf_bad_poison_source_id"] = ""
    _spawn_feedback_label(target, "✨ STATUS GEHEILT", Color("b7efc5"))
    return 4.0


func _zf_ohko(actor: Dictionary, target: Dictionary) -> float:
    var actor_level: int = maxi(1, int(actor.get("level", 1)))
    var target_level: int = maxi(1, int(target.get("level", 1)))
    if actor_level < target_level:
        _spawn_feedback_label(target, "✖ LEVEL ZU HOCH", Color("d9a5a5"))
        return 0.0
    if is_zero_approx(
        TypeSystem.get_multiplier("ground", _type_array(target.get("types", [])))
    ):
        _spawn_feedback_label(target, "🛡️ IMMUN", Color("b8d9ff"))
        return 0.0

    var chance: float = clampf(
        float(30 + actor_level - target_level) / 100.0,
        0.0,
        1.0
    )
    if randf() > chance:
        _spawn_feedback_label(target, "✖ GEOFISSUR VERFEHLT", Color("d9a5a5"))
        return 0.0

    var removed_hp: int = maxi(0, int(target.get("hp", 0)))
    if removed_hp <= 0:
        return 0.0
    target["hp"] = 0
    target["alive"] = false
    target["aggro"] = float(target.get("aggro", 0.0)) * 0.5
    target["damage_since_last_action"] = true
    target["zf_direct_hits_received"] = (
        maxi(0, int(target.get("zf_direct_hits_received", 0))) + 1
    )
    _spawn_feedback_label(target, "🌋 K.O.", Color("ffbd8c"))
    return float(removed_hp)


func _zf_tri_status(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > float(mechanic.get("chance", 0.20)):
        return 0.0
    var options: Array[String] = ["paralysis", "burn", "freeze"]
    return _zf_apply_status_direct(
        actor,
        target,
        options.pick_random(),
        1.0
    )


func _zf_opening_pause(target: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    target["db_atb_pause_remaining_seconds"] = maxf(
        float(target.get("db_atb_pause_remaining_seconds", 0.0)),
        ZF_FAKE_OUT_ATB_PAUSE_SECONDS
    )
    _spawn_feedback_label(
        target,
        "👏 AKTIONSLEISTE PAUSIERT",
        Color("ffe0a3")
    )
    return 4.0


func _zf_aggro_swap(actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty():
        return 0.0
    if str(actor.get("side", "")) == str(target.get("side", "")):
        return 0.0

    var actor_aggro: float = float(actor.get("aggro", 0.0))
    actor["aggro"] = float(target.get("aggro", 0.0))
    target["aggro"] = actor_aggro
    _spawn_feedback_label(target, "🔄 AGGRO GETAUSCHT", Color("c9d7ff"))
    return 0.0


func _zf_soak(target: Dictionary) -> float:
    var types: Array = _type_array(target.get("types", []))
    if types.size() == 1 and types.has("water"):
        return 0.0
    target["types"] = ["water"]
    _spawn_feedback_label(target, "💧 TYP: WASSER", Color("9fdcff"))
    return 3.0


func _zf_fixed_level_damage(actor: Dictionary, target: Dictionary) -> float:
    if is_zero_approx(
        TypeSystem.get_multiplier("fighting", _type_array(target.get("types", [])))
    ):
        _spawn_feedback_label(target, "🛡️ IMMUN", Color("b8d9ff"))
        return 0.0

    var damage: int = mini(
        maxi(1, int(actor.get("level", 1))),
        maxi(0, int(target.get("hp", 0)))
    )
    if damage <= 0:
        return 0.0

    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
    target["alive"] = int(target.get("hp", 0)) > 0
    target["aggro"] = float(target.get("aggro", 0.0)) * 0.5
    target["damage_since_last_action"] = true
    target["zf_direct_hits_received"] = (
        maxi(0, int(target.get("zf_direct_hits_received", 0))) + 1
    )
    _spawn_feedback_label(target, "🌍 −" + str(damage) + " KP", Color("ddb98d"))
    return float(damage)


func _zf_belly_drum(actor: Dictionary) -> float:
    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var cost: int = maxi(1, int(floor(float(max_hp) * 0.5)))
    if int(actor.get("hp", 0)) <= cost:
        _spawn_feedback_label(actor, "✖ ZU WENIG KP", Color("d9a5a5"))
        return 0.0

    actor["hp"] = int(actor.get("hp", 0)) - cost
    _zf_remove_modifiers_from_move(actor, "Bauchtrommel")

    var proxy: Dictionary = {"multiplier_from_special": 3.0}
    var multiplier: float = _status_modifier_multiplier(
        actor,
        proxy,
        "outgoing_damage_mod",
        false,
        false
    )
    _add_timed_modifier(
        actor,
        "outgoing_damage_mod",
        multiplier,
        "Bauchtrommel",
        _actor_name(actor)
    )
    _spawn_feedback_label(actor, "🥁 ANGRIFF MASSIV ↑", Color("ffd58a"))
    return _status_effect_aggro("outgoing_damage_mod", multiplier)


func _zf_chance_modifier(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if randf() > float(mechanic.get("chance", 1.0)):
        return 0.0
    return _zf_apply_modifier(actor, target, mechanic)


func _zf_modifier_on_damage(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0

    var self_scope: bool = str(mechanic.get("scope", "")) == "self"
    var resolved_target: Dictionary = actor if self_scope else target
    var effect_aggro: float = _zf_apply_modifier(
        actor,
        resolved_target,
        mechanic
    )
    return 0.0 if self_scope else effect_aggro


func _zf_apply_modifier(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    var kind: String = str(
        mechanic.get("modifier_kind", mechanic.get("kind", ""))
    )
    var proxy: Dictionary = mechanic.duplicate(true)
    proxy["kind"] = kind
    var multiplier: float = _status_modifier_multiplier(
        actor,
        proxy,
        kind,
        false,
        false
    )
    _add_timed_modifier(
        target,
        kind,
        multiplier,
        str(_move_data(_zf_active_move_id).get("name", _zf_active_move_id)),
        _actor_name(actor)
    )
    return _status_effect_aggro(kind, multiplier)


func _zf_status_on_damage(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    return _zf_apply_status_direct(
        actor,
        target,
        str(mechanic.get("status", "")),
        float(mechanic.get("chance", 1.0))
    )


func _zf_apply_status_direct(
    _actor: Dictionary,
    target: Dictionary,
    status_id: String,
    chance: float
) -> float:
    if randf() > chance:
        return 0.0

    if status_id == "confusion":
        target["confused_turns"] = randi_range(1, 4)
        _spawn_feedback_label(target, "🌀 VERWIRRT", Color("d8c7ff"))
        return 3.0

    if (
        not str(target.get("major_status", "")).is_empty()
        or _database_status_is_blocked(target, status_id)
    ):
        return 0.0

    var types: Array = _type_array(target.get("types", []))
    if status_id == "paralysis" and types.has("electric"):
        return 0.0
    if status_id == "burn" and types.has("fire"):
        return 0.0
    if status_id == "poison" and (types.has("poison") or types.has("steel")):
        return 0.0
    if status_id == "freeze" and types.has("ice"):
        return 0.0

    target["major_status"] = status_id
    if status_id == "paralysis":
        target["paralyzed"] = true
    _spawn_feedback_label(
        target,
        _zf_status_feedback(status_id),
        Color("c8dcff")
    )
    return 3.0


func _zf_status_feedback(status_id: String) -> String:
    match status_id:
        "paralysis":
            return "⚡ PARALYSIERT"
        "burn":
            return "🔥 VERBRANNT"
        "poison":
            return "☠️ VERGIFTET"
        "freeze":
            return "❄️ GEFROREN"
        _:
            return status_id.to_upper()


func _zf_refresh_nonstacking_modifiers(
    actor: Dictionary,
    move_id: String,
    move: Dictionary
) -> void:
    if move_id == "howl":
        for target_value: Variant in _targets(
            actor,
            str(move.get("target", "all_allies"))
        ):
            if target_value is Dictionary:
                _zf_remove_modifiers_from_move(
                    target_value as Dictionary,
                    "Jauler"
                )
    elif move_id == "coaching":
        for target_value: Variant in _targets(
            actor,
            str(move.get("target", "single_ally"))
        ):
            if target_value is Dictionary:
                _zf_remove_modifiers_from_move(
                    target_value as Dictionary,
                    "Coaching"
                )


func _zf_remove_modifiers_from_move(
    target: Dictionary,
    source_move: String
) -> void:
    var value: Variant = target.get("timed_modifiers", [])
    if not (value is Array):
        return

    var kept: Array = []
    for modifier_value: Variant in value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if str(modifier.get("source_move", "")) != source_move:
            kept.append(modifier)
    target["timed_modifiers"] = kept
