extends "res://scripts/demo_route_rest_pack_v1.gd"

# Fast balancing entry for the real stage-91..100 endgame.
# The test mode only provides a quick, save-isolated route into the endgame.
# Its level/ATB controls are the canonical endgame values and therefore also
# apply to stages 91-100 in the normal adventure.

const BossGauntletRules = preload("res://scripts/route_boss_rules.gd")
const BOSS_GAUNTLET_TEST_START_STAGE: int = 91
const BOSS_GAUNTLET_TEST_TEAM_LEVEL: int = 80
const BOSS_GAUNTLET_TEST_TEAM_SIZE: int = 4

var _boss_gauntlet_test_mode: bool = false
var _boss_gauntlet_balance_settings: Dictionary = {}


func boss_gauntlet_default_settings() -> Dictionary:
    return BossGauntletRules.endgame_balance_settings()


func _normalize_boss_gauntlet_settings(settings: Dictionary) -> Dictionary:
    return BossGauntletRules.normalize_endgame_balance_settings(settings)


func _boss_gauntlet_profile_for_stage(current_stage: int) -> Dictionary:
    return BossGauntletRules.boss_profile_for_stage(current_stage)


func start_route() -> void:
    # Only the fast-route isolation is disabled here. The balance values remain
    # canonical and are deliberately shared with the normal adventure.
    _boss_gauntlet_test_mode = false
    super.start_route()


func start_boss_gauntlet_test(settings: Dictionary = {}) -> void:
    if battle_demo == null:
        push_error("Bosskampflauf: BattleDemo fehlt.")
        return

    if not settings.is_empty():
        _boss_gauntlet_balance_settings = _normalize_boss_gauntlet_settings(settings)
        if not BossGauntletRules.save_endgame_balance_settings(_boss_gauntlet_balance_settings):
            push_error("Bosskampflauf: Endgame-Spielwerte konnten nicht übernommen werden.")
            return
    else:
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
    var encounter_kind: String = "LEGENDÄRES POKÉMON" if bool(profile.get("legendary_stage", false)) else "SUPERBOSS"
    event_label.text = (
        "[b]🔥 %s · TEST · ETAPPE %d/%d[/b]\n"
        + "Aktuelle Spielregel: höchstes eigenes Pokémon [b]%+d Level[/b] · "
        + "[b]ATB ×%.2f[/b] · [b]%d vollständige KP-Leisten[/b].\n"
        + "Dieselben Level- und ATB-Werte gelten auch im normalen Abenteuer."
    ) % [encounter_kind, stage, ENDGAME_ROUTE_STAGE_COUNT, level_offset, atb_multiplier, hp_bars]


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
        event_label.text = "Für Etappe %d fehlen die Endgame-Regeln." % stage
        return

    var boss_level: int = maxi(1, _highest_team_level() + int(profile.get("level_offset", 10)))
    var species_id: String = _endgame_species_for_profile(profile, boss_level)
    var legendary_stage: bool = bool(profile.get("legendary_stage", false))
    if species_id.is_empty():
        event_label.text = (
            "Für das Endgame-Pokémon auf Level %d ist aktuell keine vollständig spielbare Spezies verfügbar."
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

    var heading: String = "✨ Legendäres Pokémon" if legendary_stage else "🔥 Superboss"
    _start_special_battle(EVENT_RARE, party, heading)


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
    # The fast route must never overwrite the player's real adventure slot.
    if _boss_gauntlet_test_mode:
        return true
    return super._commit_canonical_stage_start(show_feedback)


func _finish_run(victory: bool, message: String) -> void:
    if not _boss_gauntlet_test_mode:
        super._finish_run(victory, message)
        return

    # Do not call the normal persistence/leaderboard finish path: that path
    # intentionally clears the active adventure save. The fast test is isolated.
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

    _boss_gauntlet_balance_settings = boss_gauntlet_default_settings()
    var values_label := Label.new()
    values_label.text = (
        "Aktuelle Spielwerte · 91–95: %+d Level / ATB ×%.2f · 96–100: %+d Level / ATB ×%.2f"
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
