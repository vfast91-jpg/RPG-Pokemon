extends "res://scripts/battle_demo_gen2_missing_moves_v24_10_v1.gd"

# Gen-2 / V24 missing-move integration · requested block 03/05.
#
# Adds Armstoß, Kulleraugen, Überschallknall, Retourkutsche and Watteschild as
# an additive leaf layer. Existing damage, multi-hit, Status scaling, timed
# modifiers, protection/substitute resolution, Aggro and targeting remain
# authoritative wherever an existing central mechanic already covers them.

const V24_15_MOVE_PACK_PATH: String = "res://data/gen2_missing_moves_runtime_v24_15.json"
const V24_15_ATTACK_KIND: String = "outgoing_damage_mod"
const V24_15_DEFENSE_KIND: String = "incoming_damage_mod"
const V24_15_BABY_DOLL_EYES_NAME: String = "Kulleraugen"
const V24_15_COTTON_GUARD_NAME: String = "Watteschild"


func _load_data() -> void:
    super._load_data()
    _v24_15_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _v24_15_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(V24_15_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("V24-15-Attackenpaket konnte nicht gelesen werden: " + V24_15_MOVE_PACK_PATH)
        return

    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("V24-15-Attackenpaket besitzt kein moves-Dictionary.")
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
    combatant["v24_15_retaliation_damage"] = 0
    combatant["v24_15_retaliation_source_id"] = ""
    return combatant


func _execute_move(actor: Dictionary, move_id: String) -> void:
    # Retourkutsche records actual Pokémon HP lost to one opposing attack.
    # Snapshotting around the inherited resolution naturally excludes misses,
    # immunities, full protection and substitute-only damage because those do
    # not reduce the Pokémon's own HP.
    var hp_before: Dictionary = {}
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        if not bool(combatant.get("alive", false)):
            continue
        hp_before[str(combatant.get("id", ""))] = int(combatant.get("hp", 0))

    super._execute_move(actor, move_id)

    var actor_side: String = str(actor.get("side", ""))
    var actor_id: String = str(actor.get("id", ""))
    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var victim: Dictionary = combatant_value
        if str(victim.get("side", "")) == actor_side:
            continue

        var victim_id: String = str(victim.get("id", ""))
        if victim_id.is_empty() or not hp_before.has(victim_id):
            continue

        var lost_hp: int = maxi(
            0,
            int(hp_before.get(victim_id, int(victim.get("hp", 0))))
            - int(victim.get("hp", 0))
        )
        if lost_hp <= 0:
            continue

        victim["v24_15_retaliation_damage"] = lost_hp
        victim["v24_15_retaliation_source_id"] = actor_id

    # The user's reaction window ends after its own action. Clearing after the
    # inherited execution lets Retourkutsche consume the pending record first.
    actor["v24_15_retaliation_damage"] = 0
    actor["v24_15_retaliation_source_id"] = ""


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    match kind:
        "v24_baby_doll_eyes":
            return _v24_15_baby_doll_eyes(actor, target, mechanic)
        "v24_comeuppance":
            return _v24_15_comeuppance(actor, target)
        "v24_cotton_guard":
            return _v24_15_cotton_guard(actor, mechanic)
        _:
            return super._effect(actor, target, mechanic)


func _v24_15_baby_doll_eyes(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0

    # Nonstacking refresh: the inherited helper removes only modifiers created
    # by Kulleraugen and leaves all other attack changes untouched.
    _zf_remove_modifiers_from_move(target, V24_15_BABY_DOLL_EYES_NAME)
    var proxy: Dictionary = {
        "modifier_kind": V24_15_ATTACK_KIND,
        "multiplier_from_special": float(mechanic.get("multiplier_from_special", -1.0))
    }
    var effect_aggro: float = _zf_apply_modifier(actor, target, proxy)
    if effect_aggro > 0.0:
        _spawn_feedback_label(target, "🥺 ANGRIFF ↓", Color("efc4df"))
    return effect_aggro


func _v24_15_cotton_guard(actor: Dictionary, mechanic: Dictionary) -> float:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return 0.0

    _zf_remove_modifiers_from_move(actor, V24_15_COTTON_GUARD_NAME)
    var proxy: Dictionary = {
        "modifier_kind": V24_15_DEFENSE_KIND,
        "multiplier_from_special": float(mechanic.get("multiplier_from_special", -3.0))
    }
    var effect_aggro: float = _zf_apply_modifier(actor, actor, proxy)
    if effect_aggro > 0.0:
        _spawn_feedback_label(actor, "☁️ VERTEIDIGUNG MASSIV ↑", Color("e9edf2"))
    return effect_aggro


func _v24_15_comeuppance(actor: Dictionary, _selected_target: Dictionary) -> float:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return 0.0

    var received_damage: int = maxi(0, int(actor.get("v24_15_retaliation_damage", 0)))
    var source_id: String = str(actor.get("v24_15_retaliation_source_id", ""))
    if received_damage <= 0 or source_id.is_empty():
        _spawn_feedback_label(actor, "↩️ KEIN RÜCKSCHADEN", Color("d9a5a5"))
        return 0.0

    var target: Dictionary = _tf_find_combatant(source_id)
    if (
        target.is_empty()
        or not bool(target.get("alive", false))
        or str(target.get("side", "")) == str(actor.get("side", ""))
    ):
        _spawn_feedback_label(actor, "↩️ KEIN GÜLTIGER ANGREIFER", Color("d9a5a5"))
        return 0.0

    var wanted_damage: int = maxi(1, int(floor(float(received_damage) * 1.5)))
    var actual_damage: int = mini(wanted_damage, maxi(0, int(target.get("hp", 0))))
    if actual_damage <= 0:
        return 0.0

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual_damage)
    target["damage_since_last_action"] = true
    target["aggro"] = float(target.get("aggro", 0.0)) * 0.5
    target["zf_direct_hits_received"] = (
        maxi(0, int(target.get("zf_direct_hits_received", 0))) + 1
    )
    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false

    _spawn_feedback_label(target, "↩️ −" + str(actual_damage) + " KP", Color("d6b8ef"))
    return float(actual_damage)
