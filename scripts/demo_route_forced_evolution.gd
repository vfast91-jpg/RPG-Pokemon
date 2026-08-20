extends "res://scripts/demo_route_tm_rewards.gd"

# Mandatory evolution layer.
# Linear evolutions happen automatically. When two or more valid evolution
# targets exist, the evolution is still mandatory but the target is chosen by
# the player through the generic evolution-choice UI.
#
# Generated encounters never silently pick a branch. If a branch cannot be
# resolved deterministically, that family is excluded for that generated level.

const MAX_ROUTE_XP_MULTIPLIER: float = 1.25
const MAX_EVOLUTION_HOPS: int = 8


func start_route() -> void:
    super.start_route()
    _replace_unsafe_starter_if_needed()


func route_available_evolution(member: Dictionary) -> Dictionary:
    if battle_demo == null or not battle_demo.has_method("route_required_evolution"):
        return {}
    var evolution: Dictionary = battle_demo.route_required_evolution(
        str(member.get("species_id", "")),
        maxi(1, int(member.get("level", 1)))
    )
    if evolution.is_empty():
        return {}
    evolution["optional"] = false
    evolution["mandatory"] = true
    return evolution


func _replace_unsafe_starter_if_needed() -> void:
    if battle_demo == null or team.is_empty():
        return
    if not battle_demo.has_method("route_species_ids_valid_through_level"):
        return

    var max_reachable_level: int = _max_reachable_level_from_stage(5, 1)
    var safe_roots: Array = battle_demo.route_species_ids_valid_through_level(max_reachable_level)
    if safe_roots.is_empty():
        push_error("Demo-Route: Keine entwicklungssichere Starter-Spezies verfügbar.")
        return

    var current_value: Variant = team[0]
    if current_value is Dictionary:
        var current_id: String = str((current_value as Dictionary).get("species_id", ""))
        if safe_roots.has(current_id):
            return

    var root_id: String = str(safe_roots.pick_random())
    var resolved_id: String = battle_demo.route_resolve_species_for_level(root_id, 5)
    if resolved_id.is_empty():
        return

    var replacement: Dictionary = battle_demo.route_new_member(resolved_id, 5)
    if replacement.is_empty():
        return

    team.clear()
    team.append(replacement)
    storage.clear()
    pending_capture = {}
    _show_stage_choices(
        "Deine Route beginnt mit [b]%s Lv.5[/b].\nWähle deinen ersten Weg."
        % str(replacement.get("name", battle_demo.route_species_name(resolved_id)))
    )


func _begin_capture_event() -> void:
    if battle_demo == null:
        return

    var capture_level: int = _capture_level_for_stage(stage)
    var max_reachable_level: int = _max_reachable_level_from_stage(capture_level, stage)
    var roots: Array = battle_demo.route_species_ids_valid_through_level(max_reachable_level)
    if roots.is_empty():
        event_label.text = "An dieser Fangstelle taucht heute kein vollständig designbares Pokémon auf."
        continue_button.visible = true
        return

    var root_id: String = str(roots.pick_random())
    var species_id: String = battle_demo.route_resolve_species_for_level(root_id, capture_level)
    if species_id.is_empty():
        event_label.text = "Diese Begegnung wurde verworfen, weil die verpflichtende Entwicklungsform noch nicht eindeutig auflösbar ist."
        continue_button.visible = true
        return

    pending_capture = battle_demo.route_new_member(species_id, capture_level)
    if pending_capture.is_empty():
        event_label.text = "Das Pokémon konnte nicht aus den Speziesdaten erzeugt werden."
        continue_button.visible = true
        return

    pending_capture.erase("prevent_evolution")
    var name: String = str(pending_capture.get("name", battle_demo.route_species_name(species_id)))

    if team.size() < ROUTE_TEAM_MAX:
        team.append(pending_capture)
        pending_capture = {}
        event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen und deinem Team hinzugefügt." % [name, capture_level]
        continue_button.visible = true
        _refresh_team_panel()
        return

    event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen. Dein Team mit vier Pokémon ist voll. Möchtest du es einlagern oder ein Team-Pokémon ersetzen?" % [name, capture_level]

    var store_button := Button.new()
    store_button.text = "EINLAGERN"
    store_button.pressed.connect(_store_pending_capture)
    capture_actions.add_child(store_button)

    var replace_button := Button.new()
    replace_button.text = "TEAM-POKÉMON ERSETZEN"
    replace_button.pressed.connect(_show_replace_choices)
    capture_actions.add_child(replace_button)


func _enemy_party_for_stage(current_stage: int) -> Array:
    if battle_demo == null:
        return []

    var enemy_count: int = _roll_enemy_count(current_stage)
    var enemy_level: int = _enemy_level_for_encounter(current_stage, enemy_count)
    var candidates: Array = battle_demo.route_species_ids_for_level(enemy_level)
    if candidates.is_empty():
        push_error(
            "Demo-Route: Keine Spezies besitzt auf Level %d eine vollständig und eindeutig verfügbare Entwicklungsstufe."
            % enemy_level
        )
        return []

    var result: Array = []
    for _index: int in range(enemy_count):
        result.append({
            "species_id": str(candidates.pick_random()),
            "level": enemy_level
        })
    return result


func _award_experience(amount: int) -> Array[String]:
    var messages: Array[String] = super._award_experience(amount)
    var evolution_messages: Array[String] = _apply_mandatory_evolutions()
    messages.append_array(evolution_messages)
    _refresh_team_panel()
    return messages


func _apply_mandatory_evolutions() -> Array[String]:
    var messages: Array[String] = []
    if battle_demo == null or not battle_demo.has_method("route_required_evolution"):
        return messages

    for index: int in range(team.size()):
        messages.append_array(_apply_pending_evolutions_for_member(index))

    return messages


func _apply_pending_evolutions_for_member(index: int) -> Array[String]:
    var messages: Array[String] = []
    if battle_demo == null:
        return messages
    if index < 0 or index >= team.size():
        return messages

    for _hop: int in range(MAX_EVOLUTION_HOPS):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            break

        var member: Dictionary = member_value
        member.erase("prevent_evolution")
        if bool(member.get("pending_evolution_choice", false)):
            team[index] = member
            break

        var level: int = maxi(1, int(member.get("level", 1)))
        var before_id: String = str(member.get("species_id", ""))
        var evolution: Dictionary = battle_demo.route_required_evolution(before_id, level)
        if evolution.is_empty():
            team[index] = member
            break

        if bool(evolution.get("requires_player_choice", false)):
            var choices_value: Variant = evolution.get("choices", [])
            var choices: Array = choices_value if choices_value is Array else []
            if choices.size() < 2:
                push_error("Verzweigte Entwicklung enthält weniger als zwei gültige Ziele: " + before_id)
                break

            member["pending_evolution_choice"] = true
            team[index] = member
            queue_evolution_choice(index, before_id, level, choices)
            var before_name: String = str(member.get("name", battle_demo.route_species_name(before_id)))
            messages.append(
                "[b]🌟 %s kann sich in mehrere Formen entwickeln – wähle die Entwicklung![/b]"
                % before_name
            )
            break

        var target_id: String = str(evolution.get("target_species_id", ""))
        if target_id.is_empty() or not battle_demo.route_species_is_available(target_id):
            push_error(
                "Verpflichtende Entwicklung kann nicht ausgeführt werden: %s Lv.%d benötigt %s, aber die Zielspeziesdaten fehlen."
                % [before_id, level, target_id]
            )
            break

        var applied: Dictionary = _apply_evolution_target(index, before_id, target_id, level)
        if applied.is_empty():
            break
        messages.append(
            "[b]🌟 %s entwickelt sich verpflichtend zu %s![/b]"
            % [str(applied.get("before_name", before_id)), str(applied.get("after_name", target_id))]
        )

    return messages


func _apply_evolution_target(
    index: int,
    before_species_id: String,
    target_species_id: String,
    level: int
) -> Dictionary:
    if battle_demo == null or index < 0 or index >= team.size():
        return {}
    if target_species_id.is_empty() or not battle_demo.route_species_is_available(target_species_id):
        return {}

    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return {}
    var member: Dictionary = member_value
    if str(member.get("species_id", "")) != before_species_id:
        push_warning("Entwicklungswahl ist veraltet und wird ignoriert: " + before_species_id)
        return {}

    var before_name: String = str(member.get("name", battle_demo.route_species_name(before_species_id)))
    var old_max_hp: int = maxi(1, int(member.get("max_hp", 1)))
    var old_hp: int = clampi(int(member.get("hp", old_max_hp)), 0, old_max_hp)
    var evolved: Dictionary = battle_demo.route_new_member(target_species_id, maxi(1, level))
    if evolved.is_empty():
        push_error("Verpflichtende Entwicklung konnte Zielspezies nicht erzeugen: " + target_species_id)
        return {}

    var new_max_hp: int = maxi(1, int(evolved.get("max_hp", old_max_hp)))
    member["species_id"] = target_species_id
    member["name"] = str(evolved.get("name", battle_demo.route_species_name(target_species_id)))
    member["max_hp"] = new_max_hp
    member["hp"] = mini(new_max_hp, old_hp + maxi(0, new_max_hp - old_max_hp))
    member.erase("prevent_evolution")
    member.erase("pending_evolution_choice")
    team[index] = member

    var after_name: String = str(member.get("name", target_species_id))
    queue_evolution_event(before_species_id, target_species_id, before_name, after_name)
    return {
        "before_name": before_name,
        "after_name": after_name,
        "target_species_id": target_species_id
    }


func _on_evolution_choice_selected(request: Dictionary, target_species_id: String) -> void:
    if battle_demo == null or not battle_demo.has_method("route_resolve_evolution_choice"):
        push_error("Entwicklungswahl kann ohne zentralen Resolver nicht ausgeführt werden.")
        return

    var index: int = int(request.get("member_index", -1))
    var before_id: String = str(request.get("before_species_id", ""))
    var level: int = maxi(1, int(request.get("level", 1)))
    if index < 0 or index >= team.size():
        push_warning("Entwicklungswahl verweist auf keinen gültigen Teamplatz.")
        return

    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return
    var member: Dictionary = member_value
    if str(member.get("species_id", "")) != before_id:
        member.erase("pending_evolution_choice")
        team[index] = member
        push_warning("Entwicklungswahl ist nicht mehr aktuell und wurde verworfen.")
        return

    var resolved_target: String = battle_demo.route_resolve_evolution_choice(
        before_id,
        target_species_id,
        maxi(level, int(member.get("level", level)))
    )
    if resolved_target.is_empty():
        member.erase("pending_evolution_choice")
        team[index] = member
        push_error("Ungültiges oder nicht verfügbares Entwicklungsziel: " + target_species_id)
        return

    var applied: Dictionary = _apply_evolution_target(
        index,
        before_id,
        resolved_target,
        maxi(level, int(member.get("level", level)))
    )
    if applied.is_empty():
        member.erase("pending_evolution_choice")
        team[index] = member
        return

    # Support chains without special-case code. A linear follow-up evolves
    # immediately; another branch queues another explicit player choice.
    _apply_pending_evolutions_for_member(index)
    _refresh_team_panel()


func _max_reachable_level_from_stage(start_level: int, start_stage: int) -> int:
    var level: int = maxi(1, start_level)
    var xp_pool: int = 0

    for stage_index: int in range(clampi(start_stage, 1, STAGE_COUNT), STAGE_COUNT + 1):
        var base_xp: int = 20 + stage_index * 12
        xp_pool += int(ceil(float(base_xp) * MAX_ROUTE_XP_MULTIPLIER))

    while xp_pool >= _xp_needed(level):
        xp_pool -= _xp_needed(level)
        level += 1
    return level
