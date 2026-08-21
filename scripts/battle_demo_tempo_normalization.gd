extends "res://scripts/battle_demo_three_action_effects.gd"

# Keeps the visible battle tempo stable across levels without changing the
# established relative Speed balance between combatants.
#
# At battle start, the fastest active Pokemon becomes a fixed tempo anchor.
# Its normal ATB cycle takes FASTEST_NORMAL_CYCLE_SECONDS. Every other Pokemon
# keeps the same charge-rate ratio it had under the previous Speed formula.
# The anchor is intentionally not recalculated after paralysis, buffs, debuffs,
# knockouts or other mid-battle changes, so those mechanics retain real impact.

const FASTEST_NORMAL_CYCLE_SECONDS: float = 4.0
const SPEED_RATE_BASE: float = 12.0
const SPEED_RATE_SCALE: float = 0.62

var _battle_speed_anchor_rate: float = 1.0


func _start_battle() -> void:
    super._start_battle()
    if battle_active:
        _lock_battle_speed_anchor()


func _lock_battle_speed_anchor() -> void:
    var fastest_start_rate: float = 0.0
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)):
            continue
        fastest_start_rate = maxf(
            fastest_start_rate,
            _raw_speed_charge_rate(float(combatant.get("speed", 10)))
        )

    _battle_speed_anchor_rate = maxf(0.01, fastest_start_rate)


func _raw_speed_charge_rate(effective_speed: float) -> float:
    return maxf(0.01, SPEED_RATE_BASE + maxf(0.0, effective_speed) * SPEED_RATE_SCALE)


func _normalized_speed_charge_rate(effective_speed: float) -> float:
    var fastest_fill_rate: float = 100.0 / FASTEST_NORMAL_CYCLE_SECONDS
    return (
        fastest_fill_rate
        * _raw_speed_charge_rate(effective_speed)
        / maxf(0.01, _battle_speed_anchor_rate)
    )


func _process(delta: float) -> void:
    if not battle_active or paused:
        return

    var ready_actor: Dictionary = {}
    var best_speed: float = -1.0

    for combatant_value: Variant in combatants:
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)):
            continue

        var effective_speed: float = float(combatant.get("speed", 10))
        if bool(combatant.get("paralyzed", false)):
            effective_speed *= 0.5

        var ap_cycle: float = maxf(0.01, float(combatant.get("cycle", 1.0)))
        var status_cycle: float = _combined_timed_modifier(combatant, "atb_cycle_mod")
        var effective_cycle: float = maxf(0.01, ap_cycle * status_cycle)
        var gain: float = delta * _normalized_speed_charge_rate(effective_speed) / effective_cycle
        combatant["atb"] = minf(100.0, float(combatant.get("atb", 0.0)) + gain)

        if float(combatant.get("atb", 0.0)) >= 100.0 and effective_speed > best_speed:
            ready_actor = combatant
            best_speed = effective_speed

    _refresh_cards()
    if ready_actor.is_empty():
        return

    if str(ready_actor.get("side", "")) == "player":
        _prompt_player(ready_actor)
    else:
        _enemy_act(ready_actor)
