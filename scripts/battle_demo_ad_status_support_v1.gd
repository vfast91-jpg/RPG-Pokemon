extends "res://scripts/battle_demo_ad_field_support_v1.gd"

# Status/control and utility support for the Abra -> Dodri batch.

func _ad_acupressure(actor: Dictionary, target: Dictionary) -> float:
    if target.is_empty():
        return 0.0

    var roll: int = randi_range(1, 7)
    var kind: String = ""
    var label: String = ""
    var source_name: String = "Akupressur"

    if roll <= 2:
        kind = "outgoing_damage_mod"
        label = "ANGRIFF STARK ↑"
    elif roll <= 4:
        kind = "incoming_damage_mod"
        label = "VERTEIDIGUNG STARK ↑"
    elif roll == 5:
        kind = "atb_cycle_mod"
        label = "GESCHWINDIGKEIT STARK ↑"
    elif roll == 6:
        kind = "accuracy_mod"
        label = "GENAUIGKEIT STARK ↑"
    else:
        var ratio: float = AD_StatusEffects.ratio(float(actor.get("special", 0.0)))
        target["db_incoming_accuracy_mult"] = clampf(1.0 - 2.0 * ratio, 0.2, 1.0)
        target["db_incoming_accuracy_expires"] = int(target.get("action_serial", 0)) + 3
        _spawn_feedback_label(target, "📍 AUSWEICHWIRKUNG STARK ↑", Color("ddd0ff"))
        return 4.0

    _ad_remove_source_modifier_kind(target, source_name, kind)
    var coefficient: float = -2.0 if (
        kind == "incoming_damage_mod" or kind == "atb_cycle_mod"
    ) else 2.0
    var mechanic: Dictionary = {
        "kind": kind,
        "multiplier_from_special": coefficient
    }
    var multiplier: float = _status_modifier_multiplier(
        actor, mechanic, kind, false, false
    )
    _add_timed_modifier(target, kind, multiplier, source_name, _actor_name(actor))
    _spawn_feedback_label(target, "📍 " + label, Color("ddd0ff"))
    return _status_effect_aggro(kind, multiplier)


func _ad_remove_source_modifier_kind(
    target: Dictionary,
    source_move: String,
    kind: String
) -> void:
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return
    var kept: Array = []
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if (
            str(modifier.get("source_move", "")) == source_move
            and str(modifier.get("kind", "")) == kind
        ):
            continue
        kept.append(modifier)
    target["timed_modifiers"] = kept


func _ad_mute_on_damage(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if _ad_mute_active(target):
        return 0.0

    target["ad_mute_expires_before_serial"] = (
        int(target.get("action_serial", 0))
        + maxi(1, int(mechanic.get("duration_actions", 2)))
    )

    if str(target.get("db_forced_move_id", "")) == "uproar":
        _database_interrupt_forced_sequence(target)

    _spawn_feedback_label(target, "🔇 STUMM · 2 AKTIONEN", Color("d9c2d9"))
    return 4.0


func _ad_mute_active(combatant: Dictionary) -> bool:
    var expires: int = int(combatant.get("ad_mute_expires_before_serial", -1))
    return expires >= 0 and int(combatant.get("action_serial", 0)) < expires


func _ad_is_sound_move(move: Dictionary) -> bool:
    if move.is_empty():
        return false
    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary:
        if bool((runtime_value as Dictionary).get("sound_move", false)):
            return true
        if bool((runtime_value as Dictionary).get("sound", false)):
            return true
    var tags_value: Variant = move.get("optional_tags", move.get("tags", []))
    if tags_value is Array:
        for tag_value: Variant in tags_value:
            if str(tag_value) == "sound":
                return true
    return false


func _ad_disable_muted_sound_buttons(actor: Dictionary) -> void:
    if not _ad_mute_active(actor) or action_grid == null:
        return
    var actor_moves_value: Variant = actor.get("moves", [])
    if not (actor_moves_value is Array):
        return
    for move_value: Variant in actor_moves_value:
        var move_id: String = str(move_value)
        var move: Dictionary = _move_data(move_id)
        if not _ad_is_sound_move(move):
            continue
        for child: Node in action_grid.get_children():
            if not (child is Button):
                continue
            var button: Button = child as Button
            if _action_button_matches_move(button, move, move_id):
                button.disabled = true
                if not button.tooltip_text.contains("Halsabschneider"):
                    button.tooltip_text += "\nDurch Halsabschneider vorübergehend blockiert."


func _ad_clear_expired_actor_states(actor: Dictionary) -> void:
    if (
        int(actor.get("ad_mute_expires_before_serial", -1)) >= 0
        and int(actor.get("action_serial", 0)) >= int(actor.get("ad_mute_expires_before_serial", -1))
    ):
        actor["ad_mute_expires_before_serial"] = -1

    if (
        int(actor.get("ad_mirror_expires_before_serial", -1)) >= 0
        and int(actor.get("action_serial", 0)) + 1 >= int(actor.get("ad_mirror_expires_before_serial", -1))
    ):
        actor["ad_mirror_expires_before_serial"] = -1
        actor["ad_mirror_pending_damage"] = 0
        actor["ad_mirror_pending_attacker_id"] = ""

    if (
        int(actor.get("ad_magnet_rise_expires", -1)) >= 0
        and int(actor.get("action_serial", 0)) >= int(actor.get("ad_magnet_rise_expires", -1))
    ):
        actor["ad_magnet_rise_expires"] = -1


func _ad_after_counted_action(actor: Dictionary) -> void:
    _ad_resolve_drowsy_after_action(actor)
    _ad_cleanup_field_states()


func _ad_cleanup_field_states() -> void:
    if not _ad_psychic_terrain.is_empty():
        var terrain_source: Dictionary = _zf_find_combatant(
            str(_ad_psychic_terrain.get("source_id", ""))
        )
        if (
            terrain_source.is_empty()
            or not bool(terrain_source.get("alive", false))
            or int(terrain_source.get("action_serial", 0)) >= int(
                _ad_psychic_terrain.get("expires_after_action", 0)
            )
        ):
            _ad_psychic_terrain.clear()
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary = candidate_value
            if (
                int(candidate.get("ad_magnet_rise_expires", -1)) >= 0
                and int(candidate.get("action_serial", 0)) >= int(candidate.get("ad_magnet_rise_expires", -1))
            ):
                candidate["ad_magnet_rise_expires"] = -1


func _ad_heavy_slam_power(actor: Dictionary, target: Dictionary) -> int:
    var actor_weight: float = _ad_weight_kg(actor)
    var target_weight: float = maxf(0.001, _ad_weight_kg(target))
    var ratio: float = actor_weight / target_weight
    if ratio >= 5.0:
        return 120
    if ratio >= 4.0:
        return 100
    if ratio >= 3.0:
        return 80
    if ratio >= 2.0:
        return 60
    return 40


func _ad_weight_kg(combatant: Dictionary) -> float:
    var species_value: Variant = _canonical_pack.get("species", {})
    if not (species_value is Dictionary):
        return 1.0
    var source_value: Variant = (species_value as Dictionary).get(
        str(combatant.get("species_id", "")), {}
    )
    if not (source_value is Dictionary):
        return 1.0
    var physical_value: Variant = (source_value as Dictionary).get("physical", {})
    if physical_value is Dictionary:
        return maxf(0.001, float((physical_value as Dictionary).get("weight_kg", 1.0)))
    return maxf(0.001, float((source_value as Dictionary).get("weight_kg", 1.0)))


func _ad_self_ko(actor: Dictionary) -> void:
    if not bool(actor.get("alive", false)):
        return
    actor["hp"] = 0
    actor["alive"] = false
    actor["aggro"] = 0.0
    _spawn_feedback_label(actor, "💥 K.O.", Color("ffb5aa"))


func _ad_apply_fixed_self_cost(
    actor: Dictionary,
    fraction: float,
    label: String = "⚙️ EIGENKOSTEN"
) -> void:
    if not bool(actor.get("alive", false)):
        return
    var cost: int = maxi(
        1,
        int(floor(float(actor.get("max_hp", 1)) * clampf(fraction, 0.0, 1.0)))
    )
    cost = mini(cost, int(actor.get("hp", 0)))
    actor["hp"] = maxi(0, int(actor.get("hp", 0)) - cost)
    if int(actor.get("hp", 0)) <= 0:
        actor["alive"] = false
    _spawn_feedback_label(actor, label + " −" + str(cost) + " KP", Color("ffb5aa"))


func _ad_snow_active() -> bool:
    return battle_weather.is_active() and battle_weather.current_id() == "snow"
