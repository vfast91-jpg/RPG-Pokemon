extends SceneTree

const CombatLabScript = preload("res://scripts/battle_demo_adaptive_family_ui.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = CombatLabScript.new()
    root.add_child(lab)

    _check_connector(lab, true, Vector2(8.0, 1.0), Vector2(220.0, 0.0), "Gegner oben")
    _check_connector(lab, true, Vector2(8.0, 163.0), Vector2(190.0, 144.0), "Gegner unten")
    _check_connector(lab, false, Vector2(456.0, 1.0), Vector2(350.0, 0.0), "Spieler oben")
    _check_connector(lab, false, Vector2(456.0, 163.0), Vector2(380.0, 144.0), "Spieler unten")

    lab.queue_free()

    if failures == 0:
        print("Combat connector horizontal test: PASS")
        quit(0)
    else:
        push_error("Combat connector horizontal test: %d Fehler" % failures)
        quit(1)


func _check_connector(lab, enemy: bool, card_position: Vector2, sprite_position: Vector2, label: String) -> void:
    var card := Control.new()
    card.position = card_position
    card.size = Vector2(176.0, 52.0)

    var sprite := TextureRect.new()
    sprite.position = sprite_position
    sprite.size = Vector2(72.0, 72.0)

    var line := Line2D.new()
    lab._update_roster_connector(line, card, sprite, enemy)

    _check(line.points.size() == 2, "%s: Verbindung besteht nicht aus genau einem Segment." % label)
    if line.points.size() != 2:
        return

    var start: Vector2 = line.points[0]
    var finish: Vector2 = line.points[1]
    _check(absf(start.y - finish.y) < 0.001, "%s: Verbindungslinie ist nicht horizontal." % label)

    var expected_y: float = sprite.position.y + sprite.size.y * 0.5
    _check(absf(start.y - expected_y) < 0.001, "%s: Linie richtet sich nicht am Pokemon aus." % label)

    if enemy:
        _check(absf(start.x - (card.position.x + card.size.x)) < 0.001, "%s: Linie startet nicht am Kartenrand." % label)
        _check(absf(finish.x - sprite.position.x) < 0.001, "%s: Linie endet nicht am Pokemon." % label)
    else:
        _check(absf(start.x - card.position.x) < 0.001, "%s: Linie startet nicht am Kartenrand." % label)
        _check(absf(finish.x - (sprite.position.x + sprite.size.x)) < 0.001, "%s: Linie endet nicht am Pokemon." % label)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
