extends "res://scripts/battle_demo_v22_critical_support_integrity_v1.gd"

# Final V22 effective-speed integrity layer.
#
# Electro Ball compares the acting Pokemon's currently effective Speed with the
# target's currently effective Speed. The inherited implementation compared ATB
# charge rates (12 + 0.62 * Speed), which shifts the canonical 1x/2x/3x/4x
# boundaries. V22 explicitly counts paralysis and real tempo modifiers, while
# current ATB fill, knockback/pause and the RPG-AP recovery cycle do not count.
#
# This final seam also closes the remaining Reflect migration gap. Reflect is a
# team barrier, not a per-ally target-selection move. The move therefore resolves
# once on its caster and fans the barrier state out to the whole living team.
# Its strength uses the same central Status soft-cap as the rest of the final
# runtime: R = Status / (75 + Status). The inherited Pichu-family implementation
# still contains the historical 50% clamp, so the parent damage pass is muted for
# Reflect and the final reduction is applied exactly once here.

var _v22_reflect_parent_damage_pass: bool = false


func _load_data() -> void:
    super._load_data()
    _v22_finalize_reflect_contract()


func _v22_finalize_reflect_contract() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return

    var moves: Dictionary = moves_value
    var reflect_value: Variant = moves.get("reflect", {})
    if not (reflect_value is Dictionary):
        return

    var reflect: Dictionary = reflect_value

    # The barrier has no individual ally target. Resolving once on the caster
    # prevents the UI from presenting every ally as a separate effectiveness
    # target; _effect() below applies the actual barrier to the complete team.
    reflect["target"] = "self"
    reflect["area"] = false
    reflect["status_scaling"] = {
        "uses_statuswert": true,
        "multiplier": 1.0,
        "formula": "R=Status/(75+Status)"
    }
    reflect["special_rules"] = (
        "Team-Barriere gegen physischen Schaden. Reduktion = Status/(75+Status) "
        + "des Anwenders. Dauer bis nach drei eigenen Aktionen des Quellen-Pokémon. "
        + "Durchbruch und andere zentrale Barrierenbrecher entfernen Reflektor."
    )
    reflect["required_behavior_tests"] = [
        "reflect_team_barrier",
        "reflect_physical_only",
        "reflect_status_75_half_damage",
        "reflect_low_high_status",
        "reflect_three_source_actions",
        "reflect_breakable",
        "reflect_no_per_ally_target_selection"
    ]

    var runtime_value: Variant = reflect.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    runtime["runtime_supported"] = true
    runtime["strict_contract"] = true
    runtime["v22_team_barrier"] = true
    runtime["v22_status_softcap"] = true
    reflect["runtime"] = runtime

    moves["reflect"] = reflect
    data["moves"] = moves


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) != "db_reflect":
        return super._effect(actor, target, mechanic)

    var reduction: float = _status_ratio(float(actor.get("special", 0.0)))
    var source_id: String = str(actor.get("id", ""))
    var expires_source_action: int = (
        int(actor.get("action_serial", 0))
        + maxi(1, int(mechanic.get("duration_actions", 3)))
    )
    var protected_count: int = 0

    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue
        candidate["pika_reflect_reduction"] = reduction
        candidate["pika_reflect_source_id"] = source_id
        candidate["pika_reflect_expires_source_action"] = expires_source_action
        protected_count += 1

    if protected_count > 0:
        _spawn_feedback_label(actor, "🛡️ REFLEKTOR · TEAM", Color("cdb7ff"))

    # Preserve the previous team-scaled status-aggro magnitude even though the
    # move now resolves only once instead of once per ally.
    return reduction * 10.0 * float(protected_count)


func _pika_reflect_active(target: Dictionary) -> bool:
    # battle_demo_database_pichu_family.gd asks this during its parent damage
    # pass. Answer false there so the historical 50% clamp is not applied before
    # the final Status-softcap calculation below.
    if _v22_reflect_parent_damage_pass:
        return false
    return super._pika_reflect_active(target)


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    _v22_reflect_parent_damage_pass = true
    var damage: int = super._damage(actor, target, power, move_type, category)
    _v22_reflect_parent_damage_pass = false

    if damage <= 0 or category != "physical" or not _pika_reflect_active(target):
        return damage

    var reduction: float = clampf(
        float(target.get("pika_reflect_reduction", 0.0)),
        0.0,
        0.999999
    )
    return maxi(1, int(round(float(damage) * (1.0 - reduction))))


func _compact_effect_summary(move: Dictionary) -> String:
    if str(move.get("id", "")) != "reflect":
        return super._compact_effect_summary(move)

    var duration: int = 3
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            var mechanic: Dictionary = mechanic_value
            if str(mechanic.get("kind", "")) == "db_reflect":
                duration = maxi(1, int(mechanic.get("duration_actions", 3)))
                break

    if not selected_actor.is_empty():
        var reduction_percent: int = maxi(
            0,
            int(round(_status_percent(float(selected_actor.get("special", 0.0)))))
        )
        return (
            "Physische Attacken gegen das gesamte eigene Team: −%d%% Schaden "
            + "· Spezial-Attacken unverändert · hält %d eigene Aktionen des Anwenders"
        ) % [reduction_percent, duration]

    return (
        "Team-Barriere gegen physischen Schaden · Stärke = Status/(75+Status) "
        + "· Spezial-Attacken unverändert · hält %d eigene Aktionen des Anwenders"
    ) % duration


func _pika_effective_speed_rate(combatant: Dictionary) -> float:
    var effective_speed: float = maxf(0.0, float(combatant.get("speed", 10.0)))
    if bool(combatant.get("paralyzed", false)):
        effective_speed *= 0.5

    # atb_cycle_mod is the central representation of true temporary tempo
    # effects. AP recovery lives in combatant.cycle and is deliberately ignored.
    var tempo_multiplier: float = maxf(
        0.0001,
        _combined_timed_modifier(combatant, "atb_cycle_mod")
    )
    return maxf(0.0001, effective_speed / tempo_multiplier)
