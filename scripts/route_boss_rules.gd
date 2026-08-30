extends RefCounted

# Central, data-driven route boss policy.
# The 100-stage endgame is active. Stages 91-95 keep random non-legendary
# superbosses. Stages 96-98 draw unique bosses from the configured 580 BST
# legendary pool; stages 99-100 do the same from the configured 680 BST pool.
# Pool entries may already name future species: runtime selection only uses
# species that are actually available/playable at that moment.

const RULES_PATH: String = "res://data/route_boss_rules_v1.json"
const ENDGAME_BALANCE_SETTINGS_PATH: String = "user://boss_gauntlet_balance.cfg"

const DEFAULT_ENDGAME_BALANCE := {
    "boss_level_offset": 10,
    "boss_atb_rate_multiplier": 1.5,
    "legendary_level_offset": 10,
    "legendary_atb_rate_multiplier": 2.0
}

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


static func _load_source_rules() -> Dictionary:
    var file := FileAccess.open(RULES_PATH, FileAccess.READ)
    if file == null:
        push_error("Routen-Bossregeln fehlen: " + RULES_PATH)
        return {}

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Routen-Bossregeln sind ungültig: " + RULES_PATH)
        return {}
    return (parsed as Dictionary).duplicate(true)


static func _load_rules() -> Dictionary:
    var rules: Dictionary = _load_source_rules()
    if rules.is_empty():
        return rules
    var override_settings: Dictionary = _load_endgame_balance_override()
    if override_settings.is_empty():
        return rules
    return apply_endgame_balance_settings_to_rules(rules, override_settings)


static func normalize_endgame_balance_settings(settings: Dictionary) -> Dictionary:
    var normalized: Dictionary = DEFAULT_ENDGAME_BALANCE.duplicate(true)
    normalized.merge(settings, true)
    normalized["boss_level_offset"] = clampi(
        int(normalized.get("boss_level_offset", 10)), -20, 30
    )
    normalized["boss_atb_rate_multiplier"] = clampf(
        float(normalized.get("boss_atb_rate_multiplier", 1.5)), 0.5, 4.0
    )
    normalized["legendary_level_offset"] = clampi(
        int(normalized.get("legendary_level_offset", 10)), -20, 30
    )
    normalized["legendary_atb_rate_multiplier"] = clampf(
        float(normalized.get("legendary_atb_rate_multiplier", 2.0)), 0.5, 4.0
    )
    return normalized


static func _load_endgame_balance_override() -> Dictionary:
    var config := ConfigFile.new()
    if config.load(ENDGAME_BALANCE_SETTINGS_PATH) != OK:
        return {}

    var settings: Dictionary = {}
    for key: String in [
        "boss_level_offset",
        "boss_atb_rate_multiplier",
        "legendary_level_offset",
        "legendary_atb_rate_multiplier"
    ]:
        if config.has_section_key("balance", key):
            settings[key] = config.get_value("balance", key)

    if settings.is_empty():
        return {}
    return normalize_endgame_balance_settings(settings)


static func endgame_balance_settings() -> Dictionary:
    var rules: Dictionary = _load_rules()
    var endgame_value: Variant = rules.get("planned_endgame", {})
    if not (endgame_value is Dictionary):
        return DEFAULT_ENDGAME_BALANCE.duplicate(true)

    var endgame: Dictionary = endgame_value as Dictionary
    var boss_value: Variant = endgame.get("boss_profile", {})
    var legendary_value: Variant = endgame.get("legendary_profile", {})
    var boss_profile: Dictionary = boss_value as Dictionary if boss_value is Dictionary else {}
    var legendary_profile: Dictionary = legendary_value as Dictionary if legendary_value is Dictionary else {}
    return normalize_endgame_balance_settings({
        "boss_level_offset": int(boss_profile.get("level_offset", 10)),
        "boss_atb_rate_multiplier": float(boss_profile.get("atb_rate_multiplier", 1.5)),
        "legendary_level_offset": int(legendary_profile.get("level_offset", 10)),
        "legendary_atb_rate_multiplier": float(legendary_profile.get("atb_rate_multiplier", 2.0))
    })


static func apply_endgame_balance_settings_to_rules(
    rules: Dictionary,
    settings: Dictionary
) -> Dictionary:
    var updated: Dictionary = rules.duplicate(true)
    var normalized: Dictionary = normalize_endgame_balance_settings(settings)
    var endgame_value: Variant = updated.get("planned_endgame", {})
    if not (endgame_value is Dictionary):
        return updated

    var endgame: Dictionary = endgame_value as Dictionary
    var boss_value: Variant = endgame.get("boss_profile", {})
    var legendary_value: Variant = endgame.get("legendary_profile", {})
    if not (boss_value is Dictionary) or not (legendary_value is Dictionary):
        return updated

    var boss_profile: Dictionary = boss_value as Dictionary
    var legendary_profile: Dictionary = legendary_value as Dictionary
    boss_profile["level_offset"] = int(normalized["boss_level_offset"])
    boss_profile["atb_rate_multiplier"] = float(normalized["boss_atb_rate_multiplier"])
    legendary_profile["level_offset"] = int(normalized["legendary_level_offset"])
    legendary_profile["atb_rate_multiplier"] = float(normalized["legendary_atb_rate_multiplier"])
    endgame["boss_profile"] = boss_profile
    endgame["legendary_profile"] = legendary_profile
    updated["planned_endgame"] = endgame
    return updated


static func save_endgame_balance_settings(settings: Dictionary) -> bool:
    var normalized: Dictionary = normalize_endgame_balance_settings(settings)

    # This user:// file is the persistent runtime source used by both the real
    # adventure and the fast balancing route. It also keeps packaged builds
    # functional where res:// may be read-only.
    var config := ConfigFile.new()
    config.set_value("balance", "boss_level_offset", int(normalized["boss_level_offset"]))
    config.set_value("balance", "boss_atb_rate_multiplier", float(normalized["boss_atb_rate_multiplier"]))
    config.set_value("balance", "legendary_level_offset", int(normalized["legendary_level_offset"]))
    config.set_value("balance", "legendary_atb_rate_multiplier", float(normalized["legendary_atb_rate_multiplier"]))
    var config_result: Error = config.save(ENDGAME_BALANCE_SETTINGS_PATH)
    if config_result != OK:
        push_error("Endgame-Balance konnte nicht gespeichert werden: %s" % ENDGAME_BALANCE_SETTINGS_PATH)
        return false

    # During development from the Godot project, mirror the chosen values into
    # the actual source JSON as well. In packaged exports res:// is normally
    # read-only; the persistent override above remains canonical in that case.
    var source_rules: Dictionary = _load_source_rules()
    if not source_rules.is_empty():
        var updated_rules: Dictionary = apply_endgame_balance_settings_to_rules(
            source_rules,
            normalized
        )
        var source_file := FileAccess.open(RULES_PATH, FileAccess.WRITE)
        if source_file != null:
            source_file.store_string(JSON.stringify(updated_rules, "  ", false) + "\n")
        else:
            push_warning(
                "Endgame-Balance gilt im Spiel, aber die Quell-JSON ist in dieser Ausführung schreibgeschützt."
            )

    return true


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


static func capture_legendary_pool_relative_weight() -> float:
    var rules: Dictionary = _load_rules()
    var policy_value: Variant = rules.get("legendary_policy", {})
    if not (policy_value is Dictionary):
        return 0.05
    return maxf(
        0.0,
        float((policy_value as Dictionary).get("capture_pool_relative_weight", 0.05))
    )


static func planned_endgame_enabled() -> bool:
    var rules: Dictionary = _load_rules()
    var endgame_value: Variant = rules.get("planned_endgame", {})
    if not (endgame_value is Dictionary):
        return false
    return bool((endgame_value as Dictionary).get("enabled", false))


static func legendary_pool_species_ids(pool_id: String) -> Array[String]:
    var normalized_pool_id: String = pool_id.strip_edges().to_lower()
    if normalized_pool_id.is_empty():
        return []

    var rules: Dictionary = _load_rules()
    var endgame_value: Variant = rules.get("planned_endgame", {})
    if not (endgame_value is Dictionary):
        return []

    var pools_value: Variant = (endgame_value as Dictionary).get("legendary_pools", {})
    if not (pools_value is Dictionary):
        return []

    var ids_value: Variant = (pools_value as Dictionary).get(normalized_pool_id, [])
    if not (ids_value is Array):
        return []

    var ids: Array[String] = []
    for value: Variant in ids_value:
        var species_id: String = str(value).strip_edges().to_lower()
        if not species_id.is_empty() and not ids.has(species_id):
            ids.append(species_id)
    return ids


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

    var stages_value: Variant = endgame.get("stages", [])
    if not (stages_value is Array):
        return {}

    var stage_rule: Dictionary = {}
    for stage_value: Variant in stages_value:
        if not (stage_value is Dictionary):
            continue
        var candidate: Dictionary = stage_value as Dictionary
        if int(candidate.get("stage", -1)) == current_stage:
            stage_rule = candidate.duplicate(true)
            break

    if stage_rule.is_empty():
        return {}

    var is_legendary_stage: bool = str(stage_rule.get("species_mode", "")) == "random_legendary_pool"
    var profile_key: String = "legendary_profile" if is_legendary_stage else "boss_profile"
    var profile_value: Variant = endgame.get(profile_key, endgame.get("boss_profile", {}))
    var profile: Dictionary = {}
    if profile_value is Dictionary:
        profile = (profile_value as Dictionary).duplicate(true)

    profile.merge(stage_rule, true)
    profile["level_offset"] = int(profile.get("level_offset", 5))
    profile["hp_multiplier"] = maxf(1.0, float(profile.get("hp_multiplier", 4.0)))
    profile["hp_bars"] = maxi(1, int(profile.get("hp_bars", 4)))
    profile["atb_rate_multiplier"] = maxf(0.0, float(profile.get("atb_rate_multiplier", 1.0)))
    profile["enabled"] = bool(endgame.get("enabled", false))
    profile["planned_endgame"] = true
    profile["legendary_stage"] = is_legendary_stage
    return profile


static func boss_profile_for_stage(current_stage: int) -> Dictionary:
    if planned_endgame_enabled():
        var endgame_profile: Dictionary = planned_endgame_profile_for_stage(current_stage)
        if not endgame_profile.is_empty():
            return endgame_profile
    return standard_boss_profile()
