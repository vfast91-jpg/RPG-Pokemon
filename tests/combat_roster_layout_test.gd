extends SceneTree

const CombatLabScript = preload("res://scripts/battle_demo_adaptive_family_ui.gd")

const EXPECTED_CARD_SIZE := Vector2(176.0, 52.0)
const EXPECTED_SPRITE_SIZE := Vector2(72.0, 72.0)
const EXPECTED_METER_WIDTH: float = 96.0
const EXPECTED_METER_HEIGHT: float = 6.0

var failures: int = 0


func _initialize() -> void:
    var lab = CombatLabScript.new()
    root.add_child(lab)

    _run_scenario(lab, 1, 1, "1v1")
    _run_scenario(lab, 2, 2, "2v2")
    _run_scenario(lab, 3, 3, "3v3")
    _run_scenario(lab, 4, 4, "4v4")
    _run_scenario(lab, 2, 3, "2v3")

    lab.queue_free()

    if failures == 0:
        print("Combat roster layout test: PASS")
        quit(0)
    else:
        push_error("Combat roster layout test: %d Fehler" % failures)
        quit(1)


func _run_scenario(lab, player_count: int, enemy_count: int, scenario: String) -> void:
    lab.player_setup.clear()
    lab.enemy_setup.clear()

    for _index: int in range(player_count):
        lab.player_setup.append(lab._random_family_setup(5, 5))
    for _index: int in range(enemy_count):
        lab.enemy_setup.append(lab._random_family_setup(5, 5))

    lab._start_battle()

    var area: Control = lab.battle_panel.get_node("BattleArea") as Control
    _check(area != null, "%s: BattleArea fehlt." % scenario)
    if area == null:
        return

    _validate_team(lab, lab.player_team, false, area, scenario + " Spieler")
    _validate_team(lab, lab.enemy_team, true, area, scenario + " Gegner")
    _validate_connector_states(lab, scenario)


func _validate_team(lab, team: Array, enemy: bool, area: Control, label: String) -> void:
    var previous_card_y: float = -10000.0
    var previous_sprite_x: float = 0.0

    for index: int in range(team.size()):
        var combatant: Dictionary = team[index]
        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = lab.cards.get(combatant_id, {})
        _check(ui_value is Dictionary and not (ui_value as Dictionary).is_empty(), "%s #%d: UI fehlt." % [label, index + 1])
        if not (ui_value is Dictionary) or (ui_value as Dictionary).is_empty():
            continue
        var ui: Dictionary = ui_value

        var card: Control = ui.get("card") as Control
        var sprite: TextureRect = ui.get("texture") as TextureRect
        _check(card != null, "%s #%d: Karte fehlt." % [label, index + 1])
        _check(sprite != null, "%s #%d: Pokemon-Bild fehlt." % [label, index + 1])
        if card == null or sprite == null:
            continue

        _check(_same_vec(card.size, EXPECTED_CARD_SIZE), "%s #%d: Karte ist %s statt %s." % [label, index + 1, card.size, EXPECTED_CARD_SIZE])
        _check(_same_vec(card.custom_minimum_size, EXPECTED_CARD_SIZE), "%s #%d: Karten-Minimum ist nicht fest." % [label, index + 1])
        _check(card.get_combined_minimum_size().y <= EXPECTED_CARD_SIZE.y + 0.01, "%s #%d: Karteninhalt erzwingt wieder Ueberhoehe %.1f." % [label, index + 1, card.get_combined_minimum_size().y])

        _check(card.position.y >= -0.01, "%s #%d: Karte ragt oben heraus." % [label, index + 1])
        _check(card.position.y + card.size.y <= area.size.y + 0.01, "%s #%d: Karte ragt unten heraus." % [label, index + 1])
        if index > 0:
            _check(card.position.y >= previous_card_y + EXPECTED_CARD_SIZE.y, "%s #%d: Karten ueberlappen vertikal." % [label, index + 1])
        previous_card_y = card.position.y

        _check(_same_vec(sprite.size, EXPECTED_SPRITE_SIZE), "%s #%d: Pokemon-Bild ist %s statt %s." % [label, index + 1, sprite.size, EXPECTED_SPRITE_SIZE])
        _check(sprite.position.y >= -0.01, "%s #%d: Pokemon-Bild ragt oben heraus." % [label, index + 1])
        _check(sprite.position.y + sprite.size.y <= area.size.y + 0.01, "%s #%d: Pokemon-Bild ragt unten heraus." % [label, index + 1])

        # Formation must point upward: top slot is always farthest toward center.
        if index > 0:
            if enemy:
                _check(previous_sprite_x > sprite.position.x, "%s: Gegnerformation zeigt nicht nach oben." % label)
            else:
                _check(previous_sprite_x < sprite.position.x, "%s: Spielerformation zeigt nicht nach oben." % label)
        previous_sprite_x = sprite.position.x

        _validate_meter(ui.get("hp_back") as Panel, ui.get("hp_fill") as Panel, label, index, "KP")
        _validate_meter(ui.get("aggro_back") as Panel, ui.get("aggro_fill") as Panel, label, index, "Aggro")
        _validate_meter(ui.get("atb_back") as Panel, ui.get("atb_fill") as Panel, label, index, "ATB")

        var connector: Line2D = ui.get("connector") as Line2D
        _check(connector != null, "%s #%d: Verbindungslinie fehlt." % [label, index + 1])
        if connector != null:
            _check(connector.points.size() == 2, "%s #%d: Verbindungslinie hat wieder Treppen-Ecken." % [label, index + 1])

        var info: Button = ui.get("info") as Button
        _check(info != null, "%s #%d: Info-Knopf fehlt." % [label, index + 1])
        if info != null:
            _check(info.get_combined_minimum_size().y <= 18.01, "%s #%d: Info-Knopf erzwingt wieder Karten-Ueberhoehe." % [label, index + 1])
            _check(info.position.y + info.size.y <= 48.01, "%s #%d: Info-Knopf ragt aus dem Karteninhalt." % [label, index + 1])


func _validate_meter(background: Panel, fill: Panel, label: String, index: int, meter_name: String) -> void:
    _check(background != null, "%s #%d: %s-Hintergrund fehlt." % [label, index + 1, meter_name])
    _check(fill != null, "%s #%d: %s-Fuellung fehlt." % [label, index + 1, meter_name])
    if background == null or fill == null:
        return

    _check(absf(background.size.x - EXPECTED_METER_WIDTH) < 0.01, "%s #%d: %s-Breite ist instabil." % [label, index + 1, meter_name])
    _check(absf(background.size.y - EXPECTED_METER_HEIGHT) < 0.01, "%s #%d: %s-Hoehe ist instabil." % [label, index + 1, meter_name])
    _check(fill.size.x >= -0.01 and fill.size.x <= EXPECTED_METER_WIDTH + 0.01, "%s #%d: %s-Fuellung verlaesst ihren Balken." % [label, index + 1, meter_name])
    _check(absf(fill.size.y - EXPECTED_METER_HEIGHT) < 0.01, "%s #%d: %s-Fuellung hat falsche Hoehe." % [label, index + 1, meter_name])
    _check(background.position.x + background.size.x <= 148.01, "%s #%d: %s ragt rechts aus dem reservierten Bereich." % [label, index + 1, meter_name])
    _check(background.position.y + background.size.y <= 48.01, "%s #%d: %s ragt unten aus der Karte." % [label, index + 1, meter_name])

    var background_style: StyleBoxFlat = background.get_theme_stylebox("panel") as StyleBoxFlat
    var fill_style: StyleBoxFlat = fill.get_theme_stylebox("panel") as StyleBoxFlat
    _check(background_style != null, "%s #%d: %s-Hintergrund hat keinen Rundungsstil." % [label, index + 1, meter_name])
    _check(fill_style != null, "%s #%d: %s-Fuellung hat keinen Rundungsstil." % [label, index + 1, meter_name])


func _validate_connector_states(lab, scenario: String) -> void:
    if lab.player_team.is_empty():
        return

    var active: Dictionary = lab.player_team[0]
    lab.selected_actor = active
    lab._refresh_cards()

    var active_ui_value: Variant = lab.cards.get(str(active.get("id", "")), {})
    if active_ui_value is Dictionary:
        var active_connector: Line2D = (active_ui_value as Dictionary).get("connector") as Line2D
        _check(active_connector != null, "%s: Aktive Verbindungslinie fehlt." % scenario)
        if active_connector != null:
            _check(_same_color(active_connector.default_color, Color("e0a52f")), "%s: Aktive Verbindungslinie ist nicht gelb." % scenario)
            _check(absf(active_connector.width - 3.0) < 0.01, "%s: Aktive Verbindungslinie wird nicht betont." % scenario)

    lab.selected_actor = {}
    lab._refresh_cards()

    var neutral_probe := Line2D.new()
    lab._apply_connector_state(neutral_probe, true, false, 0)
    _check(_same_color(neutral_probe.default_color, Color("fffdf2")), "%s: Neutrale Verbindungslinie ist nicht deckend weiss." % scenario)
    _check(absf(neutral_probe.width - 2.5) < 0.01, "%s: Neutrale Verbindungslinie ist auf hellem Hintergrund zu duenn." % scenario)
    neutral_probe.free()

    var found_target: bool = false
    for combatant_value: Variant in lab.combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)) or lab._incoming_target_count(combatant) <= 0:
            continue
        found_target = true
        var ui_value: Variant = lab.cards.get(str(combatant.get("id", "")), {})
        if not (ui_value is Dictionary):
            continue
        var connector: Line2D = (ui_value as Dictionary).get("connector") as Line2D
        _check(connector != null, "%s: Ziel-Verbindungslinie fehlt." % scenario)
        if connector != null:
            _check(_same_color(connector.default_color, Color("cf3434")), "%s: Aggro-Ziel-Verbindungslinie ist nicht rot." % scenario)
            _check(absf(connector.width - 3.0) < 0.01, "%s: Aggro-Ziel-Verbindungslinie wird nicht betont." % scenario)

    _check(found_target, "%s: Kein Aggro-Ziel fuer Farbtest gefunden." % scenario)


func _same_vec(left: Vector2, right: Vector2) -> bool:
    return left.distance_to(right) < 0.01


func _same_color(left: Color, right: Color) -> bool:
    return absf(left.r - right.r) < 0.001 \
        and absf(left.g - right.g) < 0.001 \
        and absf(left.b - right.b) < 0.001 \
        and absf(left.a - right.a) < 0.001


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
