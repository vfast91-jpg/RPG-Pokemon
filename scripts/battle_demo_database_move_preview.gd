extends "res://scripts/battle_demo_active_marker.gd"

# Final database move-preview layer.
# Keeps the fixed battle info strip readable for mechanics whose runtime names
# are intentionally technical (db_*). The combat rules themselves remain in
# the database effect layer; this file only translates them for the player.


func _compact_effect_summary(move: Dictionary) -> String:
    var base_summary: String = super._compact_effect_summary(move)
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return base_summary

    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        if str(mechanic.get("kind", "")) != "db_light_screen":
            continue

        var cap: float = maxf(0.0, float(mechanic.get("strength_cap", 50.0)))
        var duration: int = maxi(1, int(mechanic.get("duration_actions", 3)))
        var cap_percent: int = int(round(cap))

        if not selected_actor.is_empty():
            var status_value: float = maxf(0.0, float(selected_actor.get("special", 0.0)))
            var reduction_percent: int = int(round(minf(status_value, cap)))
            return (
                "Spezial-Attacken gegen alle Verbündeten: −%d%% Schaden "
                + "(Status %d, max. %d%%) · physische Attacken unverändert "
                + "· hält %d eigene Aktionen des Anwenders"
            ) % [
                reduction_percent,
                int(round(status_value)),
                cap_percent,
                duration
            ]

        return (
            "Spezial-Attacken gegen alle Verbündeten: Schaden −Status%% "
            + "(max. %d%%) · physische Attacken unverändert "
            + "· hält %d eigene Aktionen des Anwenders"
        ) % [cap_percent, duration]

    return base_summary
