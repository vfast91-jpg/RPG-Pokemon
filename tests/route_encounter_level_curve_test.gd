extends SceneTree

const RouteScript = preload("res://scripts/demo_route_team_panel_fit.gd")

const MODIFIERS := {
    1: 5,
    2: 1,
    3: -1,
    4: -3
}
const ONBOARDING_ENCOUNTERS := {
    1: {"count": 1, "level": 2},
    2: {"count": 1, "level": 3},
    3: {"count": 2, "level": 3},
    4: {"count": 2, "level": 4},
    5: {"count": 3, "level": 4}
}
const BASE_LEVEL_CHECKS: Array = [
    [1, 3], [5, 3],
    [6, 7], [10, 7],
    [11, 15], [20, 15],
    [21, 23], [30, 23],
    [31, 31], [40, 31],
    [41, 39], [50, 39],
    [51, 47], [60, 47],
    [61, 55], [70, 55],
    [71, 63], [80, 63],
    [81, 71], [90, 71]
]

class FakeBattleDemo:
    extends Node

    func route_species_ids_for_level(_level: int) -> Array:
        return ["test_species"]


var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    root.add_child(route)

    # The same plateau table is the single source of truth for neutral enemy
    # level and capture level.
    for check_value: Variant in BASE_LEVEL_CHECKS:
        var check: Array = check_value
        var stage: int = int(check[0])
        var expected_base: int = int(check[1])
        _check(
            route._route_base_level_for_stage(stage) == expected_base,
            "Etappe %d: Basisniveau muss Lv.%d sein." % [stage, expected_base]
        )
        _check(
            route._capture_level_for_stage(stage) == expected_base,
            "Etappe %d: Fangniveau muss Lv.%d sein." % [stage, expected_base]
        )
        _check(
            route._enemy_level_for_stage(stage) == expected_base,
            "Etappe %d: neutrales Gegnerniveau muss Lv.%d sein." % [stage, expected_base]
        )

    # Stages 1-5 are a fixed, deliberately gentle onboarding sequence. They do
    # not receive any positive action-economy correction.
    for stage: int in range(1, 6):
        var expected: Dictionary = ONBOARDING_ENCOUNTERS[stage]
        var expected_count: int = int(expected["count"])
        var expected_level: int = int(expected["level"])
        _check(
            route._roll_enemy_count(stage) == expected_count,
            "Etappe %d muss fest %d Gegner erzeugen." % [stage, expected_count]
        )
        _check(
            route._enemy_level_for_encounter(stage, expected_count) == expected_level,
            "Etappe %d: Gegner müssen fest Lv.%d sein." % [stage, expected_level]
        )

    # From stage 6 onward the established action-economy modifiers apply to the
    # plateau baseline instead of directly to the stage number.
    for stage: int in range(6, 91):
        _check(route._max_enemy_count_for_stage(stage) == 4, "Ab Etappe 6 müssen bis zu vier Gegner erlaubt sein.")
        var base_level: int = _expected_base_level(stage)
        for enemy_count: int in range(1, 5):
            var expected: int = maxi(1, base_level + int(MODIFIERS[enemy_count]))
            var actual: int = route._enemy_level_for_encounter(stage, enemy_count)
            _check(
                actual == expected,
                "Etappe %d mit %d Gegnern: erwartet Lv.%d, erhalten Lv.%d."
                % [stage, enemy_count, expected, actual]
            )

    # Concrete onboarding and plateau-boundary checks.
    _check(route._enemy_level_for_encounter(1, 1) == 2, "Etappe 1 / 1 Gegner muss Lv.2 sein.")
    _check(route._enemy_level_for_encounter(2, 1) == 3, "Etappe 2 / 1 Gegner muss Lv.3 sein.")
    _check(route._enemy_level_for_encounter(3, 2) == 3, "Etappe 3 / 2 Gegner müssen Lv.3 sein.")
    _check(route._enemy_level_for_encounter(4, 2) == 4, "Etappe 4 / 2 Gegner müssen Lv.4 sein.")
    _check(route._enemy_level_for_encounter(5, 3) == 4, "Etappe 5 / 3 Gegner müssen Lv.4 sein.")
    _check(route._enemy_level_for_encounter(6, 4) == 4, "Etappe 6 / 4 Gegner müssen Lv.4 sein.")
    _check(route._enemy_level_for_encounter(10, 1) == 12, "Etappe 10 / 1 Gegner muss Lv.12 sein.")
    _check(route._enemy_level_for_encounter(11, 1) == 20, "Etappe 11 / 1 Gegner muss Lv.20 sein.")
    _check(route._enemy_level_for_encounter(11, 2) == 16, "Etappe 11 / 2 Gegner müssen Lv.16 sein.")
    _check(route._enemy_level_for_encounter(11, 3) == 14, "Etappe 11 / 3 Gegner müssen Lv.14 sein.")
    _check(route._enemy_level_for_encounter(11, 4) == 12, "Etappe 11 / 4 Gegner müssen Lv.12 sein.")
    _check(route._enemy_level_for_encounter(30, 1) == 28, "Etappe 30 / 1 Gegner muss Lv.28 sein.")
    _check(route._enemy_level_for_encounter(31, 1) == 36, "Etappe 31 / 1 Gegner muss Lv.36 sein.")
    _check(route._enemy_level_for_encounter(90, 4) == 68, "Etappe 90 / 4 Gegner müssen Lv.68 sein.")

    # End-to-end regression through the active encounter inheritance layer.
    var fake_battle := FakeBattleDemo.new()
    root.add_child(fake_battle)
    route.battle_demo = fake_battle

    for stage: int in [1, 2, 3, 4, 5, 6, 10, 11, 20, 21, 30, 31, 40, 41, 50, 51, 60, 61, 70, 71, 80, 81, 90]:
        for _sample: int in range(32):
            var party: Array = route._enemy_party_for_stage(stage)
            var enemy_count: int = party.size()

            if stage <= 5:
                var onboarding: Dictionary = ONBOARDING_ENCOUNTERS[stage]
                var fixed_count: int = int(onboarding["count"])
                _check(
                    enemy_count == fixed_count,
                    "Etappe %d muss genau %d Gegner erzeugen, erzeugt aber %d."
                    % [stage, fixed_count, enemy_count]
                )
            else:
                _check(
                    enemy_count >= 1 and enemy_count <= 4,
                    "Etappe %d erzeugt eine ungültige Gegnerzahl: %d."
                    % [stage, enemy_count]
                )

            if enemy_count < 1:
                continue

            var expected_level: int = _expected_level(stage, enemy_count)
            for entry_value: Variant in party:
                _check(entry_value is Dictionary, "Etappe %d erzeugt einen ungültigen Gegner-Eintrag." % stage)
                if not (entry_value is Dictionary):
                    continue
                var entry: Dictionary = entry_value
                _check(
                    int(entry.get("level", -1)) == expected_level,
                    "Etappe %d mit %d Gegnern erzeugt Lv.%d statt Lv.%d."
                    % [stage, enemy_count, int(entry.get("level", -1)), expected_level]
                )

    fake_battle.queue_free()
    route.queue_free()

    if failures == 0:
        print("Route encounter level curve test: PASS")
        quit(0)
    else:
        push_error("Route encounter level curve test: %d Fehler" % failures)
        quit(1)


func _expected_base_level(stage: int) -> int:
    if stage <= 5:
        return 3
    if stage <= 10:
        return 7
    if stage <= 20:
        return 15
    if stage <= 30:
        return 23
    if stage <= 40:
        return 31
    if stage <= 50:
        return 39
    if stage <= 60:
        return 47
    if stage <= 70:
        return 55
    if stage <= 80:
        return 63
    return 71


func _expected_level(stage: int, enemy_count: int) -> int:
    if stage <= 5:
        var onboarding: Dictionary = ONBOARDING_ENCOUNTERS[stage]
        return int(onboarding["level"])
    var base_level: int = _expected_base_level(stage)
    return maxi(1, base_level + int(MODIFIERS[enemy_count]))


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
