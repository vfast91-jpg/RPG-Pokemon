extends "res://scripts/battle_demo_ad_execution_v1.gd"

# Final combat bridges for the Abra -> Dodri batch.

func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    # Any newly activated terrain replaces the currently active terrain.
    if kind == "db_electric_terrain":
        _ad_psychic_terrain.clear()
        _bulba_grassy_terrain = {}
        _cleffa_misty_terrain = {}

    match kind:
        "ad_hide_cycle":
            _ad_enter_hidden_cycle(actor)
            return 0.0
        "ad_heal":
            return _ad_heal(actor, target, mechanic)
        "ad_protect":
            return _ad_protect(actor)
        "ad_reflect_type":
            return _ad_reflect_type(actor, target)
        "ad_modifier":
            return _ad_apply_modifier(actor, target, mechanic)
        "ad_ally_switch":
            return _ad_ally_switch(actor)
        "ad_yawn":
            return _ad_yawn(target)
        "ad_psychic_terrain":
            return _ad_activate_psychic_terrain(actor)
        "ad_trick_room":
            return _ad_toggle_trick_room(actor)
        "ad_chilly_reception":
            return _ad_chilly_reception(actor)
        "ad_magnet_rise":
            return _ad_magnet_rise(actor)
        "ad_magnetic_flux":
            return _ad_magnetic_flux(actor, target)
        "ad_mirror_coat":
            return _ad_mirror_coat(actor)
        "ad_lock_on":
            return _ad_lock_on(actor, target)
        "ad_acupressure":
            return _ad_acupressure(actor, target)
        "ad_mute_on_damage":
            return _ad_mute_on_damage(actor, target, mechanic)
        _:
            return super._effect(actor, target, mechanic)


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    if move_type == "ground" and _ad_magnet_rise_active(target):
        _spawn_feedback_label(target, "🧲 BODEN-IMMUN", Color("b8d9ff"))
        return 0

    var old_defense: Variant = target.get("defense", 1)
    if _ad_snow_active() and _type_array(target.get("types", [])).has("ice"):
        target["defense"] = maxf(1.0, float(old_defense) * 1.5)

    var damage: int = super._damage(actor, target, power, move_type, category)
    target["defense"] = old_defense

    if (
        damage > 0
        and _ad_psychic_terrain_active()
        and move_type == "psychic"
        and _bulba_is_grounded(actor)
    ):
        var ratio: float = float(_ad_psychic_terrain.get("status_ratio", 0.0))
        damage = maxi(1, int(round(float(damage) * (1.0 + 0.6 * ratio))))

    if (
        damage > 0
        and bool(target.get("ad_short_charging", false))
        and str(target.get("ad_short_charge_move", "")) == "revenge"
        and str(actor.get("side", "")) != str(target.get("side", ""))
    ):
        target["ad_revenge_was_hit"] = true

    if (
        damage > 0
        and category == "special"
        and _ad_mirror_coat_active(target)
        and str(actor.get("id", "")) != str(target.get("id", ""))
    ):
        var actual: int = mini(maxi(0, int(target.get("hp", 0))), damage)
        target["ad_mirror_pending_damage"] = (
            int(target.get("ad_mirror_pending_damage", 0)) + actual
        )
        target["ad_mirror_pending_attacker_id"] = str(actor.get("id", ""))

    return damage


func _targets(actor: Dictionary, rule: String) -> Array:
    var targets: Array = super._targets(actor, rule)

    # Psychic Terrain blocks positive-priority/opening attacks against grounded
    # targets. It never grants reachability to an otherwise unreachable target.
    if _ad_psychic_terrain_active() and not _ad_active_move_id.is_empty():
        var active_move: Dictionary = _move_data(_ad_active_move_id)
        if int(active_move.get("priority", 0)) > 0:
            var priority_filtered: Array = []
            for target_value: Variant in targets:
                if not (target_value is Dictionary):
                    continue
                var target: Dictionary = target_value
                if (
                    str(target.get("side", "")) != str(actor.get("side", ""))
                    and _bulba_is_grounded(target)
                ):
                    continue
                priority_filtered.append(target)
            targets = priority_filtered

    var filtered: Array = []
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if bool(target.get("ad_hidden_cycle", false)):
            continue
        filtered.append(target)

    if (
        rule == "enemy_highest_aggro"
        and filtered.is_empty()
        and not bool(actor.get("db_charge_firing", false))
        and _zf_selected_target_id.is_empty()
    ):
        var best: Dictionary = {}
        for candidate_value: Variant in _living_opponents(actor):
            if not (candidate_value is Dictionary):
                continue
            var candidate: Dictionary = candidate_value
            if bool(candidate.get("ad_hidden_cycle", false)):
                continue
            if best.is_empty():
                best = candidate
                continue
            var candidate_aggro: float = float(candidate.get("aggro", 0.0))
            var best_aggro: float = float(best.get("aggro", 0.0))
            if candidate_aggro > best_aggro:
                best = candidate
            elif (
                is_equal_approx(candidate_aggro, best_aggro)
                and int(candidate.get("index", 0)) < int(best.get("index", 0))
            ):
                best = candidate
        return [] if best.is_empty() else [best]

    return filtered


func _is_highest_aggro(combatant: Dictionary) -> bool:
    if bool(combatant.get("ad_hidden_cycle", false)):
        return false
    return super._is_highest_aggro(combatant)


func _bulba_is_grounded(combatant: Dictionary) -> bool:
    if _ad_magnet_rise_active(combatant):
        return false
    if bool(combatant.get("ad_hidden_cycle", false)):
        return false
    return super._bulba_is_grounded(combatant)


func _bulba_activate_grassy_terrain(actor: Dictionary) -> float:
    _ad_psychic_terrain.clear()
    _pika_terrain_id = ""
    return super._bulba_activate_grassy_terrain(actor)


func _status_migration_electric_terrain(actor: Dictionary, mechanic: Dictionary) -> float:
    _ad_psychic_terrain.clear()
    _bulba_grassy_terrain = {}
    return super._status_migration_electric_terrain(actor, mechanic)


func _cleffa_activate_misty_terrain(actor: Dictionary) -> void:
    _ad_psychic_terrain.clear()
    _pika_terrain_id = ""
    _bulba_grassy_terrain = {}
    super._cleffa_activate_misty_terrain(actor)


func _database_finish_multi_hit_sequence(state: Dictionary) -> void:
    super._database_finish_multi_hit_sequence(state)
    _ad_trigger_mirror_pending_on_all()


func _weather_effect_lines(weather_id: String) -> Array[String]:
    var lines: Array[String] = super._weather_effect_lines(weather_id)
    if weather_id == "snow":
        lines.append("Eis-Pokémon: +50% Verteidigung")
        lines.append("Blizzard: trifft sicher")
        lines.append("Auroraschleier: kann unter Schnee aktiviert werden")
    return lines


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if bool(combatant.get("ad_hidden_cycle", false)):
        tokens.append("🌀 WEG")
    if int(combatant.get("ad_drowsy_trigger_serial", -1)) >= 0:
        tokens.append("🥱 SCHLÄFRIG")
    if _ad_magnet_rise_active(combatant):
        tokens.append("🧲 SCHWEBT")
    if _ad_mute_active(combatant):
        tokens.append("🔇 STUMM")
    if not str(combatant.get("ad_lock_on_target_id", "")).is_empty():
        tokens.append("🎯 ZIELSCHUSS")
    if _ad_mirror_coat_active(combatant):
        tokens.append("🪞 SPIEGEL")
    if _ad_trick_room_remaining > 0.0:
        tokens.append("🔄 BIZARR")
    return tokens
