extends "res://scripts/battle_demo_ad_mechanics_v1.gd"

# Final integration guard for the Abra -> Dodri attack batch.
#
# This top layer intentionally stays small. It closes three cross-system edges
# without duplicating the established combat runtimes below it:
# - self-K.O./fixed self-cost only resolve after a move was really attempted;
# - Magnetflug reads the already central Erdanziehung state;
# - Bizarroraum mirrors the effective speed state (including paralysis and
#   temporary speed modifiers) while leaving the chosen move's AP cycle intact.

const AD_FINAL_SPEED_COEFFICIENT: float = 0.62
const AD_FINAL_SPEED_BASE: float = 12.0

var _ad_final_executing_move_id: String = ""


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var previous_move_id: String = _ad_final_executing_move_id
    _ad_final_executing_move_id = move_id
    super._execute_move(actor, move_id)
    _ad_final_executing_move_id = previous_move_id


func _ad_self_ko(actor: Dictionary) -> void:
    # Finale/Explosion must not knock the user out when the selected action was
    # prevented before the move itself could be attempted (sleep, full paralysis,
    # confusion self-hit, etc.). A miss/immune/protected hit still counts as an
    # attempted move and therefore keeps the original self-K.O. semantics.
    if (
        not _ad_final_executing_move_id.is_empty()
        and not _database_move_was_attempted(_ad_final_executing_move_id)
    ):
        return
    super._ad_self_ko(actor)


func _ad_apply_fixed_self_cost(
    actor: Dictionary,
    fraction: float,
    label: String = "⚙️ EIGENKOSTEN"
) -> void:
    # Same action gate for Stahlstrahl and Donnerstoß crash damage. Once the
    # attack was actually attempted, misses/protection/immunity still pay the
    # designed cost where appropriate.
    if (
        not _ad_final_executing_move_id.is_empty()
        and not _database_move_was_attempted(_ad_final_executing_move_id)
    ):
        return
    super._ad_apply_fixed_self_cost(actor, fraction, label)


func _ad_gravity_active() -> bool:
    # Erdanziehung already exists as one central battlefield state in the
    # Cleffa runtime. Magnetflug must consume that exact state instead of a
    # second local timer.
    return _cleffa_gravity_is_active()


func _ad_apply_trick_room_speed_mirror() -> Dictionary:
    var originals: Dictionary = {}
    var effective_speed_equivalents: Dictionary = {}
    var min_equivalent: float = INF
    var max_equivalent: float = -INF

    # Convert each Pokémon's current speed state into an AP-independent rate.
    # Temporary Timeflow speed buffs/debuffs are represented by atb_cycle_mod;
    # paralysis is applied before the mirror as well.
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue

        var candidate_id: String = str(candidate.get("id", ""))
        var original_speed: float = maxf(0.0, float(candidate.get("speed", 10.0)))
        originals[candidate_id] = original_speed

        var paralysis_factor: float = 0.5 if bool(candidate.get("paralyzed", false)) else 1.0
        var status_cycle: float = maxf(
            0.01,
            _combined_timed_modifier(candidate, "atb_cycle_mod")
        )
        var effective_speed: float = original_speed * paralysis_factor
        var rate_without_ap: float = (
            AD_FINAL_SPEED_BASE + effective_speed * AD_FINAL_SPEED_COEFFICIENT
        ) / status_cycle
        var equivalent_speed: float = maxf(
            0.0,
            (rate_without_ap - AD_FINAL_SPEED_BASE) / AD_FINAL_SPEED_COEFFICIENT
        )

        effective_speed_equivalents[candidate_id] = {
            "value": equivalent_speed,
            "paralysis_factor": paralysis_factor,
            "status_cycle": status_cycle
        }
        min_equivalent = minf(min_equivalent, equivalent_speed)
        max_equivalent = maxf(max_equivalent, equivalent_speed)

    if effective_speed_equivalents.is_empty():
        return originals

    # Mirror slow <-> fast. We solve a temporary raw speed that, after the
    # inherited paralysis/status-cycle calculation, yields the mirrored rate.
    # actor.cycle (the AP recovery selected by the move) is never touched.
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue

        var candidate_id: String = str(candidate.get("id", ""))
        var state_value: Variant = effective_speed_equivalents.get(candidate_id, {})
        if not (state_value is Dictionary):
            continue
        var state: Dictionary = state_value
        var equivalent_speed: float = float(state.get("value", 0.0))
        var mirrored_equivalent: float = min_equivalent + max_equivalent - equivalent_speed
        var desired_rate_without_ap: float = (
            AD_FINAL_SPEED_BASE + mirrored_equivalent * AD_FINAL_SPEED_COEFFICIENT
        )
        var status_cycle: float = maxf(0.01, float(state.get("status_cycle", 1.0)))
        var paralysis_factor: float = maxf(0.01, float(state.get("paralysis_factor", 1.0)))
        var required_effective_speed: float = maxf(
            0.0,
            (
                desired_rate_without_ap * status_cycle
                - AD_FINAL_SPEED_BASE
            ) / AD_FINAL_SPEED_COEFFICIENT
        )
        candidate["speed"] = required_effective_speed / paralysis_factor

    return originals
