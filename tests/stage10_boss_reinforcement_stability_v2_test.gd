extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_boss_reinforcement_stability_v2.gd")
const VisibleLayout = preload("res://scripts/ui/visible_texture_layout.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = BattleScript.new()
    root.add_child(battle)

    battle.start_route_battle_party(
        [{"species_id": "bulbasaur", "level": 11, "hp": 28, "max_hp": 28}],
        [{
            "species_id": "tyrogue",
            "level": 16,
            "boss": true,
            "hp_multiplier": 2.0,
            "hp_bars": 2,
            "boss_reinforcement_enabled": true,
            "boss_reinforcement_count": 2,
            "boss_reinforcement_species_id": "tyrogue",
            "boss_reinforcement_level": 11,
            "boss_reinforcement_hp_multiplier": 1.0,
            "boss_reinforcement_start_atb": 0.0,
            "boss_reinforcement_trigger_remaining_bars": 1
        }]
    )

    _check(battle.enemy_team.size() == 1, "Etappe-10-Sonderboss muss mit genau einem Gegner beginnen.")
    if battle.enemy_team.is_empty():
        _finish(battle)
        return

    var boss: Dictionary = battle.enemy_team[0] as Dictionary
    var area: Control = battle._battle_area_for_reinforcements()
    _check(area != null, "Sonderboss braucht eine BattleArea.")
    if area == null:
        _finish(battle)
        return

    _check_slot_geometry(
        battle,
        area,
        boss,
        battle.STABLE_REINFORCEMENT_BOSS_CENTER_RATIO,
        true,
        "Boss vor Verstärkung"
    )

    # Build exactly the same 1 -> 3 transition used by the real encounter, but
    # skip the presentation timers so this regression test stays deterministic.
    boss["boss_reinforcement_started"] = true
    var created: Array[Dictionary] = battle._spawn_boss_reinforcements(boss)
    _check(created.size() == 2, "Boss muss genau zwei Rabauz-Verstärkungen erzeugen.")
    if created.size() != 2:
        _finish(battle)
        return

    battle._layout_reinforcement_visuals(created)
    boss["boss_reinforcement_spawned"] = true
    battle._refresh_cards()

    _check_slot_geometry(
        battle,
        area,
        created[0],
        battle.STABLE_REINFORCEMENT_TOP_CENTER_RATIO,
        false,
        "Obere Verstärkung"
    )
    _check_slot_geometry(
        battle,
        area,
        boss,
        battle.STABLE_REINFORCEMENT_BOSS_CENTER_RATIO,
        true,
        "Boss nach Verstärkung"
    )
    _check_slot_geometry(
        battle,
        area,
        created[1],
        battle.STABLE_REINFORCEMENT_BOTTOM_CENTER_RATIO,
        false,
        "Untere Verstärkung"
    )

    var top_ui: Dictionary = battle.cards.get(str(created[0].get("id", "")), {}) as Dictionary
    var bottom_ui: Dictionary = battle.cards.get(str(created[1].get("id", "")), {}) as Dictionary
    _check_compact_connector(battle, top_ui, "Obere Verstärkung")
    _check_compact_connector(battle, bottom_ui, "Untere Verstärkung")

    # Reproduce the real deadlock condition: a technical pause existed at the
    # HP-bar break, but after the animation there is no player prompt, opening
    # phase or info overlay that legitimately owns that pause.
    battle.opening_phase_active = false
    battle.selected_actor = {}
    battle.paused = true
    battle._boss_reinforcement_pause_before = true
    battle._boss_reinforcement_transition_running = true
    battle._boss_reinforcement_transition_started_msec = Time.get_ticks_msec()
    battle._finish_boss_reinforcement_transition()
    _check(not battle.paused, "Verstärkung darf Timeflow ohne echten Pause-Grund nicht festsetzen.")
    _check(not battle._boss_reinforcement_transition_running, "Verstärkungs-Lock muss nach der Phase aufgehoben sein.")

    # Timeflow must genuinely continue for the newly added combatants.
    var add_atb_before: float = float(created[0].get("atb", 0.0))
    battle._process(0.10)
    _check(
        float(created[0].get("atb", 0.0)) > add_atb_before,
        "Neue Verstärkung muss nach dem Übergang normal am Timeflow teilnehmen."
    )

    _finish(battle)


func _check_slot_geometry(
    battle,
    area: Control,
    combatant: Dictionary,
    center_ratio: float,
    boss_slot: bool,
    label: String
) -> void:
    var combatant_id: String = str(combatant.get("id", ""))
    var ui: Dictionary = battle.cards.get(combatant_id, {}) as Dictionary
    var card: Control = ui.get("card") as Control
    var sprite: TextureRect = ui.get("texture") as TextureRect
    _check(card != null, "%s braucht eine Statuskarte." % label)
    _check(sprite != null, "%s braucht ein Sprite." % label)
    if card == null or sprite == null:
        return

    var expected_center_y: float = area.size.y * center_ratio
    _check(
        absf(card.position.y + card.size.y * 0.5 - expected_center_y) <= 0.1,
        "%s: Statuskarte muss im festen Formationsslot zentriert sein." % label
    )

    var visible_rect: Rect2 = VisibleLayout.visible_rect(sprite)
    var visible_global := Rect2(sprite.position + visible_rect.position, visible_rect.size)
    _check(
        absf(visible_global.get_center().y - expected_center_y) <= 0.1,
        "%s: sichtbares Pokémon muss denselben Formationsslot wie seine Karte nutzen." % label
    )

    var shadow: Polygon2D = area.get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
    _check(shadow != null, "%s braucht einen Schatten." % label)
    if shadow != null:
        var expected_foot: Vector2 = VisibleLayout.visible_foot(sprite.position, visible_rect)
        _check(
            shadow.position.distance_to(expected_foot) <= 0.1,
            "%s: Schatten muss exakt am sichtbaren Pokémonfuß sitzen." % label
        )
        if boss_slot:
            _check(
                shadow.scale.distance_to(battle.ROUTE_BOSS_SHADOW_SCALE) <= 0.01,
                "%s: Boss-Schatten muss die Boss-Skalierung behalten." % label
            )


func _check_compact_connector(battle, ui: Dictionary, label: String) -> void:
    var connector: Line2D = ui.get("connector") as Line2D
    _check(connector != null, "%s braucht eine Verbindungslinie." % label)
    if connector == null or connector.points.size() != 2:
        return

    var max_gap: float = (
        battle.ROSTER_CARD_SPRITE_GAP
        + battle.STABLE_REINFORCEMENT_FORWARD_OFFSET
        + 0.1
    )
    _check(
        connector.points[0].distance_to(connector.points[1]) <= max_gap,
        "%s: Verbindungslinie darf nicht quer über das Kampffeld laufen." % label
    )
    _check(
        connector.width <= battle.STABLE_REINFORCEMENT_CONNECTOR_MAX_WIDTH + 0.01,
        "%s: Verbindungslinie muss dezent bleiben." % label
    )
    _check(
        connector.default_color.a <= battle.STABLE_REINFORCEMENT_CONNECTOR_MAX_ALPHA + 0.001,
        "%s: Verbindungslinie muss optisch zurücktreten." % label
    )


func _finish(battle) -> void:
    battle.queue_free()
    if failures == 0:
        print("Stage 10 boss reinforcement stability v2 test: PASS")
        quit(0)
    else:
        push_error("Stage 10 boss reinforcement stability v2 test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
