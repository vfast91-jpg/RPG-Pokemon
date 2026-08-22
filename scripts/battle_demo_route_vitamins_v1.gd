extends "res://scripts/battle_demo_cleffa_family.gd"

# Route-only permanent vitamin bonuses.
# Species base stats remain canonical. Individual route members may carry a
# `vitamin_bonuses` dictionary that is added only when their combatant is built
# for a route battle. Normal combat-lab/PvP combatants are therefore untouched.

const ROUTE_VITAMIN_KEYS: Array[String] = ["hp", "attack", "defense", "special", "speed"]


func _route_apply_state(combatant: Dictionary, state: Dictionary) -> void:
    super._route_apply_state(combatant, state)

    var bonuses_value: Variant = state.get("vitamin_bonuses", {})
    if not (bonuses_value is Dictionary):
        return
    var bonuses: Dictionary = bonuses_value

    for stat_key: String in ["attack", "defense", "special", "speed"]:
        var bonus: int = maxi(0, int(bonuses.get(stat_key, 0)))
        if bonus > 0:
            combatant[stat_key] = int(combatant.get(stat_key, 0)) + bonus

    var hp_bonus: int = maxi(0, int(bonuses.get("hp", 0)))
    if hp_bonus <= 0:
        return

    var base_max_hp: int = maxi(1, int(combatant.get("max_hp", 1)))
    var effective_max_hp: int = base_max_hp + hp_bonus
    var stored_hp: int = clampi(
        int(state.get("hp", effective_max_hp)),
        0,
        effective_max_hp
    )

    combatant["max_hp"] = effective_max_hp
    combatant["hp"] = stored_hp
    combatant["alive"] = stored_hp > 0
