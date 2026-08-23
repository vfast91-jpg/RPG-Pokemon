extends "res://scripts/battle_demo_ad_final_v1.gd"

# Topmost local-PvP guard for the currently active battle stack.
#
# The historical PvP layer lives much lower in the inheritance chain. New combat
# packages may legitimately override AI/controller hooks above it. This guard is
# therefore kept at the very top of the active BattleDemo script so Player 2 can
# never silently fall back to AI while pvp_mode is active.
#
# PvP draft generation is deliberately independent from route encounter rarity:
# every fully playable Pokemon form that is valid at the selected level appears
# exactly once in the catalog. main_pvp.gd shuffles that flat catalog, so every
# eligible Pokemon has the same chance to be offered (apart from the existing
# no-duplicate-in-your-own-team rule).


func pvp_catalog(level: int) -> Array:
    var result: Array = []
    var bounded_level: int = clampi(level, 1, 100)
    var species_value: Variant = data.get("species", {})
    if not (species_value is Dictionary):
        return result

    var species: Dictionary = species_value
    for species_id_value: Variant in species.keys():
        var species_id: String = str(species_id_value)
        if species_id.is_empty():
            continue
        if not _pvp_species_is_available_at_level(species_id, bounded_level):
            continue

        var combatant: Dictionary = _make_combatant(
            "player",
            0,
            {"species_id": species_id, "level": bounded_level}
        )
        var normal_moves: Array = _database_normal_battle_moves(combatant.get("moves", []))
        if normal_moves.is_empty():
            continue

        var types_value: Variant = combatant.get("types", [])
        var types: Array = types_value.duplicate() if types_value is Array else []
        result.append({
            "id": species_id,
            "name": str(combatant.get("name", species_id)),
            "types": types,
            "moves": _move_names(normal_moves),
            "stats": {
                "hp": int(combatant.get("max_hp", 1)),
                "attack": int(combatant.get("attack", 1)),
                "defense": int(combatant.get("defense", 1)),
                "status": int(combatant.get("special", 1)),
                "speed": int(combatant.get("speed", 1))
            }
        })

    result.sort_custom(
        func(a: Variant, b: Variant) -> bool:
            if not (a is Dictionary) or not (b is Dictionary):
                return false
            return str((a as Dictionary).get("name", "")) < str((b as Dictionary).get("name", ""))
    )
    return result


func _enemy_act(actor: Dictionary) -> void:
    if pvp_mode:
        _prompt_player(actor)
        return
    super._enemy_act(actor)


func _prompt_player(actor: Dictionary) -> void:
    super._prompt_player(actor)
    if not pvp_mode:
        return
    if not paused or selected_actor.is_empty():
        return
    if str(selected_actor.get("id", "")) != str(actor.get("id", "")):
        return

    var player_number: int = 1 if str(actor.get("side", "")) == "player" else 2
    _set_log(
        "[b]SPIELER %d[/b] · [b]%s[/b] ist bereit. Wähle eine Aktion."
        % [player_number, _actor_name(actor)]
    )
