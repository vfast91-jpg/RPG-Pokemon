extends "res://scripts/battle_demo_periodic_wait_fix.gd"

const ToxicSpikesAggroRules = preload("res://scripts/battle/aggro_rules.gd")

# Final Giftspitzen runtime completion.
#
# The canonical attack database defines a two-layer hazard:
# - 1 layer -> Gift
# - 2 layers -> schwere Vergiftung
# It triggers when a grounded opponent uses a physical contact move. Poison and
# Steel are immune, and Turbodreher/clear-allied-hazards removes the field state.
# Bad Poison is available in the inherited final Timeflow layer, so the old
# partial placeholder behavior is no longer necessary.


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    if kind == "db_toxic_spikes":
        var enemy_side: String = "enemy" if str(actor.get("side", "")) == "player" else "player"
        var layers_key: String = "db_toxic_spikes_" + enemy_side
        var source_key: String = "db_toxic_spikes_source_" + enemy_side
        var max_layers: int = maxi(1, int(mechanic.get("max_layers", 2)))
        var layers: int = mini(max_layers, int(get_meta(layers_key, 0)) + 1)
        set_meta(layers_key, layers)
        set_meta(source_key, str(actor.get("id", "")))
        _spawn_feedback_label(actor, "☣️ GIFTSPITZEN %d/%d" % [layers, max_layers], Color("c7a2dd"))
        return 0.0

    if kind == "db_clear_allied_hazards":
        var own_side: String = str(actor.get("side", ""))
        set_meta("db_toxic_spikes_" + own_side, 0)
        set_meta("db_toxic_spikes_source_" + own_side, "")
        return 0.0

    return super._effect(actor, target, mechanic)


func _database_trigger_toxic_spikes_if_defined(
    actor: Dictionary,
    move: Dictionary,
    move_attempted: bool
) -> void:
    if (
        not move_attempted
        or str(move.get("category", "")) != "physical"
        or not bool(move.get("contact", false))
        or not _tf_is_grounded(actor)
    ):
        return

    var own_side: String = str(actor.get("side", ""))
    var layers: int = int(get_meta("db_toxic_spikes_" + own_side, 0))
    if layers <= 0:
        return

    # Giftspitzen cannot overwrite another major status. Keep the hazard on the
    # field; it may still affect a later valid contact action.
    if not str(actor.get("major_status", "")).is_empty() or bool(actor.get("paralyzed", false)):
        _spawn_feedback_label(actor, "☣️ GIFTSPITZEN · STATUS BLOCKIERT", Color("c7a2dd"))
        return

    var types: Array = _type_array(actor.get("types", []))
    if types.has("poison") or types.has("steel"):
        _spawn_feedback_label(actor, "☣️ GIFTSPITZEN · IMMUN", Color("b8d9ff"))
        return

    var status_id: String = "bad_poison" if layers >= 2 else "poison"
    if _database_status_is_blocked(actor, status_id):
        _spawn_feedback_label(actor, "☣️ GIFTSPITZEN · STATUSSCHUTZ", Color("b8d9ff"))
        return

    var source_id: String = str(get_meta("db_toxic_spikes_source_" + own_side, ""))
    var source: Dictionary = _tf_find_combatant(source_id)

    if layers >= 2:
        actor["major_status"] = "bad_poison"
        actor["tf_bad_poison_stage"] = 1
        actor["tf_bad_poison_source_id"] = source_id
        _spawn_feedback_label(actor, "☣️ SCHWER VERGIFTET", Color("bd86cf"))
        if not source.is_empty():
            source["aggro"] = float(source.get("aggro", 0.0)) + ToxicSpikesAggroRules.status_application(actor, "bad_poison")
    else:
        actor["major_status"] = "poison"
        actor["paralyzed"] = false
        _spawn_feedback_label(actor, "☣️ VERGIFTET", Color("c7a2dd"))
        if not source.is_empty():
            source["aggro"] = float(source.get("aggro", 0.0)) + ToxicSpikesAggroRules.status_application(actor, "poison")

    _refresh_cards()
