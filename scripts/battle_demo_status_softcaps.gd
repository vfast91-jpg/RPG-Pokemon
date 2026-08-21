extends "res://scripts/battle_demo_uncapped_light_screen.gd"

# Central soft-cap scaling for Status-based effects with a natural 100% ceiling.
#
# Formula:
#     effect_percent = max_percent * Status / (curve + Status)
#
# This keeps every additional Status point useful while effects with a natural
# percentage ceiling only approach 100% instead of reaching a hard breakpoint.
# Weather and the generic buff/debuff safety clamps intentionally stay unchanged.

const STATUS_SOFTCAP_MAX_PERCENT: float = 100.0
const FOCUS_ENERGY_CURVE: float = 75.0
const HEALING_CURVE: float = 50.0
const LIGHT_SCREEN_CURVE: float = 50.0


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["db_focus_energy_bonus_pp"] = 0.0
    return combatant


func _status_softcap_percent(
    status_value: float,
    curve: float,
    max_percent: float = STATUS_SOFTCAP_MAX_PERCENT
) -> float:
    var status: float = maxf(0.0, status_value)
    var safe_curve: float = maxf(0.001, curve)
    var safe_max: float = maxf(0.0, max_percent)
    if status <= 0.0 or safe_max <= 0.0:
        return 0.0
    return safe_max * status / (safe_curve + status)


func _softcap_from_mechanic(
    actor: Dictionary,
    mechanic: Dictionary,
    default_curve: float
) -> float:
    return _status_softcap_percent(
        float(actor.get("special", 0.0)),
        float(mechanic.get("softcap_curve", default_curve)),
        float(mechanic.get("softcap_max", STATUS_SOFTCAP_MAX_PERCENT))
    )


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    if kind == "critical_focus":
        var bonus_pp: float = _softcap_from_mechanic(actor, mechanic, FOCUS_ENERGY_CURVE)
        actor["db_focus_energy_bonus_pp"] = bonus_pp
        _spawn_feedback_label(actor, "🎯 KRIT +%.0f%%" % bonus_pp, Color("f3dc85"))
        return bonus_pp / 10.0

    if kind == "db_heal_self":
        var heal_percent: float = _softcap_from_mechanic(actor, mechanic, HEALING_CURVE)
        var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
        if missing <= 0 or heal_percent <= 0.0:
            return 0.0
        var amount: int = mini(
            missing,
            maxi(1, int(round(float(actor.get("max_hp", 1)) * heal_percent / 100.0)))
        )
        actor["hp"] = int(actor.get("hp", 0)) + amount
        if amount > 0:
            _spawn_feedback_label(actor, "💚 +" + str(amount) + " KP", Color("8fe39b"))
        return float(amount)

    if kind == "db_light_screen":
        var reduction_percent: float = _softcap_from_mechanic(actor, mechanic, LIGHT_SCREEN_CURVE)
        target["db_light_screen_reduction"] = reduction_percent / 100.0
        target["db_light_screen_source_id"] = str(actor.get("id", ""))
        target["db_light_screen_expires_source_action"] = (
            int(actor.get("action_serial", 0))
            + maxi(1, int(mechanic.get("duration_actions", 3)))
        )
        return reduction_percent / 10.0

    return super._effect(actor, target, mechanic)


func _critical_chance(combatant: Dictionary) -> float:
    var chance: float = super._critical_chance(combatant)
    var focus_bonus: float = maxf(0.0, float(combatant.get("db_focus_energy_bonus_pp", 0.0))) / 100.0
    return clampf(chance + focus_bonus, 0.0, 1.0)


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    var status_value: float = 0.0 if selected_actor.is_empty() else maxf(0.0, float(selected_actor.get("special", 0.0)))

    if move_id == "focus_energy":
        if not selected_actor.is_empty():
            var bonus_pp: int = int(round(_status_softcap_percent(status_value, FOCUS_ENERGY_CURVE)))
            return (
                "Volltrefferchance +%d Prozentpunkte (Status %d) · "
                + "jeder weitere Statuspunkt wirkt weiter · bis Wechsel/Kampfende · nicht stapelbar"
            ) % [bonus_pp, int(round(status_value))]
        return "Volltrefferbonus folgt einer Status-Soft-Cap-Kurve · bis Wechsel/Kampfende · nicht stapelbar"

    if move_id == "synthesis" or move_id == "roost":
        var suffix: String = ""
        if move_id == "roost":
            suffix = " · Flug-Typ bis zur nächsten eigenen Aktion entfernt"
        if not selected_actor.is_empty():
            var heal_percent: int = int(round(_status_softcap_percent(status_value, HEALING_CURVE)))
            return (
                "Heilt %d%% der Max-KP (Status %d, Soft-Cap) · Status skaliert ohne harten Endpunkt"
                + suffix
            ) % [heal_percent, int(round(status_value))]
        return "Heilung folgt einer Status-Soft-Cap-Kurve gegen 100%% · kein harter Status-Endpunkt" + suffix

    if move_id == "light_screen":
        var duration: int = 3
        var mechanics_value: Variant = move.get("mechanics", [])
        if mechanics_value is Array:
            for mechanic_value: Variant in mechanics_value:
                if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "db_light_screen":
                    duration = maxi(1, int((mechanic_value as Dictionary).get("duration_actions", 3)))
                    break
        if not selected_actor.is_empty():
            var reduction_percent: int = int(round(_status_softcap_percent(status_value, LIGHT_SCREEN_CURVE)))
            return (
                "Spezial-Attacken gegen alle Verbündeten: −%d%% Schaden (Status %d, Soft-Cap) · "
                + "physische Attacken unverändert · hält %d eigene Aktionen des Anwenders"
            ) % [reduction_percent, int(round(status_value)), duration]
        return (
            "Spezial-Schadensreduktion folgt einer Status-Soft-Cap-Kurve gegen 100%% · "
            + "physische Attacken unverändert · hält %d eigene Aktionen des Anwenders"
        ) % duration

    return super._compact_effect_summary(move)
