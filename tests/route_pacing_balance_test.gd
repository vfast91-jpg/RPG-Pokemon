extends SceneTree

const RouteScript = preload("res://scripts/demo_route_pacing_balance.gd")

const BAND_BASE_LEVELS := {
    11: 15,
    21: 23,
    31: 31,
    41: 39,
    51: 47,
    61: 55,
    71: 63,
    81: 71
}

const BAND_END_BASE_LEVELS := {
    20: 15,
    30: 23,
    40: 31,
    50: 39,
    60: 47,
    70: 55,
    80: 63,
    90: 71
}

var failures: int = 0


func _initialize() -> void:
    var route = RouteScript.new()

    # Normal wins no longer hand out roughly one complete level per stage.
    _check(route._route_stage_xp(1) == 50, "Etappe 1 muss nach dem Pacing-Rebalance 50 Basis-EP geben.")
    _check(route._route_stage_xp(10) == 347, "Etappe 10 muss nach dem Pacing-Rebalance 347 Basis-EP geben.")
    _check(route._route_stage_xp(90) == 14735, "Etappe 90 muss nach dem Pacing-Rebalance 14735 Basis-EP geben.")

    # The Lv.15 plateau shown at stage 11 stays Lv.15. Only the action-economy
    # spread is made slightly firmer so common 3-4 enemy fights are not pushed
    # excessively below the advertised plateau.
    _check(route._enemy_level_for_encounter(11, 1) == 20, "Etappe 11 / 1 Gegner muss Lv.20 sein.")
    _check(route._enemy_level_for_encounter(11, 2) == 17, "Etappe 11 / 2 Gegner müssen Lv.17 sein.")
    _check(route._enemy_level_for_encounter(11, 3) == 15, "Etappe 11 / 3 Gegner müssen Lv.15 sein.")
    _check(route._enemy_level_for_encounter(11, 4) == 13, "Etappe 11 / 4 Gegner müssen Lv.13 sein.")

    # Simulate a Medium-Fast starter that takes only normal stage XP and no
    # optional Training/Direct-Path/Boss bonuses. At every regular ten-stage
    # band entry it must still be below the new plateau; near the end of that
    # same band it must have overtaken the plateau. This is the intended
    # hard -> easier -> next jump sawtooth.
    var level: int = 5
    var xp: int = 0

    for current_stage: int in range(1, 91):
        if BAND_BASE_LEVELS.has(current_stage):
            var entry_base: int = int(BAND_BASE_LEVELS[current_stage])
            _check(
                level < entry_base,
                "Etappe %d: Referenzteam Lv.%d muss unter dem neuen Niveau Lv.%d liegen."
                % [current_stage, level, entry_base]
            )

        if BAND_END_BASE_LEVELS.has(current_stage):
            var end_base: int = int(BAND_END_BASE_LEVELS[current_stage])
            _check(
                level > end_base,
                "Etappe %d: Referenzteam Lv.%d muss das alte Niveau Lv.%d inzwischen überholt haben."
                % [current_stage, level, end_base]
            )

        xp += route._route_stage_xp(current_stage)
        while level < 100:
            var required: int = route._xp_needed_for_curve("medium_fast", level)
            if required <= 0 or xp < required:
                break
            xp -= required
            level += 1

    route.free()

    if failures == 0:
        print("Route pacing balance test: PASS")
        quit(0)
    else:
        push_error("Route pacing balance test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
