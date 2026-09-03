extends "res://scripts/battle_demo_endgame_atb_v1.gd"

# Final shared guards applied at the last runtime seam so every battle mode
# using main.tscn receives the same fixes after all historical data packs and
# modifier layers below it have loaded.

const ENEMY_ONLY_SPREAD_MOVE_IDS: Array[String] = [
    "earthquake",
    "misty_explosion",
    "bulldoze",
    "surf",
    "synchronoise",
    "discharge",
    "expanding_force",
    "hyper_voice",
]

const TEMPO_SLOWDOWN_CAP: float = 2.5
const TEMPO_EFFECT_ACTIONS: int = 3


func _load_data() -> void:
    super._load_data()
    _apply_enemy_only_spread_target_guard()


func _apply_enemy_only_spread_target_guard() -> void:
    # These eight moves must never hit allied active Pokemon. Only rewrite
    # ally-inclusive spread targets; already-correct single-enemy/all-enemies
    # definitions (for example Expanding Force and Hyper Voice) stay intact.
    var runtime_moves_value: Variant = data.get("moves", {})
    if runtime_moves_value is Dictionary:
        var runtime_moves: Dictionary = runtime_moves_value
        _force_enemy_only_spread_targets(runtime_moves)
        data["moves"] = runtime_moves

    # Keep the canonical runtime mirror consistent as well, so a later rebuild
    # cannot restore an older friendly-fire target from a loaded data pack.
    var canonical_moves_value: Variant = _canonical_pack.get("moves", {})
    if canonical_moves_value is Dictionary:
        var canonical_moves: Dictionary = canonical_moves_value
        _force_enemy_only_spread_targets(canonical_moves)
        _canonical_pack["moves"] = canonical_moves


func _force_enemy_only_spread_targets(moves: Dictionary) -> void:
    for move_id: String in ENEMY_ONLY_SPREAD_MOVE_IDS:
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            continue

        var move: Dictionary = move_value
        var target_rule: String = str(move.get("target", ""))
        if target_rule == "all_other_active_pokemon" or target_rule == "field_all_pokemon":
            move["target"] = "all_enemies"
            moves[move_id] = move


# Two tempo rules are enforced here as well:
# 1) Re-applying the same named Speed/ATB-cycle effect refreshes its duration
#    instead of creating another independent stack. Different moves may still
#    combine, preserving intentional tempo-control synergies.
# 2) The combined temporary slowdown can never make the ATB cycle longer than
#    2.5x normal. This keeps strong Speed control useful while preventing a
#    self-reinforcing soft lock where the slowed Pokemon barely receives the
#    own actions that are required for its debuffs to expire.


func _add_timed_modifier(
    target: Dictionary,
    kind: String,
    multiplier: float,
    source_move: String,
    source_actor: String
) -> void:
    if kind != "atb_cycle_mod" or source_move.is_empty():
        super._add_timed_modifier(target, kind, multiplier, source_move, source_actor)
        return

    var modifiers_value: Variant = target.get("timed_modifiers", [])
    var modifiers: Array = modifiers_value if modifiers_value is Array else []
    var current_action: int = int(target.get("action_serial", 0))

    for index: int in range(modifiers.size()):
        var modifier_value: Variant = modifiers[index]
        if not (modifier_value is Dictionary):
            continue

        var modifier: Dictionary = modifier_value
        if str(modifier.get("kind", "")) != kind:
            continue
        if str(modifier.get("source_move", "")) != source_move:
            continue

        var existing_multiplier: float = maxf(
            0.0001,
            float(modifier.get("multiplier", 1.0))
        )
        var incoming_multiplier: float = maxf(0.0001, multiplier)
        var merged_multiplier: float = incoming_multiplier

        # Same-direction reapplications keep the stronger magnitude while the
        # duration is refreshed. A rare direction change from the same move
        # replaces the old value with the new one instead of mixing both.
        if existing_multiplier > 1.0 and incoming_multiplier > 1.0:
            merged_multiplier = maxf(existing_multiplier, incoming_multiplier)
        elif existing_multiplier < 1.0 and incoming_multiplier < 1.0:
            merged_multiplier = minf(existing_multiplier, incoming_multiplier)

        modifier["multiplier"] = merged_multiplier
        modifier["source_actor"] = source_actor
        modifier["expires_after_action"] = current_action + TEMPO_EFFECT_ACTIONS
        modifiers[index] = modifier
        target["timed_modifiers"] = modifiers
        return

    super._add_timed_modifier(target, kind, multiplier, source_move, source_actor)


func _combined_timed_modifier(combatant: Dictionary, kind: String) -> float:
    var result: float = super._combined_timed_modifier(combatant, kind)
    if kind == "atb_cycle_mod":
        return minf(maxf(0.0001, result), TEMPO_SLOWDOWN_CAP)
    return result