extends SceneTree

const RouteScript = preload("res://scripts/demo_route_boss_reinforcement_v1.gd")
const BossRules = preload("res://scripts/route_boss_rules.gd")

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    route.team = [
        {"species_id": "bulbasaur", "level": 12, "hp": 30, "max_hp": 30},
        {"species_id": "rattata", "level": 9, "hp": 24, "max_hp": 24}
    ]

    var reinforcement: Dictionary = BossRules.standard_reinforcement_profile()
    _check(bool(reinforcement.get("enabled", false)), "Standard-Bossverstaerkung muss aktiviert sein.")
    _check(int(reinforcement.get("count", 0)) == 2, "Standard-Boss muss genau zwei Verstaerkungen rufen.")
    _check(str(reinforcement.get("species_mode", "")) == "same_as_boss", "Verstaerkung muss exakt dieselbe Spezies wie der Boss behalten.")
    _check(str(reinforcement.get("level_mode", "")) == "player_max", "Verstaerkungs-BASISlevel muss exakt dem hoechsten eigenen Pokemon entsprechen.")
    _check(not reinforcement.has("level_offset"), "Die Bossregel selbst darf keinen zusaetzlichen Verstaerkungs-Level-Offset besitzen.")
    _check(BossRules.reinforcement_level_for_player_max(12) == 12, "Teammaximum Lv.12 muss ein Verstaerkungs-BASISlevel von Lv.12 ergeben.")
    _check(BossRules.reinforcement_level_for_player_max(1) == 1, "Teammaximum Lv.1 muss ein Verstaerkungs-BASISlevel von Lv.1 ergeben.")
    _check(is_equal_approx(float(reinforcement.get("hp_multiplier", 0.0)), 1.0), "Verstaerkung darf keinen Boss-KP-Multiplikator erhalten.")
    _check(is_equal_approx(float(reinforcement.get("start_atb_percent", -1.0)), 0.0), "Verstaerkung muss mit 0 Prozent ATB starten.")

    route.stage = 12
    var standard_party: Array = [{
        "species_id": "charmeleon",
        "level": 17,
        "boss": true,
        "hp_multiplier": 2.0,
        "hp_bars": 2
    }]
    var decorated: Array = route._decorate_standard_boss_reinforcement_contract(standard_party)
    _check(decorated.size() == 1, "Standard-Bossparty muss ein einzelner Boss bleiben.")
    var boss: Dictionary = decorated[0] as Dictionary
    _check(bool(boss.get("boss_reinforcement_enabled", false)), "Standard-Boss muss Verstaerkungsvertrag erhalten.")
    _check(int(boss.get("boss_reinforcement_count", 0)) == 2, "Bossvertrag muss zwei Verstaerkungen anfordern.")
    _check(str(boss.get("boss_reinforcement_species_id", "")) == "charmeleon", "Glutexo-Verstaerkung darf nicht zu Glumanda rueckentwickelt werden.")
    _check(int(boss.get("boss_reinforcement_level", 0)) == 12, "Bei Teammaximum Lv.12 muessen Verstaerkungen vor Schwierigkeitsskalierung Lv.12 sein.")
    _check(str(boss.get("boss_reinforcement_level_mode", "")) == "player_max", "Bossvertrag muss den Spieler-Maxlevel-Modus dokumentieren.")
    _check(not boss.has("boss_reinforcement_level_offset"), "Bossvertrag darf keinen veralteten internen Verstaerkungs-Level-Offset enthalten.")
    _check(is_equal_approx(float(boss.get("boss_reinforcement_hp_multiplier", 0.0)), 1.0), "Verstaerkungen muessen normale KP besitzen.")
    _check(is_equal_approx(float(boss.get("boss_reinforcement_start_atb", -1.0)), 0.0), "Verstaerkungen muessen mit leerer ATB-Leiste erscheinen.")
    _check(int(boss.get("level", 0)) == 17, "Bosslevel selbst darf durch den Verstaerkungsvertrag nicht veraendert werden.")

    # Die globale Routenschwierigkeit gilt fuer ALLE Gegner: Boss und spaeter
    # erscheinende Verstaerkungen erhalten denselben Level-Offset. Separate
    # Marker muessen verhindern, dass ein gespeicherter Kampf doppelt skaliert.
    route.set_route_difficulty("hard", 4)
    var difficulty_result: Array = route._apply_route_difficulty(decorated)
    var difficulty_boss: Dictionary = difficulty_result[0] as Dictionary
    _check(int(difficulty_boss.get("level", 0)) == 21, "Globale Schwierigkeit +4 muss den Boss von Lv.17 auf Lv.21 anheben.")
    _check(int(difficulty_boss.get("boss_reinforcement_level", 0)) == 16, "Globale Schwierigkeit +4 muss Verstaerkungen vom Basislevel Lv.12 auf Lv.16 anheben.")

    var difficulty_second_pass: Array = route._apply_route_difficulty(difficulty_result)
    var difficulty_boss_second_pass: Dictionary = difficulty_second_pass[0] as Dictionary
    _check(int(difficulty_boss_second_pass.get("level", 0)) == 21, "Boss-Schwierigkeit darf bei erneutem Anwenden nicht doppelt addiert werden.")
    _check(int(difficulty_boss_second_pass.get("boss_reinforcement_level", 0)) == 16, "Verstaerkungs-Schwierigkeit darf bei erneutem Anwenden nicht doppelt addiert werden.")

    route.stage = 10
    var too_early: Array = route._decorate_standard_boss_reinforcement_contract(standard_party)
    _check(not bool((too_early[0] as Dictionary).get("boss_reinforcement_enabled", false)), "Vor Etappe 11 darf kein Standard-Verstaerkungsboss entstehen.")

    route.stage = 20
    var milestone_like: Array = route._decorate_standard_boss_reinforcement_contract(standard_party)
    _check(not bool((milestone_like[0] as Dictionary).get("boss_reinforcement_enabled", false)), "Etappe 20 darf keinen normalen Verstaerkungsboss erzeugen.")

    route.stage = 91
    var endgame_like: Array = route._decorate_standard_boss_reinforcement_contract(standard_party)
    _check(not bool((endgame_like[0] as Dictionary).get("boss_reinforcement_enabled", false)), "Endgame-Superboss ab Etappe 91 darf keine Standardverstaerkung erhalten.")

    route.stage = 25
    var double_party: Array = [standard_party[0].duplicate(true), standard_party[0].duplicate(true)]
    var double_result: Array = route._decorate_standard_boss_reinforcement_contract(double_party)
    _check(not bool((double_result[0] as Dictionary).get("boss_reinforcement_enabled", false)), "Mehrere gleichzeitige Bosse duerfen nicht als Standard-Bossphase dekoriert werden.")

    route.free()

    if failures == 0:
        print("Route boss reinforcement test: PASS")
        quit(0)
    else:
        push_error("Route boss reinforcement test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
