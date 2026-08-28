extends "res://scripts/demo_route_capture_button_fix_v1.gd"

# Generation-3 legendary endgame integration.
#
# Stages 96-98 and 99-100 keep the existing two legendary strength pools and
# their uniqueness rules. Deoxys deliberately occupies exactly ONE slot in the
# configured pool. Only after that slot wins the primary draw do we roll again
# between its four independently implemented forms.

const Gen3EndgameBossRules = preload("res://scripts/route_boss_rules.gd")
const DEOXYS_POOL_ENTRY: String = "deoxys"
const DEOXYS_FORMS: Array[String] = [
    "deoxys",
    "deoxys-attack",
    "deoxys-defense",
    "deoxys-speed"
]


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
