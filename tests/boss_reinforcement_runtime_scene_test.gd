extends Node

const BattleScript = preload("res://scripts/battle_demo_aggro_rules_final_v2.gd")
const RouteScript = preload("res://scripts/demo_route_capture_button_fix_v1.gd")
const VisibleTextureLayout = preload("res://scripts/ui/visible_texture_layout.gd")

var failures: int = 0


func _ready() -> void:
    _check_route_contracts()
    await _check_live_reinforcement_transition()

    if failures == 0:
        print("Boss reinforcement runtime scene test: PASS")
        get_tree().quit(0)
    else:
        push_error("Boss reinforcement runtime scene test: %d Fehler" % failures)
        get_tree().quit(1)


func _check_route_contracts() -> void:
    var route = RouteScript.new()
    route.team = [{"species_id": "bulbasaur", "level": 11, "hp": 28, "max_hp": 28}]
    var source: Array = [{
        "species_id": "tyrogue",
        "level": 16,
        "boss": true,
        "hp_multiplier": 2.0,
        "hp_bars": 2
    }]

    var stage10_pool: Array[String] = route._route_event_pool_for_stage(10)
    _check(
        stage10_pool.size() == 1 and stage10_pool[0] == route.EVENT_RARE,
        "Etappe 10 muss weiterhin automatisch genau die feste Besondere Begegnung starten."
    )
    _check(
        route._route_event_pool_for_stage(13).has(route.EVENT_RARE),
        "Spätere Zufallsetappen müssen die normale Besondere Begegnung weiter enthalten."
    )

    for current_stage: int in [10, 13]:
        route.stage = current_stage
        var decorated: Array = route._decorate_standard_boss_reinforcement_contract(source)
        var boss: Dictionary = decorated[0] as Dictionary
        _check(
            bool(boss.get("boss_reinforcement_enabled", false)),
            "Etappe %d muss denselben sicheren Verstärkungsvertrag erhalten." % current_stage
        )
        _check(
            int(boss.get("boss_reinforcement_count", 0)) == 2,
            "Etappe %d muss genau zwei Verstärkungen anfordern." % current_stage
        )

    route.free()


func _check_live_reinforcement_transition() -> void:
    var battle = BattleScript.new()
    add_child(battle)
    await get_tree().process_frame

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
    await get_tree().process_frame

    _check(battle.enemy_team.size() == 1, "Bosskampf muss mit genau einem Gegner beginnen.")
    if battle.enemy_team.is_empty():
        battle.queue_free()
        return

    var boss: Dictionary = battle.enemy_team[0] as Dictionary
    # The real reinforcement threshold is crossed after a completed action,
    # not while the opening-choice overlay is intentionally pausing Timeflow.
    battle.paused = false
    battle.selected_actor = {}
    boss["hp"] = int(boss.get("boss_base_max_hp", 1))
    battle._refresh_cards()

    await get_tree().create_timer(0.75).timeout
    var area: Control = battle._battle_area_for_reinforcements()
    var icon: Label = area.get_node_or_null("BossAngerIcon") as Label if area != null else null
    _check(icon != null, "Wutzeichen muss während des Hilferufs sichtbar sein.")

    var boss_ui_value: Variant = battle.cards.get(str(boss.get("id", "")), {})
    if icon != null and boss_ui_value is Dictionary:
        var boss_sprite: TextureRect = (boss_ui_value as Dictionary).get("texture") as TextureRect
        if boss_sprite != null:
            var visible_rect: Rect2 = VisibleTextureLayout.visible_rect(boss_sprite)
            var expected_anchor: Vector2 = VisibleTextureLayout.enemy_forehead_anchor(
                boss_sprite.position,
                visible_rect
            )
            _check(
                (icon.position + icon.size * 0.5).distance_to(expected_anchor) <= 6.0,
                "Wutzeichen muss am vorderen Stirnbereich des sichtbaren Pokemon sitzen."
            )

    await get_tree().create_timer(3.6).timeout
    _check(not battle._boss_reinforcement_transition_running, "Verstärkungsanimation muss sicher enden.")
    _check(not battle.paused, "Kampf darf nach der Verstärkungsanimation nicht pausiert bleiben.")
    _check(battle.enemy_team.size() == 3, "Boss und zwei Verstärkungen müssen gemeinsam weiterspielen.")

    if area != null:
        _check(area.get_node_or_null("BossAngerIcon") == null, "Wutzeichen muss nach der Animation entfernt sein.")
        _check(area.get_node_or_null("BossReinforcementBanner") == null, "Hilferuf-Banner muss nach der Animation entfernt sein.")

    for combatant_value: Variant in battle.enemy_team:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value as Dictionary
        if not bool(combatant.get("boss_reinforcement", false)):
            continue
        var ui_value: Variant = battle.cards.get(str(combatant.get("id", "")), {})
        if not (ui_value is Dictionary):
            continue
        var connector: Line2D = (ui_value as Dictionary).get("connector") as Line2D
        _check(connector != null, "Jede Verstärkung braucht eine Verbindung zur Statuskarte.")
        if connector != null and connector.points.size() == 2:
            _check(
                connector.points[0].distance_to(connector.points[1]) <= 34.1,
                "Verstärkungslinie darf nicht mehr quer über das Kampffeld laufen."
            )
            _check(connector.width <= 2.01, "Verstärkungslinie muss dezent bleiben.")
            _check(connector.default_color.a <= 0.781, "Verstärkungslinie muss optisch zurücktreten.")
            _check(
                connector.begin_cap_mode == Line2D.LINE_CAP_ROUND
                    and connector.end_cap_mode == Line2D.LINE_CAP_ROUND,
                "Verstärkungslinie braucht weiche runde Enden."
            )

    # Even if a future animation step stops emitting its completion signal,
    # the watchdog must return control to the running battle.
    battle.paused = false
    battle._boss_reinforcement_pause_before = false
    battle._boss_reinforcement_transition_running = true
    battle._boss_reinforcement_transition_started_msec = (
        Time.get_ticks_msec() - battle.BOSS_REINFORCEMENT_TRANSITION_TIMEOUT_MSEC
    )
    battle._process(0.0)
    _check(
        not battle._boss_reinforcement_transition_running and not battle.paused,
        "Zeitlimit muss eine festhängende Verstärkungsanimation sicher freigeben."
    )

    battle.queue_free()
    await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
