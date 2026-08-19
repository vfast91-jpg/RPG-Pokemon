extends Node2D

const TILE_PIXELS := 16
const RENDER_SCALE := 2
const STEP := TILE_PIXELS * RENDER_SCALE
const WORLD_SIZE := Vector2i(42, 30)
const SOURCE_ID := 0
const MOVE_TIME := 0.14
const PLAYER_BASE_Y := -15.0

const TILESET_TEXTURE := preload("res://assets/punyworld-overworld-tileset_0.png")
const PLAYER_DOWN := preload("res://assets/player_down.svg")
const PLAYER_UP := preload("res://assets/player_up.svg")
const PLAYER_SIDE := preload("res://assets/player_side.svg")

@onready var ground: TileMap = $Ground
@onready var decor: TileMap = $Decor
@onready var player: Node2D = $Player
@onready var player_sprite: Sprite2D = $Player/Sprite
@onready var camera: Camera2D = $Player/Camera2D
@onready var npc: Sprite2D = $NPC
@onready var dialog: Control = $UI/Dialog
@onready var dialog_text: RichTextLabel = $UI/Dialog/Margin/Text
@onready var interact_hint: Control = $UI/InteractHint
@onready var interact_label: Label = $UI/InteractHint/Label
@onready var grass_hint: Label = $UI/GrassHint
@onready var location_banner: Control = $UI/Location

var blocked := {}
var tall_grass := {}
var interactables := {}

var player_cell := Vector2i(20, 24)
var facing := Vector2i(0, -1)
var moving := false
var move_from := Vector2.ZERO
var move_to := Vector2.ZERO
var move_target_cell := Vector2i.ZERO
var move_elapsed := 0.0
var dialog_open := false
var location_timer := 3.8
var grass_flash := 0.0

func _ready() -> void:
    _setup_tileset()
    _build_world()

    player.position = _cell_to_world(player_cell)
    player_sprite.position.y = PLAYER_BASE_Y
    npc.position = _cell_to_world(Vector2i(23, 12)) + Vector2(0, -15)

    blocked[Vector2i(23, 12)] = true
    interactables[Vector2i(23, 12)] = {
        "title": "Wanderin Mira",
        "body": "Der Hainpfad ist heute ruhig. Im hohen Gras bewegt sich schon etwas – Kämpfe bleiben in dieser Version aber noch ausgeschaltet.",
        "hint": "E  Reden"
    }

    interactables[Vector2i(24, 8)] = {
        "title": "Wegweiser",
        "body": "HAINPFAD\n← Teichufer     Waldstation →",
        "hint": "E  Lesen"
    }

    interactables[Vector2i(29, 7)] = {
        "title": "Waldstation",
        "body": "Die Tür ist noch verschlossen. Später kann dieses Gebäude betreten werden.",
        "hint": "E  Tür ansehen"
    }

    dialog.visible = false
    interact_hint.visible = false
    grass_hint.modulate.a = 0.0

    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = WORLD_SIZE.x * STEP
    camera.limit_bottom = WORLD_SIZE.y * STEP
    camera.position_smoothing_enabled = false

func _process(delta: float) -> void:
    _update_banner(delta)
    _update_feedback(delta)

    if dialog_open:
        return

    if moving:
        _advance_step(delta)
    else:
        var direction := _read_direction()
        if direction != Vector2i.ZERO:
            _try_step(direction)

    _update_interaction_hint()

func _setup_tileset() -> void:
    var tile_set := TileSet.new()
    tile_set.tile_size = Vector2i(TILE_PIXELS, TILE_PIXELS)

    var atlas := TileSetAtlasSource.new()
    atlas.texture = TILESET_TEXTURE
    atlas.texture_region_size = Vector2i(TILE_PIXELS, TILE_PIXELS)

    for y in range(65):
        for x in range(27):
            atlas.create_tile(Vector2i(x, y))

    tile_set.add_source(atlas, SOURCE_ID)
    ground.tile_set = tile_set
    decor.tile_set = tile_set
    ground.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
    decor.scale = Vector2(RENDER_SCALE, RENDER_SCALE)

func _build_world() -> void:
    # Grundfläche: echtes 16x16-Tile-Raster, im Spiel 2x vergrößert.
    for y in range(WORLD_SIZE.y):
        for x in range(WORLD_SIZE.x):
            ground.set_cell(0, Vector2i(x, y), SOURCE_ID, Vector2i(0, 0), 0)

    # Hauptweg und kleiner Platz vor der Waldstation.
    _paint_rounded_path(Rect2i(18, 0, 4, 30))
    _paint_rounded_path(Rect2i(18, 9, 15, 5))

    # Hohes Gras / wilde Wiesenflächen.
    _paint_tall_grass(Rect2i(10, 12, 6, 6))
    _paint_tall_grass(Rect2i(25, 19, 5, 5))

    # Oberer Waldrand mit einer Lücke über dem Weg.
    _stamp_region(Vector2i(0, 0), Rect2i(0, 7, 9, 3))
    _stamp_region(Vector2i(9, 0), Rect2i(9, 7, 9, 3))
    _stamp_region(Vector2i(24, 0), Rect2i(0, 7, 9, 3))
    _stamp_region(Vector2i(33, 0), Rect2i(9, 7, 9, 3))

    # Unterer Waldrand, ebenfalls mit Wegöffnung.
    _stamp_region(Vector2i(0, 27), Rect2i(0, 7, 9, 3))
    _stamp_region(Vector2i(9, 27), Rect2i(9, 7, 9, 3))
    _stamp_region(Vector2i(24, 27), Rect2i(0, 7, 9, 3))
    _stamp_region(Vector2i(33, 27), Rect2i(9, 7, 9, 3))

    # Seitenbegrenzung aus Einzelbäumen.
    for y in range(3, 27, 3):
        _stamp_region(Vector2i(0, y), Rect2i(8, 7, 1, 3))
        _stamp_region(Vector2i(41, y), Rect2i(17, 7, 1, 3))

    # Zwei dichtere Waldstücke innerhalb der Route.
    _stamp_region(Vector2i(2, 5), Rect2i(0, 7, 9, 3))
    _stamp_region(Vector2i(31, 18), Rect2i(9, 7, 9, 3))

    # Kleiner Teich aus einem fertigen 3x3-Pond-Block des Tilesets.
    _stamp_region(Vector2i(5, 18), Rect2i(7, 10, 3, 3))

    # Waldstation: drei nebeneinanderliegende Gebäudeteile aus dem Set.
    _stamp_region(Vector2i(28, 5), Rect2i(7, 26, 3, 3))

    # Schild am Platz.
    _put_decor(Vector2i(24, 8), Vector2i(7, 30))

    # Kleine Vegetationsdetails.
    _put_decor(Vector2i(8, 15), Vector2i(0, 28))
    _put_decor(Vector2i(9, 16), Vector2i(1, 28))
    _put_decor(Vector2i(34, 14), Vector2i(2, 28))
    _put_decor(Vector2i(35, 15), Vector2i(3, 28))
    _put_decor(Vector2i(12, 22), Vector2i(0, 29))
    _put_decor(Vector2i(27, 25), Vector2i(1, 29))

    # Blockierte Rasterfelder.
    for x in range(WORLD_SIZE.x):
        if x < 18 or x > 21:
            for y in range(3):
                blocked[Vector2i(x, y)] = true
            for y in range(27, 30):
                blocked[Vector2i(x, y)] = true

    for y in range(3, 27):
        blocked[Vector2i(0, y)] = true
        blocked[Vector2i(41, y)] = true

    _mark_rect_blocked(Rect2i(2, 5, 9, 3))
    _mark_rect_blocked(Rect2i(31, 18, 9, 3))
    _mark_rect_blocked(Rect2i(5, 18, 3, 3))
    _mark_rect_blocked(Rect2i(28, 5, 3, 3))
    blocked[Vector2i(24, 8)] = true

func _paint_rounded_path(rect: Rect2i) -> void:
    for local_y in range(rect.size.y):
        for local_x in range(rect.size.x):
            var atlas := Vector2i(8, 1)
            var on_left := local_x == 0
            var on_right := local_x == rect.size.x - 1
            var on_top := local_y == 0
            var on_bottom := local_y == rect.size.y - 1

            if on_top:
                if on_left:
                    atlas = Vector2i(3, 0)
                elif on_right:
                    atlas = Vector2i(6, 0)
                else:
                    atlas = Vector2i(4, 0)
            elif on_bottom:
                if on_left:
                    atlas = Vector2i(3, 2)
                elif on_right:
                    atlas = Vector2i(6, 2)
                else:
                    atlas = Vector2i(4, 2)
            elif on_left:
                atlas = Vector2i(3, 1)
            elif on_right:
                atlas = Vector2i(6, 1)

            ground.set_cell(0, rect.position + Vector2i(local_x, local_y), SOURCE_ID, atlas, 0)

func _paint_tall_grass(rect: Rect2i) -> void:
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            var cell := Vector2i(x, y)
            var atlas := Vector2i(1 + ((x + y) % 2), 0)
            ground.set_cell(0, cell, SOURCE_ID, atlas, 0)
            tall_grass[cell] = true

func _stamp_region(destination: Vector2i, source_rect: Rect2i) -> void:
    for local_y in range(source_rect.size.y):
        for local_x in range(source_rect.size.x):
            var target := destination + Vector2i(local_x, local_y)
            if not _inside_world(target):
                continue
            var atlas := source_rect.position + Vector2i(local_x, local_y)
            decor.set_cell(0, target, SOURCE_ID, atlas, 0)

func _put_decor(cell: Vector2i, atlas: Vector2i) -> void:
    if _inside_world(cell):
        decor.set_cell(0, cell, SOURCE_ID, atlas, 0)

func _mark_rect_blocked(rect: Rect2i) -> void:
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            blocked[Vector2i(x, y)] = true

func _try_step(direction: Vector2i) -> void:
    facing = direction
    _set_facing_texture(direction)

    var target := player_cell + direction
    if not _inside_world(target) or blocked.has(target):
        return

    moving = true
    move_elapsed = 0.0
    move_from = player.position
    move_to = _cell_to_world(target)
    move_target_cell = target

func _advance_step(delta: float) -> void:
    move_elapsed += delta
    var t: float = minf(move_elapsed / MOVE_TIME, 1.0)
    var eased: float = t * t * (3.0 - 2.0 * t)
    player.position = move_from.lerp(move_to, eased)
    player_sprite.position.y = PLAYER_BASE_Y - sin(t * PI) * 2.0

    if t >= 1.0:
        moving = false
        player_cell = move_target_cell
        player.position = move_to
        player_sprite.position.y = PLAYER_BASE_Y
        if tall_grass.has(player_cell):
            grass_flash = 0.8

func _read_direction() -> Vector2i:
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        return Vector2i.LEFT
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        return Vector2i.RIGHT
    if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
        return Vector2i.UP
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
        return Vector2i.DOWN
    return Vector2i.ZERO

func _set_facing_texture(direction: Vector2i) -> void:
    if direction.x != 0:
        player_sprite.texture = PLAYER_SIDE
        player_sprite.flip_h = direction.x < 0
    elif direction.y < 0:
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
        elif not moving:
            _try_interact()
    elif dialog_open and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_ESCAPE):
        _close_dialog()

func _try_interact() -> void:
    var target := player_cell + facing
    if not interactables.has(target):
        return

    var data: Dictionary = interactables[target]
    _open_dialog(str(data["title"]), str(data["body"]))

func _open_dialog(title: String, body: String) -> void:
    dialog_open = true
    dialog_text.text = "[b]" + title + "[/b]\n" + body
    dialog.visible = true
    interact_hint.visible = false

func _close_dialog() -> void:
    dialog_open = false
    dialog.visible = false

func _update_interaction_hint() -> void:
    if dialog_open or moving:
        interact_hint.visible = false
        return

    var target := player_cell + facing
    if interactables.has(target):
        var data: Dictionary = interactables[target]
        interact_label.text = str(data["hint"])
        interact_hint.visible = true
    else:
        interact_hint.visible = false

func _update_banner(delta: float) -> void:
    if location_timer > 0.0:
        location_timer -= delta
        location_banner.modulate.a = clamp(location_timer, 0.0, 1.0)

func _update_feedback(delta: float) -> void:
    grass_flash = max(grass_flash - delta, 0.0)
    grass_hint.modulate.a = min(grass_flash * 2.0, 1.0)

func _cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(cell.x * STEP + STEP / 2.0, cell.y * STEP + STEP / 2.0)

func _inside_world(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < WORLD_SIZE.x and cell.y < WORLD_SIZE.y
