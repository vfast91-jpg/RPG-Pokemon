extends "res://scripts/battle_demo_active_marker.gd"

const MoveEffectRegistry = preload("res://scripts/battle/move_effect_registry.gd")

# Final database move-preview layer.
# Keeps the fixed battle info strip readable for mechanics whose runtime names
# are intentionally technical (db_*). The combat rules themselves remain in
# the database effect layer; this file only translates them for the player.


func _target_name(rule: String) -> String:
    match rule:
        "enemy_field":
            return "gegnerische Feldseite"
        "global_battlefield", "battlefield":
            return "gesamtes Kampffeld"
        _:
            return super._target_name(rule)


func _compact_effect_summary(move: Dictionary) -> String:
    var base_summary: String = super._compact_effect_summary(move)
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return _append_effective_speed_power_summary(move, base_summary)

    var result: String = base_summary
    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        var kind: String = str(mechanic.get("kind", ""))

        match kind:
            "db_light_screen":
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

            "db_guaranteed_crit":
                result = _replace_database_mechanic_label(
                    result,
                    kind,
                    "nächster eigener Aktionsversuch: Volltreffer garantiert"
                )

            "db_toxic_spikes":
                var max_layers: int = maxi(1, int(mechanic.get("max_layers", 2)))
                result = _replace_database_mechanic_label(
                    result,
                    kind,
                    "Giftspitzen: 1 Lage pro Einsatz (max. %d) · Auslösung bei physischer Kontaktattacke"
                    % max_layers
                )

            "db_equalize_hp":
                result = _replace_database_mechanic_label(
                    result,
                    kind,
                    _endeavor_damage_summary(move)
                )

            _:
                if kind.begins_with("db_"):
                    var player_label: String = MoveEffectRegistry.player_label_for_effect(kind)
                    if not player_label.is_empty():
                        result = _replace_database_mechanic_label(
                            result,
                            kind,
                            player_label
                        )

    return _append_effective_speed_power_summary(move, result)


func _append_effective_speed_power_summary(move: Dictionary, source: String) -> String:
    var runtime_value: Variant = move.get("runtime", {})
    if not (runtime_value is Dictionary):
        return source
    var runtime: Dictionary = runtime_value
    if not bool(runtime.get("timeflow_effective_speed_power", false)):
        return source

    var power_tiers_value: Variant = runtime.get("power_tiers", [])
    var note: String = "Stärke abhängig vom aktuellen Geschwindigkeitsverhältnis Anwender/Ziel"
    if power_tiers_value is Array and not (power_tiers_value as Array).is_empty():
        var power_tiers: Array = power_tiers_value
        var minimum_power: int = int(power_tiers[0])
        var maximum_power: int = minimum_power
        for tier_value: Variant in power_tiers:
            var tier: int = int(tier_value)
            minimum_power = mini(minimum_power, tier)
            maximum_power = maxi(maximum_power, tier)
        note = (
            "Stärke %d–%d · abhängig vom aktuellen Geschwindigkeitsverhältnis Anwender/Ziel"
            % [minimum_power, maximum_power]
        )

    if source.is_empty():
        return note
    if source.contains("Geschwindigkeitsverhältnis"):
        return source
    return source + " · " + note


func _endeavor_damage_summary(move: Dictionary) -> String:
    var generic: String = "Schaden: positive KP-Differenz (Ziel-KP − eigene KP)"
    if selected_actor.is_empty():
        return generic

    var target_rule: String = str(move.get("target", "enemy_highest_aggro"))
    var current_targets: Array = _targets(selected_actor, target_rule)
    if current_targets.size() != 1 or not (current_targets[0] is Dictionary):
        return generic

    var target: Dictionary = current_targets[0]
    var target_name: String = _actor_name(target)
    var move_type: String = str(move.get("type", "normal"))
    var defender_types: Array = _type_array(target.get("types", []))
    if TypeSystem.get_multiplier(move_type, defender_types) <= 0.0:
        return "Schaden jetzt gegen %s: 0 KP (immun)" % target_name

    var actor_hp: int = maxi(0, int(selected_actor.get("hp", 0)))
    var target_hp: int = maxi(0, int(target.get("hp", 0)))
    var damage: int = maxi(0, target_hp - actor_hp)
    if damage <= 0:
        return (
            "Schaden jetzt gegen %s: 0 KP (Ziel hat nicht mehr KP als Anwender)"
            % target_name
        )

    return (
        "Schaden jetzt gegen %s: %d KP · danach Ziel-KP = eigene aktuelle KP"
        % [target_name, damage]
    )


func _replace_database_mechanic_label(
    source: String,
    kind: String,
    replacement: String
) -> String:
    var text: String = source
    text = text.replace(kind, replacement)
    text = text.replace(kind.replace("_", " "), replacement)
    return text
