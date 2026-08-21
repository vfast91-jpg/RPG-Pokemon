extends "res://scripts/battle_demo_charmander_family_runtime.gd"

func _cf_pledge_type(move: Dictionary) -> String:
    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary:
        var runtime: Dictionary = runtime_value
        var pledge: String = str(runtime.get("timeflow_pledge", runtime.get("bulba_pledge", "")))
        if not pledge.is_empty():
            return pledge
    match str(move.get("id", "")):
        "grass_pledge":
            return "grass"
        "fire_pledge":
            return "fire"
        "water_pledge":
            return "water"
    return ""


func _cf_pledge_combo_for(actor: Dictionary, current: String, pending: Dictionary) -> String:
    if pending.is_empty():
        return ""
    if str(pending.get("actor_id", "")) == str(actor.get("id", "")):
        return ""
    return _cf_pledge_combo_kind(str(pending.get("pledge", "")), current)


func _cf_pledge_combo_kind(first: String, second: String) -> String:
    var pair: Array[String] = [first, second]
    if pair.has("fire") and pair.has("grass"):
        return "fire_field"
    if pair.has("fire") and pair.has("water"):
        return "rainbow"
    return ""


func _cf_pending_pledge(side: String) -> Dictionary:
    var value: Variant = _cf_pledge_pending.get(side, {})
    return value if value is Dictionary else {}


func _cf_set_pending_pledge(side: String, value: Dictionary) -> void:
    if side.is_empty():
        return
    _cf_pledge_pending[side] = value.duplicate(true)


func _cf_apply_pledge_combo(actor: Dictionary, combo: String) -> void:
    if combo == "fire_field":
        var enemy_side: String = "enemy" if str(actor.get("side", "")) == "player" else "player"
        for target_value: Variant in _team_for_side(enemy_side):
            if not (target_value is Dictionary):
                continue
            var target: Dictionary = target_value
            if not bool(target.get("alive", false)) or _type_array(target.get("types", [])).has("fire"):
                continue
            target["cf_fire_pledge_ticks"] = 3
            target["cf_fire_pledge_source_id"] = str(actor.get("id", ""))
        _spawn_feedback_label(actor, "🔥 FEUERMEER", Color("f3aa73"))
        return

    if combo == "rainbow":
        for ally_value: Variant in _team_for_side(str(actor.get("side", ""))):
            if ally_value is Dictionary and bool((ally_value as Dictionary).get("alive", false)):
                (ally_value as Dictionary)["cf_rainbow_actions"] = 3
        _spawn_feedback_label(actor, "🌈 REGENBOGEN", Color("e8d5ff"))


func _cf_apply_dragon_cheer(actor: Dictionary) -> bool:
    var affected: int = 0
    for ally_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        if (
            not bool(ally.get("alive", false))
            or str(ally.get("id", "")) == str(actor.get("id", ""))
            or not _cf_dragon_cheer_eligible(ally)
        ):
            continue

        var stage: int = _cf_dragon_cheer_stage_for(ally)
        ally["cf_dragon_cheer_stage"] = stage
        ally["cf_dragon_cheer_actions"] = 3
        actor["aggro"] = float(actor.get("aggro", 0.0)) + _hp_scaled_aggro(ally, 0.04)
        affected += 1
        _spawn_feedback_label(
            ally,
            "🐉 KRIT +" + str(stage) + " · 3 AKTIONEN",
            Color("d7c4ff")
        )
    return affected > 0


func _cf_dragon_cheer_eligible(ally: Dictionary) -> bool:
    if int(ally.get("cf_dragon_cheer_actions", 0)) > 0:
        return false
    if float(ally.get("db_focus_energy_bonus_pp", 0.0)) > 0.0:
        return false
    if float(ally.get("critical_focus_bonus", 0.0)) > 0.0:
        return false
    return true


func _cf_dragon_cheer_stage_for(ally: Dictionary) -> int:
    return 2 if _type_array(ally.get("types", [])).has("dragon") else 1


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
