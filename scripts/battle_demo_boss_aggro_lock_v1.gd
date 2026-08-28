extends "res://scripts/battle_demo_gen3_species_v1.gd"

# Route-boss Aggro lock with a deliberately narrow scope.
#
# The generic `boss` marker never freezes Aggro. Ordinary route bosses and the
# milestone double bosses on stages 20/40/60/80 use the normal dynamic Aggro
# system. The one gameplay exception is the ordinary single boss from
# "Besondere Begegnung": its boss is locked to Aggro 1 from the beginning. When
# reinforcements arrive, their normal higher Aggro makes them the mandatory
# protectors. An explicit `boss_aggro_lock` marker remains supported as an opt-in
# for any future encounter that intentionally wants the same rule.

const ROUTE_BOSS_LOCKED_AGGRO: float = 1.0
const REINFORCEMENT_MIN_START_AGGRO: float = 2.0
const ROUTE_BOSS_AGGRO_LOCK_KEY: String = "boss_aggro_lock"


func _route_begin_wave() -> void:
    super._route_begin_wave()
    _bind_explicit_route_boss_aggro_lock()
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

    # Keep the explicit marker for saves and downstream systems. The standard
    # reinforcement contract already locks Aggro from the start of the fight.
    if not created.is_empty() and _is_standard_reinforcement_boss(boss):
        boss[ROUTE_BOSS_AGGRO_LOCK_KEY] = true

    if _uses_route_boss_aggro_lock(boss):
        for reinforcement: Dictionary in created:
            # Helpers keep ordinary dynamic Aggro, but enter above the boss's
            # fixed value so target selection can immediately prefer them.
            reinforcement["aggro"] = maxf(
                REINFORCEMENT_MIN_START_AGGRO,
                float(reinforcement.get("aggro", 0.0))
            )

    _enforce_route_boss_aggro()
    return created


func _bind_explicit_route_boss_aggro_lock() -> void:
    if not route_mode:
        return

    var count: int = mini(enemy_team.size(), _route_enemy_party.size())
    for index: int in range(count):
        var source_value: Variant = _route_enemy_party[index]
        var combatant_value: Variant = enemy_team[index]
        if not (source_value is Dictionary) or not (combatant_value is Dictionary):
            continue

        var source: Dictionary = source_value as Dictionary
        var combatant: Dictionary = combatant_value as Dictionary
        if not bool(source.get("boss", false)) or not bool(combatant.get("boss", false)):
            continue

        if bool(source.get(ROUTE_BOSS_AGGRO_LOCK_KEY, false)):
            combatant[ROUTE_BOSS_AGGRO_LOCK_KEY] = true


func _is_standard_reinforcement_boss(combatant: Dictionary) -> bool:
    return bool(combatant.get("boss", false)) and bool(
        combatant.get("boss_reinforcement_enabled", false)
    )


func _enforce_route_boss_aggro() -> void:
    for combatant_value: Variant in enemy_team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value as Dictionary
        if _uses_route_boss_aggro_lock(combatant):
            combatant["aggro"] = ROUTE_BOSS_LOCKED_AGGRO


func _uses_route_boss_aggro_lock(combatant: Dictionary) -> bool:
    return bool(combatant.get("boss", false)) and bool(
        combatant.get(ROUTE_BOSS_AGGRO_LOCK_KEY, false)
            or combatant.get("boss_reinforcement_enabled", false)
    )
