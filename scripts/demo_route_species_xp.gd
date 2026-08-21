extends "res://scripts/demo_route_dangerous_tm_fix.gd"

# Species-specific route progression.
#
# Design rules:
# - Every species uses its own canonical Pokemon growth curve.
# - Normal battle XP depends ONLY on the route stage, never on the defeated
#   species, enemy count or base EXP yield.
# - Medium Fast is the route reference: a Pokemon exactly on the intended
#   route level (Lv.5 on stage 1, Lv.6 on stage 2, ...) receives roughly the
#   complete Medium-Fast requirement for one level from a normal stage win.
# - Training is an extra pre-battle reward and never replaces the stage battle.

const PROGRESSION_DATA_PATH: String = "res://data/gen1_species_progression_v1.json"
const DEFAULT_GROWTH_CURVE: String = "medium_fast"

var _progression_by_species: Dictionary = {}
var _missing_curve_warnings: Dictionary = {}


func _ready() -> void:
    _load_progression_data()
    super._ready()


func _load_progression_data() -> void:
    _progression_by_species.clear()

    var file: FileAccess = FileAccess.open(PROGRESSION_DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Demo-Route: Spezies-EP-Kurven fehlen: " + PROGRESSION_DATA_PATH)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Demo-Route: Spezies-EP-Kurven konnten nicht gelesen werden.")
        return

    var species_value: Variant = (parsed as Dictionary).get("species", {})
    if species_value is Dictionary:
        _progression_by_species = (species_value as Dictionary).duplicate(true)


func _ensure_progression_data() -> void:
    if _progression_by_species.is_empty():
        _load_progression_data()


func _growth_curve_for_species(species_id: String) -> String:
    _ensure_progression_data()

    var entry_value: Variant = _progression_by_species.get(species_id, {})
    if entry_value is Dictionary:
        var curve: String = str((entry_value as Dictionary).get("experience_curve", DEFAULT_GROWTH_CURVE))
        if not curve.is_empty():
            return curve

    if not species_id.is_empty() and not _missing_curve_warnings.has(species_id):
        _missing_curve_warnings[species_id] = true
        push_warning(
            "Demo-Route: Keine EP-Kurve für %s gefunden; Medium Fast wird als Fallback verwendet."
            % species_id
        )
    return DEFAULT_GROWTH_CURVE


func _growth_curve_for_member(member: Dictionary) -> String:
    return _growth_curve_for_species(str(member.get("species_id", "")))


func _total_xp_for_level(curve: String, level: int) -> int:
    var n: int = clampi(level, 1, 100)
    if n <= 1:
        return 0

    var n2: int = n * n
    var n3: int = n2 * n
    var normalized: String = curve.strip_edges().to_lower()

    match normalized:
        "fast":
            return int(floor(float(4 * n3) / 5.0))
        "medium_slow":
            return maxi(
                0,
                int(floor(
                    (6.0 * float(n3) / 5.0)
                    - (15.0 * float(n2))
                    + (100.0 * float(n))
                    - 140.0
                ))
            )
        "slow":
            return int(floor(5.0 * float(n3) / 4.0))
        "erratic":
            if n <= 50:
                return int(floor(float(n3 * (100 - n)) / 50.0))
            if n <= 68:
                return int(floor(float(n3 * (150 - n)) / 100.0))
            if n <= 98:
                var factor: int = int(floor(float(1911 - 10 * n) / 3.0))
                return int(floor(float(n3 * factor) / 500.0))
            return int(floor(float(n3 * (160 - n)) / 100.0))
        "fluctuating":
            if n <= 15:
                var early_factor: int = int(floor(float(n + 1) / 3.0)) + 24
                return int(floor(float(n3 * early_factor) / 50.0))
            if n <= 35:
                return int(floor(float(n3 * (n + 14)) / 50.0))
            var late_factor: int = int(floor(float(n) / 2.0)) + 32
            return int(floor(float(n3 * late_factor) / 50.0))
        _:
            # Medium Fast is the neutral route reference and safe fallback.
            return n3


func _xp_needed_for_curve(curve: String, level: int) -> int:
    var current_level: int = clampi(level, 1, 100)
    if current_level >= 100:
        return 0

    return maxi(
        1,
        _total_xp_for_level(curve, current_level + 1)
        - _total_xp_for_level(curve, current_level)
    )


func _xp_needed_for_member_level(member: Dictionary, level: int) -> int:
    return _xp_needed_for_curve(_growth_curve_for_member(member), level)


func _xp_needed_for_member(member: Dictionary) -> int:
    return _xp_needed_for_member_level(member, maxi(1, int(member.get("level", 1))))


func _xp_needed(level: int) -> int:
    # Legacy helpers without a species context use the route reference curve.
    return maxi(1, _xp_needed_for_curve(DEFAULT_GROWTH_CURVE, level))


func _route_stage_xp(current_stage: int) -> int:
    # Stage 1 starts with a Lv.5 Pokemon. With no bonuses, a Medium-Fast
    # reference Pokemon therefore advances one level per normal stage victory.
    var reference_level: int = clampi(current_stage + 4, 1, 99)
    return maxi(1, _xp_needed_for_curve(DEFAULT_GROWTH_CURVE, reference_level))


func _max_reachable_level_from_stage(start_level: int, start_stage: int) -> int:
    var level: int = clampi(start_level, 1, 100)
    var xp_pool: int = 0

    for stage_index: int in range(
        clampi(start_stage, 1, ROUTE_STAGE_COUNT_90),
        ROUTE_STAGE_COUNT_90 + 1
    ):
        xp_pool += int(ceil(float(_route_stage_xp(stage_index)) * MAX_ROUTE_XP_MULTIPLIER))

    while level < 100:
        var required_xp: int = _xp_needed_for_curve(DEFAULT_GROWTH_CURVE, level)
        if required_xp <= 0 or xp_pool < required_xp:
            break
        xp_pool -= required_xp
        level += 1

    return level


func _award_experience(amount: int) -> Array[String]:
    # Preserve the established route rule: every Pokemon that ENTERED the
    # battle receives normal stage XP even if it fainted before the victory.
    var fainted_participants: Array[Dictionary] = []
    for index: int in _battle_participant_indices:
        if index < 0 or index >= team.size():
            continue
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            fainted_participants.append({
                "index": index,
                "hp": int(member.get("hp", 0))
            })
            member["hp"] = 1

    var messages: Array[String] = _award_experience_species_core(amount)

    for restore_value: Dictionary in fainted_participants:
        var index: int = int(restore_value.get("index", -1))
        if index < 0 or index >= team.size():
            continue
        var member_value: Variant = team[index]
        if member_value is Dictionary:
            (member_value as Dictionary)["hp"] = int(restore_value.get("hp", 0))

    _battle_participant_indices.clear()
    _refresh_team_panel()
    return messages


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
        var level: int = clampi(int(member.get("level", 1)), 1, 100)

        while level < 100:
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

        member["xp"] = 0 if level >= 100 else xp

    # Preserve the established mandatory-evolution pipeline that normally wraps
    # the inherited level-up implementation.
    var evolution_messages: Array[String] = _apply_mandatory_evolutions()
    messages.append_array(evolution_messages)

    _refresh_team_panel()
    if not _levelup_queue.is_empty():
        call_deferred("_show_next_levelup_popup")
    return messages


func _apply_next_level_progress_bonus(
    members: Array,
    bonus_fraction: float
) -> Array[String]:
    var messages: Array[String] = []
    if bonus_fraction <= 0.0:
        return messages

    var percent: int = int(round(bonus_fraction * 100.0))
    for member_value: Variant in members:
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue

        var required_xp: int = _xp_needed_for_member(member)
        if required_xp <= 0:
            continue

        var bonus_xp: int = maxi(1, int(round(float(required_xp) * bonus_fraction)))
        member["xp"] = int(member.get("xp", 0)) + bonus_xp

        messages.append(
            "%s: +%d EP (%d%% von %d EP)"
            % [str(member.get("name", "Pokémon")), bonus_xp, percent, required_xp]
        )

    return messages


func _begin_training_event() -> void:
    event_label.text = (
        "[b]🏋️ Trainingsplatz[/b]\n"
        + "Wähle genau ein Pokémon. Es erhält EP in Höhe seiner vollständigen aktuellen "
        + "EP-Anforderung – ein Level-Aufstieg ist garantiert. Danach folgt wie gewohnt "
        + "der reguläre Etappenkampf."
    )

    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        var level: int = maxi(1, int(member.get("level", 1)))
        var required_xp: int = _xp_needed_for_member_level(member, level)
        var current_xp: int = maxi(0, int(member.get("xp", 0)))

        var button := Button.new()
        button.text = "%s Lv.%d · +%d EP (%d/%d)" % [
            str(member.get("name", "Pokémon")),
            level,
            required_xp,
            current_xp,
            required_xp
        ]
        button.custom_minimum_size = Vector2(0, 28)
        button.tooltip_text = (
            "Dieses Pokémon erhält genau %d EP gemäß seiner eigenen EP-Kurve. "
            + "Der bestehende EP-Stand bleibt erhalten; danach folgt der Etappenkampf."
        ) % required_xp
        button.pressed.connect(_train_team_member.bind(index))
        capture_actions.add_child(button)


func _train_team_member(team_index: int) -> void:
    if team_index < 0 or team_index >= team.size():
        return
    var target_value: Variant = team[team_index]
    if not (target_value is Dictionary):
        return

    var target: Dictionary = target_value
    var before_name: String = str(target.get("name", "Pokémon"))
    var before_level: int = maxi(1, int(target.get("level", 1)))
    var training_xp: int = _xp_needed_for_member_level(target, before_level)

    # Reuse the complete XP -> level-up -> moves -> evolution pipeline while
    # making only the selected Pokemon eligible for this training reward.
    var saved_hp: Array[int] = []
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if member_value is Dictionary:
            var member: Dictionary = member_value
            saved_hp.append(int(member.get("hp", 0)))
            if index != team_index:
                member["hp"] = 0
            elif int(member.get("hp", 0)) <= 0:
                member["hp"] = 1
        else:
            saved_hp.append(0)

    _battle_participant_indices.clear()
    var level_messages: Array[String] = _award_experience(training_xp)

    for index: int in range(team.size()):
        if index == team_index:
            if saved_hp[index] <= 0:
                var trained_value: Variant = team[index]
                if trained_value is Dictionary:
                    (trained_value as Dictionary)["hp"] = 0
            continue

        var member_value: Variant = team[index]
        if member_value is Dictionary:
            (member_value as Dictionary)["hp"] = saved_hp[index]

    _refresh_team_panel()
    _clear_container(capture_actions)

    var summary: String = (
        "[b]🏋️ Trainingsplatz abgeschlossen![/b]\n"
        + "%s erhielt [b]+%d EP[/b] gemäß seiner eigenen EP-Kurve."
    ) % [before_name, training_xp]
    if not level_messages.is_empty():
        summary += "\n" + "\n".join(level_messages)
    summary += "\n\n[b]Als Nächstes folgt der reguläre Etappenkampf.[/b]"

    last_route_message = summary
    event_label.text = summary
    continue_button.visible = true


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    if _active_special_battle == EVENT_DANGEROUS:
        _active_special_battle = ""
        team = updated_team.duplicate(true)
        visible = true

        if not victory:
            _dangerous_pending_xp = 0
            _finish_run(false, "Dein Team wurde auf Etappe %d besiegt." % stage)
            return

        _dangerous_pending_xp = _route_stage_xp(stage)
        _dangerous_tm_reward_pending = true
        _dangerous_battle_summary = (
            "[b]⚠️ Gefährlicher Pfad bezwungen![/b]\n"
            + "Wähle jetzt deine versprochene TM-Belohnung. Danach erhält dein Team [b]+%d EP[/b]."
        ) % _dangerous_pending_xp
        last_route_message = _dangerous_battle_summary
        _begin_tm_event()
        return

    if _active_special_battle == EVENT_RARE:
        _active_special_battle = ""
        team = updated_team.duplicate(true)
        visible = true

        if not victory:
            _finish_run(false, "Dein Team wurde auf Etappe %d besiegt." % stage)
            return

        var boss_xp: int = maxi(
            1,
            int(round(float(_route_stage_xp(stage)) * BOSS_XP_MULTIPLIER))
        )
        var boss_level_messages: Array[String] = _award_experience(boss_xp)
        var boss_summary: String = (
            "[b]👑 Mini-Boss besiegt![/b] · +%d EP (2× Etappen-EP)" % boss_xp
        )
        if not boss_level_messages.is_empty():
            boss_summary += "\n" + "\n".join(boss_level_messages)

        last_route_message = boss_summary
        _complete_special_stage(boss_summary)
        return

    if not _active_special_battle.is_empty():
        super._on_route_battle_finished(victory, updated_team)
        return

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

    if stage >= ROUTE_STAGE_COUNT_90:
        _finish_run(
            true,
            summary + "\n\nDu hast alle 90 Etappen der Demo-Route geschafft."
        )
        return

    stage += 1
    _show_stage_choices(summary + "\n\nDer Weg teilt sich erneut.")


func _make_route_team_card(member: Dictionary, index: int) -> Control:
    var card: Control = super._make_route_team_card(member, index)

    var progress_bars: Array[ProgressBar] = []
    _collect_progress_bars(card, progress_bars)
    if progress_bars.size() < 2:
        return card

    var required_xp: int = maxi(1, _xp_needed_for_member(member))
    var current_xp: int = clampi(int(member.get("xp", 0)), 0, required_xp)
    var xp_bar: ProgressBar = progress_bars[1]
    xp_bar.max_value = float(required_xp)
    xp_bar.value = float(current_xp)

    for child: Node in xp_bar.get_children():
        if child is Label:
            (child as Label).text = "EP %d/%d" % [current_xp, required_xp]
            break

    return card


func _collect_progress_bars(node: Node, result: Array[ProgressBar]) -> void:
    if node is ProgressBar:
        result.append(node as ProgressBar)
    for child: Node in node.get_children():
        _collect_progress_bars(child, result)


func _show_route_member_info(index: int) -> void:
    super._show_route_member_info(index)

    if index < 0 or index >= team.size() or _route_info_stats == null:
        return
    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return

    var member: Dictionary = member_value
    var level: int = maxi(1, int(member.get("level", 1)))
    var reference_needed: int = maxi(1, _xp_needed(level))
    var actual_needed: int = maxi(1, _xp_needed_for_member(member))
    var raw_xp: int = maxi(0, int(member.get("xp", 0)))

    var reference_segment: String = "EP %d/%d" % [
        clampi(raw_xp, 0, reference_needed),
        reference_needed
    ]
    var actual_segment: String = "EP %d/%d" % [
        clampi(raw_xp, 0, actual_needed),
        actual_needed
    ]
    _route_info_stats.text = _route_info_stats.text.replace(
        reference_segment,
        actual_segment
    )
