extends "res://scripts/battle_demo_endgame_v1.gd"

# Hardening layer: for levels above 100, deliberately build the established
# level-100 combatant first and then apply Timeflow's uncapped continuation.
# This prevents any older layer from preserving a >100 level label while still
# silently calculating level-100 stats.
#
# This top battle layer also owns the CENTRAL spread-damage reduction. Keeping
# it here means the multiplier is applied after all inherited damage modifiers,
# exactly as required by the Timeflow rule: it scales the final damage per
# actually targeted/hit Pokemon and therefore cannot be forgotten by a family
# implementation.
#
# Numerical spread-status effects are centralized here for the same reason.
# Their strength is reduced by target count while duration, hit/status chance
# and binary effects remain untouched.

const AreaDamageRules = preload("res://scripts/battle/area_damage_rules.gd")
const AreaStatusRules = preload("res://scripts/battle/area_status_rules.gd")

# Keyed by actor id + counted action + move id. The first damage resolution of
# a spread move freezes its target-count multiplier for that whole action. That
# prevents early KOs from making later targets in the SAME attack take a larger
# percentage simply because fewer Pokemon are still alive by then.
var _area_damage_action_multipliers: Dictionary = {}
var _area_status_effect_pre_scaled: bool = false


func _start_battle() -> void:
    _area_damage_action_multipliers.clear()
    _area_status_effect_pre_scaled = false
    super._start_battle()


func open_config() -> void:
    _area_damage_action_multipliers.clear()
    _area_status_effect_pre_scaled = false
    super.open_config()


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var requested_level: int = maxi(1, int(setup.get("level", 1)))
    if requested_level <= 100:
        return super._make_combatant(side, index, setup)

    var capped_setup: Dictionary = setup.duplicate(true)
    capped_setup["level"] = 100
    var combatant: Dictionary = super._make_combatant(side, index, capped_setup)
    var reference_level: int = maxi(1, int(combatant.get("level", 100)))
    _apply_uncapped_level_growth(combatant, requested_level, reference_level)
    return combatant


func route_new_member(species_id: String, level: int) -> Dictionary:
    var requested_level: int = maxi(1, level)
    if requested_level <= 100:
        return super.route_new_member(species_id, requested_level)

    var member: Dictionary = super.route_new_member(species_id, 100)
    var resolved_species: String = route_resolve_species_for_level(species_id, requested_level)
    if resolved_species.is_empty():
        resolved_species = str(member.get("species_id", species_id))

    var snapshot: Dictionary = route_stat_snapshot(resolved_species, requested_level)
    member["species_id"] = resolved_species
    member["name"] = route_species_name(resolved_species)
    member["level"] = requested_level
    member["max_hp"] = maxi(1, int(snapshot.get("max_hp", member.get("max_hp", 1))))
    member["hp"] = int(member["max_hp"])
    member["known_moves"] = route_moves_for_level(resolved_species, requested_level)
    return member


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    var damage: int = super._damage(actor, target, power, move_type, category)
    if damage <= 0:
        return damage

    var move: Dictionary = _area_damage_active_move()
    if move.is_empty() or not AreaDamageRules.move_uses_central_scaling(move):
        return damage

    var multiplier: float = _area_damage_multiplier_for_resolution(actor, move)
    if multiplier >= 0.9999:
        return damage

    return maxi(1, int(round(float(damage) * multiplier)))


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if not AreaStatusRules.mechanic_uses_scaling(mechanic):
        return super._effect(actor, target, mechanic)

    var target_rule: String = _area_status_target_rule(mechanic)
    if not AreaStatusRules.target_rule_uses_scaling(target_rule):
        return super._effect(actor, target, mechanic)

    var target_count: int = _area_status_target_count(actor, target_rule, str(target.get("side", "")))
    if target_count <= 1:
        return super._effect(actor, target, mechanic)

    var scaled_mechanic: Dictionary = mechanic.duplicate(true)
    scaled_mechanic["multiplier_from_special"] = AreaStatusRules.scale_special_coefficient(
        float(mechanic.get("multiplier_from_special", 0.0)),
        target_count
    )

    # Some inherited/custom numerical handlers calculate their final modifier
    # through _status_modifier_multiplier(). Mark this call as already scaled so
    # the shared fallback below cannot apply the area factor a second time.
    _area_status_effect_pre_scaled = true
    var result: float = super._effect(actor, target, scaled_mechanic)
    _area_status_effect_pre_scaled = false
    return result


func _status_modifier_multiplier(
    actor: Dictionary,
    mechanic: Dictionary,
    kind: String,
    flag_a: bool = false,
    flag_b: bool = false
) -> float:
    var multiplier: float = super._status_modifier_multiplier(
        actor, mechanic, kind, flag_a, flag_b
    )
    if _area_status_effect_pre_scaled:
        return multiplier

    var target_rule: String = _area_status_target_rule(mechanic)
    if not AreaStatusRules.target_rule_uses_scaling(target_rule):
        return multiplier

    var target_count: int = _area_status_target_count(actor, target_rule)
    if target_count <= 1:
        return multiplier

    return AreaStatusRules.scale_modifier_multiplier(multiplier, target_count)


func _area_status_target_rule(mechanic: Dictionary) -> String:
    var scope: String = str(mechanic.get("scope", ""))
    if AreaStatusRules.target_rule_uses_scaling(scope):
        return scope

    var move: Dictionary = _area_damage_active_move()
    var move_rule: String = str(move.get("target", "")) if not move.is_empty() else ""
    if AreaStatusRules.target_rule_uses_scaling(move_rule):
        return move_rule

    return scope if not scope.is_empty() else move_rule


func _area_status_target_count(
    actor: Dictionary,
    target_rule: String,
    target_side: String = ""
) -> int:
    if not AreaStatusRules.target_rule_uses_scaling(target_rule):
        return 1

    var targets: Array = _targets(actor, target_rule)
    var count: int = 0
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var candidate: Dictionary = target_value
        if not bool(candidate.get("alive", false)):
            continue
        if not target_side.is_empty() and str(candidate.get("side", "")) != target_side:
            continue
        count += 1
    return maxi(1, count)


func _area_damage_active_move() -> Dictionary:
    if not _database_active_move.is_empty():
        return _database_active_move

    var move_id: String = str(_database_move_id)
    if move_id.is_empty():
        return {}
    return _move_data(move_id)


func _area_damage_multiplier_for_resolution(actor: Dictionary, move: Dictionary) -> float:
    if not AreaDamageRules.move_uses_central_scaling(move):
        return 1.0

    var move_id: String = str(move.get("id", _database_move_id))
    var action_key: String = (
        str(actor.get("id", ""))
        + "|" + str(actor.get("action_serial", 0))
        + "|" + move_id
    )
    if not _area_damage_action_multipliers.has(action_key):
        _area_damage_action_multipliers[action_key] = _area_damage_multiplier_for_move(actor, move)
    return float(_area_damage_action_multipliers.get(action_key, 1.0))


func _area_damage_multiplier_for_move(actor: Dictionary, move: Dictionary) -> float:
    if not AreaDamageRules.move_uses_central_scaling(move):
        return 1.0
    return AreaDamageRules.damage_multiplier(_area_damage_target_count(actor, move))


func _area_damage_target_count(actor: Dictionary, move: Dictionary) -> int:
    var rule: String = str(move.get("target", "enemy_highest_aggro"))
    var targets: Array = _targets(actor, rule)
    var count: int = 0
    for target_value: Variant in targets:
        if target_value is Dictionary and bool((target_value as Dictionary).get("alive", false)):
            count += 1
    return count
