extends Node2D

var player_pos := Vector2(180, 360)
var player_speed := 180.0
var in_battle := false
var encounter_cooldown := 0.0
var battle: BattleController

const GRASS_RECT := Rect2(520, 180, 330, 360)
const HEAL_RECT := Rect2(70, 90, 150, 110)
const TRAINER_RECT := Rect2(980, 290, 70, 100)

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if in_battle:
		return
	encounter_cooldown = max(0.0, encounter_cooldown - delta)
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player_pos += input * player_speed * delta
	player_pos.x = clamp(player_pos.x, 30.0, 1240.0)
	player_pos.y = clamp(player_pos.y, 70.0, 680.0)
	if HEAL_RECT.has_point(player_pos):
		# Persistent party HP follows in a later milestone; this station already acts as the world healing hook.
		pass
	if GRASS_RECT.has_point(player_pos) and input.length() > 0.1 and encounter_cooldown <= 0.0 and randf() < delta * 0.35:
		_start_battle()
	if Input.is_action_just_pressed("interact") and _distance_to_rect(TRAINER_RECT, player_pos) < 70.0:
		_start_battle()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("23342a"))
	draw_rect(Rect2(0, 300, 1280, 150), Color("b9a878"))
	draw_rect(GRASS_RECT, Color("356b38"))
	for x in range(int(GRASS_RECT.position.x) + 12, int(GRASS_RECT.end.x), 28):
		for y in range(int(GRASS_RECT.position.y) + 12, int(GRASS_RECT.end.y), 28):
			draw_line(Vector2(x, y + 8), Vector2(x + 6, y - 5), Color("6da34d"), 3)
	draw_rect(HEAL_RECT, Color("d7e5e5"))
	draw_rect(Rect2(105, 112, 80, 18), Color("d95f59"))
	draw_rect(TRAINER_RECT, Color("8055a6"))
	draw_circle(player_pos, 18, Color("f2c14e"))
	draw_string(ThemeDB.fallback_font, Vector2(28, 34), "RPG-Pokemon — technische Testkarte", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(28, 60), "Bewegen: Pfeiltasten/WASD  |  Trainer: E  |  Gras: Zufallskampf", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(78, 82), "HEILSTATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(965, 275), "TRAINER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(625, 165), "HOHES GRAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _start_battle() -> void:
	if in_battle: return
	in_battle = true
	battle = BattleController.new()
	add_child(battle)
	battle.start_battle(DataLoader.monsters())
	battle.battle_finished.connect(_on_battle_finished)

func _on_battle_finished(_won: bool) -> void:
	in_battle = false
	encounter_cooldown = 3.0

func _distance_to_rect(rect: Rect2, point: Vector2) -> float:
	var nearest := Vector2(clamp(point.x, rect.position.x, rect.end.x), clamp(point.y, rect.position.y, rect.end.y))
	return nearest.distance_to(point)
