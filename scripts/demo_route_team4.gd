extends "res://scripts/demo_route.gd"

# Current route rule: the player's travelling team contains at most four Pokémon.
# Extra captures can still be stored or swapped into one of those four slots.
const ROUTE_TEAM_MAX: int = 4


func _begin_capture_event() -> void:
    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        event_label.text = "An dieser Fangstelle taucht heute kein Pokémon auf."
        continue_button.visible = true
        return

    var sid: String = str(ids.pick_random())
    pending_capture = battle_demo.route_new_member(sid, CAPTURE_LEVEL)
    var name: String = str(pending_capture.get("name", battle_demo.route_species_name(sid)))

    if team.size() < ROUTE_TEAM_MAX:
        team.append(pending_capture)
        pending_capture = {}
        event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen und deinem Team hinzugefügt." % [name, CAPTURE_LEVEL]
        continue_button.visible = true
        _refresh_team_panel()
        return

    event_label.text = "[b]Fangwiese[/b]\n%s Lv.%d wurde gefangen. Dein Team mit vier Pokémon ist voll. Möchtest du es einlagern oder ein Team-Pokémon ersetzen?" % [name, CAPTURE_LEVEL]

    var store_button := Button.new()
    store_button.text = "EINLAGERN"
    store_button.pressed.connect(_store_pending_capture)
    capture_actions.add_child(store_button)

    var replace_button := Button.new()
    replace_button.text = "TEAM-POKÉMON ERSETZEN"
    replace_button.pressed.connect(_show_replace_choices)
    capture_actions.add_child(replace_button)


func _start_stage_battle() -> void:
    if battle_demo == null:
        return
    continue_button.visible = false

    if not _team_has_living_member():
        _finish_run(false, "Dein gesamtes Team ist kampfunfähig.")
        return

    var enemy_party: Array = _enemy_party_for_stage(stage)
    if enemy_party.is_empty():
        return

    var enemy_lines: Array[String] = []
    for enemy_value: Variant in enemy_party:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        enemy_lines.append(
            "%s Lv.%d" % [
                battle_demo.route_species_name(str(enemy.get("species_id", ""))),
                int(enemy.get("level", 1))
            ]
        )

    event_label.text = "[b]Etappe %d[/b]\nGegner: %s" % [stage, ", ".join(enemy_lines)]
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


func _enemy_party_for_stage(current_stage: int) -> Array:
    var ids: Array = battle_demo.route_species_ids()
    if ids.is_empty():
        return []

    # Difficulty budget rises every stage: 2 total levels on stage 1,
    # 3 on stage 2, ... up to 11 on stage 10.
    var level_budget: int = maxi(2, current_stage + 1)
    var enemy_count: int = _enemy_count_for_stage(current_stage, level_budget)
    var levels: Array[int] = []

    for _index: int in range(enemy_count):
        levels.append(1)

    var remaining: int = level_budget - enemy_count
    while remaining > 0:
        var target_index: int = randi_range(0, enemy_count - 1)
        levels[target_index] += 1
        remaining -= 1

    levels.shuffle()

    var result: Array = []
    for level: int in levels:
        result.append({
            "species_id": str(ids.pick_random()),
            "level": level
        })
    return result


func _enemy_count_for_stage(current_stage: int, level_budget: int) -> int:
    var roll: float = randf()
    var desired: int = 1

    if current_stage <= 2:
        desired = 1 if roll < 0.45 else 2
    elif current_stage <= 5:
        if roll < 0.25:
            desired = 1
        elif roll < 0.70:
            desired = 2
        else:
            desired = 3
    elif current_stage <= 8:
        if roll < 0.15:
            desired = 1
        elif roll < 0.45:
            desired = 2
        elif roll < 0.80:
            desired = 3
        else:
            desired = 4
    else:
        if roll < 0.10:
            desired = 1
        elif roll < 0.30:
            desired = 2
        elif roll < 0.60:
            desired = 3
        else:
            desired = 4

    return clampi(desired, 1, mini(ROUTE_TEAM_MAX, level_budget))


func _award_experience(amount: int) -> Array[String]:
    var messages: Array[String] = []

    for member_value: Variant in team:
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue

        var xp: int = int(member.get("xp", 0)) + amount
        var level: int = int(member.get("level", 1))

        while xp >= _xp_needed(level):
            xp -= _xp_needed(level)

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
            var learned: Array[String] = []
            for move_value: Variant in new_moves:
                if not old_moves.has(move_value):
                    learned.append(battle_demo.route_move_name(str(move_value)))

            var lines: Array[String] = []
            lines.append(
                "[b]⬆ %s steigt auf Lv.%d![/b]" % [
                    str(member.get("name", "Pokémon")),
                    level
                ]
            )
            lines.append(_stat_change_line("KP", old_stats, new_stats, "max_hp"))
            lines.append(_stat_change_line("Angriff", old_stats, new_stats, "attack"))
            lines.append(_stat_change_line("Verteidigung", old_stats, new_stats, "defense"))
            lines.append(_stat_change_line("Status", old_stats, new_stats, "special"))
            lines.append(_stat_change_line("Initiative", old_stats, new_stats, "speed"))

            if not learned.is_empty():
                lines.append("Neue Attacke: [b]%s[/b]" % ", ".join(learned))
            else:
                lines.append("Keine neue Attacke auf diesem Level.")

            messages.append("\n".join(lines))

        member["xp"] = xp

    _refresh_team_panel()
    return messages


func _route_stats(species_id: String, level: int) -> Dictionary:
    if battle_demo.has_method("route_stat_snapshot"):
        var snapshot: Variant = battle_demo.route_stat_snapshot(species_id, level)
        if snapshot is Dictionary:
            return snapshot

    var fallback: Dictionary = battle_demo.route_new_member(species_id, level)
    return {
        "max_hp": int(fallback.get("max_hp", 1)),
        "attack": 0,
        "defense": 0,
        "special": 0,
        "speed": 0
    }


func _stat_change_line(label: String, before: Dictionary, after: Dictionary, key: String) -> String:
    var old_value: int = int(before.get(key, 0))
    var new_value: int = int(after.get(key, old_value))
    var delta: int = new_value - old_value
    var delta_text: String = "+%d" % delta if delta >= 0 else str(delta)
    return "%s: %d → %d (%s)" % [label, old_value, new_value, delta_text]
