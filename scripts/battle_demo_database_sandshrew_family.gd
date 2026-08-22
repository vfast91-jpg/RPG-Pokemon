extends "res://scripts/battle_demo_database_pichu_family.gd"

# Sandan/Sandamer Gate-2 runtime bridge.
# The family uses existing central Timeflow systems wherever possible:
# timed modifiers, multi-hit, binding, type effectiveness, forced actions and
# entry-hazard cleanup. Only the approved Timeflow translations that need field
# orchestration live here.

const SAND_WEIGHT_PATH: String = "res://data/gen1_species_weights_v1.json"
const SAND_ROLLOUT_POWERS: Array[int] = [30, 60, 120, 240, 480]

const SAND_MOVE_SUMMARIES: Dictionary = {
    "defense_curl": "Verteidigung ↑ für 3 eigene Aktionen · Eingerollt bleibt bis Kampfende und verdoppelt Walzer",
    "rollout": "Bis zu 5 erzwungene eigene Aktionen · Stärke 30 → 60 → 120 → 240 → 480 · Einigler verdoppelt",
    "crush_claw": "Schaden · 50 %: Verteidigung ↓ (Statuswert) für 3 Zielaktionen",
    "fury_swipes": "2–5 Treffer · ein Genauigkeitswurf · Volltreffer pro Treffer",
    "sand_tomb": "Schaden · Bindung 4–5 Zielaktionen · danach jeweils 1/8 Max-KP",
    "low_kick": "Je schwerer das Ziel, desto stärker: Stärke 20–120",
    "spikes": "Bis 3 Lagen · bodengebundene physische Kontaktaktionen lösen 1/8, 1/6 oder 1/4 Max-KP aus",
    "stealth_rock": "Physische Kontaktaktionen lösen 1/8 Max-KP × Gesteins-Effektivität aus",
    "stone_edge": "Stärke 100 · 80 % Genauigkeit · erhöhte Volltrefferchance",
    "high_horsepower": "Stärke 95 · 95 % Genauigkeit · zuverlässiger Boden-Einzelangriff"
}

var _sand_weights_kg: Dictionary = {}


func _load_data() -> void:
    super._load_data()
    var pack: Dictionary = _database_read_json_dictionary(SAND_WEIGHT_PATH)
    var weights_value: Variant = pack.get("weights_kg", {})
    _sand_weights_kg = weights_value.duplicate(true) if weights_value is Dictionary else {}


func _start_battle() -> void:
    _sand_reset_hazards()
    super._start_battle()


func open_config() -> void:
    _sand_reset_hazards()
    super.open_config()


func _sand_reset_hazards() -> void:
    for side: String in ["player", "enemy"]:
        set_meta("sand_spikes_" + side, 0)
        set_meta("sand_spikes_source_" + side, "")
        set_meta("sand_stealth_rock_" + side, false)
        set_meta("sand_stealth_rock_source_" + side, "")


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["sand_defense_curled"] = false
    combatant["sand_rollout_active"] = false
    combatant["sand_rollout_step"] = 0
    return combatant


func _database_interrupt_forced_sequence(actor: Dictionary) -> void:
    super._database_interrupt_forced_sequence(actor)
    actor["sand_rollout_active"] = false
    actor["sand_rollout_step"] = 0


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var source_move: Dictionary = _move_data(move_id)
    if source_move.is_empty():
        super._execute_move(actor, move_id)
        return

    var move: Dictionary = source_move.duplicate(true)
    var snapshots: Dictionary = _pika_target_snapshots(actor, move)
    var rollout_was_active: bool = (
        move_id == "rollout"
        and bool(actor.get("sand_rollout_active", false))
    )

    if move_id == "low_kick":
        var low_kick_targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
        if not low_kick_targets.is_empty() and low_kick_targets[0] is Dictionary:
            move["power"] = _sand_low_kick_power_for_target(low_kick_targets[0])

    if move_id == "rollout":
        move["power"] = _sand_rollout_power_for_step(
            int(actor.get("sand_rollout_step", 0)),
            bool(actor.get("sand_defense_curled", false))
        )

    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        super._execute_move(actor, move_id)
        return
    var runtime_moves: Dictionary = moves_value
    runtime_moves[move_id] = move
    data["moves"] = runtime_moves

    super._execute_move(actor, move_id)

    var attempted: bool = _database_move_was_attempted(move_id)
    var hit_success: bool = _pika_any_target_hit(snapshots)

    runtime_moves[move_id] = source_move
    data["moves"] = runtime_moves

    if move_id == "defense_curl" and attempted:
        actor["sand_defense_curled"] = true
        _spawn_feedback_label(actor, "🛡️ EINGEROLLT", Color("d7c998"))

    if move_id == "rollout":
        _sand_finish_rollout_action(actor, attempted, hit_success, rollout_was_active)

    if move_id == "spikes" and attempted:
        _sand_place_spikes(actor)

    if move_id == "stealth_rock" and attempted:
        _sand_place_stealth_rock(actor)

    _refresh_cards()
    _check_end()


func _sand_finish_rollout_action(
    actor: Dictionary,
    attempted: bool,
    hit_success: bool,
    rollout_was_active: bool
) -> void:
    if not attempted or not hit_success or not bool(actor.get("alive", false)):
        _database_interrupt_forced_sequence(actor)
        if bool(actor.get("alive", false)):
            _spawn_feedback_label(actor, "🪨 WALZER-SERIE ENDE", Color("d9b49a"))
        return

    if not rollout_was_active:
        actor["sand_rollout_active"] = true
        actor["sand_rollout_step"] = 1
        actor["db_forced_move_id"] = "rollout"
        actor["db_forced_actions_left"] = 4
        _spawn_feedback_label(actor, "🪨 WALZER 1/5", Color("dfc98a"))
        return

    var completed_step: int = clampi(int(actor.get("sand_rollout_step", 0)), 1, 4)
    var actions_left: int = maxi(0, int(actor.get("db_forced_actions_left", 0)) - 1)
    actor["db_forced_actions_left"] = actions_left

    if actions_left <= 0 or completed_step >= 4:
        _spawn_feedback_label(actor, "🪨 WALZER 5/5", Color("f0d07c"))
        _database_interrupt_forced_sequence(actor)
        return

    actor["sand_rollout_step"] = completed_step + 1
    _spawn_feedback_label(
        actor,
        "🪨 WALZER " + str(completed_step + 1) + "/5",
        Color("dfc98a")
    )


func _sand_rollout_power_for_step(step: int, defense_curled: bool) -> int:
    var index: int = clampi(step, 0, SAND_ROLLOUT_POWERS.size() - 1)
    var power: int = SAND_ROLLOUT_POWERS[index]
    return power * 2 if defense_curled else power


func _sand_low_kick_power_for_target(target: Dictionary) -> int:
    var species_id: String = str(target.get("species_id", ""))
    var weight_kg: float = float(_sand_weights_kg.get(species_id, 0.0))
    return _sand_weight_power(weight_kg)


func _sand_weight_power(weight_kg: float) -> int:
    if weight_kg < 10.0:
        return 20
    if weight_kg < 25.0:
        return 40
    if weight_kg < 50.0:
        return 60
    if weight_kg < 100.0:
        return 80
    if weight_kg < 200.0:
        return 100
    return 120


func _sand_place_spikes(actor: Dictionary) -> void:
    var target_side: String = _sand_opposite_side(str(actor.get("side", "")))
    if target_side.is_empty():
        return
    var key: String = "sand_spikes_" + target_side
    var layers: int = mini(3, int(get_meta(key, 0)) + 1)
    set_meta(key, layers)
    set_meta("sand_spikes_source_" + target_side, str(actor.get("id", "")))
    _spawn_feedback_label(actor, "🔺 STACHLER " + str(layers) + "/3", Color("dec58b"))


func _sand_place_stealth_rock(actor: Dictionary) -> void:
    var target_side: String = _sand_opposite_side(str(actor.get("side", "")))
    if target_side.is_empty():
        return
    set_meta("sand_stealth_rock_" + target_side, true)
    set_meta("sand_stealth_rock_source_" + target_side, str(actor.get("id", "")))
    _spawn_feedback_label(actor, "🪨 TARNSTEINE", Color("cbbd9b"))


func _sand_opposite_side(side: String) -> String:
    if side == "player":
        return "enemy"
    if side == "enemy":
        return "player"
    return ""


func _database_trigger_toxic_spikes_if_defined(
    actor: Dictionary,
    move: Dictionary,
    move_attempted: bool
) -> void:
    super._database_trigger_toxic_spikes_if_defined(actor, move, move_attempted)

    if (
        not move_attempted
        or str(move.get("category", "")) != "physical"
        or not bool(move.get("contact", false))
        or not bool(actor.get("alive", false))
    ):
        return

    var own_side: String = str(actor.get("side", ""))
    if own_side.is_empty():
        return

    var spikes_layers: int = int(get_meta("sand_spikes_" + own_side, 0))
    if spikes_layers > 0 and _tf_is_grounded(actor):
        var spike_damage: int = _sand_apply_hazard_damage(
            actor,
            _sand_spikes_fraction(spikes_layers),
            str(get_meta("sand_spikes_source_" + own_side, "")),
            "🔺 STACHLER"
        )
        if spike_damage > 0 and not bool(actor.get("alive", false)):
            _refresh_cards()
            _check_end()
            return

    if bool(get_meta("sand_stealth_rock_" + own_side, false)):
        var effectiveness: float = TypeSystem.get_multiplier(
            "rock",
            _type_array(actor.get("types", []))
        )
        _sand_apply_hazard_damage(
            actor,
            0.125 * effectiveness,
            str(get_meta("sand_stealth_rock_source_" + own_side, "")),
            "🪨 TARNSTEINE"
        )

    _refresh_cards()
    _check_end()


func _sand_spikes_fraction(layers: int) -> float:
    match clampi(layers, 1, 3):
        1:
            return 1.0 / 8.0
        2:
            return 1.0 / 6.0
        _:
            return 1.0 / 4.0


func _sand_apply_hazard_damage(
    target: Dictionary,
    fraction: float,
    source_id: String,
    label_text: String
) -> int:
    if fraction <= 0.0 or not bool(target.get("alive", false)):
        return 0

    var amount: int = maxi(
        1,
        int(floor(float(target.get("max_hp", 1)) * fraction))
    )
    var actual: int = mini(amount, int(target.get("hp", 0)))
    if actual <= 0:
        return 0

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    _spawn_feedback_label(target, label_text + " −" + str(actual), Color("dfb98b"))

    var source: Dictionary = _tf_find_combatant(source_id)
    if not source.is_empty():
        source["aggro"] = float(source.get("aggro", 0.0)) + float(actual)

    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false
    return actual


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind == "db_clear_allied_hazards":
        var own_side: String = str(actor.get("side", ""))
        var removed_new_hazard: bool = _sand_clear_side_hazards(own_side)
        var base_effect: float = super._effect(actor, target, mechanic)
        return maxf(base_effect, 1.0 if removed_new_hazard else 0.0)
    return super._effect(actor, target, mechanic)


func _sand_clear_side_hazards(side: String) -> bool:
    if side.is_empty():
        return false
    var had_hazard: bool = (
        int(get_meta("sand_spikes_" + side, 0)) > 0
        or bool(get_meta("sand_stealth_rock_" + side, false))
    )
    set_meta("sand_spikes_" + side, 0)
    set_meta("sand_spikes_source_" + side, "")
    set_meta("sand_stealth_rock_" + side, false)
    set_meta("sand_stealth_rock_source_" + side, "")
    return had_hazard


func _bfam_apply_defog_cleanup(actor: Dictionary) -> void:
    super._bfam_apply_defog_cleanup(actor)
    _sand_clear_side_hazards("player")
    _sand_clear_side_hazards("enemy")


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if SAND_MOVE_SUMMARIES.has(move_id):
        return str(SAND_MOVE_SUMMARIES[move_id])
    return super._compact_effect_summary(move)


func _move_tooltip(move: Dictionary) -> String:
    var text: String = super._move_tooltip(move)
    var move_id: String = str(move.get("id", ""))

    if move_id == "low_kick" and not selected_actor.is_empty():
        var targets: Array = _targets(
            selected_actor,
            str(move.get("target", "enemy_highest_aggro"))
        )
        if not targets.is_empty() and targets[0] is Dictionary:
            text += "\nAktuelle Stärke gegen Ziel: " + str(
                _sand_low_kick_power_for_target(targets[0])
            )

    if move_id == "rollout" and not selected_actor.is_empty():
        text += "\nAktuelle Walzer-Stärke: " + str(
            _sand_rollout_power_for_step(
                int(selected_actor.get("sand_rollout_step", 0)),
                bool(selected_actor.get("sand_defense_curled", false))
            )
        )

    return _final_attack_text(text)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if bool(combatant.get("sand_defense_curled", false)):
        tokens.append("EINGEROLLT")
    if bool(combatant.get("sand_rollout_active", false)):
        tokens.append(
            "WALZER " + str(clampi(int(combatant.get("sand_rollout_step", 0)) + 1, 1, 5)) + "/5"
        )
    return tokens
