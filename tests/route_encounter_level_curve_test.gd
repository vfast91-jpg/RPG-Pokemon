extends SceneTree

const RouteScript = preload("res://scripts/demo_route_team_panel_fit.gd")

const MODIFIERS := {
    1: 5,
    2: 1,
    3: -1,
    4: -3
}
const EARLY_LEVELS := {
    1: {1: 2},
    2: {1: 3, 2: 1},
    3: {1: 5, 2: 3},
    4: {1: 6, 2: 4, 3: 2},
    5: {1: 8, 2: 6, 3: 4}
}
const EARLY_MAX_COUNTS := {
    1: 1,
    2: 2,
    3: 2,
    4: 3,
    5: 3
}

class FakeBattleDemo:
    extends Node

    func route_species_ids_for_level(_level: int) -> Array:
        return ["test_species"]


var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    root.add_child(route)

    # Stages 1-5 are deliberately hand-tuned onboarding encounters.
    for stage: int in range(1, 6):
        var max_count: int = int(EARLY_MAX_COUNTS[stage])
        _check(
            route._max_enemy_count_for_stage(stage) == max_count,
            "Etappe %d darf höchstens %d Gegner haben." % [stage, max_count]
        )

        var stage_levels: Dictionary = EARLY_LEVELS[stage]
        for enemy_count: int in range(1, max_count + 1):
            var expected: int = int(stage_levels[enemy_count])
            var actual: int = route._enemy_level_for_encounter(stage, enemy_count)
            _check(
                actual == expected,
                "Etappe %d mit %d Gegnern: erwartet Lv.%d, erhalten Lv.%d."
                % [stage, enemy_count, expected, actual]
            )

    # From stage 6 onward the revised universal action-economy formula applies.
    for stage: int in range(6, 21):
        _check(route._max_enemy_count_for_stage(stage) == 4, "Ab Etappe 6 müssen bis zu vier Gegner erlaubt sein.")
        for enemy_count: int in range(1, 5):
            var expected: int = maxi(1, stage + int(MODIFIERS[enemy_count]))
            var actual: int = route._enemy_level_for_encounter(stage, enemy_count)
            _check(
                actual == expected,
                "Etappe %d mit %d Gegnern: erwartet Lv.%d, erhalten Lv.%d."
                % [stage, enemy_count, expected, actual]
            )

    # Concrete checks for the agreed onboarding curve and revised later curve.
    _check(route._enemy_level_for_encounter(1, 1) == 2, "Etappe 1 / 1 Gegner muss Lv.2 sein.")
    _check(route._enemy_level_for_encounter(2, 2) == 1, "Etappe 2 / 2 Gegner müssen Lv.1 sein.")
    _check(route._enemy_level_for_encounter(3, 2) == 3, "Etappe 3 / 2 Gegner müssen Lv.3 sein.")
    _check(route._enemy_level_for_encounter(4, 3) == 2, "Etappe 4 / 3 Gegner müssen Lv.2 sein.")
    _check(route._enemy_level_for_encounter(5, 3) == 4, "Etappe 5 / 3 Gegner müssen Lv.4 sein.")
    _check(route._enemy_level_for_encounter(6, 4) == 3, "Etappe 6 / 4 Gegner müssen Lv.3 sein.")
    _check(route._enemy_level_for_encounter(11, 1) == 16, "Etappe 11 / 1 Gegner muss Lv.16 sein.")
    _check(route._enemy_level_for_encounter(11, 2) == 12, "Etappe 11 / 2 Gegner müssen Lv.12 sein.")
    _check(route._enemy_level_for_encounter(11, 3) == 10, "Etappe 11 / 3 Gegner müssen Lv.10 sein.")
    _check(route._enemy_level_for_encounter(11, 4) == 8, "Etappe 11 / 4 Gegner müssen Lv.8 sein.")

    # End-to-end regression through the actual active route inheritance chain.
    # This catches later overrides of _enemy_party_for_stage that accidentally
    # bypass either the onboarding table or the encounter-size modifier.
    var fake_battle := FakeBattleDemo.new()
    root.add_child(fake_battle)
    route.battle_demo = fake_battle

    for stage: int in [1, 2, 3, 4, 5, 6, 10, 11, 20]:
        for _sample: int in range(32):
            var party: Array = route._enemy_party_for_stage(stage)
            var enemy_count: int = party.size()
            var max_count: int = route._max_enemy_count_for_stage(stage)
            _check(
                enemy_count >= 1 and enemy_count <= max_count,
                "Etappe %d erzeugt eine ungültige Gegnerzahl: %d (Maximum %d)."
                % [stage, enemy_count, max_count]
            )
            if enemy_count < 1 or enemy_count > max_count:
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


func _expected_level(stage: int, enemy_count: int) -> int:
    if EARLY_LEVELS.has(stage):
        var stage_levels: Dictionary = EARLY_LEVELS[stage]
        if stage_levels.has(enemy_count):
            return int(stage_levels[enemy_count])
    return maxi(1, stage + int(MODIFIERS[enemy_count]))


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
