class_name Combatant
extends RefCounted

var id := ""
var display_name := ""
var level := 1
var max_hp := 100
var hp := 100
var attack := 10
var defense := 10
var special := 10
var speed := 10
var base_power := 100
var team_position := 0
var atb := 0.0
var recovery_factor := 1.0
var aggro := 0.0
var statuses: Dictionary = {}
var moves: Array[String] = []

func setup(data: Dictionary, position: int) -> Combatant:
	id = str(data.get("id", "monster"))
	display_name = str(data.get("name", id))
	level = int(data.get("level", 1))
	max_hp = int(data.get("hp", 100))
	hp = max_hp
	attack = int(data.get("attack", 10))
	defense = int(data.get("defense", 10))
	special = int(data.get("special", 10))
	speed = int(data.get("speed", 10))
	base_power = int(data.get("base_power", 100))
	team_position = position
	for move_id in data.get("moves", []):
		moves.append(str(move_id))
	aggro = BattleRules.starting_aggro(self)
	return self

func is_alive() -> bool:
	return hp > 0

func fill_atb(delta: float) -> void:
	if not is_alive() or atb >= BattleConfig.ATB_MAX:
		return
	var speed_factor := 0.65 + float(speed) / 100.0
	atb = min(BattleConfig.ATB_MAX, atb + delta * BattleConfig.BASE_ATB_RATE * speed_factor / max(recovery_factor, 0.1))

func ready() -> bool:
	return is_alive() and atb >= BattleConfig.ATB_MAX

func consume_turn(next_recovery: float = 1.0) -> void:
	atb = 0.0
	recovery_factor = max(next_recovery, 0.1)
