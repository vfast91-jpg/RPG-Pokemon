extends "res://scripts/demo_route_user_polish.gd"

# Dynamic route encounter level scaling.
#
# Stages 1-5 remain the protected, hand-tuned onboarding sequence. From stage 6
# onward the highest level in the player's CURRENT team is the neutral
# reference. Enemy group size then compensates for action economy:
# 1 enemy +5, 2 enemies +2, 3 enemies +/-0, 4 enemies -2.
#
# Capture levels deliberately remain on the legacy table in this isolated phase
# so Phase C changes only opponent scaling and its player-facing notice. The
# Fangwiese gets its own highest-team-level -3 rule in Phase E.

const ENCOUNTER_LEVEL_MODIFIERS := {
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
    5: {"count": 3, "level": 4}
}

var _dynamic_scaling_notice_shown: bool = false


func start_route() -> void:
    _dynamic_scaling_notice_shown = false
    super.start_route()


func _highest_team_level() -> int:
    var highest: int = 1
    for member_value: Variant in team:
        if not (member_value is Dictionary):
            continue
        highest = maxi(highest, int((member_value as Dictionary).get("level", 1)))
    return clampi(highest, 1, 100)


func _route_base_level_for_stage(current_stage: int) -> int:
    if current_stage <= 5:
        return 3
    return _highest_team_level()


func _legacy_capture_level_for_stage(current_stage: int) -> int:
    var clamped_stage: int = clampi(current_stage, 1, 90)
    if clamped_stage <= 5:
        return 3
    if clamped_stage <= 10:
        return 7
    if clamped_stage <= 20:
        return 15
    if clamped_stage <= 30:
        return 23
    if clamped_stage <= 40:
        return 31
    if clamped_stage <= 50:
        return 39
    if clamped_stage <= 60:
        return 47
    if clamped_stage <= 70:
        return 55
    if clamped_stage <= 80:
        return 63
    return 71


func _capture_level_for_stage(current_stage: int) -> int:
    return _legacy_capture_level_for_stage(current_stage)


func _enemy_level_for_stage(current_stage: int) -> int:
    return _route_base_level_for_stage(current_stage)


func _roll_enemy_count(current_stage: int) -> int:
    var onboarding_value: Variant = ONBOARDING_ENCOUNTERS.get(current_stage, {})
    if onboarding_value is Dictionary and not (onboarding_value as Dictionary).is_empty():
        return int((onboarding_value as Dictionary).get("count", 1))
    return super._roll_enemy_count(current_stage)


func _enemy_level_for_encounter(current_stage: int, enemy_count: int) -> int:
    var onboarding_value: Variant = ONBOARDING_ENCOUNTERS.get(current_stage, {})
    if onboarding_value is Dictionary and not (onboarding_value as Dictionary).is_empty():
        return clampi(int((onboarding_value as Dictionary).get("level", 1)), 1, 100)

    var reference_level: int = _highest_team_level()
    var clamped_count: int = clampi(enemy_count, 1, 4)
    return clampi(
        reference_level + int(ENCOUNTER_LEVEL_MODIFIERS[clamped_count]),
        1,
        100
    )


func _show_stage_choices(message: String = "") -> void:
    if stage == 6 and not _dynamic_scaling_notice_shown:
        var level_notice: String = _route_level_notice_for_stage(stage)
        if not level_notice.is_empty():
            if message.is_empty():
                message = level_notice
            else:
                message = level_notice + "\n\n" + message
        _dynamic_scaling_notice_shown = true
    super._show_stage_choices(message)


func _route_level_notice_for_stage(current_stage: int) -> String:
    if current_stage != 6:
        return ""

    return (
        "[b]⚖ Dynamisches Gegnerniveau[/b]\n"
        + "Ab jetzt richtet sich das Levelniveau der Gegner nach deinem "
        + "[b]höchstleveligen Pokémon[/b]. Kleine Gegnergruppen liegen darüber, "
        + "große Gruppen etwas darunter."
    )
