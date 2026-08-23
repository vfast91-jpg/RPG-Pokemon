extends SceneTree

const ActiveRouteScript = preload("res://scripts/demo_route_endgame_legendary_landscapes_v1.gd")
const ActiveBattleScript = preload("res://scripts/battle_demo_landscape_background_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var main_file := FileAccess.open("res://main.tscn", FileAccess.READ)
    _check(main_file != null, "main.tscn konnte nicht gelesen werden.")
    if main_file != null:
        var main_text: String = main_file.get_as_text()
        _check(main_text.contains("demo_route_endgame_legendary_landscapes_v1.gd"), "main.tscn muss den aktiven Landschafts-/Endgame-Route-Layer verwenden.")
        _check(main_text.contains("battle_demo_landscape_background_v1.gd"), "main.tscn muss den aktiven Landschafts-Kampflayer verwenden.")

    var route = ActiveRouteScript.new()
    route.team = [
        {"species_id": "pikachu", "level": 18, "hp": 40, "max_hp": 40},
        {"species_id": "caterpie", "level": 15, "hp": 30, "max_hp": 30},
        {"species_id": "rattata", "level": 14, "hp": 0, "max_hp": 30}
    ]
    route.stage = 11

    # Protected onboarding through stage 10, then dynamic opponent scaling.
    _check(route._highest_team_level() == 18, "Aktive Route muss das höchste Teamlevel Lv.18 erkennen.")
    _check(route._enemy_level_for_encounter(1, 1) == 2, "Etappe 1 muss den geschützten Lv.2-Kampf verwenden.")
    _check(route._enemy_level_for_encounter(5, 3) == 4, "Etappe 5 muss den geschützten Lv.4-Kampf verwenden.")
    _check(route._enemy_level_for_encounter(6, 2) == 5, "Etappe 6 muss den geschützten 2x-Lv.5-Kampf verwenden.")
    _check(route._enemy_level_for_encounter(7, 2) == 6, "Etappe 7 muss den geschützten 2x-Lv.6-Kampf verwenden.")
    _check(route._enemy_level_for_encounter(8, 3) == 6, "Etappe 8 muss den geschützten 3x-Lv.6-Kampf verwenden.")
    _check(route._enemy_level_for_encounter(9, 3) == 7, "Etappe 9 muss den geschützten 3x-Lv.7-Kampf verwenden.")
    _check(route._enemy_level_for_encounter(10, 3) == 8, "Etappe 10 muss den geschützten 3x-Lv.8-Kampf verwenden.")
    _check(route._enemy_level_for_encounter(11, 1) == 23, "Aktive Route ab Etappe 11: 1 Gegner muss Lv.23 sein.")
    _check(route._enemy_level_for_encounter(11, 2) == 20, "Aktive Route ab Etappe 11: 2 Gegner müssen Lv.20 sein.")
    _check(route._enemy_level_for_encounter(11, 3) == 18, "Aktive Route ab Etappe 11: 3 Gegner müssen Lv.18 sein.")
    _check(route._enemy_level_for_encounter(11, 4) == 16, "Aktive Route ab Etappe 11: 4 Gegner müssen Lv.16 sein.")

    # Notice semantics.
    _check(route._route_level_notice_for_stage(6).is_empty(), "Etappe 6 darf noch keinen Hinweis zum dynamischen Gegnerniveau zeigen.")
    _check(not route._route_level_notice_for_stage(11).is_empty(), "Etappe 11 braucht den einmaligen Hinweis zum dynamischen Gegnerniveau.")
    _check(route._route_level_notice_for_stage(21).is_empty(), "Etappe 21 darf keinen weiteren Levelband-Hinweis besitzen.")

    # XP pacing and level cap strategy.
    _check(route._route_stage_xp(1) == 46, "Aktive Route muss die halbierten Etappen-EP verwenden.")
    _check(route._route_stage_xp(10) == 316, "Etappe 10 muss 316 EP verwenden.")
    _check(route._route_stage_xp(90) == 13396, "Etappe 90 muss 13396 EP verwenden.")

    # Fangwiese: direktes Gambling gegen das höchste eigene Pokémon.
    _check(route.CAPTURE_SEARCH_LEVEL_OFFSETS == [1, 3, 5], "Fangwiese muss -1/-3/-5 als feste Suchabstände verwenden.")
    _check(route._capture_level_for_stage(11) == 17, "Fangwiesen-Basislevel muss höchstes Teamlevel -1 sein.")
    _check(route._capture_level_for_search(1) == 17, "Fangwiese Suche 1 muss höchstes Level -1 verwenden.")
    _check(route._capture_level_for_search(2) == 15, "Fangwiese Suche 2 muss höchstes Level -3 verwenden.")
    _check(route._capture_level_for_search(3) == 13, "Fangwiese Suche 3 muss höchstes Level -5 verwenden.")
    _check(route.CAPTURE_SEARCH_MAX == 3, "Fangwiese darf maximal drei Suchen besitzen.")

    # Encounter family weighting is shared by capture and ordinary enemies.
    _check(route._family_catch_rate("bulbasaur") == 45.0, "Bisasam-Familien-Fangrate muss 45 sein.")
    _check(route._encounter_species_weight("rattata") > route._encounter_species_weight("bulbasaur"), "Rattfratz-Familie muss ein höheres Grund-Begegnungsgewicht als Bisasam besitzen.")
    _check(route._capture_family_weight("bulbasaur", 1) > route._capture_family_weight("bulbasaur", 2), "Fangwiesen-Suche 2 muss die Fangraten-Gewichtung abflachen.")

    # Fundstelle and vitamins.
    _check(route.VITAMINS.size() == 5, "Es müssen genau fünf Vitaminarten existieren.")
    _check(route.VITAMIN_BONUS_PER_USE == 1, "Vitamin muss +1 Wertpunkt geben.")
    _check(route.VITAMIN_STAT_CAP == 10, "Vitamin-Cap muss +10 pro Attribut/Pokémon sein.")
    _check(str(route._healing_item_for_stage(1).get("name", "")) == "Trank", "Frühe Fundstelle muss Trank anbieten.")
    _check(str(route._healing_item_for_stage(61).get("name", "")) == "Top-Trank", "Späte Fundstelle muss Top-Trank anbieten.")

    # Protected event pool: no boss through stage 10. From stage 11 onward use
    # exactly 3 distinct choices from the complete five-event pool.
    for stage: int in [1, 5, 10]:
        for _sample: int in range(32):
            var early_choices: Array[Dictionary] = route._choices_for_stage(stage)
            _check(early_choices.size() == 3, "Etappe %d muss genau drei Wege auswürfeln." % stage)
            var early_kinds: Array[String] = []
            for choice: Dictionary in early_choices:
                var kind: String = str(choice.get("kind", ""))
                _check(kind != route.EVENT_RARE, "Etappe %d darf im geschützten Einstieg keinen Boss anbieten." % stage)
                _check(not early_kinds.has(kind), "Etappe %d würfelt dasselbe Ereignis doppelt: %s" % [stage, kind])
                early_kinds.append(kind)

    for _sample: int in range(64):
        var choices: Array[Dictionary] = route._choices_for_stage(11)
        _check(choices.size() == 3, "Aktive Route muss ab Etappe 11 genau drei Wege auswürfeln.")
        var kinds: Array[String] = []
        for choice: Dictionary in choices:
            var kind: String = str(choice.get("kind", ""))
            _check(route.ACTIVE_ROUTE_EVENTS.has(kind), "Aktive Route würfelt ein ungültiges Ereignis: %s" % kind)
            _check(not kinds.has(kind), "Aktive Route würfelt dasselbe Ereignis doppelt: %s" % kind)
            kinds.append(kind)
        _check(not kinds.has(route.EVENT_DIRECT), "Direkter Pfad darf im finalen aktiven System nicht vorkommen.")
        _check(not kinds.has(route.EVENT_DANGEROUS), "Gefährlicher Pfad darf im finalen aktiven System nicht vorkommen.")

    # Boss contract remains unchanged once bosses become available at stage 11.
    _check(route._boss_level() == 23, "Boss muss bei Teammaximum Lv.18 auf Lv.23 liegen.")
    _check(is_equal_approx(route.BOSS_HP_MULTIPLIER, 2.0), "Boss muss den doppelten KP-Pool behalten.")

    # Battle layer can apply permanent route-only vitamin bonuses without
    # changing canonical species data.
    var battle = ActiveBattleScript.new()
    var combatant: Dictionary = {
        "max_hp": 50,
        "hp": 50,
        "attack": 30,
        "defense": 30,
        "special": 30,
        "speed": 30,
        "alive": true
    }
    battle._route_apply_state(combatant, {
        "hp": 51,
        "major_status": "",
        "vitamin_bonuses": {"hp": 2, "attack": 1, "defense": 1, "special": 1, "speed": 1}
    })
    _check(int(combatant.get("max_hp", 0)) == 52, "Aktiver Kampflayer muss Zink auf Max-KP anwenden.")
    _check(int(combatant.get("attack", 0)) == 31, "Aktiver Kampflayer muss Protein auf Angriff anwenden.")
    _check(int(combatant.get("defense", 0)) == 31, "Aktiver Kampflayer muss Eisen auf Verteidigung anwenden.")
    _check(int(combatant.get("special", 0)) == 31, "Aktiver Kampflayer muss Kalzium auf Status anwenden.")
    _check(int(combatant.get("speed", 0)) == 31, "Aktiver Kampflayer muss Carbon auf Initiative anwenden.")

    battle.free()
    route.free()

    if failures == 0:
        print("Route rebalance integration test: PASS")
        quit(0)
    else:
        push_error("Route rebalance integration test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
