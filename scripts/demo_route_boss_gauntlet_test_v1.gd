extends "res://scripts/demo_route_rest_pack_v1.gd"

# Fast balancing entry for the real stage-91..100 endgame.
# The test mode reuses the production route/endgame methods and only overrides
# the two balancing knobs the player wants to experiment with: level offset and
# ATB rate for stages 91-95 and 96-100. Production values remain untouched.

const BossGauntletRules = preload("res://scripts/route_boss_rules.gd")
const BOSS_GAUNTLET_TEST_START_STAGE: int = 91
const BOSS_GAUNTLET_TEST_TEAM_LEVEL: int = 80
const BOSS_GAUNTLET_TEST_TEAM_SIZE: int = 4

var _boss_gauntlet_test_mode: bool = false
var _boss_gauntlet_balance_settings: Dictionary = {}


func boss_gauntlet_default_settings() -> Dictionary:
    var boss_profile: Dictionary = BossGauntletRules.boss_profile_for_stage(91)
    var legendary_profile: Dictionary = BossGauntletRules.boss_profile_for_stage(96)
    return {
        "boss_level_offset": int(boss_profile.get("level_offset", 10)),
        "boss_atb_rate_multiplier": float(boss_profile.get("atb_rate_multiplier", 1.5)),
        "legendary_level_offset": int(legendary_profile.get("level_offset", 10)),
        "legendary_atb_rate_multiplier": float(legendary_profile.get("atb_rate_multiplier", 2.0))
    }


func _normalize_boss_gauntlet_settings(settings: Dictionary) -> Dictionary:
    var normalized: Dictionary = boss_gauntlet_default_settings()
    normalized.merge(settings, true)
    normalized["boss_level_offset"] = clampi(
        int(normalized.get("boss_level_offset", 10)), -20, 30
    )
    normalized["boss_atb_rate_multiplier"] = clampf(
        float(normalized.get("boss_atb_rate_multiplier", 1.5)), 0.5, 4.0
    )
    normalized["legendary_level_offset"] = clampi(
        int(normalized.get("legendary_level_offset", 10)), -20, 30
    )
    normalized["legendary_atb_rate_multiplier"] = clampf(
        float(normalized.get("legendary_atb_rate_multiplier", 2.0)), 0.5, 4.0
    )
    return normalized


func _boss_gauntlet_profile_for_stage(current_stage: int) -> Dictionary:
    var profile: Dictionary = BossGauntletRules.boss_profile_for_stage(current_stage)
    if not _boss_gauntlet_test_mode or profile.is_empty():
        return profile

    if _boss_gauntlet_balance_settings.is_empty():
        _boss_gauntlet_balance_settings = boss_gauntlet_default_settings()

    var legendary_stage: bool = bool(profile.get(
        "legendary_stage",
        current_stage >= ENDGAME_LEGENDARY_STAGE_START
    ))
    if legendary_stage:
        profile["level_offset"] = int(_boss_gauntlet_balance_settings.get(
            "legendary_level_offset",
            profile.get("level_offset", 10)
        ))
        profile["atb_rate_multiplier"] = float(_boss_gauntlet_balance_settings.get(
            "legendary_atb_rate_multiplier",
            profile.get("atb_rate_multiplier", 2.0)
        ))
    else:
        profile["level_offset"] = int(_boss_gauntlet_balance_settings.get(
            "boss_level_offset",
            profile.get("level_offset", 10)
        ))
        profile["atb_rate_multiplier"] = float(_boss_gauntlet_balance_settings.get(
            "boss_atb_rate_multiplier",
            profile.get("atb_rate_multiplier", 1.5)
        ))
    return profile


func start_route() -> void:
    # A normal adventure must always use the normal persistence path and the
    # production balance values from route_boss_rules_v1.json.
    _boss_gauntlet_test_mode = false
    super.start_route()


func start_boss_gauntlet_test(settings: Dictionary = {}) -> void:
    if battle_demo == null:
        push_error("Bosskampflauf: BattleDemo fehlt.")
        return

    if not settings.is_empty():
        _boss_gauntlet_balance_settings = _normalize_boss_gauntlet_settings(settings)
    elif _boss_gauntlet_balance_settings.is_empty():
        _boss_gauntlet_balance_settings = boss_gauntlet_default_settings()

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
        + "91–95: +%d Level · ATB ×%.2f · 96–100: +%d Level · ATB ×%.2f"
        % [
            BOSS_GAUNTLET_TEST_TEAM_LEVEL,
            BOSS_GAUNTLET_TEST_START_STAGE,
            int(_boss_gauntlet_balance_settings.get("boss_level_offset", 10)),
            float(_boss_gauntlet_balance_settings.get("boss_atb_rate_multiplier", 1.5)),
            int(_boss_gauntlet_balance_settings.get("legendary_level_offset", 10)),
            float(_boss_gauntlet_balance_settings.get("legendary_atb_rate_multiplier", 2.0))
        ]
    )


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    if (
        not _boss_gauntlet_test_mode
        or stage < ENDGAME_STAGE_START
        or stage > ENDGAME_STAGE_END
    ):
        return

    var profile: Dictionary = _boss_gauntlet_profile_for_stage(stage)
    if profile.is_empty():
        return

    var level_offset: int = int(profile.get("level_offset", 10))
    var atb_multiplier: float = float(profile.get("atb_rate_multiplier", 1.0))
    var hp_bars: int = maxi(1, int(profile.get("hp_bars", 4)))
    var boss_kind: String = "LEGENDÄRER BOSS" if bool(profile.get("legendary_stage", false)) else "SUPERBOSS"
    event_label.text = (
        "[b]🔥 %s · TEST · ETAPPE %d/%d[/b]\n"
        + "Aktuelle Testregel: höchstes eigenes Pokémon [b]%+d Level[/b] · "
        + "[b]ATB ×%.2f[/b] · [b]%d vollständige KP-Leisten[/b].\n"
        + "Diese Werte gelten nur für den Bosskampflauf und verändern das echte Abenteuer nicht."
    ) % [boss_kind, stage, ENDGAME_ROUTE_STAGE_COUNT, level_offset, atb_multiplier, hp_bars]


func _boss_level() -> int:
    if not _boss_gauntlet_test_mode:
        return super._boss_level()
    var profile: Dictionary = _boss_gauntlet_profile_for_stage(stage)
    return maxi(1, _highest_team_level() + int(profile.get("level_offset", 10)))


func _begin_endgame_boss() -> void:
    if not _boss_gauntlet_test_mode:
        super._begin_endgame_boss()
        return

    if stage < ENDGAME_STAGE_START or stage > ENDGAME_STAGE_END or battle_demo == null:
        return

    var profile: Dictionary = _boss_gauntlet_profile_for_stage(stage)
    if profile.is_empty():
        event_label.text = "Für Etappe %d fehlen die Superboss-Regeln." % stage
        return

    var boss_level: int = maxi(1, _highest_team_level() + int(profile.get("level_offset", 10)))
    var species_id: String = _endgame_species_for_profile(profile, boss_level)
    if species_id.is_empty():
        event_label.text = (
            "Für den Superboss auf Level %d ist aktuell keine vollständig spielbare Spezies verfügbar."
            % boss_level
        )
        return

    var party: Array = [{
        "species_id": species_id,
        "level": boss_level,
        "boss": true,
        "hp_multiplier": maxf(1.0, float(profile.get("hp_multiplier", 4.0))),
        "hp_bars": maxi(1, int(profile.get("hp_bars", 4)))
    }]

    _start_special_battle(EVENT_RARE, party, "🔥 Superboss")


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    var prepared_party: Array = enemy_party.duplicate(true)
    if stage >= ENDGAME_STAGE_START and stage <= ENDGAME_STAGE_END:
        var profile: Dictionary = (
            _boss_gauntlet_profile_for_stage(stage)
            if _boss_gauntlet_test_mode
            else BossGauntletRules.boss_profile_for_stage(stage)
        )
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

    var values_label := Label.new()
    values_label.text = (
        "Getestet · 91–95: %+d Level / ATB ×%.2f · 96–100: %+d Level / ATB ×%.2f"
        % [
            int(_boss_gauntlet_balance_settings.get("boss_level_offset", 10)),
            float(_boss_gauntlet_balance_settings.get("boss_atb_rate_multiplier", 1.5)),
            int(_boss_gauntlet_balance_settings.get("legendary_level_offset", 10)),
            float(_boss_gauntlet_balance_settings.get("legendary_atb_rate_multiplier", 2.0))
        ]
    )
    values_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    values_label.add_theme_font_size_override("font_size", 10)
    path_box.add_child(values_label)

    var restart_test := Button.new()
    restart_test.text = "MIT DIESEN WERTEN NEU STARTEN"
    restart_test.custom_minimum_size = Vector2(330, 42)
    restart_test.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    restart_test.pressed.connect(start_boss_gauntlet_test)
    path_box.add_child(restart_test)

    var menu_button := Button.new()
    menu_button.text = "ZUM HAUPTMENÜ · WERTE ÄNDERN"
    menu_button.custom_minimum_size = Vector2(330, 38)
    menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    menu_button.pressed.connect(_leave_boss_gauntlet_test)
    path_box.add_child(menu_button)

    _refresh_team_panel()


func _leave_boss_gauntlet_test() -> void:
    _boss_gauntlet_test_mode = false
    _leave_run_to_main_menu()
