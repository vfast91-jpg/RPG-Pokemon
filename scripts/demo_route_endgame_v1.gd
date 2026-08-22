extends "res://scripts/demo_route_fundstelle_rewards_v2.gd"

# Active 100-stage route layer.
# Stages 1-90 keep the established route flow.
# Stages 91-100 are a mandatory superboss gauntlet with no normal path choice.
# All ten bosses are currently random non-legendary Pokemon. The data file keeps
# future legendary markers for stages 96-100 without requiring those species yet.

const EndgameBossRules = preload("res://scripts/route_boss_rules.gd")

const ROUTE_STAGE_COUNT: int = 100
const ENDGAME_STAGE_START: int = 91
const ENDGAME_STAGE_END: int = 100
const ENDGAME_POST_BATTLE_SETTLE_SECONDS: float = 0.65


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)

    title_label.text = "DEMO-ROUTE · ETAPPE %d/%d" % [stage, ROUTE_STAGE_COUNT]
    progress_label.text = _progress_text()

    if stage < ENDGAME_STAGE_START:
        return

    _clear_container(path_box)
    _clear_container(capture_actions)
    path_box.visible = true
    continue_button.visible = false
    restart_button.visible = false
    stage_xp_multiplier = 1.0

    var profile: Dictionary = EndgameBossRules.boss_profile_for_stage(stage)
    var level_offset: int = int(profile.get("level_offset", 5))
    var hp_bars: int = maxi(1, int(profile.get("hp_bars", 4)))

    event_label.text = (
        "[b]🔥 SUPERBOSS · ETAPPE %d/%d[/b]\n"
        + "Der Spießrutenlauf hat begonnen. Kein normaler Weg, kein Ausweichen: "
        + "Du musst diesen Boss besiegen.\n\n"
        + "Boss-Regel: höchstes eigenes Pokémon [b]+%d Level[/b] · [b]%d vollständige KP-Leisten[/b]."
    ) % [stage, ROUTE_STAGE_COUNT, level_offset, hp_bars]

    var boss_button := Button.new()
    boss_button.text = "🔥 SUPERBOSS HERAUSFORDERN  →"
    boss_button.custom_minimum_size = Vector2(330, 44)
    boss_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    boss_button.tooltip_text = "Starte den Superboss von Etappe %d." % stage
    boss_button.pressed.connect(_begin_endgame_boss)
    path_box.add_child(boss_button)

    _refresh_team_panel()


func _progress_text() -> String:
    var completed: int = clampi(stage - 1, 0, ROUTE_STAGE_COUNT)
    var percent: int = int(round(float(completed) / float(ROUTE_STAGE_COUNT) * 100.0))
    return "Fortschritt: %d%% · Etappe %d von %d" % [
        percent,
        clampi(stage, 1, ROUTE_STAGE_COUNT),
        ROUTE_STAGE_COUNT
    ]


func _boss_level() -> int:
    var profile: Dictionary = EndgameBossRules.boss_profile_for_stage(stage)
    var level_offset: int = int(profile.get("level_offset", 5))
    return maxi(1, _highest_team_level() + level_offset)


func _begin_endgame_boss() -> void:
    if stage < ENDGAME_STAGE_START or stage > ENDGAME_STAGE_END or battle_demo == null:
        return

    var profile: Dictionary = EndgameBossRules.boss_profile_for_stage(stage)
    if profile.is_empty():
        event_label.text = "Für Etappe %d fehlen die Superboss-Regeln." % stage
        return

    var boss_level: int = maxi(1, _highest_team_level() + int(profile.get("level_offset", 5)))
    var species_id: String = _endgame_species_for_profile(profile, boss_level)
    if species_id.is_empty():
        event_label.text = (
            "Für den Superboss auf Level %d ist noch keine vollständig spielbare nicht-legendäre Spezies verfügbar."
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


func _endgame_species_for_profile(profile: Dictionary, boss_level: int) -> String:
    var mode: String = str(profile.get("species_mode", "random_non_legendary"))
    if mode == "fixed":
        var fixed_id: String = str(profile.get("species_id", ""))
        if not fixed_id.is_empty() and battle_demo.route_species_is_available(fixed_id):
            return fixed_id

    var candidates: Array = _standard_combat_candidates(
        battle_demo.route_species_ids_for_level(boss_level)
    )
    if candidates.is_empty():
        return ""
    return _weighted_encounter_species(candidates)


func _complete_special_stage(summary: String) -> void:
    _clear_container(capture_actions)
    last_route_message = summary

    if stage >= ROUTE_STAGE_COUNT:
        _finish_run(
            true,
            summary + "\n\n[b]Du hast alle 100 Etappen von Pokémon Timeflow geschafft![/b]"
        )
        return

    stage += 1
    var transition: String = "\n\nDer Weg teilt sich erneut."
    if stage >= ENDGAME_STAGE_START:
        transition = "\n\nDer nächste Superboss wartet."
    _show_stage_choices(summary + transition)


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    # Special battles already finish their stage through _complete_special_stage,
    # which this layer overrides for the new 100-stage route.
    if stage != 90 or not _active_special_battle.is_empty():
        super._on_route_battle_finished(victory, updated_team)
        return

    # The inherited normal-battle handler still considers stage 90 the finish.
    # Resolve exactly this transition here so stages 1-89 remain untouched.
    if victory:
        await get_tree().create_timer(ENDGAME_POST_BATTLE_SETTLE_SECONDS).timeout

    var adjusted_team: Array = updated_team.duplicate(true)
    var bonus_fraction: float = maxf(0.0, stage_xp_multiplier - 1.0)
    var bonus_lines: Array[String] = []

    if victory and bonus_fraction > 0.0:
        bonus_lines = _apply_next_level_progress_bonus(adjusted_team, bonus_fraction)
        stage_xp_multiplier = 1.0

    team = adjusted_team
    visible = true

    if not victory:
        _finish_run(false, "Du hast den Kampf auf Etappe %d verloren." % stage)
        return

    var gained_xp: int = _route_stage_xp(stage)
    var level_messages: Array[String] = _award_experience(gained_xp)
    var summary: String = (
        "[b]Etappe %d geschafft![/b]\nDein Team erhält %d EP."
        % [stage, gained_xp]
    )
    if not level_messages.is_empty():
        summary += "\n" + "\n".join(level_messages)

    if not bonus_lines.is_empty():
        var percent: int = int(round(bonus_fraction * 100.0))
        summary += (
            "\n\n[b]+%d%% Bonus-EP[/b] – berechnet aus der individuellen vollständigen "
            + "EP-Anforderung bis zum nächsten Level:\n%s"
        ) % [percent, "\n".join(bonus_lines)]

    last_route_message = summary
    stage = 91
    _show_stage_choices(summary + "\n\n[b]Der Superboss-Spießrutenlauf beginnt.[/b]")


func _xp_needed_for_curve(curve: String, level: int) -> int:
    var current_level: int = maxi(1, level)
    if current_level < 100:
        return super._xp_needed_for_curve(curve, current_level)

    # Canonical Pokemon growth curves end at Lv.100. Timeflow intentionally does
    # not. Continue each curve smoothly from its own 99->100 requirement and let
    # later requirements grow quadratically, matching the slope of cubic growth
    # without introducing another hard cap.
    var total_99: int = super._total_xp_for_level(curve, 99)
    var total_100: int = super._total_xp_for_level(curve, 100)
    var level_100_step: int = maxi(1, total_100 - total_99)
    var growth_factor: float = pow(float(current_level + 1) / 100.0, 2.0)
    return maxi(1, int(round(float(level_100_step) * growth_factor)))


func _award_experience_species_core(amount: int) -> Array[String]:
    var messages: Array[String] = []
    _levelup_queue.clear()

    for member_value: Variant in team:
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue

        var xp: int = maxi(0, int(member.get("xp", 0))) + maxi(0, amount)
        var level: int = maxi(1, int(member.get("level", 1)))

        while true:
            var required_xp: int = _xp_needed_for_member_level(member, level)
            if required_xp <= 0 or xp < required_xp:
                break

            xp -= required_xp

            var species_id: String = str(member.get("species_id", ""))
            var old_level: int = level
            var old_moves: Array = battle_demo.route_moves_for_level(species_id, old_level)
            var old_stats: Dictionary = _route_stats(species_id, old_level)
            var old_max_hp: int = int(member.get("max_hp", old_stats.get("max_hp", 1)))

            level += 1

            var refreshed: Dictionary = battle_demo.route_new_member(species_id, level)
            var new_stats: Dictionary = _route_stats(species_id, level)
            var new_max_hp: int = int(refreshed.get("max_hp", new_stats.get("max_hp", old_max_hp)))

            member["level"] = level
            member["max_hp"] = new_max_hp
            member["hp"] = mini(
                new_max_hp,
                int(member.get("hp", 0)) + maxi(0, new_max_hp - old_max_hp)
            )

            var new_moves: Array = battle_demo.route_moves_for_level(species_id, level)
            var learned_names: Array[String] = []
            var learned_move_ids: Array[String] = []
            for move_value: Variant in new_moves:
                if old_moves.has(move_value):
                    continue
                var move_id: String = str(move_value)
                learned_move_ids.append(move_id)
                learned_names.append(battle_demo.route_move_name(move_id))

            _levelup_queue.append({
                "species_id": species_id,
                "name": str(member.get("name", "Pokémon")),
                "old_level": old_level,
                "new_level": level,
                "before": old_stats.duplicate(true),
                "after": new_stats.duplicate(true),
                "learned": learned_names.duplicate(),
                "learned_move_ids": learned_move_ids.duplicate()
            })
            messages.append(
                "[b]⬆ %s erreicht Lv.%d![/b] · Details im Level-Up-Fenster."
                % [str(member.get("name", "Pokémon")), level]
            )

        member["xp"] = xp

    var evolution_messages: Array[String] = _apply_mandatory_evolutions()
    messages.append_array(evolution_messages)

    _refresh_team_panel()
    if not _levelup_queue.is_empty():
        call_deferred("_show_next_levelup_popup")
    return messages


func _show_leaderboard_entry_overlay() -> void:
    super._show_leaderboard_entry_overlay()
    if _leaderboard_entry_summary == null:
        return

    _leaderboard_entry_summary.text = "Etappe %d von %d · %s\nTeam: %s" % [
        clampi(stage, 1, ROUTE_STAGE_COUNT),
        ROUTE_STAGE_COUNT,
        _leaderboard_pending_outcome,
        LeaderboardStore.team_text({"team": _leaderboard_team_snapshot()})
    ]
