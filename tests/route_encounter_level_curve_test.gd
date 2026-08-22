extends SceneTree

const RouteScript = preload("res://scripts/demo_route_team_panel_fit.gd")

const MODIFIERS := {
    1: 5,
    2: 2,
    3: 0,
    4: -2
}
const ONBOARDING_ENCOUNTERS := {
    1: {"count": 1, "level": 2},
    2: {"count": 1, "level": 3},
    3: {"count": 2, "level": 3},
    4: {"count": 2, "level": 4},
    5: {"count": 3, "level": 4},
    6: {"count": 2, "level": 5},
    7: {"count": 2, "level": 6},
    8: {"count": 3, "level": 6},
    9: {"count": 3, "level": 7},
    10: {"count": 3, "level": 8}
}

class FakeBattleDemo:
    extends Node

    func route_species_ids() -> Array:
        return ["test_species"]

    func route_species_ids_for_level(_level: int) -> Array:
        return ["test_species"]


var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()
    root.add_child(route)

    route.team = [
        {"species_id": "a", "level": 18, "hp": 20, "max_hp": 20},
        {"species_id": "b", "level": 15, "hp": 20, "max_hp": 20},
        {"species_id": "c", "level": 14, "hp": 0, "max_hp": 20}
    ]

    # Stages 1-10 are the exact protected onboarding sequence and do not use
    # dynamic team scaling. Four-enemy groups are deliberately impossible here.
    for stage: int in range(1, 11):
        var expected: Dictionary = ONBOARDING_ENCOUNTERS[stage]
        var expected_count: int = int(expected["count"])
        var expected_level: int = int(expected["level"])
        _check(
            route._roll_enemy_count(stage) == expected_count,
            "Etappe %d muss fest %d Gegner erzeugen." % [stage, expected_count]
        )
        _check(
            expected_count <= 3,
            "Etappe %d darf im geschützten Einstieg keine Vierergruppe erzeugen." % stage
        )
        _check(
            route._route_base_level_for_stage(stage) == expected_level,
            "Etappe %d muss als festes Basisniveau Lv.%d verwenden." % [stage, expected_level]
        )
        _check(
            route._enemy_level_for_encounter(stage, expected_count) == expected_level,
            "Etappe %d: Gegner müssen fest Lv.%d sein." % [stage, expected_level]
        )

    # From stage 11 onward stage number no longer controls opponent level. The
    # highest level in the complete current team is the neutral reference.
    _check(route._highest_team_level() == 18, "Höchstes Teamlevel muss Lv.18 sein.")
    for stage: int in [11, 21, 50, 90]:
        _check(
            route._route_base_level_for_stage(stage) == 18,
            "Etappe %d muss das höchste Teamlevel Lv.18 als Referenz verwenden." % stage
        )
        _check(
            route._enemy_level_for_stage(stage) == 18,
            "Etappe %d: neutrales Gegnerniveau muss Lv.18 sein." % stage
        )
        for enemy_count: int in range(1, 5):
            var expected_level: int = 18 + int(MODIFIERS[enemy_count])
            var actual_level: int = route._enemy_level_for_encounter(stage, enemy_count)
            _check(
                actual_level == expected_level,
                "Etappe %d mit %d Gegnern: erwartet Lv.%d, erhalten Lv.%d."
                % [stage, enemy_count, expected_level, actual_level]
            )

    # Concrete action-economy reference example agreed for a Lv.18 team leader.
    _check(route._enemy_level_for_encounter(11, 1) == 23, "1 Gegner bei Referenz Lv.18 muss Lv.23 sein.")
    _check(route._enemy_level_for_encounter(11, 2) == 20, "2 Gegner bei Referenz Lv.18 müssen Lv.20 sein.")
    _check(route._enemy_level_for_encounter(11, 3) == 18, "3 Gegner bei Referenz Lv.18 müssen Lv.18 sein.")
    _check(route._enemy_level_for_encounter(11, 4) == 16, "4 Gegner bei Referenz Lv.18 müssen Lv.16 sein.")

    # The highest TEAM member counts even when currently fainted. Scaling is a
    # team-building rule, not a living-party exploit.
    route.team.append({"species_id": "d", "level": 22, "hp": 0, "max_hp": 20})
    _check(route._highest_team_level() == 22, "Ein kampfunfähiges Lv.22-Teammitglied muss das Gegnerniveau weiterhin bestimmen.")
    _check(route._enemy_level_for_encounter(40, 3) == 22, "3 Gegner müssen sich am vollständigen Teammaximum Lv.22 orientieren.")

    # Levels are always clamped to the canonical 1..100 range.
    route.team = [{"species_id": "cap", "level": 100, "hp": 1, "max_hp": 1}]
    _check(route._enemy_level_for_encounter(90, 1) == 100, "Gegnerlevel darf Lv.100 nicht überschreiten.")
    _check(route._enemy_level_for_encounter(90, 4) == 98, "Vier Gegner bei Referenz Lv.100 müssen Lv.98 sein.")

    route.team = [{"species_id": "low", "level": 1, "hp": 1, "max_hp": 1}]
    _check(route._enemy_level_for_encounter(11, 4) == 1, "Gegnerlevel darf Lv.1 nicht unterschreiten.")

    # This layer still exposes its legacy capture table; the active Fangwiese
    # layer overrides it with the dedicated highest-team-level -3 rule.
    _check(route._capture_level_for_stage(6) == 7, "Legacy-Fanglevel auf Etappe 6 wurde unerwartet verändert.")
    _check(route._capture_level_for_stage(11) == 15, "Legacy-Fanglevel auf Etappe 11 wurde unerwartet verändert.")

    # The old level-band notices are gone. Only stage 11 explains the transition
    # from protected onboarding to dynamic opponent scaling.
    var stage11_notice: String = route._route_level_notice_for_stage(11)
    _check(not stage11_notice.is_empty(), "Etappe 11 braucht den Hinweis zum dynamischen Gegnerniveau.")
    _check(stage11_notice.contains("höchstleveligen Pokémon"), "Etappe-11-Hinweis muss die höchste eigene Pokémon-Stufe erklären.")
    for stage: int in [1, 5, 6, 7, 10, 12, 21, 31, 41, 51, 61, 71, 81, 90]:
        _check(
            route._route_level_notice_for_stage(stage).is_empty(),
            "Etappe %d darf keinen Levelniveau-Hinweis zeigen." % stage
        )

    # End-to-end through the active encounter-party generator: stages 1-10 use
    # their fixed curve; stage 11+ uses the dynamic level associated with group size.
    route.team = [
        {"species_id": "a", "level": 18, "hp": 20, "max_hp": 20},
        {"species_id": "b", "level": 15, "hp": 20, "max_hp": 20}
    ]
    var fake_battle := FakeBattleDemo.new()
    root.add_child(fake_battle)
    route.battle_demo = fake_battle

    for stage: int in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 30, 60, 90]:
        for _sample: int in range(32):
            var party: Array = route._enemy_party_for_stage(stage)
            var enemy_count: int = party.size()

            if stage <= 10:
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

            var expected_level: int = _expected_level(stage, enemy_count, 18)
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


func _expected_level(stage: int, enemy_count: int, reference_level: int) -> int:
    if stage <= 10:
        var onboarding: Dictionary = ONBOARDING_ENCOUNTERS[stage]
        return int(onboarding["level"])
    return clampi(reference_level + int(MODIFIERS[enemy_count]), 1, 100)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
