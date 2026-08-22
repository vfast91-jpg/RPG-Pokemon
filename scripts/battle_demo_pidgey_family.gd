extends "res://scripts/battle_demo_beedrill_family.gd"

# Taubsi -> Tauboga -> Tauboss V4 runtime integration.
# Stahlflügel reuses the central Statuswert softcap and timed-modifier system.
# Only the post-hit 10-% self-defense proc needs a family layer here.


func _cf_apply_post_hit_runtime(
    actor: Dictionary,
    move: Dictionary,
    runtime: Dictionary,
    snapshots: Dictionary
) -> void:
    super._cf_apply_post_hit_runtime(actor, move, runtime, snapshots)

    if not runtime.has("timeflow_self_defense_buff_chance"):
        return

    var chance: float = _cf_effect_chance(
        actor,
        float(runtime.get("timeflow_self_defense_buff_chance", 0.0))
    )
    if randf() > chance:
        return

    # incoming_damage_mod uses the central sign convention: a negative signed
    # weight creates a Defense-up multiplier above 1.0 (e.g. Status 25 -> 1.25).
    _cf_apply_self_modifier(
        actor,
        "incoming_damage_mod",
        -absf(float(runtime.get("timeflow_self_defense_buff_weight", 1.0))),
        str(move.get("type", "normal")),
        str(move.get("name", "Attacke"))
    )
    _spawn_feedback_label(actor, "VERTEIDIGUNG ↑ · 3 AKTIONEN", Color("b9e2a8"))


func _compact_effect_summary(move: Dictionary) -> String:
    if str(move.get("id", "")) == "steel_wing":
        return "Stärke 70 · 10 %: Verteidigung ↑ (Statuswert) · 3 eigene Aktionen"
    return super._compact_effect_summary(move)
