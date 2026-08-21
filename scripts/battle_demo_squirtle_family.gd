extends "res://scripts/battle_demo_charmander_family.gd"

# Final Timeflow integration for Schiggy -> Schillok -> Turtok TM package.
# This layer only adds the newly approved mechanics and reuses all central
# Bisasam/Glumanda systems underneath it.

const SF_PER_TARGET_ACCURACY_MOVES: Array[String] = ["icy_wind", "blizzard", "muddy_water"]
const SF_UNDERWATER_HIT_MOVES: Array[String] = ["surf", "whirlpool"]
const SF_SUMMARIES: Dictionary = {
    "chilling_water":"Schaden · Treffer: Angriff ↓ (Statuswert) · 3 Zielaktionen",
    "icy_wind":"Alle Gegner · Treffer: Geschwindigkeit ↓ (Statuswert) · 3 Zielaktionen",
    "mud_shot":"Schaden · Treffer: Geschwindigkeit ↓ (Statuswert) · 3 Zielaktionen",
    "zen_headbutt":"Schaden · 20 % Zurückschrecken: aktuelle Zeitleiste auf 0 %",
    "ice_punch":"Schaden · 10 % Gefroren",
    "liquidation":"Schaden · 20 %: Verteidigung ↓ (Statuswert) · 3 Zielaktionen",
    "surf":"Trifft alle anderen aktiven Pokémon · gegen Unterwasserziel doppelte Stärke",
    "ice_spinner":"Schaden · Treffer entfernt aktives Terrain, nicht das Wetter",
    "ice_beam":"Schaden · 10 % Gefroren",
    "blizzard":"Alle Gegner · 10 % Gefroren je Treffer · bei Schnee garantiert",
    "water_pledge":"Allein Stärke 80 · Säulen-Kombo Stärke 150 · Feuer=W Regenbogen, Pflanze=W Sumpf",
    "gyro_ball":"Stärke 1–150 nach Verhältnis der aktuellen effektiven Geschwindigkeiten",
    "flip_turn":"Schaden · Treffer setzt die aktuelle Aggro des Anwenders auf 0",
    "whirlpool":"Schaden · Fesselung 4–5 Zielaktionen mit 1/8 Max-KP · Unterwasser doppelt",
    "muddy_water":"Alle Gegner · 30 % je Treffer: Genauigkeit ↓ (Statuswert) · 3 Zielaktionen",
    "avalanche":"Stärke 120 gegen genau den Gegner, der seit der letzten eigenen Aktion KP-Schaden verursacht hat",
    "body_press":"Verwendet die aktuelle Verteidigung des Anwenders als offensiven Wert",
    "dark_pulse":"Schaden · 20 % Zurückschrecken: aktuelle Zeitleiste auf 0 %",
    "aura_sphere":"Trifft ohne normale Genauigkeitsprüfung; echte Unverwundbarkeit bleibt bestehen",
    "hydro_cannon":"Stärke 150 · Treffer: nächste eigene Aktion ist Regeneration",
    "smack_down":"Schaden · fliegende/schwebende Ziele für 3 eigene Aktionen am Boden"
}

var _sf_active_move_id: String = ""
var _sf_filtered_target_ids: Dictionary = {}
var _sf_filter_targets: bool = false


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["db_freeze_actions"] = 0
    combatant["sf_grounded_until_action"] = 0
    combatant["sf_direct_damage_sources"] = {}
    return combatant


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    if str(actor.get("major_status", "")) == "freeze":
        var freeze_left: int = maxi(0, int(actor.get("db_freeze_actions", 0)))
        if freeze_left > 0:
            _database_interrupt_forced_sequence(actor)
            _sf_consume_freeze_action(actor, freeze_left)
            actor["sf_direct_damage_sources"] = {}
            return
        actor["major_status"] = ""

    var original: Dictionary = _move_data(move_id)
    if original.is_empty():
        super._execute_move(actor, move_id)
        actor["sf_direct_damage_sources"] = {}
        return

    var temp: Dictionary = original.duplicate(true)
    var initial_targets: Array = super._targets(actor, str(temp.get("target", "enemy_highest_aggro")))
    var snapshots: Dictionary = _sf_snapshot_targets(initial_targets)

    if move_id == "avalanche" and not initial_targets.is_empty() and initial_targets[0] is Dictionary:
        var avalanche_target: Dictionary = initial_targets[0]
        var sources_value: Variant = actor.get("sf_direct_damage_sources", {})
        if sources_value is Dictionary and bool((sources_value as Dictionary).get(str(avalanche_target.get("id", "")), false)):
            temp["power"] = 120

    if move_id == "gyro_ball" and not initial_targets.is_empty() and initial_targets[0] is Dictionary:
        temp["power"] = _sf_gyro_ball_power(actor, initial_targets[0] as Dictionary)

    if move_id == "blizzard" and battle_weather.current_id() == "snow":
        temp["accuracy"] = null
    elif SF_PER_TARGET_ACCURACY_MOVES.has(move_id):
        _sf_prepare_per_target_accuracy(actor, temp, initial_targets)

    data["moves"][move_id] = temp
    _sf_active_move_id = move_id
    super._execute_move(actor, move_id)
    _sf_active_move_id = ""
    _sf_filter_targets = false
    _sf_filtered_target_ids.clear()
    data["moves"][move_id] = original

    var hit_success: bool = _sf_any_hit(snapshots)
    _sf_record_direct_hp_damage(actor, snapshots)

    if hit_success:
        match move_id:
            "ice_spinner":
                if _bulba_grassy_terrain_active():
                    _bulba_grassy_terrain.clear()
                    _spawn_feedback_label(actor, "🧊 TERRAIN ENTFERNT", Color("bfe7f5"))
            "flip_turn":
                actor["aggro"] = 0.0
                _spawn_feedback_label(actor, "↩️ AGGRO → 0", Color("b9d7ff"))
            "smack_down":
                _sf_apply_smack_down(snapshots)

    actor["sf_direct_damage_sources"] = {}
    _refresh_cards()


func _choose_wait() -> void:
    var actor: Dictionary = selected_actor
    super._choose_wait()
    if not actor.is_empty():
        actor["sf_direct_damage_sources"] = {}


func _database_consume_recharge(actor: Dictionary) -> void:
    super._database_consume_recharge(actor)
    actor["sf_direct_damage_sources"] = {}


func _sf_consume_freeze_action(actor: Dictionary, freeze_left: int) -> void:
    var fake_id: String = "__timeflow_freeze"
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return
    var moves: Dictionary = moves_value
    var previous_value: Variant = moves.get(fake_id, null)
    moves[fake_id] = {
        "id":fake_id,"name":"Gefroren","description":"Das Pokémon ist gefroren und kann diese eigene Aktion nicht handeln.",
        "emoji":"🧊","type":"ice","category":"status","power":null,"accuracy":null,"ap":1,
        "target":"self","area":false,"priority":0,"opening":false,"mechanics":[]
    }
    data["moves"] = moves
    super._execute_move(actor, fake_id)
    if previous_value == null:
        moves.erase(fake_id)
    else:
        moves[fake_id] = previous_value
    data["moves"] = moves

    var remaining: int = freeze_left - 1
    actor["db_freeze_actions"] = maxi(0, remaining)
    if remaining <= 0:
        actor["major_status"] = ""
        _set_log(_actor_name(actor) + " taut auf.")
        _spawn_feedback_label(actor, "✨ TAUT AUF", Color("f0e7a6"))
    else:
        _set_log(_actor_name(actor) + " ist gefroren und kann nicht handeln.")
        _spawn_feedback_label(actor, "🧊 GEFROREN · " + str(remaining), Color("bfe7f5"))
    _refresh_cards()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind in ["status", "db_status"] and str(mechanic.get("status", "")) == "freeze":
        return _sf_apply_freeze(actor, target, float(mechanic.get("chance", 1.0)))
    if kind == "atb_knockback":
        return _sf_apply_flinch(actor, target, float(mechanic.get("chance", 1.0)))
    return super._effect(actor, target, mechanic)


func _sf_apply_freeze(actor: Dictionary, target: Dictionary, base_chance: float) -> float:
    if not bool(target.get("alive", false)):
        return 0.0
    if _bulba_substitute_blocks_effect(actor, target, {"kind":"status"}):
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return 0.0
    if randf() > _cf_effect_chance(actor, base_chance):
        return 0.0
    if _database_status_is_blocked(target, "freeze"):
        return 0.0
    if not str(target.get("major_status", "")).is_empty() or bool(target.get("paralyzed", false)):
        return 0.0
    target["major_status"] = "freeze"
    target["db_freeze_actions"] = randi_range(1, 3)
    _spawn_feedback_label(target, "🧊 GEFROREN · 1–3 AKTIONEN", Color("bfe7f5"))
    return _hp_scaled_aggro(target, 0.10)


func _sf_apply_flinch(actor: Dictionary, target: Dictionary, base_chance: float) -> float:
    if not bool(target.get("alive", false)):
        return 0.0
    if _bulba_substitute_blocks_effect(actor, target, {"kind":"atb_knockback"}):
        _spawn_feedback_label(target, "🧸 ABGEFANGEN", Color("edcf9b"))
        return 0.0
    if randf() > _cf_effect_chance(actor, base_chance):
        return 0.0
    var removed: float = clampf(float(target.get("atb", 0.0)), 0.0, 100.0)
    target["atb"] = 0.0
    _spawn_feedback_label(target, "💫 ZURÜCKGESCHRECKT · ATB 0 %", Color("d7c4ff"))
    return _hp_scaled_aggro(target, 0.10) * (removed / 100.0)


func _cf_thaw(combatant: Dictionary, feedback: String) -> bool:
    var thawed: bool = super._cf_thaw(combatant, feedback)
    if thawed:
        combatant["db_freeze_actions"] = 0
    return thawed


func _targets(actor: Dictionary, rule: String) -> Array:
    var targets: Array = super._targets(actor, rule)
    if not _sf_filter_targets or _sf_active_move_id.is_empty():
        return targets
    var filtered: Array = []
    for target_value: Variant in targets:
        if target_value is Dictionary and _sf_filtered_target_ids.has(str((target_value as Dictionary).get("id", ""))):
            filtered.append(target_value)
    return filtered


func _sf_prepare_per_target_accuracy(actor: Dictionary, move: Dictionary, targets: Array) -> void:
    _sf_filtered_target_ids.clear()
    _sf_filter_targets = true
    var base_accuracy: float = float(move.get("accuracy", 100.0))
    var actor_multiplier: float = maxf(0.0, float(actor.get("accuracy_mult", 1.0)))
    actor_multiplier *= maxf(0.0, _combined_timed_modifier(actor, "accuracy_mod"))
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_multiplier: float = 1.0
        if int(target.get("action_serial", 0)) < int(target.get("db_incoming_accuracy_expires", 0)):
            target_multiplier = maxf(0.0, float(target.get("db_incoming_accuracy_mult", 1.0)))
        var hit_chance: float = clampf(base_accuracy * actor_multiplier * target_multiplier / 100.0, 0.0, 1.0)
        if randf() <= hit_chance:
            _sf_filtered_target_ids[str(target.get("id", ""))] = true
    if _sf_filtered_target_ids.is_empty() and not targets.is_empty():
        move["accuracy"] = 0.0
        _sf_filter_targets = false
    else:
        move["accuracy"] = null


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var adjusted_power: int = power
    var move_id: String = _sf_current_move_id()

    if SF_UNDERWATER_HIT_MOVES.has(move_id) and _tf_has_state(target, "underwater"):
        adjusted_power *= 2

    var original_attack: Variant = actor.get("attack", 0)
    var original_types: Variant = target.get("types", [])
    var body_press: bool = move_id == "body_press"
    var remove_flying_for_ground: bool = move_type == "ground" and _sf_force_grounded_active(target) and _type_array(target.get("types", [])).has("flying")

    if body_press:
        actor["attack"] = _sf_body_press_offense(actor)
    if remove_flying_for_ground:
        var adjusted_types: Array = _type_array(target.get("types", []))
        adjusted_types.erase("flying")
        target["types"] = adjusted_types

    var damage: int = super._damage(actor, target, adjusted_power, move_type, category)
    actor["attack"] = original_attack
    target["types"] = original_types
    return damage


func _sf_body_press_offense(actor: Dictionary) -> float:
    return maxf(1.0, float(actor.get("defense", 1.0)) * _combined_timed_modifier(actor, "incoming_damage_mod"))


func _sf_effective_speed(combatant: Dictionary) -> float:
    var speed: float = maxf(0.01, float(combatant.get("speed", 1.0)))
    if bool(combatant.get("paralyzed", false)):
        speed *= 0.5
    return maxf(0.01, speed / maxf(0.0001, _combined_timed_modifier(combatant, "atb_cycle_mod")))


func _sf_gyro_ball_power(actor: Dictionary, target: Dictionary) -> int:
    var user_speed: float = _sf_effective_speed(actor)
    var target_speed: float = _sf_effective_speed(target)
    return clampi(int(floor(25.0 * target_speed / maxf(0.01, user_speed))) + 1, 1, 150)


func _cf_target_reachable_by_move(target: Dictionary, move_id: String) -> bool:
    if _tf_has_state(target, "underwater"):
        return SF_UNDERWATER_HIT_MOVES.has(move_id)
    if _tf_has_state(target, "airborne_fly") and move_id == "smack_down":
        return true
    return super._cf_target_reachable_by_move(target, move_id)


func _tf_is_grounded(combatant: Dictionary) -> bool:
    if _sf_force_grounded_active(combatant):
        return true
    return super._tf_is_grounded(combatant)


func _sf_force_grounded_active(combatant: Dictionary) -> bool:
    var expires: int = int(combatant.get("sf_grounded_until_action", 0))
    return expires > 0 and int(combatant.get("action_serial", 0)) < expires


func _sf_apply_smack_down(snapshots: Dictionary) -> void:
    for entry_value: Variant in snapshots.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var target_value: Variant = entry.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if not _sf_entry_was_hit(entry):
            continue
        var was_not_grounded: bool = not super._tf_is_grounded(target) or _tf_has_state(target, "airborne_fly") or _tf_has_state(target, "raised")
        if not was_not_grounded:
            continue
        target["sf_grounded_until_action"] = int(target.get("action_serial", 0)) + 3
        _tf_set_state(target, "airborne_fly", false)
        _tf_set_state(target, "airborne_bounce", false)
        _tf_set_state(target, "raised", false)
        _cf_set_sprite_visible(target, true)
        _spawn_feedback_label(target, "🪨 AM BODEN · 3 AKTIONEN", Color("d3bd9b"))


func _cf_pledge_combo_kind(first: String, second: String) -> String:
    var pair: Array[String] = [first, second]
    if pair.has("grass") and pair.has("water"):
        return "swamp"
    return super._cf_pledge_combo_kind(first, second)


func _cf_apply_pledge_combo(actor: Dictionary, combo: String) -> void:
    if combo == "swamp":
        for target_value: Variant in _living_opponents(actor):
            if not (target_value is Dictionary):
                continue
            var target: Dictionary = target_value
            _bulba_refresh_timed_modifier(target, "atb_cycle_mod", 4.0, "Sumpf", _actor_name(actor))
            _spawn_feedback_label(target, "🌫️ SUMPF · GESCHWINDIGKEIT 25 % · 3 AKTIONEN", Color("a8c5a0"))
        return
    super._cf_apply_pledge_combo(actor, combo)


func _sf_snapshot_targets(targets: Array) -> Dictionary:
    var result: Dictionary = {}
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        result[str(target.get("id", ""))] = {
            "target":target,
            "hp":int(target.get("hp", 0)),
            "substitute_hp":int(target.get("db_substitute_hp", 0))
        }
    return result


func _sf_entry_was_hit(entry: Dictionary) -> bool:
    var target_value: Variant = entry.get("target", {})
    if not (target_value is Dictionary):
        return false
    var target: Dictionary = target_value
    return int(target.get("hp", 0)) < int(entry.get("hp", 0)) or int(target.get("db_substitute_hp", 0)) < int(entry.get("substitute_hp", 0))


func _sf_any_hit(snapshots: Dictionary) -> bool:
    for entry_value: Variant in snapshots.values():
        if entry_value is Dictionary and _sf_entry_was_hit(entry_value as Dictionary):
            return true
    return false


func _sf_record_direct_hp_damage(actor: Dictionary, snapshots: Dictionary) -> void:
    var actor_id: String = str(actor.get("id", ""))
    if actor_id.is_empty():
        return
    for entry_value: Variant in snapshots.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var target_value: Variant = entry.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        if str(target.get("id", "")) == actor_id or int(target.get("hp", 0)) >= int(entry.get("hp", 0)):
            continue
        var sources_value: Variant = target.get("sf_direct_damage_sources", {})
        var sources: Dictionary = sources_value if sources_value is Dictionary else {}
        sources[actor_id] = true
        target["sf_direct_damage_sources"] = sources


func _sf_current_move_id() -> String:
    if not _sf_active_move_id.is_empty():
        return _sf_active_move_id
    return _cf_current_move_id()


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if str(combatant.get("major_status", "")) == "freeze":
        tokens.append("🧊 GEF " + str(maxi(0, int(combatant.get("db_freeze_actions", 0)))))
    if _sf_force_grounded_active(combatant):
        tokens.append("🪨 AM BODEN")
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var text: String = super._detail_info(combatant)
    var extra: Array[String] = []
    if str(combatant.get("major_status", "")) == "freeze":
        extra.append("🧊 Gefroren: noch %d eigene Aktionsmöglichkeit(en) ohne Handlung" % maxi(0, int(combatant.get("db_freeze_actions", 0))))
    if _sf_force_grounded_active(combatant):
        extra.append("🪨 Am Boden: Bodenimmunität durch Flug/Schweben aufgehoben; Terrain wirkt")
    if extra.is_empty():
        return text
    return text + "\n\n[b]SCHIGGY-FAMILIE[/b]\n• " + "\n• ".join(extra)


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if SF_SUMMARIES.has(move_id):
        return str(SF_SUMMARIES[move_id])
    return super._compact_effect_summary(move)
