class_name BattleController
extends CanvasLayer

signal battle_finished(player_won: bool)

var moves: Dictionary
var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
var trainer_atb := 0.0
var paused_for_choice := false
var acting_monster: Combatant
var root_panel: Panel
var status_label: Label
var action_box: VBoxContainer

func start_battle(monster_data: Array) -> void:
	moves = DataLoader.move_map()
	for i in range(min(4, monster_data.size())):
		allies.append(Combatant.new().setup(monster_data[i], i))
	for i in range(4):
		var source: Dictionary = monster_data[(i + 2) % monster_data.size()].duplicate(true)
		source["name"] = "Wild %s" % source["name"]
		source["level"] = max(1, int(source["level"]) - 1)
		enemies.append(Combatant.new().setup(source, i))
	_build_ui()

func _build_ui() -> void:
	root_panel = Panel.new()
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_panel.modulate = Color(0.12, 0.14, 0.18, 0.97)
	add_child(root_panel)
	var title := Label.new()
	title.text = "BATTLE SANDBOX — Wait-ATB / Aggro"
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 24)
	root_panel.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(28, 70)
	status_label.size = Vector2(1180, 420)
	status_label.add_theme_font_size_override("font_size", 18)
	root_panel.add_child(status_label)
	action_box = VBoxContainer.new()
	action_box.position = Vector2(28, 500)
	action_box.size = Vector2(520, 190)
	root_panel.add_child(action_box)
	_refresh_ui("Kampf beginnt. ATB läuft.")

func _process(delta: float) -> void:
	if paused_for_choice:
		return
	for monster in allies + enemies:
		monster.fill_atb(delta)
	trainer_atb = min(BattleConfig.ATB_MAX, trainer_atb + delta * BattleConfig.TRAINER_ATB_RATE)
	for enemy in enemies:
		if enemy.ready():
			_enemy_turn(enemy)
			if _check_end(): return
	for ally in allies:
		if ally.ready():
			_prompt_monster(ally)
			return
	if trainer_atb >= BattleConfig.ATB_MAX:
		_prompt_trainer()
		return
	_refresh_ui("ATB läuft …")

func _prompt_monster(monster: Combatant) -> void:
	paused_for_choice = true
	acting_monster = monster
	_clear_actions()
	for move_id in monster.moves:
		var move: Dictionary = moves[move_id]
		var button := Button.new()
		button.text = "%s  [%s]" % [move["name"], move["time_cost"]]
		button.pressed.connect(func(): _player_move(monster, move))
		action_box.add_child(button)
	var wait_button := Button.new()
	wait_button.text = "Warten — Aggro senken / schneller wieder bereit"
	wait_button.pressed.connect(func():
		BattleRules.apply_wait(monster)
		paused_for_choice = false
		_refresh_ui("%s wartet." % monster.display_name)
	)
	action_box.add_child(wait_button)
	_refresh_ui("%s ist bereit. Kampfzeit pausiert." % monster.display_name)

func _prompt_trainer() -> void:
	paused_for_choice = true
	acting_monster = null
	_clear_actions()
	var heal := Button.new()
	heal.text = "Trainer: Heilitem auf schwächstes aktives Monster"
	heal.pressed.connect(_trainer_heal)
	action_box.add_child(heal)
	var hold := Button.new()
	hold.text = "Trainer: Aktion zurückhalten"
	hold.pressed.connect(func(): trainer_atb = 0.0; paused_for_choice = false)
	action_box.add_child(hold)
	_refresh_ui("Trainer ist bereit. Kampfzeit pausiert.")

func _player_move(actor: Combatant, move: Dictionary) -> void:
	_clear_actions()
	if randf() > float(move["accuracy"]):
		BattleRules.apply_miss(actor, float(move["recovery"]))
		paused_for_choice = false
		_refresh_ui("%s verfehlt! Kürzere Erholung." % actor.display_name)
		return
	if bool(move["aoe"]):
		var total := 0
		for target in enemies:
			if target.is_alive():
				total += BattleRules.apply_damage(actor, target, float(move["power"]), 0.0, float(move["aggro_scale"]))
		actor.aggro += float(move["base_aggro"])
		actor.consume_turn(float(move["recovery"]))
		paused_for_choice = false
		_refresh_ui("%s trifft alle Gegner für insgesamt %d." % [actor.display_name, total])
	else:
		var target := BattleRules.highest_aggro_target(enemies)
		if target != null and bool(move["damage"]):
			var amount := BattleRules.apply_damage(actor, target, float(move["power"]), float(move["base_aggro"]), float(move["aggro_scale"]))
			_refresh_ui("%s trifft verpflichtend %s (höchste Aggro) für %d." % [actor.display_name, target.display_name, amount])
		actor.consume_turn(float(move["recovery"]))
		paused_for_choice = false
	_check_end()

func _enemy_turn(actor: Combatant) -> void:
	var target := BattleRules.highest_aggro_target(allies)
	if target == null: return
	var move: Dictionary = moves.get(actor.moves[0], moves["standard_strike"])
	if randf() <= float(move["accuracy"]):
		BattleRules.apply_damage(actor, target, float(move["power"]), float(move["base_aggro"]), float(move["aggro_scale"]))
		actor.consume_turn(float(move["recovery"]))
	else:
		BattleRules.apply_miss(actor, float(move["recovery"]))

func _trainer_heal() -> void:
	var living: Array = allies.filter(func(m): return m.is_alive())
	living.sort_custom(func(a,b): return float(a.hp)/a.max_hp < float(b.hp)/b.max_hp)
	if not living.is_empty():
		var target: Combatant = living[0]
		var restored: int = mini(45, target.max_hp - target.hp)
		target.hp += restored
		# Trainer healing does not create monster aggro; trainer threat can be added later as its own system.
	trainer_atb = 0.0
	paused_for_choice = false
	_refresh_ui("Trainer benutzt ein Heilitem.")

func _check_end() -> bool:
	var allies_alive := allies.any(func(m): return m.is_alive())
	var enemies_alive := enemies.any(func(m): return m.is_alive())
	if allies_alive and enemies_alive: return false
	paused_for_choice = true
	_clear_actions()
	_refresh_ui("Sieg!" if allies_alive else "Niederlage.")
	var back := Button.new()
	back.text = "Zurück zur Testkarte"
	back.pressed.connect(func(): battle_finished.emit(allies_alive); queue_free())
	action_box.add_child(back)
	return true

func _clear_actions() -> void:
	for child in action_box.get_children(): child.queue_free()

func _refresh_ui(message: String) -> void:
	if status_label == null: return
	var text := message + "\n\nDEIN TEAM\n"
	for m in allies:
		text += "%d. %-12s KP %3d/%3d | ATB %3d%% | Aggro %5.1f%s\n" % [m.team_position+1, m.display_name, m.hp, m.max_hp, int(m.atb), m.aggro, "  ← Ziel" if BattleRules.highest_aggro_target(allies) == m else ""]
	text += "\nGEGNER\n"
	for m in enemies:
		text += "%d. %-12s KP %3d/%3d | ATB %3d%% | Aggro %5.1f%s\n" % [m.team_position+1, m.display_name, m.hp, m.max_hp, int(m.atb), m.aggro, "  ← Pflichtziel" if BattleRules.highest_aggro_target(enemies) == m else ""]
	text += "\nTrainer-ATB: %d%%" % int(trainer_atb)
	status_label.text = text
