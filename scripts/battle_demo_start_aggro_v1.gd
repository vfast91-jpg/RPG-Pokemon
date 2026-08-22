extends "res://scripts/battle_demo_route_vitamins_v1.gd"

const StartAggroRules = preload("res://scripts/battle/start_aggro_rules.gd")

# Final start-Aggro layer.
# Start threat is based on both level and the species' five Timeflow base stats:
# HP + Attack + Defense + Status (internal: special) + Speed.
# Individual runtime stat changes, vitamins and temporary modifiers deliberately
# do not alter this initial species-strength contribution.
#
# Audio is intentionally NOT implemented in this inheritance chain anymore.
# The top-level main_audio.gd observes BattleDemo and handles music/SFX without
# adding dependencies between presentation and Pokemon family scripts.


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    var species: Dictionary = {}
    var species_all_value: Variant = data.get("species", {})
    if species_all_value is Dictionary:
        var species_value: Variant = (species_all_value as Dictionary).get(
            str(combatant.get("species_id", setup.get("species_id", ""))),
            {}
        )
        if species_value is Dictionary:
            species = species_value

    combatant["aggro"] = StartAggroRules.calculate(
        species,
        int(combatant.get("level", setup.get("level", 1)))
    )
    return combatant
