extends "res://scripts/battle_demo_charmander_family_runtime.gd"

# Pledge- und Dragon-Cheer-Helfer, die bereits vom Runtime-Layer selbst benutzt
# werden, leben absichtlich in battle_demo_charmander_family_runtime.gd. Dadurch
# kann Godot jede Basisklasse der Vererbungskette eigenständig auflösen.

func _critical_chance(combatant: Dictionary) -> float:
    var chance: float = super._critical_chance(combatant)
    var stage: int = maxi(0, int(combatant.get("cf_dragon_cheer_stage", 0)))
    var move: Dictionary = _move_data(_cf_current_move_id())
    var runtime_value: Variant = move.get("runtime", {}) if not move.is_empty() else {}
    if runtime_value is Dictionary and bool((runtime_value as Dictionary).get("high_crit", false)):
        stage += 1
    return maxf(chance, _cf_critical_stage_floor(stage))


func _cf_critical_stage_floor(stage: int) -> float:
    if stage >= 3:
        return 1.0
    if stage == 2:
        return 0.50
    if stage == 1:
        return 0.125
    return 0.0


func _resolve_after_action_effects(combatant: Dictionary) -> void:
    super._resolve_after_action_effects(combatant)
    if not bool(combatant.get("alive", false)):
        return

    var fire_ticks: int = maxi(0, int(combatant.get("cf_fire_pledge_ticks", 0)))
    if fire_ticks > 0:
        _cf_deal_field_damage(
            combatant,
            1.0 / 8.0,
            "🔥 FEUERMEER",
            str(combatant.get("cf_fire_pledge_source_id", ""))
        )
        combatant["cf_fire_pledge_ticks"] = fire_ticks - 1
        if fire_ticks - 1 <= 0:
            combatant["cf_fire_pledge_source_id"] = ""

    var rainbow: int = maxi(0, int(combatant.get("cf_rainbow_actions", 0)))
    if rainbow > 0:
        combatant["cf_rainbow_actions"] = rainbow - 1

    var cheer: int = maxi(0, int(combatant.get("cf_dragon_cheer_actions", 0)))
    if cheer > 0:
        combatant["cf_dragon_cheer_actions"] = cheer - 1
        if cheer - 1 <= 0:
            combatant["cf_dragon_cheer_stage"] = 0


func _cf_deal_field_damage(
    target: Dictionary,
    fraction: float,
    label_text: String,
    source_id: String
) -> int:
    var requested: int = maxi(1, int(floor(float(target.get("max_hp", 1)) * fraction)))
    var actual: int = mini(requested, int(target.get("hp", 0)))
    if actual <= 0:
        return 0
    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    _spawn_feedback_label(target, label_text + " −" + str(actual), Color("f3aa73"))
    var source: Dictionary = _tf_find_combatant(source_id)
    if not source.is_empty():
        source["aggro"] = float(source.get("aggro", 0.0)) + float(actual)
    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false
    return actual
