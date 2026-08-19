class_name TeamRoster
extends RefCounted

var members: Array[Combatant] = []
var active_indices: Array[int] = []

func add_member(member: Combatant) -> bool:
	if members.size() >= BattleConfig.MAX_TEAM_SIZE:
		return false
	members.append(member)
	if active_indices.size() < BattleConfig.MAX_ACTIVE:
		active_indices.append(members.size() - 1)
	return true

func active_members() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for index in active_indices:
		if index >= 0 and index < members.size():
			result.append(members[index])
	return result

func reserve_members() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for i in range(members.size()):
		if not active_indices.has(i):
			result.append(members[i])
	return result

func switch_active(active_slot: int, reserve_member_index: int) -> bool:
	if active_slot < 0 or active_slot >= active_indices.size():
		return false
	if reserve_member_index < 0 or reserve_member_index >= members.size():
		return false
	if active_indices.has(reserve_member_index):
		return false
	var outgoing := members[active_indices[active_slot]]
	var incoming := members[reserve_member_index]
	incoming.atb = BattleConfig.ATB_MAX * BattleConfig.SWITCH_ATB_RATIO
	incoming.aggro = max(incoming.aggro, outgoing.aggro * BattleConfig.SWITCH_AGGRO_RETAIN_FACTOR)
	active_indices[active_slot] = reserve_member_index
	return true
