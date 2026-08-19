extends SceneTree

func _init() -> void:
	_test_aggro_target_and_tie_break()
	_test_wait()
	_test_opening_order()
	_test_speed_atb()
	print("All battle rule tests passed.")
	quit(0)

func _monster(name: String, speed: int, position: int, aggro: float) -> Combatant:
	var m := Combatant.new()
	m.display_name = name
	m.hp = 100
	m.max_hp = 100
	m.speed = speed
	m.level = 10
	m.base_power = 100
	m.team_position = position
	m.aggro = aggro
	return m

func _test_aggro_target_and_tie_break() -> void:
	var a := _monster("A", 30, 0, 50.0)
	var b := _monster("B", 30, 1, 80.0)
	assert(BattleRules.highest_aggro_target([a, b]) == b)
	a.aggro = 80.0
	assert(BattleRules.highest_aggro_target([a, b]) == a)

func _test_wait() -> void:
	var m := _monster("Waiter", 30, 0, 100.0)
	m.atb = 100.0
	BattleRules.apply_wait(m)
	assert(is_equal_approx(m.aggro, 55.0))
	assert(is_equal_approx(m.recovery_factor, BattleConfig.WAIT_RECOVERY_FACTOR))
	assert(is_zero_approx(m.atb))

func _test_opening_order() -> void:
	var slow := _monster("Slow", 20, 0, 20)
	var fast := _monster("Fast", 60, 1, 20)
	var ordered := BattleRules.opening_order([{"actor": slow}, {"actor": fast}])
	assert(ordered[0]["actor"] == fast)

func _test_speed_atb() -> void:
	var slow := _monster("Slow", 20, 0, 20)
	var fast := _monster("Fast", 60, 1, 20)
	slow.fill_atb(1.0)
	fast.fill_atb(1.0)
	assert(fast.atb > slow.atb)
