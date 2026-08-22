extends SceneTree

const ActiveRouteScript = preload("res://scripts/demo_route_endgame_v1.gd")
const ActiveBattleScript = preload("res://scripts/battle_demo_endgame_v2.gd")
const RULES_PATH: String = "res://data/route_boss_rules_v1.json"

var failures: int = 0


func _initialize() -> void:
    var main_text: String = FileAccess.get_file_as_string("res://main.tscn")
    _check(main_text.contains("res://scripts/demo_route_endgame_v1.gd"), "main.tscn muss die 100-Etappen-Route aktivieren.")
    _check(main_text.contains("res://scripts/battle_demo_endgame_v2.gd"), "main.tscn muss den unlimitierten Endgame-Kampflayer aktivieren.")

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

            var profile: Dictionary = endgame.get("boss_profile", {})
            _check(int(profile.get("level_offset", 0)) == 5, "Superboss muss +5 Level besitzen.")
            _check(is_equal_approx(float(profile.get("hp_multiplier", 0.0)), 4.0), "Superboss muss 4x KP besitzen.")
            _check(int(profile.get("hp_bars", 0)) == 4, "Superboss muss vier KP-Leisten besitzen.")

            var stages_value: Variant = endgame.get("stages", [])
            _check(stages_value is Array and (stages_value as Array).size() == 10, "Endgame braucht exakt zehn Boss-Etappen.")
            if stages_value is Array:
                for stage_value: Variant in stages_value:
                    if not (stage_value is Dictionary):
                        _fail("Ungültiger Stage-Eintrag in planned_endgame.")
                        continue
                    var stage_rule: Dictionary = stage_value as Dictionary
                    _check(
                        str(stage_rule.get("species_mode", "")) == "random_non_legendary",
                        "Alle aktuellen Superbosse 91-100 müssen vorerst zufällig und nicht-legendär sein."
                    )

    var route = ActiveRouteScript.new()
    _check(route.ROUTE_STAGE_COUNT == 100, "Aktive Route muss 100 Etappen besitzen.")
    _check(route.ENDGAME_STAGE_START == 91, "Superbosslauf muss auf Etappe 91 beginnen.")
    _check(route.ENDGAME_STAGE_END == 100, "Superbosslauf muss auf Etappe 100 enden.")

    route.stage = 91
    route.team = [{"species_id": "bulbasaur", "level": 100, "hp": 1, "max_hp": 1}]
    _check(route._boss_level() == 105, "Ein Teammaximum Lv.100 muss einen Superboss Lv.105 erzeugen.")

    route.team = [{"species_id": "bulbasaur", "level": 103, "hp": 1, "max_hp": 1}]
    _check(route._boss_level() == 108, "Level oberhalb 100 dürfen nicht gekappt werden.")
    _check(route._xp_needed_for_curve("medium_fast", 100) > 0, "Von Lv.100 zu Lv.101 muss weiterhin EP benötigt werden.")
    _check(route._xp_needed_for_curve("medium_fast", 105) > 0, "Auch oberhalb Lv.100 muss die EP-Kurve weiterlaufen.")

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
