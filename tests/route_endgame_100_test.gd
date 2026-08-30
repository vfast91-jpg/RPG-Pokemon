extends SceneTree

const ActiveMainMenuScript = preload("res://scripts/main_menu_click_difficulty_v1.gd")
const ActiveRouteScript = preload("res://scripts/demo_route_boss_gauntlet_test_v1.gd")
const ActiveBattleScript = preload("res://scripts/battle_demo_endgame_atb_v1.gd")
const BossRules = preload("res://scripts/route_boss_rules.gd")
const RULES_PATH: String = "res://data/route_boss_rules_v1.json"

var failures: int = 0


func _initialize() -> void:
    var main_text: String = FileAccess.get_file_as_string("res://main.tscn")
    _check(main_text.contains("res://scripts/demo_route_boss_gauntlet_test_v1.gd"), "main.tscn muss den aktiven 100-Etappen-/Bosskampflauf-Routenlayer laden.")
    _check(main_text.contains("res://scripts/battle_demo_endgame_atb_v1.gd"), "main.tscn muss den aktiven Endgame-ATB-Kampflayer laden.")

    var rules_text: String = FileAccess.get_file_as_string(RULES_PATH)
    var parsed: Variant = JSON.parse_string(rules_text)
    _check(parsed is Dictionary, "Endgame-Bossregeln müssen gültiges JSON sein.")
    if parsed is Dictionary:
        var rules: Dictionary = parsed as Dictionary
        var endgame_value: Variant = rules.get("planned_endgame", {})
        _check(endgame_value is Dictionary, "planned_endgame fehlt.")
        if endgame_value is Dictionary:
            var endgame: Dictionary = endgame_value as Dictionary
            _check(bool(endgame.get("enabled", false)), "Endgame 91-100 muss aktiv sein.")
            _check(int(endgame.get("stage_start", 0)) == 91, "Endgame muss auf Etappe 91 beginnen.")
            _check(int(endgame.get("stage_end", 0)) == 100, "Endgame muss auf Etappe 100 enden.")

            var boss_profile: Dictionary = endgame.get("boss_profile", {})
            _check(int(boss_profile.get("level_offset", 0)) == 10, "Superboss muss +10 Level besitzen.")
            _check(is_equal_approx(float(boss_profile.get("hp_multiplier", 0.0)), 4.0), "Superboss muss 4x KP besitzen.")
            _check(int(boss_profile.get("hp_bars", 0)) == 4, "Superboss muss vier KP-Leisten besitzen.")
            _check(is_equal_approx(float(boss_profile.get("atb_rate_multiplier", 0.0)), 1.5), "Superboss-ATB muss auf 1.5 konfiguriert sein.")

            var legendary_profile: Dictionary = endgame.get("legendary_profile", {})
            _check(int(legendary_profile.get("level_offset", 0)) == 10, "Legendäres Endgame-Pokémon muss +10 Level besitzen.")
            _check(is_equal_approx(float(legendary_profile.get("hp_multiplier", 0.0)), 4.0), "Legendäres Endgame-Pokémon muss 4x KP besitzen.")
            _check(int(legendary_profile.get("hp_bars", 0)) == 4, "Legendäres Endgame-Pokémon muss vier KP-Leisten besitzen.")
            _check(is_equal_approx(float(legendary_profile.get("atb_rate_multiplier", 0.0)), 2.0), "Legendären-ATB muss auf 2.0 konfiguriert sein.")

            var stages_value: Variant = endgame.get("stages", [])
            _check(stages_value is Array and (stages_value as Array).size() == 10, "Endgame braucht exakt zehn Boss-Etappen.")
            if stages_value is Array:
                for stage_value: Variant in stages_value:
                    if not (stage_value is Dictionary):
                        _fail("Ungültiger Stage-Eintrag in planned_endgame.")
                        continue
                    var stage_rule: Dictionary = stage_value as Dictionary
                    var current_stage: int = int(stage_rule.get("stage", 0))
                    if current_stage <= 95:
                        _check(str(stage_rule.get("species_mode", "")) == "random_non_legendary", "Etappen 91-95 müssen zufällige nicht-legendäre Superbosse bleiben.")
                    elif current_stage <= 98:
                        _check(str(stage_rule.get("species_mode", "")) == "random_legendary_pool", "Etappen 96-98 müssen den 580er-Legendärenpool verwenden.")
                        _check(str(stage_rule.get("legendary_pool", "")) == "bst_580", "Etappen 96-98 müssen Pool bst_580 verwenden.")
                        _check(bool(stage_rule.get("unique_within_pool", false)), "Etappen 96-98 dürfen innerhalb des 580er-Pools keine Wiederholung zulassen.")
                    else:
                        _check(str(stage_rule.get("species_mode", "")) == "random_legendary_pool", "Etappen 99-100 müssen den 680er-Legendärenpool verwenden.")
                        _check(str(stage_rule.get("legendary_pool", "")) == "bst_680", "Etappen 99-100 müssen Pool bst_680 verwenden.")
                        _check(bool(stage_rule.get("unique_within_pool", false)), "Etappen 99-100 dürfen innerhalb des 680er-Pools keine Wiederholung zulassen.")

                    if current_stage >= 96:
                        _check(str(stage_rule.get("fallback_mode", "")) == "random_non_legendary", "Unvollständige Legendären-Pools müssen sicher auf einen normalen Superboss zurückfallen.")

    var stage_91_profile: Dictionary = BossRules.boss_profile_for_stage(91)
    _check(int(stage_91_profile.get("level_offset", 0)) == 10, "Etappe 91 muss den echten Superboss-Levelbonus verwenden.")
    _check(is_equal_approx(float(stage_91_profile.get("atb_rate_multiplier", 0.0)), 1.5), "Etappe 91 muss ATB x1.5 verwenden.")
    _check(not bool(stage_91_profile.get("legendary_stage", true)), "Etappe 91 darf nicht als Legendärenstufe aufgelöst werden.")

    var stage_96_profile: Dictionary = BossRules.boss_profile_for_stage(96)
    _check(int(stage_96_profile.get("level_offset", 0)) == 10, "Etappe 96 muss den echten Legendären-Levelbonus verwenden.")
    _check(is_equal_approx(float(stage_96_profile.get("atb_rate_multiplier", 0.0)), 2.0), "Etappe 96 muss ATB x2.0 verwenden.")
    _check(bool(stage_96_profile.get("legendary_stage", false)), "Etappe 96 muss als Legendärenstufe aufgelöst werden.")

    var pool_580: Array[String] = BossRules.legendary_pool_species_ids("bst_580")
    _check(pool_580.size() == 12, "580er-Pool muss die aktuell konfigurierten zwölf Legendären enthalten.")
    for expected_id: String in ["articuno", "zapdos", "moltres", "raikou", "entei", "suicune", "regirock", "regice", "registeel", "latias", "latios", "deoxys"]:
        _check(pool_580.has(expected_id), "580er-Pool fehlt: %s" % expected_id)

    var pool_680: Array[String] = BossRules.legendary_pool_species_ids("bst_680")
    _check(pool_680.size() == 6, "680er-Pool muss die aktuell konfigurierten sechs Legendären enthalten.")
    for expected_id: String in ["mewtwo", "lugia", "ho-oh", "kyogre", "groudon", "rayquaza"]:
        _check(pool_680.has(expected_id), "680er-Pool fehlt: %s" % expected_id)

    _check(BossRules.is_legendary_species("raikou"), "Raikou muss aus normalen Kampf-Pools ausgeschlossen sein.")
    _check(BossRules.is_legendary_species("lugia"), "Lugia muss aus normalen Kampf-Pools ausgeschlossen sein.")
    _check(BossRules.is_legendary_species("rayquaza"), "Rayquaza muss aus normalen Kampf-Pools ausgeschlossen sein.")

    var route = ActiveRouteScript.new()
    _check(route.ENDGAME_ROUTE_STAGE_COUNT == 100, "Aktive Route muss 100 Etappen besitzen.")
    _check(route.ENDGAME_STAGE_START == 91, "Superbosslauf muss auf Etappe 91 beginnen.")
    _check(route.ENDGAME_STAGE_END == 100, "Superbosslauf muss auf Etappe 100 enden.")
    _check(route.ENDGAME_LEGENDARY_STAGE_START == 96, "Legendäre Endgame-Pools müssen auf Etappe 96 beginnen.")
    _check(route.BOSS_GAUNTLET_TEST_START_STAGE == 91, "Bosskampflauf-Test muss direkt bei Etappe 91 starten.")
    _check(route.BOSS_GAUNTLET_TEST_TEAM_LEVEL == 80, "Bosskampflauf-Testteam muss auf Level 80 starten.")
    _check(route.BOSS_GAUNTLET_TEST_TEAM_SIZE == 4, "Bosskampflauf-Testteam muss vier Pokémon besitzen.")

    var test_defaults: Dictionary = route.boss_gauntlet_default_settings()
    _check(int(test_defaults.get("boss_level_offset", 0)) == 10, "Balance-Labor muss den echten Superboss-Levelwert als Standard laden.")
    _check(is_equal_approx(float(test_defaults.get("boss_atb_rate_multiplier", 0.0)), 1.5), "Balance-Labor muss den echten Superboss-ATB-Wert als Standard laden.")
    _check(int(test_defaults.get("legendary_level_offset", 0)) == 10, "Balance-Labor muss den echten Legendären-Levelwert als Standard laden.")
    _check(is_equal_approx(float(test_defaults.get("legendary_atb_rate_multiplier", 0.0)), 2.0), "Balance-Labor muss den echten Legendären-ATB-Wert als Standard laden.")

    route.stage = 91
    route.team = [{"species_id": "bulbasaur", "level": 100, "hp": 1, "max_hp": 1}]
    _check(route._boss_level() == 110, "Ein Teammaximum Lv.100 muss auf Etappe 91 einen Superboss Lv.110 erzeugen.")

    route.team = [{"species_id": "bulbasaur", "level": 103, "hp": 1, "max_hp": 1}]
    _check(route._boss_level() == 113, "Level oberhalb 100 dürfen nicht gekappt werden.")
    _check(route._xp_needed_for_curve("medium_fast", 100) > 0, "Von Lv.100 zu Lv.101 muss weiterhin EP benötigt werden.")
    _check(route._xp_needed_for_curve("medium_fast", 105) > 0, "Auch oberhalb Lv.100 muss die EP-Kurve weiterlaufen.")

    route.stage = 96
    route.team = [{"species_id": "bulbasaur", "level": 80, "hp": 1, "max_hp": 1}]
    _check(route._boss_level() == 90, "Legendäres Endgame-Pokémon muss bei Teammaximum Lv.80 auf Lv.90 liegen.")

    route._boss_gauntlet_balance_settings = route._normalize_boss_gauntlet_settings({
        "boss_level_offset": 15,
        "boss_atb_rate_multiplier": 1.75,
        "legendary_level_offset": 20,
        "legendary_atb_rate_multiplier": 2.25
    })
    route._boss_gauntlet_test_mode = true

    route.stage = 91
    route.team = [{"species_id": "bulbasaur", "level": 80, "hp": 1, "max_hp": 1}]
    _check(route._boss_level() == 95, "Testmodus muss den frei gewählten Superboss-Levelbonus anwenden.")
    var test_stage_91_profile: Dictionary = route._boss_gauntlet_profile_for_stage(91)
    _check(is_equal_approx(float(test_stage_91_profile.get("atb_rate_multiplier", 0.0)), 1.75), "Testmodus muss den frei gewählten Superboss-ATB-Faktor anwenden.")

    route.stage = 96
    _check(route._boss_level() == 100, "Testmodus muss den frei gewählten Legendären-Levelbonus anwenden.")
    var test_stage_96_profile: Dictionary = route._boss_gauntlet_profile_for_stage(96)
    _check(is_equal_approx(float(test_stage_96_profile.get("atb_rate_multiplier", 0.0)), 2.25), "Testmodus muss den frei gewählten Legendären-ATB-Faktor anwenden.")

    route._boss_gauntlet_test_mode = false
    route.stage = 91
    _check(route._boss_level() == 90, "Nach dem Testmodus muss wieder ausschließlich die Produktionsbalance gelten.")

    route.stage = 100
    _check(route._progress_text().contains("Etappe 100 von 100"), "Fortschrittsanzeige muss Etappe 100 von 100 zeigen.")

    var battle = ActiveBattleScript.new()
    _check(battle.PRACTICAL_LEVEL_PICKER_MAX > 100.0, "Kampflabor darf keine Level-100-Obergrenze mehr besitzen.")

    battle.free()
    route.free()

    if failures == 0:
        print("100-stage endgame regression test: PASS")
        quit(0)
    else:
        push_error("100-stage endgame regression test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    failures += 1
    push_error(message)
