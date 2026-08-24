extends "res://scripts/battle_demo_feedback_queue_v1.gd"

# Final V22 integrity for semi-invulnerable charge states.
#
# Smack Down (Katapult) already removes the airborne state and restores the
# sprite in the Squirtle-family runtime. V22 additionally requires the active
# Fly/Bounce two-phase sequence itself to be cancelled. Without clearing the
# generic charge state, the grounded Pokemon would still auto-fire the stored
# second phase at its next own action.

const V22_SMACK_DOWN_CANCELLED_CHARGES: Array[String] = ["fly", "bounce"]


func _sf_apply_smack_down(snapshots: Dictionary) -> void:
    super._sf_apply_smack_down(snapshots)
    _v22_cancel_air_charge_after_smack_down(snapshots)


func _v22_cancel_air_charge_after_smack_down(snapshots: Dictionary) -> void:
    for entry_value: Variant in snapshots.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        if not _sf_entry_was_hit(entry):
            continue

        var target_value: Variant = entry.get("target", {})
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var charge_move: String = str(target.get("db_charge_move", ""))
        if not V22_SMACK_DOWN_CANCELLED_CHARGES.has(charge_move):
            continue

        target["db_charge_move"] = ""
        target["db_charge_target_id"] = ""
        target["db_charge_firing"] = false
        _v22_clear_charge_slot(target)
        _spawn_feedback_label(target, "🪨 LUFTPHASE ABGEBROCHEN", Color("d3bd9b"))
