extends "res://scripts/battle_demo_bulbasaur_family_tm_final.gd"

# Central action-semantics correction.
# Warten is a real own action in Timeflow. Periodic effects that trigger after
# the affected Pokemon's own action therefore resolve after Warten as well.
# This keeps schwere Vergiftung, Fluch and the already-central burn/poison/seed/
# binding effects consistent with normal move actions.


func _choose_wait() -> void:
    if selected_actor.is_empty():
        super._choose_wait()
        return

    var actor: Dictionary = selected_actor
    super._choose_wait()

    if not battle_active or not bool(actor.get("alive", false)):
        return

    _resolve_after_action_effects(actor)
    _refresh_cards()
    _check_end()
