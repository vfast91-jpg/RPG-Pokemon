extends Node2D

const SPEED := 190.0
const PLAYER_START := Vector2(760, 760)
const NPC_HOME := Vector2(872, 392)
const SIGN_POS := Vector2(718, 476)

const PLAYER_DOWN := preload("res://assets/player_down.svg")
const PLAYER_UP := preload("res://assets/player_up.svg")
const PLAYER_SIDE := preload("res://assets/player_side.svg")

@onready var player: CharacterBody2D = $Player
@onready var player_sprite: Sprite2D = $Player/Sprite
@onready var npc: Sprite2D = $NPC
@onready var dialog: Control = $UI/Dialog
@onready var dialog_text: RichTextLabel = $UI/Dialog/Margin/Text
@onready var interact_hint: Control = $UI/InteractHint
@onready var interact_label: Label = $UI/InteractHint/Label
@onready var grass_hint: Label = $UI/GrassHint

var dialog_open := false
var facing := Vector2.DOWN
var walk_clock := 0.0
var npc_clock := 0.0

func _ready() -> void:
    player.position = PLAYER_START
    dialog.visible = false
    interact_hint.visible = false
    grass_hint.modulate.a = 0.0

    # World collision: map bounds, forest masses, pond, house and fence.
    _add_block(Rect2(-20, -20, 1640, 44))
    _add_block(Rect2(-20, 876, 1640, 44))
    _add_block(Rect2(-20, 0, 44, 900))
    _add_block(Rect2(1576, 0, 44, 900))

    _add_block(Rect2(18, 35, 185, 760))
    _add_block(Rect2(190, 24, 720, 112))
    _add_block(Rect2(1420, 34, 166, 520))
    _add_block(Rect2(120, 785, 480, 92))
    _add_block(Rect2(900, 824, 180, 55))
    _add_block(Rect2(1470, 770, 116, 110))

    _add_block(Rect2(1118, 116, 296, 222))
    _add_block(Rect2(1040, 350, 245, 86))
    _add_block(Rect2(1045, 560, 440, 292))

    _add_block(Rect2(NPC_HOME - Vector2(18, 14), Vector2(36, 28)))

func _physics_process(delta: float) -> void:
    npc_clock += delta
    npc.position = NPC_HOME + Vector2(0, sin(npc_clock * 2.1) * 1.4)

    var input_vector := Vector2.ZERO
    if not dialog_open:
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
            input_vector.x += 1.0
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
            input_vector.x -= 1.0
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
            input_vector.y += 1.0
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
            input_vector.y -= 1.0

    if input_vector.length_squared() > 0.0:
        input_vector = input_vector.normalized()
        facing = input_vector
        player.velocity = input_vector * SPEED
        player.move_and_slide()
        walk_clock += delta * 11.0
        player_sprite.position.y = -4.0 - abs(sin(walk_clock)) * 2.0
        _set_facing_texture(input_vector)
    else:
        player.velocity = Vector2.ZERO
        player_sprite.position.y = -4.0
        player_sprite.rotation = lerp(player_sprite.rotation, 0.0, min(delta * 12.0, 1.0))

    _update_interaction_hint()
    _update_grass_feedback(delta, input_vector)

func _set_facing_texture(dir: Vector2) -> void:
    if abs(dir.x) > abs(dir.y):
        player_sprite.texture = PLAYER_SIDE
        player_sprite.flip_h = dir.x < 0.0
    elif dir.y < 0.0:
        player_sprite.texture = PLAYER_UP
        player_sprite.flip_h = false
    else:
        player_sprite.texture = PLAYER_DOWN
        player_sprite.flip_h = false

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return

    if key_event.keycode == KEY_E or key_event.keycode == KEY_SPACE:
        if dialog_open:
            _close_dialog()
        else:
            _try_interact()
    elif (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_ESCAPE) and dialog_open:
        _close_dialog()

func _try_interact() -> void:
    if player.position.distance_to(NPC_HOME) < 92.0:
        _open_dialog("Wanderin Mira", "Der Hainpfad ist ruhig heute. Im hohen Gras raschelt es zwar – aber Kämpfe sind für diese Demo bewusst ausgeschaltet.")
        return

    if player.position.distance_to(SIGN_POS) < 86.0:
        _open_dialog("Wegweiser", "HAINPFAD\n← Blumenwiese    Waldstation →")
        return

func _open_dialog(title: String, body: String) -> void:
    dialog_open = true
    player.velocity = Vector2.ZERO
    dialog_text.text = "[b]" + title + "[/b]\n" + body
    dialog.visible = true
    interact_hint.visible = false

func _close_dialog() -> void:
    dialog_open = false
    dialog.visible = false

func _update_interaction_hint() -> void:
    if dialog_open:
        interact_hint.visible = false
        return

    var near_npc := player.position.distance_to(NPC_HOME) < 92.0
    var near_sign := player.position.distance_to(SIGN_POS) < 86.0
    interact_hint.visible = near_npc or near_sign
    if near_npc:
        interact_label.text = "E  Reden"
    elif near_sign:
        interact_label.text = "E  Lesen"

func _update_grass_feedback(delta: float, movement: Vector2) -> void:
    var grass_rect := Rect2(268, 314, 430, 255)
    var in_grass := grass_rect.has_point(player.position)
    var target_alpha := 0.0
    if in_grass and movement.length_squared() > 0.0:
        target_alpha = 0.9
    var hint_color := grass_hint.modulate
    hint_color.a = move_toward(hint_color.a, target_alpha, delta * 2.8)
    grass_hint.modulate = hint_color

func _add_block(rect: Rect2) -> void:
    var body := StaticBody2D.new()
    var shape_node := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    shape_node.shape = shape
    shape_node.position = rect.position + rect.size * 0.5
    body.add_child(shape_node)
    add_child(body)
