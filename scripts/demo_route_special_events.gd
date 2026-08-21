extends "res://scripts/demo_route_tm_decline_xp.gd"

# Route event layer for the currently established encounter pool.
# Landscapes, Pokemon nests and lookout points deliberately stay out of scope
# until the landscape system exists.

const DANGEROUS_LEVEL_BONUS: int = 2
const BOSS_HP_MULTIPLIER: float = 2.0
const BOSS_XP_MULTIPLIER: float = 2.0

const EVENT_HEAL: String = "heal"
const EVENT_CATCH: String = "catch"
const EVENT_TM: String = "item"
const EVENT_DIRECT: String = "battle"
const EVENT_TRAINING: String = "training"
const EVENT_DANGEROUS: String = "dangerous"
const EVENT_RARE: String = "rare"

const SECONDARY_EVENT_POOL: Array[String] = [
    EVENT_HEAL,
    EVENT_CATCH,
    EVENT_TM,
    EVENT_DIRECT,
    EVENT_TRAINING,
    EVENT_DANGEROUS,
    EVENT_RARE
]

var _active_special_battle: String = ""
var _dangerous_tm_reward_pending: bool = false
var _dangerous_battle_summary: String = ""


func start_route() -> void:
    _reset_special_event_state()
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    _active_special_battle = ""
    _dangerous_tm_reward_pending = false
    _dangerous_battle_summary = ""
    super._show_stage_choices(message)


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    # Slot 1 is always the reliable recovery/capture anchor. Slots 2 and 3 are
    # sampled uniformly without replacement from every currently active event.
    var first_kind: String = EVENT_HEAL if randf() < 0.5 else EVENT_CATCH
    var remaining: Array[String] = SECONDARY_EVENT_POOL.duplicate()
    remaining.erase(first_kind)
    remaining.shuffle()

    return [
        _special_event_choice(first_kind, current_stage),
        _special_event_choice(remaining[0], current_stage),
        _special_event_choice(remaining[1], current_stage)
    ]


func _special_event_choice(kind: String, current_stage: int) -> Dictionary:
    match kind:
        EVENT_HEAL:
            return {
                "kind": EVENT_HEAL,
                "label": "💧 Heilquelle",
                "hint": "Dein gesamtes Team wird vollständig geheilt."
            }
        EVENT_CATCH:
            return {
                "kind": EVENT_CATCH,
                "label": "🌿 Fangwiese",
                "hint": "Du erhältst ein zufälliges Pokémon auf Level %d." % _capture_level_for_stage(current_stage)
            }
        EVENT_TM:
            return {
                "kind": EVENT_TM,
                "label": "💿 TM-Fundstelle",
                "hint": (
                    "Wähle eine kompatible TM und weise sie einem Pokémon zu – oder lehne die Auswahl ab "
                    + "und erhalte nach dem nächsten Sieg +25% Level-EP."
                )
            }
        EVENT_TRAINING:
            return {
                "kind": EVENT_TRAINING,
                "label": "🏋️ Trainingsplatz",
                "hint": "Trainiere genau ein Pokémon · garantierter Level-Aufstieg."
            }
        EVENT_DANGEROUS:
            return {
                "kind": EVENT_DANGEROUS,
                "label": "⚠️ Gefährlicher Pfad",
                "hint": "1–4 Gegner auf ihrem normalen Etappenlevel +2 · nach dem Sieg eine TM."
            }
        EVENT_RARE:
            return {
                "kind": EVENT_RARE,
                "label": "👑 Seltene Begegnung",
                "hint": "Ein Mini-Boss mit doppelten KP · Sieg bringt doppelte Etappen-EP."
            }
        _:
            return {
                "kind": EVENT_DIRECT,
                "label": "⚔ Direkter Pfad",
                "hint": "Direkt in den Etappenkampf · +25% Level-EP nach dem Sieg."
            }


func _choose_path(choice: Dictionary) -> void:
    var kind: String = str(choice.get("kind", EVENT_DIRECT))
    if kind != EVENT_TRAINING and kind != EVENT_DANGEROUS and kind != EVENT_RARE:
        super._choose_path(choice)
        return

    _set_path_buttons_disabled(true)
    _clear_container(capture_actions)
    continue_button.visible = false
    path_box.visible = false
    stage_xp_multiplier = 1.0

    match kind:
        EVENT_TRAINING:
            _begin_training_event()
        EVENT_DANGEROUS:
            _begin_dangerous_path()
        EVENT_RARE:
            _begin_rare_encounter()


func _begin_training_event() -> void:
    event_label.text = (
        "[b]🏋️ Trainingsplatz[/b]\n"
        + "Wähle genau ein Pokémon. Es erhält EP in Höhe seiner vollständigen aktuellen "
        + "Level-Anforderung – ein Level-Aufstieg ist garantiert, vorhandene EP bleiben erhalten."
    )

    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        var level: int = maxi(1, int(member.get("level", 1)))
        var required_xp: int = _xp_needed(level)
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
        button.tooltip_text = "Dieses Pokémon erhält genau %d EP. Der bestehende EP-Stand wird nicht zurückgesetzt." % required_xp
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
    var training_xp: int = _xp_needed(before_level)

    # Reuse the complete existing XP -> level-up -> moves -> evolution pipeline.
    # Other team members are temporarily made XP-ineligible without changing
    # their permanent HP. A fainted selected Pokémon may train, but stays fainted.
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
        + "%s erhielt [b]+%d EP[/b] – genau die vollständige EP-Anforderung von Lv.%d."
    ) % [before_name, training_xp, before_level]
    if not level_messages.is_empty():
        summary += "\n" + "\n".join(level_messages)
    last_route_message = summary
    event_label.text = summary
    _add_complete_stage_button(summary)


func _begin_dangerous_path() -> void:
    var enemy_count: int = _roll_enemy_count(stage)
    var normal_level: int = _enemy_level_for_encounter(stage, enemy_count)
    var enemy_level: int = maxi(1, normal_level + DANGEROUS_LEVEL_BONUS)
    var candidates: Array = battle_demo.route_species_ids_for_level(enemy_level)
    if candidates.is_empty():
        event_label.text = "Für den Gefährlichen Pfad ist auf Level %d noch keine vollständig spielbare Spezies verfügbar." % enemy_level
        _add_cancel_special_event_button()
        return

    var party: Array = []
    for _index: int in range(enemy_count):
        party.append({
            "species_id": str(candidates.pick_random()),
            "level": enemy_level
        })

    _start_special_battle(EVENT_DANGEROUS, party, "⚠️ Gefährlicher Pfad")


func _begin_rare_encounter() -> void:
    var boss_level: int = _enemy_level_for_encounter(stage, 1)
    var candidates: Array = battle_demo.route_species_ids_for_level(boss_level)
    if candidates.is_empty():
        event_label.text = "Für die Seltene Begegnung ist auf Level %d noch keine vollständig spielbare Spezies verfügbar." % boss_level
        _add_cancel_special_event_button()
        return

    var party: Array = [{
        "species_id": str(candidates.pick_random()),
        "level": boss_level,
        "boss": true,
        "hp_multiplier": BOSS_HP_MULTIPLIER
    }]
    _start_special_battle(EVENT_RARE, party, "👑 Seltene Begegnung")


func _start_special_battle(kind: String, enemy_party: Array, heading: String) -> void:
    if battle_demo == null or enemy_party.is_empty():
        return
    if not _team_has_living_member():
        _finish_run(false, "Dein gesamtes Team ist kampfunfähig.")
        return

    _battle_participant_indices.clear()
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if member_value is Dictionary and int((member_value as Dictionary).get("hp", 0)) > 0:
            _battle_participant_indices.append(index)

    var enemy_lines: Array[String] = []
    for enemy_value: Variant in enemy_party:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        var prefix: String = "👑 " if bool(enemy.get("boss", false)) else ""
        enemy_lines.append("%s%s Lv.%d" % [
            prefix,
            battle_demo.route_species_name(str(enemy.get("species_id", ""))),
            int(enemy.get("level", 1))
        ])

    _active_special_battle = kind
    event_label.text = "[b]%s · Etappe %d[/b]\nGegner: %s" % [heading, stage, ", ".join(enemy_lines)]
    last_route_message = event_label.text
    visible = false

    if battle_demo.has_method("start_route_battle_party"):
        battle_demo.start_route_battle_party(team, enemy_party)
    else:
        var fallback: Dictionary = enemy_party[0]
        battle_demo.start_route_battle(
            team,
            str(fallback.get("species_id", "")),
            int(fallback.get("level", stage))
        )


func _on_route_battle_finished(victory: bool, updated_team: Array) -> void:
    if _active_special_battle.is_empty():
        super._on_route_battle_finished(victory, updated_team)
        return

    var completed_kind: String = _active_special_battle
    _active_special_battle = ""
    team = updated_team.duplicate(true)
    visible = true

    if not victory:
        _finish_run(false, "Dein Team wurde auf Etappe %d besiegt." % stage)
        return

    var base_xp: int = 20 + stage * 12
    var xp_multiplier: float = BOSS_XP_MULTIPLIER if completed_kind == EVENT_RARE else 1.0
    var gained_xp: int = int(round(float(base_xp) * xp_multiplier))
    var level_messages: Array[String] = _award_experience(gained_xp)

    var summary: String
    if completed_kind == EVENT_RARE:
        summary = "[b]👑 Mini-Boss besiegt![/b] · +%d EP (2× Etappen-EP)" % gained_xp
    else:
        summary = "[b]⚠️ Gefährlicher Pfad bezwungen![/b] · +%d EP" % gained_xp

    if not level_messages.is_empty():
        summary += "\n" + "\n".join(level_messages)
    last_route_message = summary

    if completed_kind == EVENT_DANGEROUS:
        _dangerous_tm_reward_pending = true
        _dangerous_battle_summary = summary
        _begin_tm_event()
        return

    _complete_special_stage(summary)


func _begin_tm_event() -> void:
    super._begin_tm_event()
    if _dangerous_tm_reward_pending and continue_button.visible:
        # Existing TM fallback: if no compatible TM exists, it heals the team.
        # For a post-battle reward that concludes the stage instead of starting
        # another battle, so replace the normal continue behavior.
        _prepare_dangerous_reward_finish(event_label.text)


func _show_tm_offer_buttons() -> void:
    super._show_tm_offer_buttons()
    if not _dangerous_tm_reward_pending:
        return

    # A dangerous-path victory promises a TM reward. Reuse the existing TM
    # candidate/recipient system, but do not offer the normal pre-battle
    # "decline for next-battle XP" alternative here.
    for child: Node in capture_actions.get_children():
        if child is Button and str((child as Button).text).begins_with("KEINE TM"):
            (child as Button).disabled = true
            (child as Button).visible = false

    event_label.text = (
        _dangerous_battle_summary
        + "\n\n[b]💿 Belohnung: TM-Auswahl[/b]\n"
        + "Wähle eine kompatible TM und weise sie einem Pokémon zu."
    )


func _assign_tm(entry: Dictionary, team_index: int) -> void:
    super._assign_tm(entry, team_index)
    if _dangerous_tm_reward_pending and continue_button.visible:
        _prepare_dangerous_reward_finish(event_label.text)


func _prepare_dangerous_reward_finish(reward_text: String) -> void:
    continue_button.visible = false
    _clear_container(capture_actions)
    event_label.text = reward_text

    var finish_button := Button.new()
    finish_button.text = "WEITER ZUR NÄCHSTEN ETAPPE"
    finish_button.custom_minimum_size = Vector2(0, 30)
    finish_button.pressed.connect(_finish_dangerous_reward.bind(reward_text))
    capture_actions.add_child(finish_button)


func _finish_dangerous_reward(reward_text: String) -> void:
    var summary: String = _dangerous_battle_summary
    if not reward_text.is_empty():
        summary += "\n\n" + reward_text
    _dangerous_tm_reward_pending = false
    _dangerous_battle_summary = ""
    _complete_special_stage(summary)


func _add_complete_stage_button(summary: String) -> void:
    continue_button.visible = false
    var finish_button := Button.new()
    finish_button.text = "WEITER ZUR NÄCHSTEN ETAPPE"
    finish_button.custom_minimum_size = Vector2(0, 30)
    finish_button.pressed.connect(_complete_special_stage.bind(summary))
    capture_actions.add_child(finish_button)


func _add_cancel_special_event_button() -> void:
    var back_button := Button.new()
    back_button.text = "ZURÜCK ZUR WEGAUSWAHL"
    back_button.custom_minimum_size = Vector2(0, 28)
    back_button.pressed.connect(_show_stage_choices.bind("Diese Begegnung ist mit den aktuell vollständigen Pokémon-Daten noch nicht verfügbar."))
    capture_actions.add_child(back_button)


func _complete_special_stage(summary: String) -> void:
    _clear_container(capture_actions)
    last_route_message = summary
    if stage >= ROUTE_STAGE_COUNT_90:
        _finish_run(true, summary + "\n\nDu hast alle 90 Etappen der Demo-Route geschafft.")
        return

    stage += 1
    _show_stage_choices(summary + "\n\nDer Weg teilt sich erneut.")


func _reset_special_event_state() -> void:
    _active_special_battle = ""
    _dangerous_tm_reward_pending = false
    _dangerous_battle_summary = ""
