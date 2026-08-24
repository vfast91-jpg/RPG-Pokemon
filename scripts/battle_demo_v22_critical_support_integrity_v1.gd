extends "res://scripts/battle_demo_ditto_transform_integrity_v1.gd"

# Final V22 critical-support integrity layer.
#
# Focus Energy and Dragon Cheer use the same central Status soft-cap formulas in
# the inherited runtime. V22 additionally requires them to be mutually exclusive
# in both use orders. The inherited Dragon Cheer eligibility already blocks
# Dragon Cheer when Focus Energy is active; this layer closes the inverse path
# because the later Status-softcap handler otherwise consumes critical_focus
# before the older migration guard can see it.


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if (
        str(mechanic.get("kind", "")) == "critical_focus"
        and _v22_focus_energy_blocked_by_dragon_cheer(actor)
    ):
        _spawn_feedback_label(actor, "✖ KRIT-BONUS BEREITS AKTIV", Color("d9a5a5"))
        return 0.0
    return super._effect(actor, target, mechanic)


func _v22_focus_energy_blocked_by_dragon_cheer(actor: Dictionary) -> bool:
    return int(actor.get("cf_dragon_cheer_actions", 0)) > 0
