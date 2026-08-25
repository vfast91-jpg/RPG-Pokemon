extends RefCounted

# Central, data-driven route boss policy.
# The 100-stage endgame is active. Stages 91-95 keep their random non-legendary
# superboss profiles, while stages 96-100 are fixed legendary bosses defined in
# data/route_boss_rules_v1.json.

const RULES_PATH: String = "res://data/route_boss_rules_v1.json"

const DEFAULT_REINFORCEMENT_PROFILE := {
    "enabled": true,
    "trigger_remaining_bars": 1,
    "count": 2,
    "species_mode": "same_as_boss",
    "level_mode": "player_max",
    "hp_multiplier": 1.0,
    "start_atb_percent": 0.0
}

const DEFAULT_STANDARD_PROFILE := {
    "level_offset": 5,
    "hp_multiplier": 2.0,
    "hp_bars": 2,
    "species_mode": "random_non_legendary",
    "reinforcements": DEFAULT_REINFORCEMENT_PROFILE
}


static func _load_rules() -> Dictionary:
    var file := FileAccess.open(RULES_PATH, FileAccess.READ)
    if file == null:
        push_error("Routen-Bossregeln fehlen: " + RULES_PATH)
        return {}

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Routen-Bossregeln sind ungültig: " + RULES_PATH)
        return {}
    return (parsed as Dictionary).duplicate(true)


static func standard_boss_profile() -> Dictionary:
    var rules: Dictionary = _load_rules()
    var value: Variant = rules.get("standard_special_boss", {})
    if not (value is Dictionary):
        return DEFAULT_STANDARD_PROFILE.duplicate(true)

    var profile: Dictionary = DEFAULT_STANDARD_PROFILE.duplicate(true)
    profile.merge((value as Dictionary), true)
    profile["reinforcements"] = _normalized_reinforcement_profile(
        (value as Dictionary).get("reinforcements", {})
    )
    return profile


static func standard_reinforcement_profile() -> Dictionary:
    var profile: Dictionary = standard_boss_profile()
    return _normalized_reinforcement_profile(profile.get("reinforcements", {}))


static func reinforcement_level_for_player_max(player_max_level: int) -> int:
    return maxi(1, player_max_level)


static func _normalized_reinforcement_profile(value: Variant) -> Dictionary:
    var result: Dictionary = DEFAULT_REINFORCEMENT_PROFILE.duplicate(true)
    if value is Dictionary:
        result.merge((value as Dictionary), true)

    result["enabled"] = bool(result.get("enabled", true))
    result["trigger_remaining_bars"] = maxi(1, int(result.get("trigger_remaining_bars", 1)))
    result["count"] = clampi(int(result.get("count", 2)), 1, 3)
    result["species_mode"] = "same_as_boss"
    result["level_mode"] = "player_max"
    result.erase("level_offset")
    result["hp_multiplier"] = maxf(1.0, float(result.get("hp_multiplier", 1.0)))
    result["start_atb_percent"] = clampf(
        float(result.get("start_atb_percent", 0.0)),
        0.0,
        100.0
    )
    return result


static func legendary_species_ids() -> Array[String]:
    var rules: Dictionary = _load_rules()
    var policy_value: Variant = rules.get("legendary_policy", {})
    if not (policy_value is Dictionary):
        return []

    var ids_value: Variant = (policy_value as Dictionary).get("species_ids", [])
    if not (ids_value is Array):
        return []

    var ids: Array[String] = []
    for value: Variant in ids_value:
        var species_id: String = str(value).strip_edges().to_lower()
        if not species_id.is_empty() and not ids.has(species_id):
            ids.append(species_id)
    return ids


static func is_legendary_species(species_id: String) -> bool:
    return legendary_species_ids().has(species_id.strip_edges().to_lower())


static func filter_standard_combat_candidates(candidates: Array) -> Array:
    # This filter is intentionally combat-only. The Fangwiese has its own pool
    # and must remain capable of offering legendary Pokémon later.
    var filtered: Array = []
    for value: Variant in candidates:
        var species_id: String = str(value)
        if not is_legendary_species(species_id):
            filtered.append(value)
    return filtered


static func capture_event_allows_legendary() -> bool:
    var rules: Dictionary = _load_rules()
    var policy_value: Variant = rules.get("legendary_policy", {})
    if not (policy_value is Dictionary):
        return true
    return bool((policy_value as Dictionary).get("capture_event", true))


static func planned_endgame_enabled() -> bool:
    var rules: Dictionary = _load_rules()
    var endgame_value: Variant = rules.get("planned_endgame", {})
    if not (endgame_value is Dictionary):
        return false
    return bool((endgame_value as Dictionary).get("enabled", false))


static func planned_endgame_profile_for_stage(current_stage: int) -> Dictionary:
    var rules: Dictionary = _load_rules()
    var endgame_value: Variant = rules.get("planned_endgame", {})
    if not (endgame_value is Dictionary):
        return {}

    var endgame: Dictionary = endgame_value as Dictionary
    var stage_start: int = int(endgame.get("stage_start", 91))
    var stage_end: int = int(endgame.get("stage_end", 100))
    if current_stage < stage_start or current_stage > stage_end:
        return {}

    var profile: Dictionary = {}
    var base_profile_value: Variant = endgame.get("boss_profile", {})
    if base_profile_value is Dictionary:
        profile = (base_profile_value as Dictionary).duplicate(true)

    var stages_value: Variant = endgame.get("stages", [])
    if not (stages_value is Array):
        return {}

    var stage_found: bool = false
    for stage_value: Variant in stages_value:
        if not (stage_value is Dictionary):
            continue
        var stage_rule: Dictionary = stage_value as Dictionary
        if int(stage_rule.get("stage", -1)) != current_stage:
            continue
        profile.merge(stage_rule, true)
        stage_found = true
        break

    if not stage_found:
        return {}

    profile["enabled"] = bool(endgame.get("enabled", false))
    profile["planned_endgame"] = true
    return profile


static func boss_profile_for_stage(current_stage: int) -> Dictionary:
    if planned_endgame_enabled():
        var endgame_profile: Dictionary = planned_endgame_profile_for_stage(current_stage)
        if not endgame_profile.is_empty():
            return endgame_profile
    return standard_boss_profile()
