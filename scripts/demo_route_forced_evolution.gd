extends "res://scripts/demo_route_tm_rewards.gd"

# Mandatory evolution layer.
# Evolution can no longer be declined. Generated encounters are resolved to the
# form required by their level. If that required form has not been designed and
# loaded yet, that family is excluded instead of spawning an invalid form.

const MAX_ROUTE_XP_MULTIPLIER: float = 1.25


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
        event_label.text = "Diese Begegnung wurde verworfen, weil die verpflichtende Entwicklungsform noch nicht als Spieldatensatz vorliegt."
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
    var enemy_level: int = _enemy_level_for_stage(current_stage)
    var candidates: Array = battle_demo.route_species_ids_for_level(enemy_level)
    if candidates.is_empty():
        push_error(
            "Demo-Route: Keine Spezies besitzt auf Level %d eine vollständig verfügbare Entwicklungsstufe."
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
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        member.erase("prevent_evolution")

        for _hop: int in range(8):
            var level: int = maxi(1, int(member.get("level", 1)))
            var before_id: String = str(member.get("species_id", ""))
            var evolution: Dictionary = battle_demo.route_required_evolution(before_id, level)
            if evolution.is_empty():
                break

            var target_id: String = str(evolution.get("target_species_id", ""))
            if target_id.is_empty() or not battle_demo.route_species_is_available(target_id):
                push_error(
                    "Verpflichtende Entwicklung kann nicht ausgeführt werden: %s Lv.%d benötigt %s, aber die Zielspeziesdaten fehlen."
                    % [before_id, level, target_id]
                )
                break

            var before_name: String = str(member.get("name", battle_demo.route_species_name(before_id)))
            var old_max_hp: int = maxi(1, int(member.get("max_hp", 1)))
            var old_hp: int = clampi(int(member.get("hp", old_max_hp)), 0, old_max_hp)
            var evolved: Dictionary = battle_demo.route_new_member(target_id, level)
            if evolved.is_empty():
                push_error("Verpflichtende Entwicklung konnte Zielspezies nicht erzeugen: " + target_id)
                break

            var new_max_hp: int = maxi(1, int(evolved.get("max_hp", old_max_hp)))
            member["species_id"] = target_id
            member["name"] = str(evolved.get("name", battle_demo.route_species_name(target_id)))
            member["max_hp"] = new_max_hp
            member["hp"] = mini(new_max_hp, old_hp + maxi(0, new_max_hp - old_max_hp))
            member.erase("prevent_evolution")
            team[index] = member

            var after_name: String = str(member.get("name", target_id))
            queue_evolution_event(before_id, target_id, before_name, after_name)
            messages.append(
                "[b]🌟 %s entwickelt sich verpflichtend zu %s![/b]"
                % [before_name, after_name]
            )

    return messages


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
