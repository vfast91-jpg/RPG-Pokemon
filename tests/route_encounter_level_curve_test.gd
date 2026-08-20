extends SceneTree

const RouteScript = preload("res://scripts/demo_route_team_panel_fit.gd")

const MODIFIERS := {
    1: 5,
    2: 2,
    3: 0,
    4: -2
}

class FakeBattleDemo:
    extends Node

    func route_species_ids_for_level(_level: int) -> Array:
        return ["test_species"]


var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    root.add_child(route)

    for stage: int in range(1, 21):
        for enemy_count: int in range(1, 5):
            var expected: int = maxi(1, stage + int(MODIFIERS[enemy_count]))
            var actual: int = route._enemy_level_for_encounter(stage, enemy_count)
            _check(
                actual == expected,
                "Etappe %d mit %d Gegnern: erwartet Lv.%d, erhalten Lv.%d."
                % [stage, enemy_count, expected, actual]
            )

    # Concrete regression around the jump that exposed the old balancing flaw.
    _check(route._enemy_level_for_encounter(10, 1) == 15, "Etappe 10 / 1 Gegner muss Lv.15 sein.")
    _check(route._enemy_level_for_encounter(10, 4) == 8, "Etappe 10 / 4 Gegner müssen Lv.8 sein.")
    _check(route._enemy_level_for_encounter(11, 1) == 16, "Etappe 11 / 1 Gegner muss Lv.16 sein.")
    _check(route._enemy_level_for_encounter(11, 4) == 9, "Etappe 11 / 4 Gegner müssen Lv.9 sein.")

    # End-to-end regression through the actual active route inheritance chain.
    # This catches later overrides of _enemy_party_for_stage that accidentally
    # bypass the encounter-size modifier (the bug seen as 3x Lv.4 on stage 5).
    var fake_battle := FakeBattleDemo.new()
    root.add_child(fake_battle)
    route.battle_demo = fake_battle

    for stage: int in [5, 10, 11, 20]:
        for _sample: int in range(24):
            var party: Array = route._enemy_party_for_stage(stage)
            var enemy_count: int = party.size()
            _check(
                enemy_count >= 1 and enemy_count <= 4,
                "Etappe %d erzeugt eine ungültige Gegnerzahl: %d." % [stage, enemy_count]
            )
            if enemy_count < 1 or enemy_count > 4:
                continue

            var expected_level: int = maxi(1, stage + int(MODIFIERS[enemy_count]))
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


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
