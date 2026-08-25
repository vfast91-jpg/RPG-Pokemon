extends "res://scripts/battle_demo_boss_reinforcement_v1.gd"

# Final route-boss Aggro invariant.
#
# Every combatant carrying the existing `boss` marker stays at exactly Aggro 1.
# This is deliberately enforced around the battle tick as well as card refreshes:
# inherited mechanics may add/reduce Aggro during an action, but no later target
# selection is allowed to observe a route boss at any other value.

const ROUTE_BOSS_LOCKED_AGGRO: float = 1.0
const REINFORCEMENT_MIN_START_AGGRO: float = 2.0


func _route_begin_wave() -> void:
    super._route_begin_wave()
    _enforce_route_boss_aggro()


func _process(delta: float) -> void:
    _enforce_route_boss_aggro()
    super._process(delta)
    _enforce_route_boss_aggro()


func _refresh_cards() -> void:
    _enforce_route_boss_aggro()
    super._refresh_cards()
    _enforce_route_boss_aggro()


func _spawn_boss_reinforcements(boss: Dictionary) -> Array[Dictionary]:
    var created: Array[Dictionary] = super._spawn_boss_reinforcements(boss)
    for reinforcement: Dictionary in created:
        # The companions enter with normal calculated Aggro, but their initial
        # value must always outrank the boss's fixed 1. Afterwards they use the
        # ordinary dynamic Aggro rules like every other non-boss combatant.
        reinforcement["aggro"] = maxf(
            REINFORCEMENT_MIN_START_AGGRO,
            float(reinforcement.get("aggro", 0.0))
        )
    _enforce_route_boss_aggro()
    return created


func _enforce_route_boss_aggro() -> void:
    for combatant_value: Variant in enemy_team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value as Dictionary
        if bool(combatant.get("boss", false)):
            combatant["aggro"] = ROUTE_BOSS_LOCKED_AGGRO
