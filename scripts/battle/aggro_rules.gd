class_name AggroRules
extends RefCounted

# Central, side-effect-free Aggro mathematics for Pokemon Timeflow.
# Runtime layers may detect what actually changed; this file owns how that
# change is valued. Keeping the formulas here prevents per-move magic numbers.

const AreaDamageRules = preload("res://scripts/battle/area_damage_rules.gd")

const LEVEL_BASIS_FACTOR: float = 2.0
const MODIFIER_ACTION_WEIGHT: float = 0.50
const STATUS_PROTECTION_ACTION_WEIGHT: float = 0.25
const CLEANSE_WEIGHT: float = 0.50
const PARTIAL_CONTROL_ACTION_WEIGHT: float = 0.125
const UTILITY_EFFECT_WEIGHT: float = 0.25

const MODIFIER_KINDS: Array[String] = [
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod"
]


static func level_basis(combatant: Dictionary) -> float:
    return float(maxi(1, int(combatant.get("level", 1)))) * LEVEL_BASIS_FACTOR


static func spread_multiplier(target_count: int) -> float:
    # Effect Aggro deliberately shares the already approved spread-damage table.
    return AreaDamageRules.damage_multiplier(target_count)


static func status_application(
    target: Dictionary,
    status_id: String,
    affected_actions: int = 1
) -> float:
    var basis: float = level_basis(target)
    var actions: int = maxi(0, affected_actions)
    match _normalized_status(status_id):
        "burn":
            return basis * 0.75
        "poison":
            return basis * 0.60
        "bad_poison":
            return basis * 0.90
        "sleep", "freeze":
            return basis * 0.50 * float(actions)
        "paralysis":
            return basis * 0.75
        "confusion":
            return basis * 0.25 * float(actions)
    return 0.0


static func status_cleanse(
    target: Dictionary,
    status_id: String,
    remaining_actions: int = 1
) -> float:
    return status_application(target, status_id, remaining_actions) * CLEANSE_WEIGHT


static func direct_atb_removal(target: Dictionary, removed_percent_points: float) -> float:
    return level_basis(target) * clampf(removed_percent_points / 100.0, 0.0, 1.0)


static func partial_control(target: Dictionary, affected_actions: int) -> float:
    # Move-lock and heal-lock restrict options without guaranteeing a lost
    # action. They are deliberately worth half as much per action as confusion.
    return (
        level_basis(target)
        * PARTIAL_CONTROL_ACTION_WEIGHT
        * float(maxi(0, affected_actions))
    )


static func utility_effect(target: Dictionary) -> float:
    # Conservative fallback for a successful, real utility state change that
    # has no more specific rule. It prevents old flat awards from leaking back
    # into the runtime while keeping niche utility moves relevant.
    return level_basis(target) * UTILITY_EFFECT_WEIGHT


static func status_protection_transition(
    target: Dictionary,
    current_action: int,
    before_value: Variant,
    after_value: Variant
) -> float:
    var before_coverage: Dictionary = _immunity_coverage(before_value, current_action)
    var after_coverage: Dictionary = _immunity_coverage(after_value, current_action)
    var added_actions: int = 0
    for status_value: Variant in after_coverage.keys():
        var status_id: String = str(status_value)
        added_actions += maxi(
            0,
            int(after_coverage.get(status_id, 0)) - int(before_coverage.get(status_id, 0))
        )
    return level_basis(target) * STATUS_PROTECTION_ACTION_WEIGHT * float(added_actions)


static func modifier_transition(
    target: Dictionary,
    current_action: int,
    before_value: Variant,
    after_value: Variant,
    target_is_allied: bool = true
) -> float:
    var before: Array = before_value if before_value is Array else []
    var after: Array = after_value if after_value is Array else []
    var horizon: int = maxi(
        _modifier_horizon(before, current_action),
        _modifier_horizon(after, current_action)
    )
    if horizon <= 0:
        return 0.0

    var total_delta: float = 0.0
    for kind: String in MODIFIER_KINDS:
        for offset: int in range(horizon):
            var action_serial: int = current_action + offset
            var before_value_at_action: float = _modifier_performance(
                kind,
                _combined_modifier(before, kind, action_serial)
            )
            var after_value_at_action: float = _modifier_performance(
                kind,
                _combined_modifier(after, kind, action_serial)
            )
            var signed_delta: float = after_value_at_action - before_value_at_action
            var favorable_delta: float = 0.0
            if kind == "incoming_damage_mod":
                # The performance value here is damage taken: lower helps an
                # ally, higher hurts an opponent.
                favorable_delta = -signed_delta if target_is_allied else signed_delta
            else:
                favorable_delta = signed_delta if target_is_allied else -signed_delta
            total_delta += maxf(0.0, favorable_delta)

    return level_basis(target) * MODIFIER_ACTION_WEIGHT * total_delta


static func _modifier_performance(kind: String, multiplier: float) -> float:
    var safe_multiplier: float = maxf(0.0001, multiplier)
    match kind:
        "incoming_damage_mod":
            # Runtime divides incoming damage by this value.
            return 1.0 / safe_multiplier
        "atb_cycle_mod":
            # A shorter cycle means a proportionally higher action frequency.
            return 1.0 / safe_multiplier
        _:
            return safe_multiplier


static func _combined_modifier(modifiers: Array, kind: String, action_serial: int) -> float:
    var result: float = 1.0
    for modifier_value: Variant in modifiers:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if str(modifier.get("kind", "")) != kind:
            continue
        if action_serial >= int(modifier.get("expires_after_action", action_serial)):
            continue
        result *= float(modifier.get("multiplier", 1.0))

    match kind:
        "accuracy_mod":
            return clampf(result, 0.2, 2.5)
        "atb_cycle_mod":
            return clampf(result, 0.25, 4.0)
        _:
            return clampf(result, 0.25, 4.0)


static func _modifier_horizon(modifiers: Array, current_action: int) -> int:
    var result: int = 0
    for modifier_value: Variant in modifiers:
        if modifier_value is Dictionary:
            result = maxi(
                result,
                int((modifier_value as Dictionary).get("expires_after_action", current_action))
                - current_action
            )
    return maxi(0, result)


static func _immunity_coverage(value: Variant, current_action: int) -> Dictionary:
    var result: Dictionary = {}
    if not (value is Array):
        return result
    for immunity_value: Variant in value:
        if not (immunity_value is Dictionary):
            continue
        var immunity: Dictionary = immunity_value
        var status_id: String = str(immunity.get("status", "major_status"))
        var remaining: int = maxi(
            0,
            int(immunity.get("expires_after_action", current_action)) - current_action
        )
        result[status_id] = maxi(int(result.get(status_id, 0)), remaining)
    return result


static func _normalized_status(status_id: String) -> String:
    return "bad_poison" if status_id == "toxic" else status_id
