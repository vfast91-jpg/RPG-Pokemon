extends "res://scripts/battle_demo_database_move_preview.gd"

# Light Screen balance correction.
#
# The previous database/runtime rule capped Status scaling at 50%. That made
# additional Status points irrelevant for this move. Light Screen now uses the
# acting Pokemon's full current Status value. Other move/system caps are left
# untouched until they are reviewed separately.

var _light_screen_parent_damage_pass: bool = false


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) != "db_light_screen":
        return super._effect(actor, target, mechanic)

    var status_percent: float = maxf(0.0, float(actor.get("special", 0.0)))
    var reduction: float = status_percent / 100.0
    target["db_light_screen_reduction"] = reduction
    target["db_light_screen_source_id"] = str(actor.get("id", ""))
    target["db_light_screen_expires_source_action"] = (
        int(actor.get("action_serial", 0))
        + maxi(1, int(mechanic.get("duration_actions", 3)))
    )
    return status_percent / 10.0


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    # Prevent the inherited database layer from applying its old hard 50% cap.
    _light_screen_parent_damage_pass = true
    var damage: int = super._damage(actor, target, power, move_type, category)
    _light_screen_parent_damage_pass = false

    if damage <= 0 or category != "special" or not _uncapped_light_screen_is_active(target):
        return damage

    var reduction: float = maxf(0.0, float(target.get("db_light_screen_reduction", 0.0)))
    var remaining_multiplier: float = maxf(0.0, 1.0 - reduction)
    return maxi(0, int(round(float(damage) * remaining_multiplier)))


func _database_light_screen_is_active(target: Dictionary) -> bool:
    # battle_demo_database_effects.gd asks this while calculating damage. During
    # that parent pass we deliberately answer false so its legacy 50% clamp is
    # skipped; this layer applies the current rule immediately afterwards.
    if _light_screen_parent_damage_pass:
        return false
    return _uncapped_light_screen_is_active(target)


func _uncapped_light_screen_is_active(target: Dictionary) -> bool:
    var source_id: String = str(target.get("db_light_screen_source_id", ""))
    if source_id.is_empty():
        return false

    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if str(candidate.get("id", "")) != source_id:
            continue
        return (
            bool(candidate.get("alive", false))
            and int(candidate.get("action_serial", 0))
                < int(target.get("db_light_screen_expires_source_action", 0))
        )
    return false


func _compact_effect_summary(move: Dictionary) -> String:
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            var mechanic: Dictionary = mechanic_value
            if str(mechanic.get("kind", "")) != "db_light_screen":
                continue

            var duration: int = maxi(1, int(mechanic.get("duration_actions", 3)))
            if not selected_actor.is_empty():
                var status_percent: int = maxi(0, int(round(float(selected_actor.get("special", 0.0)))))
                return (
                    "Spezial-Attacken gegen alle Verbündeten: −%d%% Schaden "
                    + "(entspricht Status %d) · physische Attacken unverändert "
                    + "· hält %d eigene Aktionen des Anwenders"
                ) % [status_percent, status_percent, duration]

            return (
                "Spezial-Attacken gegen alle Verbündeten: Schaden −Status%% "
                + "· kein künstliches 50%%-Limit · physische Attacken unverändert "
                + "· hält %d eigene Aktionen des Anwenders"
            ) % duration

    return super._compact_effect_summary(move)
