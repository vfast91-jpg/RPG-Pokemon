extends SceneTree

const VisibleTextureLayout = preload("res://scripts/ui/visible_texture_layout.gd")
const AREA_SIZE := Vector2(632.0, 216.0)
const CARD_SIZE := Vector2(176.0, 60.0)
const BOSS_SIZE := Vector2(95.04, 95.04)
const GAP: float = 6.0

var failures: int = 0


func _initialize() -> void:
    var species: Array[String] = ["Digda", "Mauzi"]
    var slot_ratios: Array[float] = [0.24, 0.76]
    var previous_visible_bottom: float = -INF

    for index: int in range(2):
        var center_y: float = AREA_SIZE.y * slot_ratios[index]
        var card_rect := Rect2(
            Vector2(8.0, center_y - CARD_SIZE.y * 0.5),
            CARD_SIZE
        )
        var sprite := TextureRect.new()
        sprite.texture = load("res://assets/monsters/%s.png" % species[index]) as Texture2D
        sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        sprite.flip_h = true
        sprite.size = BOSS_SIZE

        var visible_rect: Rect2 = VisibleTextureLayout.visible_rect(sprite)
        var sprite_position: Vector2 = VisibleTextureLayout.position_visible_right_of_card(
            AREA_SIZE,
            card_rect,
            visible_rect,
            GAP
        )
        var visible_global := Rect2(sprite_position + visible_rect.position, visible_rect.size)

        _check(
            absf(visible_global.get_center().y - card_rect.get_center().y) < 0.01,
            "Boss %d: Sichtbares Pokemon und Karte muessen dieselbe vertikale Mitte besitzen." % (index + 1)
        )
        _check(
            absf(visible_global.position.x - (card_rect.end.x + GAP)) < 0.01,
            "Boss %d: Transparenter Bildrand darf den Abstand zur Karte nicht vergroessern." % (index + 1)
        )
        _check(
            visible_global.position.y >= -0.01 and visible_global.end.y <= AREA_SIZE.y + 0.01,
            "Boss %d: Sichtbare Bildpixel muessen vollstaendig in der Kampfflaeche liegen." % (index + 1)
        )
        _check(
            visible_global.position.y >= previous_visible_bottom - 0.01,
            "Die beiden sichtbaren Boss-Pokemon duerfen sich nicht ueberlappen."
        )
        previous_visible_bottom = visible_global.end.y

        var connector: PackedVector2Array = VisibleTextureLayout.enemy_connector_points(
            card_rect,
            sprite_position,
            visible_rect
        )
        _check(
            connector.size() == 2
                and connector[1].distance_to(Vector2(visible_global.position.x, visible_global.get_center().y)) < 0.01,
            "Boss %d: Verbindungslinie muss am sichtbaren Pokemon enden." % (index + 1)
        )
        _check(
            VisibleTextureLayout.visible_foot(sprite_position, visible_rect).distance_to(
                Vector2(visible_global.get_center().x, visible_global.end.y)
            ) < 0.01,
            "Boss %d: Schatten muss an den sichtbaren Fuessen sitzen." % (index + 1)
        )

        sprite.free()

    if failures == 0:
        print("Milestone boss layout test: PASS")
        quit(0)
    else:
        push_error("Milestone boss layout test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
