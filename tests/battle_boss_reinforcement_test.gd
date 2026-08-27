extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_boss_aggro_lock_v1.gd")
const SingleTargetAggroRules = preload("res://scripts/battle/single_target_aggro_rules.gd")
const VisibleTextureLayout = preload("res://scripts/ui/visible_texture_layout.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = BattleScript.new()
    root.add_child(battle)

    var team_state: Array = [{
        "species_id": "bulbasaur",
        "level": 12,
        "hp": 30,
        "max_hp": 30
    }]
    var enemy_party: Array = [{
        "species_id": "charmeleon",
        "level": 17,
        "boss": true,
        "hp_multiplier": 2.0,
        "hp_bars": 2,
        "boss_reinforcement_enabled": true,
        "boss_reinforcement_count": 2,
        "boss_reinforcement_species_id": "charmeleon",
        "boss_reinforcement_level": 12,
        "boss_reinforcement_hp_multiplier": 1.0,
        "boss_reinforcement_start_atb": 0.0,
        "boss_reinforcement_trigger_remaining_bars": 1
    }]

    battle.start_route_battle_party(team_state, enemy_party)
    _check(battle.enemy_team.size() == 1, "Bosskampf muss vor Phase 2 mit genau einem Gegner starten.")
    if battle.enemy_team.is_empty():
        _finish(battle)
        return

    var boss: Dictionary = battle.enemy_team[0] as Dictionary
    _check(bool(boss.get("boss_reinforcement_enabled", false)), "Boss muss den Routen-Verstaerkungsvertrag in den Kampf uebernehmen.")
    _check(int(boss.get("level", 0)) == 17, "Boss muss Lv.17 bleiben.")
    _check(str(boss.get("species_id", "")) == "charmeleon", "Boss-Spezies muss Glutexo bleiben.")
    _check(is_equal_approx(float(boss.get("aggro", -1.0)), 1.0), "Boss muss den Kampf mit exakt Aggro 1 beginnen.")

    boss["aggro"] = 99.0
    battle._enforce_route_boss_aggro()
    _check(is_equal_approx(float(boss.get("aggro", -1.0)), 1.0), "Boss-Aggro muss nach jeder Veraenderung hart auf 1 zurueckgesetzt werden.")

    var boss_relief_probe: Dictionary = {"boss": true, "aggro": 1.0}
    SingleTargetAggroRules.reduce(boss_relief_probe)
    _check(is_equal_approx(float(boss_relief_probe.get("aggro", -1.0)), 1.0), "Single-Target-Aggroabbau darf Boss-Aggro 1 nicht halbieren.")

    var normal_relief_probe: Dictionary = {"boss": false, "aggro": 20.0}
    SingleTargetAggroRules.reduce(normal_relief_probe)
    _check(is_equal_approx(float(normal_relief_probe.get("aggro", -1.0)), 10.0), "Normale Pokemon muessen weiterhin die bestehende Aggro-Halbierung erhalten.")

    var base_max_hp: int = maxi(1, int(boss.get("boss_base_max_hp", 0)))
    _check(int(boss.get("max_hp", 0)) == base_max_hp * 2, "Boss muss weiterhin exakt zwei normale KP-Leisten besitzen.")

    boss["hp"] = base_max_hp + 1
    _check(not battle._boss_should_call_reinforcements(boss), "Verstaerkung darf vor dem Bruch der ersten KP-Leiste nicht starten.")
    boss["hp"] = base_max_hp
    _check(battle._boss_should_call_reinforcements(boss), "Bei Beginn der zweiten KP-Leiste muss die Verstaerkungsphase ausloesen.")

    var boss_ui_before: Dictionary = battle.cards.get(str(boss.get("id", "")), {}) as Dictionary
    var boss_card_before: Control = boss_ui_before.get("card") as Control
    var boss_sprite_before: TextureRect = boss_ui_before.get("texture") as TextureRect
    var boss_card_position_before: Vector2 = boss_card_before.position if boss_card_before != null else Vector2.ZERO
    var boss_card_size_before: Vector2 = boss_card_before.size if boss_card_before != null else Vector2.ZERO
    var boss_sprite_position_before: Vector2 = boss_sprite_before.position if boss_sprite_before != null else Vector2.ZERO
    var boss_sprite_size_before: Vector2 = boss_sprite_before.size if boss_sprite_before != null else Vector2.ZERO

    var normal_probe: Dictionary = battle._make_combatant(
        "enemy",
        99,
        {"species_id": "charmeleon", "level": 12}
    )
    var expected_normal_hp: int = int(normal_probe.get("max_hp", 0))
    var expected_start_aggro: float = maxf(2.0, float(normal_probe.get("aggro", -1.0)))

    boss["boss_reinforcement_started"] = true
    var created: Array[Dictionary] = battle._spawn_boss_reinforcements(boss)
    _check(created.size() == 2, "Boss muss genau zwei Verstaerkungen erzeugen.")
    _check(battle.enemy_team.size() == 3, "Phase 2 muss aus 1 Boss + 2 Verstaerkungen bestehen.")
    _check(is_equal_approx(float(boss.get("aggro", -1.0)), 1.0), "Boss muss auch nach dem Spawn der Verstaerkungen exakt Aggro 1 behalten.")

    for index: int in range(created.size()):
        var add: Dictionary = created[index]
        _check(str(add.get("species_id", "")) == "charmeleon", "Verstaerkung #%d muss Glutexo bleiben und darf nicht zu Glumanda rueckentwickelt werden." % (index + 1))
        _check(int(add.get("level", 0)) == 12, "Verstaerkung #%d muss bei Spieler-Maxlevel Lv.12 exakt Lv.12 sein." % (index + 1))
        _check(not bool(add.get("boss", true)), "Verstaerkung #%d darf keinen Bossstatus besitzen." % (index + 1))
        _check(bool(add.get("boss_reinforcement", false)), "Verstaerkung #%d braucht die Laufzeit-Markierung." % (index + 1))
        _check(int(add.get("max_hp", 0)) == expected_normal_hp, "Verstaerkung #%d muss normale statt verdoppelte KP besitzen." % (index + 1))
        _check(is_equal_approx(float(add.get("atb", -1.0)), 0.0), "Verstaerkung #%d muss mit 0 Prozent ATB starten." % (index + 1))
        _check(is_equal_approx(float(add.get("aggro", -2.0)), expected_start_aggro), "Verstaerkung #%d muss die zentrale Start-Aggro verwenden und beim Eintritt sicher ueber Boss-Aggro 1 liegen." % (index + 1))
        _check(float(add.get("aggro", 0.0)) > float(boss.get("aggro", 1.0)), "Verstaerkung #%d muss beim Eintritt mehr Aggro als der Boss besitzen." % (index + 1))

    battle._layout_reinforcement_visuals(created)
    boss["boss_reinforcement_spawned"] = true
    battle._apply_boss_reinforcement_formation(boss)

    var area: Control = battle.battle_panel.get_node("BattleArea") as Control
    _check(area != null, "Boss+2-Formation braucht die BattleArea.")
    if area != null and created.size() == 2:
        var boss_ui: Dictionary = battle.cards.get(str(boss.get("id", "")), {}) as Dictionary
        var top_ui: Dictionary = battle.cards.get(str(created[0].get("id", "")), {}) as Dictionary
        var bottom_ui: Dictionary = battle.cards.get(str(created[1].get("id", "")), {}) as Dictionary

        var boss_card: Control = boss_ui.get("card") as Control
        var top_card: Control = top_ui.get("card") as Control
        var bottom_card: Control = bottom_ui.get("card") as Control
        var boss_sprite: TextureRect = boss_ui.get("texture") as TextureRect
        var top_sprite: TextureRect = top_ui.get("texture") as TextureRect
        var bottom_sprite: TextureRect = bottom_ui.get("texture") as TextureRect

        _check(boss_card != null and top_card != null and bottom_card != null, "Alle drei Gegner brauchen eigene Statuskarten.")
        _check(boss_sprite != null and top_sprite != null and bottom_sprite != null, "Alle drei Gegner brauchen eigene Sprites.")

        if boss_card != null and top_card != null and bottom_card != null:
            _check(top_card.position.y + top_card.size.y <= boss_card.position.y + 0.01, "Obere Verstaerkungskarte darf die Bosskarte nicht ueberlappen.")
            _check(boss_card.position.y + boss_card.size.y <= bottom_card.position.y + 0.01, "Bosskarte darf die untere Verstaerkungskarte nicht ueberlappen.")
            _check(top_card.position.y >= -0.01, "Obere Verstaerkungskarte darf nicht aus dem Feld ragen.")
            _check(bottom_card.position.y + bottom_card.size.y <= area.size.y + 0.01, "Untere Verstaerkungskarte darf nicht aus dem Feld ragen.")
            _check(top_card.position.y >= 10.0, "Obere Verstaerkung darf nicht mehr am extremen oberen Rand kleben.")
            _check(bottom_card.position.y + bottom_card.size.y <= area.size.y - 10.0, "Untere Verstaerkung darf nicht mehr am extremen unteren Rand kleben.")
            _check((boss_card.position - boss_card_position_before).length() < 0.01, "Bosskarte darf beim Phasenwechsel ihre Position nicht veraendern.")
            _check((boss_card.size - boss_card_size_before).length() < 0.01, "Bosskarte darf beim Phasenwechsel ihre Groesse nicht veraendern.")

        if boss_sprite != null and top_sprite != null and bottom_sprite != null:
            var expected_add_sprite_side: float = 72.0
            _check((boss_sprite.position - boss_sprite_position_before).length() < 0.01, "Boss-Sprite darf beim Erscheinen der Verstaerkungen nicht springen.")
            _check((boss_sprite.size - boss_sprite_size_before).length() < 0.01, "Boss-Sprite darf beim Erscheinen der Verstaerkungen nicht schrumpfen.")
            _check(boss_sprite.size.x > top_sprite.size.x, "Boss muss in Phase 2 sichtbar groesser als seine Verstaerkungen bleiben.")
            _check(absf(top_sprite.size.x - expected_add_sprite_side) < 0.01 and absf(bottom_sprite.size.x - expected_add_sprite_side) < 0.01, "Verstaerkungssprites muessen wieder die normale gut sichtbare Darstellungsgroesse besitzen.")

            var boss_rect := _visible_global_rect(boss_sprite)
            var top_rect := _visible_global_rect(top_sprite)
            var bottom_rect := _visible_global_rect(bottom_sprite)
            _check(not boss_rect.intersects(top_rect), "Boss-Sprite darf die obere Verstaerkung nicht ueberlappen.")
            _check(not boss_rect.intersects(bottom_rect), "Boss-Sprite darf die untere Verstaerkung nicht ueberlappen.")
            _check(not top_rect.intersects(bottom_rect), "Die beiden Verstaerkungssprites duerfen sich nicht ueberlappen.")

            for add: Dictionary in created:
                var add_id: String = str(add.get("id", ""))
                var add_ui: Dictionary = battle.cards.get(add_id, {}) as Dictionary
                var add_sprite: TextureRect = add_ui.get("texture") as TextureRect
                var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + add_id) as Polygon2D
                _check(shadow != null, "Jede Verstaerkung braucht einen am Sprite verankerten Schatten.")
                if shadow != null and add_sprite != null:
                    var visible_rect: Rect2 = VisibleTextureLayout.visible_rect(add_sprite)
                    var expected_foot: Vector2 = VisibleTextureLayout.visible_foot(add_sprite.position, visible_rect)
                    var expected_shadow_x: float = expected_foot.x
                    var expected_shadow_y: float = expected_foot.y
                    _check(absf(shadow.position.x - expected_shadow_x) < 0.01, "Verstaerkungsschatten muss horizontal am Spritefuss verankert sein.")
                    _check(absf(shadow.position.y - expected_shadow_y) < 0.01, "Verstaerkungsschatten muss vertikal am Spritefuss verankert sein.")
                    _check(absf(shadow.scale.x - 1.0) < 0.01 and absf(shadow.scale.y - 1.0) < 0.01, "Verstaerkungsschatten muss zur normalen Darstellungsgroesse des Sprites passen.")

    _finish(battle)


func _finish(battle) -> void:
    battle.queue_free()
    if failures == 0:
        print("Battle boss reinforcement test: PASS")
        quit(0)
    else:
        push_error("Battle boss reinforcement test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)


func _visible_global_rect(sprite: TextureRect) -> Rect2:
    var visible_rect: Rect2 = VisibleTextureLayout.visible_rect(sprite)
    return Rect2(sprite.position + visible_rect.position, visible_rect.size)
