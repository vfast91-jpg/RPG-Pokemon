extends "res://scripts/battle_demo_ad_runtime_support_v1.gd"

# Field and reactive support for the Abra -> Dodri batch.

func _ad_activate_psychic_terrain(actor: Dictionary) -> float:
    _pika_terrain_id = ""
    _bulba_grassy_terrain = {}
    _cleffa_misty_terrain = {}
    _ad_psychic_terrain = {
        "source_id": str(actor.get("id", "")),
        "expires_after_action": int(actor.get("action_serial", 0)) + 3,
        "status_ratio": AD_StatusEffects.ratio(float(actor.get("special", 0.0)))
    }
    _spawn_feedback_label(actor, "🧠 PSYCHOFELD · 3 AKTIONEN", Color("d7c6ef"))
    return 5.0


func _ad_psychic_terrain_active() -> bool:
    if _ad_psychic_terrain.is_empty():
        return false
    var source: Dictionary = _zf_find_combatant(
        str(_ad_psychic_terrain.get("source_id", ""))
    )
    if source.is_empty() or not bool(source.get("alive", false)):
        _ad_psychic_terrain.clear()
        return false
    if int(source.get("action_serial", 0)) > int(
        _ad_psychic_terrain.get("expires_after_action", 0)
    ):
        _ad_psychic_terrain.clear()
        return false
    return true


func _ad_toggle_trick_room(actor: Dictionary) -> float:
    if _ad_trick_room_remaining > 0.0:
        _ad_trick_room_remaining = 0.0
        _spawn_feedback_label(actor, "🔄 BIZARRORAUM ENDET", Color("d7c5ff"))
        return 2.0
    _ad_trick_room_remaining = AD_TRICK_ROOM_DURATION_SECONDS
    _spawn_feedback_label(actor, "🔄 BIZARRORAUM", Color("d7c5ff"))
    return 5.0


func _ad_apply_trick_room_speed_mirror() -> Dictionary:
    var originals: Dictionary = {}
    var effective_values: Array[float] = []

    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue
        var speed: float = float(candidate.get("speed", 10.0))
        var paralysis_factor: float = 0.5 if bool(candidate.get("paralyzed", false)) else 1.0
        effective_values.append(speed * paralysis_factor)

    if effective_values.is_empty():
        return originals

    var min_speed: float = effective_values[0]
    var max_speed: float = effective_values[0]
    for value: float in effective_values:
        min_speed = minf(min_speed, value)
        max_speed = maxf(max_speed, value)

    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue
        var candidate_id: String = str(candidate.get("id", ""))
        var original_speed: float = float(candidate.get("speed", 10.0))
        originals[candidate_id] = original_speed
        var paralysis_factor: float = 0.5 if bool(candidate.get("paralyzed", false)) else 1.0
        var effective_speed: float = original_speed * paralysis_factor
        var mirrored_effective: float = min_speed + max_speed - effective_speed
        candidate["speed"] = mirrored_effective / paralysis_factor
    return originals


func _ad_restore_speeds(originals: Dictionary) -> void:
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        var candidate_id: String = str(candidate.get("id", ""))
        if originals.has(candidate_id):
            candidate["speed"] = float(originals[candidate_id])


func _ad_chilly_reception(actor: Dictionary) -> float:
    if not _ad_snow_active():
        var activation: Dictionary = battle_weather.activate("snow", actor)
        if bool(activation.get("ok", false)):
            _update_weather_ui()
    _ad_enter_hidden_cycle(actor)
    return 4.0


func _ad_enter_hidden_cycle(actor: Dictionary) -> void:
    actor["ad_hidden_cycle"] = true
    actor["aggro"] = 0.0
    _ad_set_hidden_visual(actor, true)
    _spawn_feedback_label(actor, "🌀 VERSCHWUNDEN", Color("c7d8ff"))


func _ad_return_from_hidden_cycle(actor: Dictionary) -> void:
    if not bool(actor.get("ad_hidden_cycle", false)):
        return
    actor["ad_hidden_cycle"] = false
    _ad_set_hidden_visual(actor, false)
    _spawn_feedback_label(actor, "✨ ZURÜCK", Color("d7e7ff"))


func _ad_set_hidden_visual(actor: Dictionary, hidden: bool) -> void:
    var ui_value: Variant = cards.get(str(actor.get("id", "")), {})
    if not (ui_value is Dictionary):
        return
    var texture: TextureRect = (ui_value as Dictionary).get("texture") as TextureRect
    if texture != null:
        texture.visible = not hidden


func _ad_magnet_rise(actor: Dictionary) -> float:
    actor["ad_magnet_rise_expires"] = int(actor.get("action_serial", 0)) + 3
    _spawn_feedback_label(actor, "🧲 SCHWEBT · 3 AKTIONEN", Color("c9ddff"))
    return 4.0


func _ad_magnet_rise_active(combatant: Dictionary) -> bool:
    var expires: int = int(combatant.get("ad_magnet_rise_expires", -1))
    return expires >= 0 and int(combatant.get("action_serial", 0)) <= expires


func _ad_cancel_all_magnet_rise() -> void:
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            if _ad_magnet_rise_active(candidate):
                candidate["ad_magnet_rise_expires"] = -1
                _spawn_feedback_label(candidate, "🧲 ZU BODEN", Color("d9c6ac"))


func _ad_gravity_active() -> bool:
    if not has_meta("ad_gravity_source_id"):
        return false
    var source: Dictionary = _zf_find_combatant(str(get_meta("ad_gravity_source_id", "")))
    if source.is_empty() or not bool(source.get("alive", false)):
        return false
    return int(source.get("action_serial", 0)) < int(
        get_meta("ad_gravity_expires_after_action", 0)
    )


func _ad_magnetic_flux(
    actor: Dictionary,
    target: Dictionary
) -> float:
    if not _type_array(target.get("types", [])).has("electric"):
        return 0.0
    var mechanic: Dictionary = {
        "modifier_kind": "incoming_damage_mod",
        "multiplier_from_special": -1.0
    }
    return _ad_apply_modifier(actor, target, mechanic)


func _ad_mirror_coat(actor: Dictionary) -> float:
    actor["ad_mirror_expires_before_serial"] = int(actor.get("action_serial", 0)) + 1
    actor["ad_mirror_pending_damage"] = 0
    actor["ad_mirror_pending_attacker_id"] = ""
    _spawn_feedback_label(actor, "🪞 SPIEGEL-BEREITSCHAFT", Color("d7e1f4"))
    return 4.0


func _ad_mirror_coat_active(actor: Dictionary) -> bool:
    var expires: int = int(actor.get("ad_mirror_expires_before_serial", -1))
    if expires < 0:
        return false
    return int(actor.get("action_serial", 0)) < expires


func _ad_trigger_mirror_pending_on_all() -> void:
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            _ad_trigger_mirror_pending(candidate_value as Dictionary)


func _ad_trigger_mirror_pending(target: Dictionary) -> void:
    var damage_received: int = int(target.get("ad_mirror_pending_damage", 0))
    if damage_received <= 0 or not _ad_mirror_coat_active(target):
        return

    var attacker: Dictionary = _zf_find_combatant(
        str(target.get("ad_mirror_pending_attacker_id", ""))
    )
    target["ad_mirror_pending_damage"] = 0
    target["ad_mirror_pending_attacker_id"] = ""
    target["ad_mirror_expires_before_serial"] = -1

    if attacker.is_empty() or not bool(attacker.get("alive", false)):
        return
    if _type_array(attacker.get("types", [])).has("dark"):
        _spawn_feedback_label(attacker, "🛡️ PSYCHO-IMMUN", Color("b8d9ff"))
        return

    var reflected: int = mini(
        int(attacker.get("hp", 0)),
        maxi(1, damage_received * 2)
    )
    attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - reflected)
    if int(attacker.get("hp", 0)) <= 0:
        attacker["alive"] = false
    target["aggro"] = float(target.get("aggro", 0.0)) + float(reflected)
    _spawn_feedback_label(attacker, "🪞 −" + str(reflected) + " KP", Color("d7c5ff"))


func _ad_lock_on(actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty():
        return 0.0
    actor["ad_lock_on_target_id"] = str(target.get("id", ""))
    _spawn_feedback_label(target, "🎯 ANVISIERT", Color("ffd5a3"))
    return 3.0
