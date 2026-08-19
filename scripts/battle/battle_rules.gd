class_name BattleRules
extends RefCounted

static func starting_aggro(monster: Combatant) -> float:
	return 20.0 + monster.level * BattleConfig.START_AGGRO_LEVEL_WEIGHT + monster.base_power * BattleConfig.START_AGGRO_POWER_WEIGHT

static func highest_aggro_target(candidates: Array) -> Combatant:
	var alive: Array = candidates.filter(func(c): return c != null and c.is_alive())
	if alive.is_empty():
		return null
	alive.sort_custom(func(a, b):
		if is_equal_approx(a.aggro, b.aggro):
			return a.team_position < b.team_position
		return a.aggro > b.aggro
	)
	return alive[0]

static func calculate_damage(attacker: Combatant, defender: Combatant, power: float) -> int:
	var raw := power * (0.75 + float(attacker.attack) / 50.0)
	var mitigation := 100.0 / (100.0 + float(defender.defense))
	return max(1, int(round(raw * mitigation)))

static func apply_damage(attacker: Combatant, defender: Combatant, power: float, base_aggro: float, aggro_scale: float) -> int:
	var amount := min(defender.hp, calculate_damage(attacker, defender, power))
	defender.hp -= amount
	attacker.aggro += base_aggro + amount * aggro_scale
	defender.aggro *= BattleConfig.AGGRO_AFTER_HIT_FACTOR
	return amount

static func apply_wait(monster: Combatant) -> void:
	monster.aggro *= BattleConfig.WAIT_AGGRO_FACTOR
	monster.consume_turn(BattleConfig.WAIT_RECOVERY_FACTOR)

static func apply_miss(monster: Combatant, recovery: float) -> void:
	monster.consume_turn(recovery * BattleConfig.MISS_RECOVERY_FACTOR)

static func status_strength(user: Combatant, base_value: float) -> float:
	return base_value * (0.75 + float(user.special) / 60.0)

static func opening_order(actions: Array) -> Array:
	var ordered := actions.duplicate()
	ordered.sort_custom(func(a, b):
		var a_speed: int = a["actor"].speed
		var b_speed: int = b["actor"].speed
		if a_speed == b_speed:
			return a["actor"].team_position < b["actor"].team_position
		return a_speed > b_speed
	)
	return ordered
