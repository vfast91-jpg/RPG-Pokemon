extends SceneTree

const VisibleTextureLayout = preload("res://scripts/ui/visible_texture_layout.gd")
const AREA_SIZE := Vector2(632.0, 216.0)
const CARD_X: float = 8.0
const CARD_WIDTH: float = 176.0
const ADD_CARD_SIZE := Vector2(CARD_WIDTH, 52.0)
const BOSS_CARD_SIZE := Vector2(CARD_WIDTH, 60.0)
const ADD_SIZE := Vector2(72.0, 72.0)
const BOSS_SIZE := Vector2(108.0, 108.0)
const NORMAL_GAP: float = 14.0
const FORWARD_GAP: float = 34.0

var failures: int = 0


func _initialize() -> void:
    VisibleTextureLayout._used_rect_cache.clear()
    for species: String in ["Taubsi", "Paras"]:
        _check_species_formation(species)

    _check(
        VisibleTextureLayout._used_rect_cache.size() == 2,
        "Sichtbare Bildgrenzen muessen pro Pokemon-Textur nur einmal gelesen werden."
    )

    if failures == 0:
        print("Boss reinforcement visual layout test: PASS")
        quit(0)
    else:
        push_error("Boss reinforcement visual layout test: %d Fehler" % failures)
        quit(1)


func _check_species_formation(species: String) -> void:
    var card_rects: Array[Rect2] = [
        Rect2(Vector2(CARD_X, 17.0), ADD_CARD_SIZE),
        Rect2(Vector2(CARD_X, 78.0), BOSS_CARD_SIZE),
        Rect2(Vector2(CARD_X, 147.0), ADD_CARD_SIZE)
    ]
    var sprite_sizes: Array[Vector2] = [ADD_SIZE, BOSS_SIZE, ADD_SIZE]
    var gaps: Array[float] = [FORWARD_GAP, NORMAL_GAP, FORWARD_GAP]
    var visible_globals: Array[Rect2] = []

    for index: int in range(3):
        var sprite := TextureRect.new()
        sprite.texture = load("res://assets/monsters/%s.png" % species) as Texture2D
        sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        sprite.flip_h = true
        sprite.size = sprite_sizes[index]

        var visible_rect: Rect2 = VisibleTextureLayout.visible_rect(sprite)
        var sprite_position: Vector2 = VisibleTextureLayout.position_visible_right_of_card(
            AREA_SIZE,
            card_rects[index],
            visible_rect,
            gaps[index]
        )
        var visible_global := Rect2(sprite_position + visible_rect.position, visible_rect.size)
        visible_globals.append(visible_global)

        _check(
            absf(visible_global.get_center().y - card_rects[index].get_center().y) < 0.01,
            "%s Slot %d: Sichtbare Pixel muessen mittig zur Statuskarte stehen." % [species, index]
        )
        _check(
            visible_global.position.y >= -0.01 and visible_global.end.y <= AREA_SIZE.y + 0.01,
            "%s Slot %d: Sichtbare Pixel duerfen nicht aus der Kampfflaeche ragen." % [species, index]
        )
        _check(
            absf(visible_global.position.x - (card_rects[index].end.x + gaps[index])) < 0.01,
            "%s Slot %d: Transparente PNG-Raender duerfen den Kartenabstand nicht verfalschen." % [species, index]
        )
        var connector: PackedVector2Array = VisibleTextureLayout.enemy_connector_points(
            card_rects[index],
            sprite_position,
            visible_rect
        )
        _check(
            connector.size() == 2 and absf(connector[1].x - connector[0].x - gaps[index]) < 0.01,
            "%s Slot %d: Verbindungslinie muss exakt dem kompakten sichtbaren Abstand entsprechen." % [species, index]
        )

        var forehead: Vector2 = VisibleTextureLayout.enemy_forehead_anchor(
            sprite_position,
            visible_rect
        )
        _check(
            forehead.x > visible_global.get_center().x,
            "%s Slot %d: Wutzeichen muss vor der Kopfmitte in Blickrichtung sitzen." % [species, index]
        )
        _check(
            forehead.y >= visible_global.position.y
                and forehead.y <= visible_global.position.y + visible_global.size.y * 0.35,
            "%s Slot %d: Wutzeichen muss im oberen Stirnbereich sitzen." % [species, index]
        )
        sprite.free()

    _check(not visible_globals[0].intersects(visible_globals[1]), "%s: Obere Verstaerkung darf den Boss nicht ueberdecken." % species)
    _check(not visible_globals[1].intersects(visible_globals[2]), "%s: Untere Verstaerkung darf den Boss nicht ueberdecken." % species)
    _check(visible_globals[0].position.x > visible_globals[1].position.x, "%s: Obere Verstaerkung muss vor dem Boss stehen." % species)
    _check(visible_globals[2].position.x > visible_globals[1].position.x, "%s: Untere Verstaerkung muss vor dem Boss stehen." % species)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
