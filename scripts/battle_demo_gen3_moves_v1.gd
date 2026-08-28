extends "res://scripts/battle_demo_disable_selection_v1.gd"

# Gen-3 attack integration for the first five spreadsheet entries.
# Existing central damage, status, critical and targeting systems remain authoritative.

const GEN3_MOVE_PACK_PATH: String = "res://data/gen3_moves_runtime_v1.json"


func _load_data() -> void:
    super._load_data()
    _gen3_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _gen3_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(GEN3_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("Gen-3-Attackenpaket konnte nicht gelesen werden: " + GEN3_MOVE_PACK_PATH)
        return

    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("Gen-3-Attackenpaket besitzt kein moves-Dictionary.")
        return

    var runtime_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var canonical_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_value if canonical_value is Dictionary else {}

    for move_id_value: Variant in (entries_value as Dictionary).keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
        if not (move_value is Dictionary):
            continue
        runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
        canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)

    data["moves"] = runtime_moves
    _canonical_pack["moves"] = canonical_moves


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["db_aurora_veil_reduction"] = 0.0
    combatant["db_aurora_veil_source_id"] = ""
    combatant["db_aurora_veil_expires_source_action"] = 0
    return combatant


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    match str(mechanic.get("kind", "")):
        "db_aurora_veil":
            return _gen3_apply_aurora_veil(actor, target, mechanic)
        "db_target_modifier_bypass":
            # The actual bypass is applied at the accuracy/damage boundaries.
            return 0.0
        _:
            return super._effect(actor, target, mechanic)


func _gen3_apply_aurora_veil(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if battle_weather.current_id() != "snow":
        _spawn_feedback_label(actor, "✖ SCHNEE ERFORDERLICH", Color("d9a5a5"))
        return 0.0

    var status_value: float = maxf(0.0, float(actor.get("special", 0.0)))
    var reduction: float = status_value / (75.0 + status_value)
    target["db_aurora_veil_reduction"] = reduction
    target["db_aurora_veil_source_id"] = str(actor.get("id", ""))
    target["db_aurora_veil_expires_source_action"] = (
        int(actor.get("action_serial", 0))
        + maxi(1, int(mechanic.get("duration_actions", 3)))
    )
    return reduction * 10.0


func _gen3_sacred_sword_active() -> bool:
    var move_id: String = str(_database_active_move.get("id", _database_move_id))
    return move_id == "sacred_sword"


func _sf_prepare_per_target_accuracy(actor: Dictionary, move: Dictionary, targets: Array) -> void:
    if not _gen3_sacred_sword_active():
        super._sf_prepare_per_target_accuracy(actor, move, targets)
        return

    var saved_accuracy: Dictionary = {}
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        saved_accuracy[target_id] = target.get("db_incoming_accuracy_mult", 1.0)
        target["db_incoming_accuracy_mult"] = 1.0

    super._sf_prepare_per_target_accuracy(actor, move, targets)

    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        if saved_accuracy.has(target_id):
            target["db_incoming_accuracy_mult"] = saved_accuracy[target_id]


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var sacred_bypass: bool = _gen3_sacred_sword_active()
    var aurora_reduction: float = _gen3_aurora_reduction(target)
    var saved_modifiers: Variant = target.get("timed_modifiers", null)
    var had_modifiers: bool = target.has("timed_modifiers")
    var saved_stockpile: Variant = target.get("db_stockpile_defense_multiplier", 1.0)
    var saved_reflect: Variant = target.get("pika_reflect_reduction", 0.0)
    var saved_light_screen: Variant = target.get("db_light_screen_reduction", 0.0)

    if sacred_bypass:
        _gen3_remove_temporary_defense(target)
        target["db_stockpile_defense_multiplier"] = 1.0

    var barrier_active: bool = aurora_reduction >= 0.0
    if barrier_active:
        # Suppress older single-category screens during the parent pass so the
        # strongest applicable reduction can be selected exactly once below.
        if category == "physical":
            target["pika_reflect_reduction"] = 0.0
        elif category == "special":
            target["db_light_screen_reduction"] = 0.0

    var damage: int = super._damage(actor, target, power, move_type, category)

    if sacred_bypass:
        if had_modifiers:
            target["timed_modifiers"] = saved_modifiers
        else:
            target.erase("timed_modifiers")
        target["db_stockpile_defense_multiplier"] = saved_stockpile

    if barrier_active:
        target["pika_reflect_reduction"] = saved_reflect
        target["db_light_screen_reduction"] = saved_light_screen

    if damage <= 0 or not barrier_active:
        return damage

    var existing_reduction: float = 0.0
    if category == "physical":
        existing_reduction = maxf(0.0, float(saved_reflect))
    elif category == "special":
        existing_reduction = maxf(0.0, float(saved_light_screen))

    var reduction: float = clampf(maxf(aurora_reduction, existing_reduction), 0.0, 0.95)
    return maxi(1, int(round(float(damage) * (1.0 - reduction))))


func _gen3_remove_temporary_defense(target: Dictionary) -> void:
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return
    var kept: Array = []
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if str(modifier.get("kind", "")) != "incoming_damage_mod":
            kept.append(modifier)
    target["timed_modifiers"] = kept


func _gen3_aurora_reduction(target: Dictionary) -> float:
    var source_id: String = str(target.get("db_aurora_veil_source_id", ""))
    if source_id.is_empty():
        return -1.0

    var expires: int = int(target.get("db_aurora_veil_expires_source_action", 0))
    var reduction: float = float(target.get("db_aurora_veil_reduction", 0.0))
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if str(candidate.get("id", "")) != source_id:
            continue
        if not bool(candidate.get("alive", false)):
            return -1.0
        if int(candidate.get("action_serial", 0)) >= expires:
            return -1.0
        return clampf(reduction, 0.0, 0.95)
    return -1.0
