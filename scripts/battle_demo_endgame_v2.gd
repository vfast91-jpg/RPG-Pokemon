extends "res://scripts/battle_demo_endgame_v1.gd"

# Hardening layer: for levels above 100, deliberately build the established
# level-100 combatant first and then apply Timeflow's uncapped continuation.
# This prevents any older layer from preserving a >100 level label while still
# silently calculating level-100 stats.


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var requested_level: int = maxi(1, int(setup.get("level", 1)))
    if requested_level <= 100:
        return super._make_combatant(side, index, setup)

    var capped_setup: Dictionary = setup.duplicate(true)
    capped_setup["level"] = 100
    var combatant: Dictionary = super._make_combatant(side, index, capped_setup)
    var reference_level: int = maxi(1, int(combatant.get("level", 100)))
    _apply_uncapped_level_growth(combatant, requested_level, reference_level)
    return combatant


func route_new_member(species_id: String, level: int) -> Dictionary:
    var requested_level: int = maxi(1, level)
    if requested_level <= 100:
        return super.route_new_member(species_id, requested_level)

    var member: Dictionary = super.route_new_member(species_id, 100)
    var resolved_species: String = route_resolve_species_for_level(species_id, requested_level)
    if resolved_species.is_empty():
        resolved_species = str(member.get("species_id", species_id))

    var snapshot: Dictionary = route_stat_snapshot(resolved_species, requested_level)
    member["species_id"] = resolved_species
    member["name"] = route_species_name(resolved_species)
    member["level"] = requested_level
    member["max_hp"] = maxi(1, int(snapshot.get("max_hp", member.get("max_hp", 1))))
    member["hp"] = int(member["max_hp"])
    member["known_moves"] = route_moves_for_level(resolved_species, requested_level)
    return member
