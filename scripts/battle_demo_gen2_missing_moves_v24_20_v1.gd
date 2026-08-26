extends "res://scripts/battle_demo_gen2_missing_moves_v24_15_v1.gd"

# Gen-2 / V24 missing-move integration · requested block 04/05.
# Adds Schmetterramme, Klauenwetzer, Hyperbohrer, Kraftteiler and Krafttrick
# as an additive leaf. Existing damage, protection/substitute, timed modifier,
# targeting and Aggro systems remain authoritative.

const V24_20_MOVE_PACK_PATH: String = "res://data/gen2_missing_moves_runtime_v24_20.json"
const V24_20_HEADLONG_RUSH_NAME: String = "Schmetterramme"
const V24_20_HONE_CLAWS_NAME: String = "Klauenwetzer"
const V24_20_ATTACK_KIND: String = "outgoing_damage_mod"
const V24_20_DEFENSE_KIND: String = "incoming_damage_mod"
const V24_20_ACCURACY_KIND: String = "accuracy_mod"


func _load_data() -> void:
    super._load_data()
    _v24_20_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _v24_20_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(V24_20_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("V24-20-Attackenpaket konnte nicht gelesen werden: " + V24_20_MOVE_PACK_PATH)
        return

    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("V24-20-Attackenpaket besitzt kein moves-Dictionary.")
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


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var headlong_targets: Array = []
    var headlong_hp_before: Dictionary = {}

    if move_id == "headlong_rush":
        var move: Dictionary = _move_data(move_id)
        headlong_targets = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
        for target_value: Variant in headlong_targets:
            if target_value is Dictionary:
                var target: Dictionary = target_value
                headlong_hp_before[str(target.get("id", ""))] = int(target.get("hp", 0))

    if move_id == "hyper_drill":
        # Hyperbohrer's contract is exposed to the inherited central hit path.
        # Protection and Substitute are separate there; only protection is bypassed.
        var moves_value: Variant = data.get("moves", {})
        if moves_value is Dictionary:
            var move_value: Variant = (moves_value as Dictionary).get(move_id, {})
            if move_value is Dictionary:
                var original: Dictionary = (move_value as Dictionary).duplicate(true)
                var runtime_value: Variant = (move_value as Dictionary).get("runtime", {})
                var runtime: Dictionary = runtime_value.duplicate(true) if runtime_value is Dictionary else {}
                runtime["bypass_protection"] = true
                runtime["ignore_protection"] = true
                (move_value as Dictionary)["runtime"] = runtime
                (move_value as Dictionary)["bypass_protection"] = true
                (move_value as Dictionary)["ignore_protection"] = true
                (moves_value as Dictionary)[move_id] = move_value
                data["moves"] = moves_value
                super._execute_move(actor, move_id)
                (data["moves"] as Dictionary)[move_id] = original
                return

    super._execute_move(actor, move_id)

    if move_id == "headlong_rush" and _v24_20_any_target_lost_hp(headlong_targets, headlong_hp_before):
        _zf_remove_modifiers_from_move(actor, V24_20_HEADLONG_RUSH_NAME)
        var proxy: Dictionary = {
            "modifier_kind": V24_20_DEFENSE_KIND,
            "multiplier_from_special": 1.0
        }
        var effect_aggro: float = _zf_apply_modifier(actor, actor, proxy)
        if effect_aggro > 0.0:
            _spawn_feedback_label(actor, "💥 VERTEIDIGUNG ↓", Color("e6b59c"))


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    match str(mechanic.get("kind", "")):
        "v24_hone_claws":
            return _v24_20_hone_claws(actor)
        "v24_power_split":
            return _v24_20_power_split(actor, target)
        "v24_power_trick":
            return _v24_20_power_trick(actor)
        _:
            return super._effect(actor, target, mechanic)


func _v24_20_hone_claws(actor: Dictionary) -> float:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return 0.0

    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    _zf_remove_modifiers_from_move(actor, V24_20_HONE_CLAWS_NAME)

    _add_timed_modifier(
        actor,
        V24_20_ATTACK_KIND,
        1.0 + ratio,
        V24_20_HONE_CLAWS_NAME,
        str(actor.get("id", ""))
    )
    _add_timed_modifier(
        actor,
        V24_20_ACCURACY_KIND,
        1.0 + ratio,
        V24_20_HONE_CLAWS_NAME,
        str(actor.get("id", ""))
    )
    _spawn_feedback_label(actor, "🦞 ANGRIFF + GENAUIGKEIT ↑", Color("dfc5ef"))
    return ratio * 20.0


func _v24_20_power_split(actor: Dictionary, target: Dictionary) -> float:
    if (
        actor.is_empty()
        or target.is_empty()
        or not bool(actor.get("alive", false))
        or not bool(target.get("alive", false))
    ):
        return 0.0

    var actor_attack: int = int(actor.get("attack", 0))
    var target_attack: int = int(target.get("attack", 0))
    var average_attack: int = int(floor((float(actor_attack) + float(target_attack)) / 2.0))
    actor["attack"] = average_attack
    target["attack"] = average_attack
    _spawn_feedback_label(actor, "⚖️ KRAFT GETEILT", Color("d8c7ef"))
    _spawn_feedback_label(target, "⚖️ KRAFT GETEILT", Color("d8c7ef"))
    return float(abs(actor_attack - average_attack) + abs(target_attack - average_attack)) * 0.25


func _v24_20_power_trick(actor: Dictionary) -> float:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return 0.0

    var old_attack: int = int(actor.get("attack", 0))
    var old_defense: int = int(actor.get("defense", 0))
    actor["attack"] = old_defense
    actor["defense"] = old_attack
    _spawn_feedback_label(actor, "🔄 ANGRIFF ↔ VERTEIDIGUNG", Color("d8c7ef"))
    return float(abs(old_attack - old_defense)) * 0.25


func _v24_20_any_target_lost_hp(targets: Array, before: Dictionary) -> bool:
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        if target_id.is_empty() or not before.has(target_id):
            continue
        if int(target.get("hp", 0)) < int(before.get(target_id, int(target.get("hp", 0)))):
            return true
    return false
