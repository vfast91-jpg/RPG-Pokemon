extends "res://scripts/demo_route_fundstelle_v1.gd"

# Phase G: final five-event route pool, encounter-family weighting and boss
# reward flow. Direct Path and Dangerous Path remain only as unreachable
# inherited legacy code until Phase H removes dead compatibility entry points.
#
# Stages 1-10 are the protected onboarding window. During that window the Boss
# event is deliberately excluded so the gentler fixed encounter curve cannot be
# bypassed by a highest-team-level +5 battle with double HP.

const RouteBossRules = preload("res://scripts/route_boss_rules.gd")

const ACTIVE_ROUTE_EVENTS: Array[String] = [
    EVENT_HEAL,
    EVENT_CATCH,
    EVENT_TM,
    EVENT_TRAINING,
    EVENT_RARE
]

var _boss_fundstelle_pending: bool = false
var _boss_reward_summary: String = ""
var _boss_reward_sequence_id: int = 0


func start_route() -> void:
    _reset_boss_reward_state()
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    _boss_reward_sequence_id += 1
    _boss_fundstelle_pending = false
    _boss_reward_summary = ""
    super._show_stage_choices(message)


func _reset_boss_reward_state() -> void:
    _boss_reward_sequence_id += 1
    _boss_fundstelle_pending = false
    _boss_reward_summary = ""


func _route_event_pool_for_stage(current_stage: int) -> Array[String]:
    var pool: Array[String] = ACTIVE_ROUTE_EVENTS.duplicate()
    if current_stage <= 10:
        pool.erase(EVENT_RARE)
    return pool


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var pool: Array[String] = _route_event_pool_for_stage(current_stage)
    pool.shuffle()

    var choices: Array[Dictionary] = []
    for index: int in range(mini(3, pool.size())):
        choices.append(_active_event_choice(pool[index], current_stage))
    return choices


func _active_event_choice(kind: String, current_stage: int) -> Dictionary:
    var choice: Dictionary = _special_event_choice(kind, current_stage)
    match kind:
        EVENT_TM:
            choice["label"] = "🎁 Fundstelle"
            choice["hint"] = "Wähle genau eine Belohnung: passende TM, Heilitem oder Vitamin."
        EVENT_RARE:
            choice["label"] = "👑 Besondere Begegnung"
            choice["hint"] = (
                "Boss mit doppelten KP auf dem höchsten eigenen Level +5. "
                + "Sieg gibt normale Etappen-EP und danach eine Fundstelle."
            )
    return choice


func _encounter_species_weight(species_id: String) -> float:
    return pow(
        _family_catch_rate(_family_id_for_species(species_id)),
        _route_rarity_exponent_for_stage(stage)
    )


func _weighted_encounter_species(candidates: Array) -> String:
    if candidates.is_empty():
        return ""

    var total_weight: float = 0.0
    var weights: Array[float] = []
    for species_value: Variant in candidates:
        var species_id: String = str(species_value)
        var weight: float = maxf(0.0001, _encounter_species_weight(species_id))
        weights.append(weight)
        total_weight += weight

    if total_weight <= 0.0:
        return str(candidates.pick_random())

    var roll: float = randf() * total_weight
    var cumulative: float = 0.0
    for index: int in range(candidates.size()):
        cumulative += weights[index]
        if roll <= cumulative:
            return str(candidates[index])
    return str(candidates[candidates.size() - 1])


func _standard_combat_candidates(candidates: Array) -> Array:
    # Legendary Pokémon are deliberately absent from normal route battles and
    # ordinary Besondere Begegnungen. This does NOT filter the Fangwiese.
    return RouteBossRules.filter_standard_combat_candidates(candidates)


func _enemy_party_for_stage(current_stage: int) -> Array:
    if battle_demo == null:
        return []

    var enemy_count: int = _roll_enemy_count(current_stage)
    var enemy_level: int = _enemy_level_for_encounter(current_stage, enemy_count)
    var candidates: Array = _standard_combat_candidates(
        battle_demo.route_species_ids_for_level(enemy_level)
    )
    if candidates.is_empty():
        push_error(
            "Demo-Route: Keine vollständig spielbare nicht-legendäre Spezies für Gegnerlevel %d verfügbar."
            % enemy_level
        )
        return []

    var result: Array = []
    for _index: int in range(enemy_count):
        result.append({
            "species_id": _weighted_encounter_species(candidates),
            "level": enemy_level
        })
    return result


func _boss_level() -> int:
    var profile: Dictionary = RouteBossRules.standard_boss_profile()
    var level_offset: int = int(profile.get("level_offset", 5))
    return clampi(_highest_team_level() + level_offset, 1, 100)


func _begin_rare_encounter() -> void:
    var boss_level: int = _boss_level()
    var candidates: Array = _standard_combat_candidates(
        battle_demo.route_species_ids_for_level(boss_level)
    )
    if candidates.is_empty():
        event_label.text = "Für die Besondere Begegnung ist auf Level %d noch keine vollständig spielbare nicht-legendäre Spezies verfügbar." % boss_level
        _add_cancel_special_event_button()
        return

    var profile: Dictionary = RouteBossRules.standard_boss_profile()
    var party: Array = [{
        "species_id": _weighted_encounter_species(candidates),
        "level": boss_level,
        "boss": true,
        "hp_multiplier": float(profile.get("hp_multiplier", BOSS_HP_MULTIPLIER)),
        "hp_bars": maxi(1, int(profile.get("hp_bars", 2)))
    }]
    _start_special_battle(EVENT_RARE, party, "👑 Besondere Begegnung")


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    if _active_special_battle != EVENT_RARE:
        super._on_route_battle_finished(victory, updated_team)
        return

    _active_special_battle = ""
    team = updated_team.duplicate(true)
    visible = true

    if not victory:
        _reset_boss_reward_state()
        _finish_run(false, "Dein Team wurde auf Etappe %d vom Boss besiegt." % stage)
        return

    var gained_xp: int = _route_stage_xp(stage)
    var level_messages: Array[String] = _award_experience(gained_xp)
    _boss_reward_summary = "[b]👑 Boss besiegt![/b] · +%d normale Etappen-EP" % gained_xp
    if not level_messages.is_empty():
        _boss_reward_summary += "\n" + "\n".join(level_messages)

    last_route_message = _boss_reward_summary
    event_label.text = (
        _boss_reward_summary
        + "\n\nLevel-Ups und Entwicklungen werden zuerst vollständig abgeschlossen. "
        + "Danach folgt die Fundstelle als Bossbelohnung."
    )

    _boss_fundstelle_pending = true
    _boss_reward_sequence_id += 1
    var sequence_id: int = _boss_reward_sequence_id
    _show_boss_fundstelle_after_progression(sequence_id)


func _show_boss_fundstelle_after_progression(sequence_id: int) -> void:
    await get_tree().process_frame

    while _route_progression_presentation_pending():
        if sequence_id != _boss_reward_sequence_id or not _boss_fundstelle_pending:
            return
        await get_tree().process_frame

    if sequence_id != _boss_reward_sequence_id or not _boss_fundstelle_pending:
        return

    _begin_fundstelle()


func _show_fundstelle_options() -> void:
    super._show_fundstelle_options()
    if _boss_fundstelle_pending and not _boss_reward_summary.is_empty():
        event_label.text = _boss_reward_summary + "\n\n" + event_label.text


func _route_progression_presentation_pending() -> bool:
    if not _levelup_queue.is_empty():
        return true
    if _levelup_overlay != null and _levelup_overlay.visible:
        return true

    if not _evolution_queue.is_empty():
        return true
    if _evolution_overlay != null and _evolution_overlay.visible:
        return true

    if not _evolution_choice_queue.is_empty():
        return true
    if not _active_evolution_choice.is_empty():
        return true
    if _evolution_choice_overlay != null and _evolution_choice_overlay.visible:
        return true

    return false


func _assign_tm(entry: Dictionary, team_index: int) -> void:
    var boss_reward: bool = _boss_fundstelle_pending
    super._assign_tm(entry, team_index)
    if boss_reward and continue_button.visible:
        _prepare_boss_reward_finish(event_label.text)


func _apply_healing_item(team_index: int, item: Dictionary) -> void:
    var boss_reward: bool = _boss_fundstelle_pending
    super._apply_healing_item(team_index, item)
    if boss_reward and continue_button.visible:
        _prepare_boss_reward_finish(event_label.text)


func _apply_vitamin(team_index: int, vitamin: Dictionary) -> void:
    var boss_reward: bool = _boss_fundstelle_pending
    super._apply_vitamin(team_index, vitamin)
    if boss_reward and continue_button.visible:
        _prepare_boss_reward_finish(event_label.text)


func _prepare_boss_reward_finish(reward_text: String) -> void:
    continue_button.visible = false
    _clear_container(capture_actions)

    var combined: String = _boss_reward_summary
    if not reward_text.is_empty():
        combined += "\n\n" + reward_text
    event_label.text = combined

    var finish_button := Button.new()
    finish_button.text = "WEITER ZUR NÄCHSTEN ETAPPE"
    finish_button.custom_minimum_size = Vector2(0, 30)
    finish_button.pressed.connect(_finish_boss_reward.bind(combined))
    capture_actions.add_child(finish_button)


func _finish_boss_reward(combined_summary: String) -> void:
    _boss_fundstelle_pending = false
    _boss_reward_summary = ""
    _boss_reward_sequence_id += 1
    _complete_special_stage(combined_summary)
