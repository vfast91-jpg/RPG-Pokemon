extends "res://scripts/battle_demo_gen2_missing_moves_v24_20_v1.gd"

# Gen-2 / V24 missing-move integration · requested block 05/05.
# Adds Psycho-Schildstoß, Verzögerung, Rollentausch, Tränendrüse and Doppelstrahl
# as the final additive leaf. Existing damage, multi-hit, modifier, protection,
# substitute, targeting, ATB and Aggro systems remain authoritative.

const V24_25_MOVE_PACK_PATH: String = "res://data/gen2_missing_moves_runtime_v24_25.json"
const V24_25_PSYSHIELD_BASH_NAME: String = "Psycho-Schildstoß"
const V24_25_TEARFUL_LOOK_NAME: String = "Tränendrüse"
const V24_25_ATTACK_KIND: String = "outgoing_damage_mod"
const V24_25_DEFENSE_KIND: String = "incoming_damage_mod"
const V24_25_ROLE_PLAY_KINDS: Array[String] = [
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod"
]


func _load_data() -> void:
    super._load_data()
    _v24_25_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _v24_25_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(V24_25_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("V24-25-Attackenpaket konnte nicht gelesen werden: " + V24_25_MOVE_PACK_PATH)
        return

    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("V24-25-Attackenpaket besitzt kein moves-Dictionary.")
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
    var psyshield_targets: Array = []
    var psyshield_before: Dictionary = {}

    if move_id == "psyshield_bash":
        var move: Dictionary = _move_data(move_id)
        psyshield_targets = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
        for target_value: Variant in psyshield_targets:
            if not (target_value is Dictionary):
                continue
            var target: Dictionary = target_value
            psyshield_before[str(target.get("id", ""))] = {
                "hp": int(target.get("hp", 0)),
                "substitute_hp": int(target.get("db_substitute_hp", 0))
            }

    super._execute_move(actor, move_id)

    if move_id == "psyshield_bash" and _v24_25_any_target_connected(psyshield_targets, psyshield_before):
        _zf_remove_modifiers_from_move(actor, V24_25_PSYSHIELD_BASH_NAME)
        var proxy: Dictionary = {
            "modifier_kind": V24_25_DEFENSE_KIND,
            "multiplier_from_special": -1.0
        }
        var effect_aggro: float = _zf_apply_modifier(actor, actor, proxy)
        if effect_aggro > 0.0:
            actor["aggro"] = float(actor.get("aggro", 0.0)) + effect_aggro
            _spawn_feedback_label(actor, "🛡️ VERTEIDIGUNG ↑", Color("c9d8ef"))
            _refresh_cards()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    match str(mechanic.get("kind", "")):
        "v24_quash":
            return _v24_25_quash(target)
        "v24_role_play":
            return _v24_25_role_play(actor, target)
        "v24_tearful_look":
            return _v24_25_tearful_look(actor, target, mechanic)
        _:
            return super._effect(actor, target, mechanic)


func _v24_25_quash(target: Dictionary) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0

    var before: float = clampf(float(target.get("atb", 0.0)), 0.0, 1.0)
    if before <= 0.0:
        _spawn_feedback_label(target, "⏳ BEREITS VERZÖGERT", Color("c8bfdc"))
        return 0.0

    target["atb"] = 0.0
    _spawn_feedback_label(target, "⏳ AKTIONSLEISTE → 0 %", Color("d8c7ef"))
    # Aggro follows the actual amount of timeline progress removed.
    return maxf(1.0, before * 10.0)


func _v24_25_role_play(actor: Dictionary, target: Dictionary) -> float:
    if (
        actor.is_empty()
        or target.is_empty()
        or not bool(actor.get("alive", false))
        or not bool(target.get("alive", false))
    ):
        return 0.0

    var total_change: float = 0.0
    for kind: String in V24_25_ROLE_PLAY_KINDS:
        var before: float = _combined_timed_modifier(actor, kind)
        var target_modifiers: Array = _v24_10_active_modifiers(target, kind)
        _v24_10_replace_modifiers(actor, kind, target_modifiers)
        var after: float = _combined_timed_modifier(actor, kind)
        total_change += absf(after - before)

    if total_change <= 0.0001:
        _spawn_feedback_label(actor, "🎭 KEINE ÄNDERUNG", Color("c8bfdc"))
        return 0.0

    _spawn_feedback_label(actor, "🎭 ROLLE ÜBERNOMMEN", Color("d8c7ef"))
    return total_change * 10.0


func _v24_25_tearful_look(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0

    # Original Attack + Sp. Atk reduction maps exactly once to Timeflow's
    # unified attack channel.
    _zf_remove_modifiers_from_move(target, V24_25_TEARFUL_LOOK_NAME)
    var proxy: Dictionary = {
        "modifier_kind": V24_25_ATTACK_KIND,
        "multiplier_from_special": float(mechanic.get("multiplier_from_special", -1.0))
    }
    var effect_aggro: float = _zf_apply_modifier(actor, target, proxy)
    if effect_aggro > 0.0:
        _spawn_feedback_label(target, "😢 ANGRIFF ↓", Color("b9c9e8"))
    return effect_aggro


func _v24_25_any_target_connected(targets: Array, before: Dictionary) -> bool:
    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        if target_id.is_empty() or not before.has(target_id):
            continue
        var snapshot_value: Variant = before.get(target_id, {})
        if not (snapshot_value is Dictionary):
            continue
        var snapshot: Dictionary = snapshot_value
        if int(target.get("hp", 0)) < int(snapshot.get("hp", int(target.get("hp", 0)))):
            return true
        if (
            int(target.get("db_substitute_hp", 0))
            < int(snapshot.get("substitute_hp", int(target.get("db_substitute_hp", 0))))
        ):
            return true
    return false
