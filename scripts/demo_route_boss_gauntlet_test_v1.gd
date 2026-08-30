extends "res://scripts/demo_route_rest_pack_v1.gd"

# Fast balancing entry for the real stage-91..100 endgame.
# The test mode deliberately reuses the production route/endgame methods and
# route_boss_rules.gd. It only supplies a fresh random Lv.80 team and starts at
# stage 91. No balancing values are duplicated here.

const BossGauntletRules = preload("res://scripts/route_boss_rules.gd")
const BOSS_GAUNTLET_TEST_START_STAGE: int = 91
const BOSS_GAUNTLET_TEST_TEAM_LEVEL: int = 80
const BOSS_GAUNTLET_TEST_TEAM_SIZE: int = 4

var _boss_gauntlet_test_mode: bool = false


func start_route() -> void:
    # A normal adventure must always use the normal persistence path.
    _boss_gauntlet_test_mode = false
    super.start_route()


func start_boss_gauntlet_test() -> void:
    if battle_demo == null:
        push_error("Bosskampflauf: BattleDemo fehlt.")
        return

    _boss_gauntlet_test_mode = true
    stage = BOSS_GAUNTLET_TEST_START_STAGE
    stage_xp_multiplier = 1.0
    last_route_message = ""
    pending_capture.clear()
    _endgame_pool_picks.clear()
    rest_pack_count = 0
    rest_pack_claimed_stages.clear()
    _reset_rest_pack_reward_popup_state()

    if has_method("_reset_boss_reward_state"):
        call("_reset_boss_reward_state")
    if has_method("_reset_fundstelle_state"):
        call("_reset_fundstelle_state")

    var available: Array = battle_demo.route_species_ids_for_level(BOSS_GAUNTLET_TEST_TEAM_LEVEL)
    var candidates: Array = _standard_combat_candidates(available)
    if candidates.size() < BOSS_GAUNTLET_TEST_TEAM_SIZE:
        push_error("Bosskampflauf: Nicht genug spielbare Pokémon für ein zufälliges Viererteam verfügbar.")
        _boss_gauntlet_test_mode = false
        return

    candidates.shuffle()
    team.clear()
    for index: int in range(BOSS_GAUNTLET_TEST_TEAM_SIZE):
        var species_id: String = str(candidates[index])
        var member: Dictionary = battle_demo.route_new_member(
            species_id,
            BOSS_GAUNTLET_TEST_TEAM_LEVEL
        )
        member["level"] = BOSS_GAUNTLET_TEST_TEAM_LEVEL
        member["hp"] = int(member.get("max_hp", member.get("hp", 1)))
        team.append(member)

    visible = true
    _show_stage_choices(
        "[b]Bosskampflauf-Test[/b]\n"
        + "Zufälliges Viererteam auf Level %d · direkter Einstieg bei Etappe %d.\n"
        + "Level- und ATB-Boni stammen exakt aus den Regeln des echten Spiels."
        % [BOSS_GAUNTLET_TEST_TEAM_LEVEL, BOSS_GAUNTLET_TEST_START_STAGE]
    )


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    var prepared_party: Array = enemy_party.duplicate(true)
    if stage >= ENDGAME_STAGE_START and stage <= ENDGAME_STAGE_END:
        var profile: Dictionary = BossGauntletRules.boss_profile_for_stage(stage)
        var atb_multiplier: float = maxf(
            0.0,
            float(profile.get("atb_rate_multiplier", 1.0))
        )
        for enemy_value: Variant in prepared_party:
            if not (enemy_value is Dictionary):
                continue
            var enemy: Dictionary = enemy_value as Dictionary
            if bool(enemy.get("boss", false)):
                enemy["atb_rate_multiplier"] = atb_multiplier

    super._start_special_battle(kind, prepared_party, heading)


func _commit_canonical_stage_start(show_feedback: bool = true) -> bool:
    # The laboratory must never overwrite the player's real adventure slot.
    if _boss_gauntlet_test_mode:
        return true
    return super._commit_canonical_stage_start(show_feedback)


func _finish_run(victory: bool, message: String) -> void:
    if not _boss_gauntlet_test_mode:
        super._finish_run(victory, message)
        return

    # Do not call the normal persistence/leaderboard finish path: that path
    # intentionally clears the active adventure save. The lab is isolated.
    visible = true
    last_route_message = message
    _clear_container(path_box)
    _clear_container(capture_actions)
    path_box.visible = true
    continue_button.visible = false
    restart_button.visible = false
    event_label.text = message

    var result_label := Label.new()
    result_label.text = "✅ TESTLAUF BEENDET" if victory else "❌ TESTLAUF BEENDET"
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.add_theme_font_size_override("font_size", 16)
    path_box.add_child(result_label)

    var restart_test := Button.new()
    restart_test.text = "BOSSKAMPFLAUF NEU STARTEN"
    restart_test.custom_minimum_size = Vector2(330, 42)
    restart_test.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    restart_test.pressed.connect(start_boss_gauntlet_test)
    path_box.add_child(restart_test)

    var menu_button := Button.new()
    menu_button.text = "ZUM HAUPTMENÜ"
    menu_button.custom_minimum_size = Vector2(330, 38)
    menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    menu_button.pressed.connect(_leave_boss_gauntlet_test)
    path_box.add_child(menu_button)

    _refresh_team_panel()


func _leave_boss_gauntlet_test() -> void:
    _boss_gauntlet_test_mode = false
    _leave_run_to_main_menu()
