extends "res://scripts/battle_demo_igglybuff_family.gd"

# Runtime activation of data/rules/status_effect_migration_v1.json.
# This is deliberately a thin top layer: established targeting, durations,
# visuals and special-case rules stay in their existing family/runtime layers;
# only the quantitative Status-dependent strengths are replaced here.

const StatusEffects = preload("res://scripts/battle/status_effect_runtime.gd")
const LEGACY_GRASSY_DAMAGE_MULTIPLIER: float = 1.30
const LEGACY_VOLT_SWITCH_CYCLE_MULTIPLIER: float = 0.70


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["status_migration_dragon_cheer_bonus"] = 0.0
    return combatant


func _status_value(combatant: Dictionary) -> float:
    return maxf(0.0, float(combatant.get("special", 0.0)))


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    match kind:
        "db_heal_self":
            return _status_migration_heal_self(actor, mechanic)
        "db_swallow":
            return _status_migration_swallow(actor)
        "db_reflect":
            return _status_migration_reflect(actor, target, mechanic)
        "db_electric_terrain":
            return _status_migration_electric_terrain(actor, mechanic)
        "critical_focus":
            # Dragon Cheer and Focus Energy intentionally cannot coexist.
            if int(actor.get("cf_dragon_cheer_actions", 0)) > 0:
                _spawn_feedback_label(actor, "✖ KRIT-BONUS BEREITS AKTIV", Color("d9a5a5"))
                return 0.0
    return super._effect(actor, target, mechanic)


func _status_migration_heal_self(actor: Dictionary, mechanic: Dictionary) -> float:
    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    if missing <= 0:
        return 0.0

    var weight: float = float(mechanic.get("status_weight", 1.0))
    if not mechanic.has("status_weight") and mechanic.has("fraction_max_hp"):
        # Preserve the old reference fraction at Status 75 (R=0.5).
        weight = 2.0 * float(mechanic.get("fraction_max_hp", 0.5))

    var requested: int = StatusEffects.max_hp_heal(
        int(actor.get("max_hp", 1)),
        _status_value(actor),
        weight
    )
    var healed: int = mini(missing, requested)
    if healed <= 0:
        return 0.0

    actor["hp"] = int(actor.get("hp", 0)) + healed
    _spawn_feedback_label(actor, "💚 +" + str(healed) + " KP", Color("8fe39b"))
    return float(healed)


func _status_migration_swallow(actor: Dictionary) -> float:
    var stacks: int = clampi(int(actor.get("db_stockpile", 0)), 0, 3)
    if stacks <= 0:
        return 0.0

    var weight_by_stacks: Dictionary = {1: 0.5, 2: 1.0, 3: 2.0}
    var weight: float = float(weight_by_stacks.get(stacks, 2.0))
    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    var requested: int = StatusEffects.max_hp_heal(
        int(actor.get("max_hp", 1)),
        _status_value(actor),
        weight
    )
    var healed: int = mini(missing, requested)
    if healed > 0:
        actor["hp"] = int(actor.get("hp", 0)) + healed
        _spawn_feedback_label(actor, "💚 +" + str(healed) + " KP", Color("8fe39b"))
    actor["db_stockpile"] = 0
    return float(healed)


func _status_migration_reflect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var reduction: float = StatusEffects.bounded_ratio(_status_value(actor), 1.0)
    target["pika_reflect_reduction"] = reduction
    target["pika_reflect_source_id"] = str(actor.get("id", ""))
    target["pika_reflect_expires_source_action"] = (
        int(actor.get("action_serial", 0))
        + maxi(1, int(mechanic.get("duration_actions", 3)))
    )
    return reduction * 10.0


func _status_migration_electric_terrain(actor: Dictionary, mechanic: Dictionary) -> float:
    _pika_terrain_id = "electric"
    _pika_terrain_strength = 0.6 * StatusEffects.ratio(_status_value(actor))
    _pika_terrain_source_id = str(actor.get("id", ""))
    _pika_terrain_expires_source_action = (
        int(actor.get("action_serial", 0))
        + maxi(1, int(mechanic.get("duration_actions", 3)))
    )
    _spawn_feedback_label(actor, "⚡ ELEKTROFELD", Color("f1dc75"))
    return _pika_terrain_strength * 10.0


func _bulba_apply_drain_heal(actor: Dictionary, damage: int, legacy_fraction: float) -> void:
    if damage <= 0:
        return
    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    if missing <= 0:
        return

    # Legacy fractions describe the old reference healing. At Status 75 the
    # new curve has R=0.5, therefore weight=2*fraction preserves that point.
    var weight: float = maxf(0.0, 2.0 * legacy_fraction)
    var requested: int = StatusEffects.drain_heal(damage, _status_value(actor), weight)
    var healed: int = mini(missing, requested)
    if healed <= 0:
        return
    actor["hp"] = int(actor.get("hp", 0)) + healed
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(healed)
    _spawn_feedback_label(actor, "💚 +" + str(healed) + " KP", Color("8fe39b"))


func _cfam_finish_pollen_puff(actor: Dictionary, snapshots: Dictionary) -> bool:
    var target: Dictionary = _cfam_first_snapshot_target(snapshots)
    if target.is_empty():
        return false
    if str(target.get("side", "")) != str(actor.get("side", "")):
        return false
    if str(target.get("id", "")) == str(actor.get("id", "")):
        return false

    var missing: int = maxi(0, int(target.get("max_hp", 1)) - int(target.get("hp", 0)))
    if missing <= 0:
        _spawn_feedback_label(target, "💚 KP BEREITS VOLL", Color("8fe39b"))
        return true

    var requested: int = StatusEffects.max_hp_heal(
        int(target.get("max_hp", 1)),
        _status_value(actor),
        1.0
    )
    var healed: int = mini(missing, requested)
    if healed > 0:
        target["hp"] = int(target.get("hp", 0)) + healed
        actor["aggro"] = float(actor.get("aggro", 0.0)) + float(healed)
        _spawn_feedback_label(target, "🌼 +" + str(healed) + " KP", Color("8fe39b"))
    return true


func _apply_seed(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var result: float = super._apply_seed(actor, target, mechanic)
    if result <= 0.0:
        return result
    var seed_value: Variant = target.get("seed_effect", {})
    if seed_value is Dictionary:
        var seed: Dictionary = seed_value
        seed["status_ratio"] = StatusEffects.ratio(_status_value(actor))
        target["seed_effect"] = seed
    return result


func _resolve_seed_tick(target: Dictionary) -> void:
    var seed_value: Variant = target.get("seed_effect", {})
    if not (seed_value is Dictionary) or (seed_value as Dictionary).is_empty():
        return
    var seed: Dictionary = seed_value

    var source: Dictionary = _effect_source_occupant(seed)
    if source.is_empty():
        return

    var fraction: float = float(seed.get("damage_fraction", SEED_DAMAGE_FRACTION))
    var amount: int = maxi(1, int(floor(float(target.get("max_hp", 1)) * fraction)))
    var actual: int = mini(amount, int(target.get("hp", 0)))
    if actual <= 0:
        return

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    _spawn_feedback_label(target, "🌱 EGELSAMEN −" + str(actual), Color("a9db82"))

    var stored_ratio: float = float(seed.get(
        "status_ratio",
        StatusEffects.ratio(_status_value(source))
    ))
    var heal_fraction: float = clampf(2.0 * stored_ratio, 0.0, 1.0)
    var missing_hp: int = maxi(0, int(source.get("max_hp", 0)) - int(source.get("hp", 0)))
    var healed: int = mini(missing_hp, int(floor(float(actual) * heal_fraction)))
    if healed > 0:
        source["hp"] = int(source.get("hp", 0)) + healed
        _spawn_feedback_label(source, "🌱 +" + str(healed) + " KP", Color("8fe39b"))

    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false


func _bulba_activate_grassy_terrain(actor: Dictionary) -> float:
    _bulba_grassy_terrain = {
        "source_id": str(actor.get("id", "")),
        "source_side": str(actor.get("side", "")),
        "expires_after_action": int(actor.get("action_serial", 0)) + 3,
        "status_ratio": StatusEffects.ratio(_status_value(actor))
    }
    _spawn_feedback_label(actor, "🌱 GRASFELD · 3 AKTIONEN", Color("9ee28d"))
    return 4.0


func _bulba_grassy_pulse(source: Dictionary) -> void:
    var stored_ratio: float = float(_bulba_grassy_terrain.get(
        "status_ratio",
        StatusEffects.ratio(_status_value(source))
    ))
    var source_aggro: float = 0.0
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)) or not _bulba_is_grounded(combatant):
            continue
        var missing: int = maxi(0, int(combatant.get("max_hp", 1)) - int(combatant.get("hp", 0)))
        if missing <= 0:
            continue
        var requested: int = maxi(
            0,
            int(floor(float(combatant.get("max_hp", 1)) * 0.125 * stored_ratio))
        )
        var healed: int = mini(missing, requested)
        if healed <= 0:
            continue
        combatant["hp"] = int(combatant.get("hp", 0)) + healed
        _spawn_feedback_label(combatant, "🌱 +" + str(healed) + " KP", Color("9ee28d"))
        if str(combatant.get("side", "")) == str(source.get("side", "")):
            source_aggro += float(healed)
    source["aggro"] = float(source.get("aggro", 0.0)) + source_aggro


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var snapshots: Dictionary = {}
    var tracked_hit_move: bool = move_id == "volt_switch" or move_id == "grassy_glide"
    if tracked_hit_move:
        var move: Dictionary = _move_data(move_id)
        if not move.is_empty():
            snapshots = _pika_target_snapshots(actor, move)

    var status_before: float = _status_value(actor)
    var grassy_glide_enabled: bool = (
        move_id == "grassy_glide"
        and _bulba_grassy_terrain_active()
        and _bulba_is_grounded(actor)
    )

    super._execute_move(actor, move_id)

    if snapshots.is_empty() or not _pika_any_target_hit(snapshots):
        return

    if move_id == "volt_switch":
        var desired_cycle_multiplier: float = StatusEffects.next_cycle_multiplier(status_before, 0.5)
        var current_cycle: float = float(actor.get("cycle", 1.0))
        actor["cycle"] = current_cycle / LEGACY_VOLT_SWITCH_CYCLE_MULTIPLIER * desired_cycle_multiplier

    if move_id == "grassy_glide" and grassy_glide_enabled:
        actor["atb"] = StatusEffects.atb_start_percent(status_before, 0.5)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0:
        return damage

    if _bulba_grassy_terrain_active() and move_type == "grass" and _bulba_is_grounded(actor):
        var terrain_ratio: float = float(_bulba_grassy_terrain.get(
            "status_ratio",
            StatusEffects.ratio(_status_value(actor))
        ))
        var desired_grassy_multiplier: float = 1.0 + 0.6 * terrain_ratio
        damage = maxi(
            1,
            int(round(float(damage) / LEGACY_GRASSY_DAMAGE_MULTIPLIER * desired_grassy_multiplier))
        )

    if category == "physical" and _pika_reflect_active(target):
        var reduction: float = clampf(float(target.get("pika_reflect_reduction", 0.0)), 0.0, 0.999999)
        if reduction > 0.50:
            damage = maxi(1, int(round(float(damage) * (1.0 - reduction) / 0.50)))

    return damage


func _cf_apply_dragon_cheer(actor: Dictionary) -> bool:
    var affected: int = 0
    var actor_status: float = _status_value(actor)
    for ally_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        if (
            not bool(ally.get("alive", false))
            or str(ally.get("id", "")) == str(actor.get("id", ""))
            or not _cf_dragon_cheer_eligible(ally)
        ):
            continue

        var is_dragon: bool = _type_array(ally.get("types", [])).has("dragon")
        var weight: float = 1.0 if is_dragon else 0.5
        var bonus: float = StatusEffects.critical_bonus_fraction(actor_status, weight)
        ally["status_migration_dragon_cheer_bonus"] = bonus
        ally["cf_dragon_cheer_stage"] = 0
        ally["cf_dragon_cheer_actions"] = 3
        actor["aggro"] = float(actor.get("aggro", 0.0)) + _hp_scaled_aggro(ally, 0.04)
        affected += 1
        _spawn_feedback_label(
            ally,
            "🐉 KRIT +" + str(int(round(bonus * 100.0))) + "% · 3 AKTIONEN",
            Color("d7c4ff")
        )
    return affected > 0


func _critical_chance(combatant: Dictionary) -> float:
    var chance: float = super._critical_chance(combatant)
    if int(combatant.get("cf_dragon_cheer_actions", 0)) > 0:
        chance += float(combatant.get("status_migration_dragon_cheer_bonus", 0.0))
    return clampf(chance, 0.0, 1.0)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if int(combatant.get("cf_dragon_cheer_actions", 0)) > 0:
        var bonus: float = float(combatant.get("status_migration_dragon_cheer_bonus", 0.0))
        if bonus > 0.0001:
            tokens.append(
                "🐉 KRIT+" + str(int(round(bonus * 100.0))) + "% ("
                + str(int(combatant.get("cf_dragon_cheer_actions", 0))) + ")"
            )
    return tokens
