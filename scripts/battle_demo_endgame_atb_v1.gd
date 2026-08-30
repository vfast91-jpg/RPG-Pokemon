extends "res://scripts/battle_demo_spotlight_ui_v1.gd"

# Production/test shared ATB layer for stages 91-100.
# The route source carries atb_rate_multiplier from route_boss_rules.gd. This
# layer scales only the ATB gained during a frame; it never rewrites Speed, so
# Tailwind, paralysis and other speed modifiers keep their normal calculations.
# Stages 96-100 additionally carry a presentation-only legendary_endgame flag;
# internal boss=true semantics remain untouched for HP bars and boss mechanics.


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not route_mode or enemy_team.is_empty() or _route_enemy_party.is_empty():
        return

    var legendary_found: bool = false
    var legendary_hp_bars: int = 4
    var count: int = mini(enemy_team.size(), _route_enemy_party.size())
    for index: int in range(count):
        var source_value: Variant = _route_enemy_party[index]
        var combatant_value: Variant = enemy_team[index]
        if not (source_value is Dictionary) or not (combatant_value is Dictionary):
            continue

        var source: Dictionary = source_value as Dictionary
        var combatant: Dictionary = combatant_value as Dictionary
        if not bool(source.get("boss", false)):
            continue

        combatant["atb_rate_multiplier"] = maxf(
            0.0,
            float(source.get("atb_rate_multiplier", 1.0))
        )

        if bool(source.get("legendary_endgame", false)):
            combatant["legendary_endgame"] = true
            legendary_found = true
            legendary_hp_bars = maxi(1, int(source.get("hp_bars", 4)))
            _apply_legendary_endgame_name(combatant)

    if legendary_found:
        _set_log(
            "✨ Ein legendäres Pokémon fordert dich heraus! Es besitzt %d vollständige KP-Leisten."
            % legendary_hp_bars
        )


func _apply_legendary_endgame_name(combatant: Dictionary) -> void:
    var combatant_id: String = str(combatant.get("id", ""))
    var ui_value: Variant = cards.get(combatant_id, {})
    if not (ui_value is Dictionary):
        return
    var ui: Dictionary = ui_value as Dictionary
    var card: Control = ui.get("card") as Control
    if card == null:
        return
    var canvas: Control = card.get_node_or_null("CardCanvas") as Control
    if canvas == null:
        return
    var name_label: Label = canvas.get_node_or_null("Name") as Label
    if name_label == null:
        return
    name_label.text = _legendary_endgame_name_text(combatant)


func _legendary_endgame_name_text(combatant: Dictionary) -> String:
    return "✨ LEGENDÄR · %s Lv.%d" % [
        str(combatant.get("name", "Pokémon")),
        int(combatant.get("level", 1))
    ]


func _process(delta: float) -> void:
    var tracked: Array[Dictionary] = []
    var before_atb: Dictionary = {}

    for enemy_value: Variant in enemy_team:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value as Dictionary
        var multiplier: float = maxf(0.0, float(enemy.get("atb_rate_multiplier", 1.0)))
        if is_equal_approx(multiplier, 1.0):
            continue
        var combatant_id: String = str(enemy.get("id", ""))
        if combatant_id.is_empty():
            continue
        tracked.append(enemy)
        before_atb[combatant_id] = float(enemy.get("atb", 0.0))

    super._process(delta)

    for enemy: Dictionary in tracked:
        if int(enemy.get("hp", 0)) <= 0:
            continue
        var combatant_id: String = str(enemy.get("id", ""))
        if not before_atb.has(combatant_id):
            continue

        var before: float = float(before_atb[combatant_id])
        var current: float = float(enemy.get("atb", 0.0))
        # If an action fired during super._process(), ATB may already have been
        # consumed/reset. Never reinterpret that reset as negative ATB gain.
        if current < before:
            continue

        var gained: float = current - before
        if gained <= 0.0:
            continue

        var multiplier: float = maxf(0.0, float(enemy.get("atb_rate_multiplier", 1.0)))
        enemy["atb"] = clampf(before + gained * multiplier, 0.0, ATB_MAX)
