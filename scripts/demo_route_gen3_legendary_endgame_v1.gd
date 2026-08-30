extends "res://scripts/demo_route_capture_button_fix_v1.gd"

# Generation-3 legendary endgame integration.
#
# Stages 96-98 and 99-100 keep the existing two legendary strength pools and
# their uniqueness rules. Deoxys deliberately occupies exactly ONE slot in the
# configured pool. Only after that slot wins the primary draw do we roll again
# between its four independently implemented forms.
#
# The selected endgame target is prepared at the canonical stage-start save.
# Reloading that checkpoint therefore never rerolls the legendary target.
# Its battle landscape is derived deterministically from the selected species'
# types and the existing landscapes_v1.json metadata. The route landscape itself
# is never changed, so stages 91-95 and normal route encounters remain untouched.

const Gen3EndgameBossRules = preload("res://scripts/route_boss_rules.gd")
const DEOXYS_POOL_ENTRY: String = "deoxys"
const DEOXYS_FORMS: Array[String] = [
    "deoxys",
    "deoxys-attack",
    "deoxys-defense",
    "deoxys-speed"
]
const LEGENDARY_LANDSCAPE_PREFERRED_SCORE: int = 100
const LEGENDARY_LANDSCAPE_RARE_SCORE: int = 25
const LEGENDARY_LANDSCAPE_EXCLUDED_SCORE: int = -1000000
const LEGENDARY_ENDGAME_HEADING: String = "✨ LEGENDÄRES POKÉMON"
const LEGENDARY_ENDGAME_BUTTON_TEXT: String = "✨ LEGENDÄRES POKÉMON HERAUSFORDERN  →"
const LEGENDARY_LANDSCAPE_OVERRIDES: Dictionary = {
    # Tiny iconic overrides only where pure type scoring would pick a less
    # characteristic equal/better match from the existing landscape registry.
    "groudon": "volcano",
    "rayquaza": "mystic"
}

var canonical_endgame_target_stage: int = 0
var canonical_endgame_target_species_id: String = ""
var canonical_endgame_target_level: int = 0


func start_route() -> void:
    canonical_endgame_target_stage = 0
    canonical_endgame_target_species_id = ""
    canonical_endgame_target_level = 0
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    if not _tf_is_legendary_endgame_stage(stage):
        return

    var profile: Dictionary = Gen3EndgameBossRules.boss_profile_for_stage(stage)
    var level_offset: int = int(profile.get("level_offset", 10))
    var hp_bars: int = maxi(1, int(profile.get("hp_bars", 4)))
    var target_id: String = ""
    if canonical_endgame_target_stage == stage:
        target_id = canonical_endgame_target_species_id

    var target_line: String = "Ein legendäres Pokémon wartet auf deine Herausforderung."
    var landscape_line: String = "Der Kampfort wird automatisch passend zu seinen Typen gewählt."
    if not target_id.is_empty():
        target_line = "Dein nächstes legendäres Ziel ist [b]%s[/b]." % _tf_species_display_name(target_id)
        var landscape_id: String = _tf_legendary_landscape_id_for_species(target_id)
        var landscape: Dictionary = route_landscape(landscape_id)
        if not landscape.is_empty():
            landscape_line = "Kampfort: [b]%s[/b]." % str(landscape.get("name", landscape_id))

    var prefix: String = _tf_legendary_visible_message(message)
    if not prefix.is_empty():
        prefix += "\n\n"

    event_label.text = (
        prefix
        + "[b]%s · ETAPPE %d/%d[/b]\n"
        + "%s\n%s\n\n"
        + "Herausforderung: höchstes eigenes Pokémon [b]%+d Level[/b] · "
        + "[b]%d vollständige KP-Leisten[/b]."
    ) % [
        LEGENDARY_ENDGAME_HEADING,
        stage,
        ENDGAME_ROUTE_STAGE_COUNT,
        target_line,
        landscape_line,
        level_offset,
        hp_bars
    ]

    for child: Node in path_box.get_children():
        if not (child is Button):
            continue
        var challenge_button: Button = child as Button
        challenge_button.text = LEGENDARY_ENDGAME_BUTTON_TEXT
        challenge_button.tooltip_text = "Fordere das legendäre Pokémon auf Etappe %d heraus." % stage


func _begin_endgame_boss() -> void:
    if not _tf_is_legendary_endgame_stage(stage):
        super._begin_endgame_boss()
        return

    # Resolve once through the canonical target cache before the inherited
    # battle construction runs. That preserves all existing boss mechanics while
    # ensuring an unavailable legendary never falls through to a Boss-labelled
    # error on the player-facing 96-100 path.
    if not _prepare_canonical_endgame_target():
        event_label.text = (
            "Für das legendäre Pokémon auf Etappe %d ist aktuell keine vollständig spielbare Spezies verfügbar."
            % stage
        )
        return

    super._begin_endgame_boss()


func _prepare_canonical_endgame_target() -> bool:
    if stage < ENDGAME_STAGE_START or stage > ENDGAME_STAGE_END:
        return true
    if (
        canonical_endgame_target_stage == stage
        and not canonical_endgame_target_species_id.is_empty()
        and canonical_endgame_target_level > 0
    ):
        return true
    if battle_demo == null:
        return false

    var profile: Dictionary = Gen3EndgameBossRules.boss_profile_for_stage(stage)
    if profile.is_empty():
        return false

    var boss_level: int = maxi(
        1,
        _highest_team_level() + int(profile.get("level_offset", 5))
    )
    # Resolve through the inherited endgame policy exactly once. This includes
    # pool uniqueness and the second Deoxys-form roll when that pool slot wins.
    var species_id: String = super._endgame_species_for_profile(profile, boss_level)
    if species_id.is_empty():
        return false

    canonical_endgame_target_stage = stage
    canonical_endgame_target_species_id = species_id
    canonical_endgame_target_level = boss_level
    return true


func _endgame_species_for_profile(profile: Dictionary, boss_level: int) -> String:
    if (
        canonical_endgame_target_stage == stage
        and canonical_endgame_target_level == boss_level
        and not canonical_endgame_target_species_id.is_empty()
    ):
        return canonical_endgame_target_species_id
    return super._endgame_species_for_profile(profile, boss_level)


func _pick_available_legendary_pool_species(pool_id: String, unique_within_pool: bool) -> String:
    if pool_id.is_empty() or battle_demo == null:
        return ""

    var pool_species: Array[String] = Gen3EndgameBossRules.legendary_pool_species_ids(pool_id)
    if not pool_species.has(DEOXYS_POOL_ENTRY):
        return super._pick_available_legendary_pool_species(pool_id, unique_within_pool)

    var used: Array = []
    var used_value: Variant = _endgame_pool_picks.get(pool_id, [])
    if used_value is Array:
        used = (used_value as Array).duplicate()

    var candidates: Array[String] = []
    for species_id: String in pool_species:
        if unique_within_pool and used.has(species_id):
            continue

        if species_id == DEOXYS_POOL_ENTRY:
            if _available_deoxys_forms().is_empty():
                continue
        elif not battle_demo.route_species_is_available(species_id):
            continue

        candidates.append(species_id)

    if candidates.is_empty():
        return ""

    var selected_entry: String = str(candidates.pick_random())
    if unique_within_pool:
        # Store the pool entry, not the resolved form. This is what makes all
        # four Deoxys forms collectively count as one legendary encounter.
        used.append(selected_entry)
        _endgame_pool_picks[pool_id] = used

    if selected_entry != DEOXYS_POOL_ENTRY:
        return selected_entry

    var available_forms: Array[String] = _available_deoxys_forms()
    if available_forms.is_empty():
        return ""
    return str(available_forms.pick_random())


func _available_deoxys_forms() -> Array[String]:
    var available: Array[String] = []
    if battle_demo == null:
        return available

    for form_id: String in DEOXYS_FORMS:
        if battle_demo.route_species_is_available(form_id):
            available.append(form_id)
    return available


func _tf_is_legendary_endgame_stage(current_stage: int) -> bool:
    if current_stage < ENDGAME_LEGENDARY_STAGE_START or current_stage > ENDGAME_STAGE_END:
        return false
    var profile: Dictionary = Gen3EndgameBossRules.boss_profile_for_stage(current_stage)
    return bool(profile.get("legendary_stage", false))


func _tf_legendary_landscape_id_for_species(species_id: String) -> String:
    _tf_load_landscape_registry()
    var normalized_species: String = species_id.strip_edges().to_lower()
    var override_id: String = str(LEGENDARY_LANDSCAPE_OVERRIDES.get(normalized_species, ""))
    if not override_id.is_empty() and not route_landscape(override_id).is_empty():
        return override_id

    var species_types: Array[String] = _tf_species_types(normalized_species)
    if species_types.is_empty():
        # Defensive fallback for incomplete runtime data. This is still an
        # encounter-specific battle override and never inherits the route scene.
        if not route_landscape("mystic").is_empty():
            return "mystic"
        var fallback_ids: Array[String] = _tf_sorted_landscape_ids()
        return fallback_ids[0] if not fallback_ids.is_empty() else ""

    var best_id: String = ""
    var best_score: int = LEGENDARY_LANDSCAPE_EXCLUDED_SCORE
    for landscape_id: String in _tf_sorted_landscape_ids():
        var landscape: Dictionary = route_landscape(landscape_id)
        if str(landscape.get("background", "")).strip_edges().is_empty():
            continue
        var score: int = _tf_legendary_landscape_score(landscape, species_types)
        if score > best_score:
            best_score = score
            best_id = landscape_id

    if best_id.is_empty() or best_score <= LEGENDARY_LANDSCAPE_EXCLUDED_SCORE:
        return "mystic" if not route_landscape("mystic").is_empty() else best_id
    return best_id


func _tf_legendary_landscape_score(landscape: Dictionary, species_types: Array[String]) -> int:
    var excluded: Array[String] = _tf_normalized_type_list(landscape.get("excluded_types", []))
    for species_type: String in species_types:
        if excluded.has(species_type):
            return LEGENDARY_LANDSCAPE_EXCLUDED_SCORE

    var preferred: Array[String] = _tf_normalized_type_list(landscape.get("preferred_types", []))
    var rare: Array[String] = _tf_normalized_type_list(landscape.get("rare_types", []))
    var score: int = 0
    for species_type: String in species_types:
        if preferred.has(species_type):
            score += LEGENDARY_LANDSCAPE_PREFERRED_SCORE
        elif rare.has(species_type):
            score += LEGENDARY_LANDSCAPE_RARE_SCORE
    return score


func _tf_apply_legendary_endgame_battle_landscape_for_species(
    current_stage: int,
    species_id: String
) -> bool:
    if not _tf_is_legendary_endgame_stage(current_stage):
        return false
    var landscape_id: String = _tf_legendary_landscape_id_for_species(species_id)
    if landscape_id.is_empty():
        return false
    return _tf_apply_battle_landscape_only(landscape_id)


func _tf_apply_battle_landscape_only(landscape_id: String) -> bool:
    var landscape: Dictionary = route_landscape(landscape_id)
    if landscape.is_empty():
        return false

    var background_path: String = str(landscape.get("background", "")).strip_edges()
    if background_path.is_empty():
        return false

    var active_battle_demo: Node = battle_demo as Node
    if active_battle_demo == null:
        var parent: Node = get_parent()
        if parent != null:
            active_battle_demo = parent.get_node_or_null("BattleDemo")
    if active_battle_demo == null:
        return false

    var framing_value: Variant = landscape.get("battle_framing", {})
    var framing: Dictionary = framing_value as Dictionary if framing_value is Dictionary else {}
    if active_battle_demo.has_method("set_battle_background_framed"):
        active_battle_demo.call("set_battle_background_framed", background_path, framing)
        return true
    if active_battle_demo.has_method("set_battle_background"):
        active_battle_demo.call("set_battle_background", background_path)
        return true
    return false


func _tf_species_types(species_id: String) -> Array[String]:
    if battle_demo == null:
        return []
    var data_value: Variant = battle_demo.get("data")
    if not (data_value is Dictionary):
        return []
    var species_value: Variant = (data_value as Dictionary).get("species", {})
    if not (species_value is Dictionary):
        return []
    var entry_value: Variant = (species_value as Dictionary).get(species_id, {})
    if not (entry_value is Dictionary):
        return []
    return _tf_normalized_type_list((entry_value as Dictionary).get("types", []))


func _tf_species_display_name(species_id: String) -> String:
    if battle_demo != null:
        var data_value: Variant = battle_demo.get("data")
        if data_value is Dictionary:
            var species_value: Variant = (data_value as Dictionary).get("species", {})
            if species_value is Dictionary:
                var entry_value: Variant = (species_value as Dictionary).get(species_id, {})
                if entry_value is Dictionary:
                    var display_name: String = str((entry_value as Dictionary).get("name", "")).strip_edges()
                    if not display_name.is_empty():
                        return display_name
    return species_id.replace("-", " ").capitalize()


func _tf_normalized_type_list(value: Variant) -> Array[String]:
    var result: Array[String] = []
    if not (value is Array):
        return result
    for entry_value: Variant in value:
        var normalized: String = str(entry_value).strip_edges().to_lower()
        if not normalized.is_empty() and not result.has(normalized):
            result.append(normalized)
    return result


func _tf_sorted_landscape_ids() -> Array[String]:
    _tf_load_landscape_registry()
    var ids: Array[String] = []
    for key_value: Variant in _landscape_by_id.keys():
        ids.append(str(key_value))
    ids.sort()
    return ids


func _tf_legendary_visible_message(message: String) -> String:
    # Only stage 96-100 uses this sanitized player-facing copy. Internal class,
    # function and data names deliberately retain their established boss terms.
    return message.replace("SUPERBOSS", "LEGENDÄRES POKÉMON").replace(
        "Superboss", "legendäres Pokémon"
    ).replace("Bosskampf", "legendären Kampf").replace("Boss", "legendäres Pokémon")
