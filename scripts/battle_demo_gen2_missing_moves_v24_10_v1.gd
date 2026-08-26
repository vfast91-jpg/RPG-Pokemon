extends "res://scripts/battle_demo_gen2_missing_moves_v24_05_v1.gd"

# Gen-2 / V24 missing-move integration · requested block 02/05.
#
# Adds Krafttausch, Psycho-Shift, Schattenstoß, Klebenetz and Giftfaden as an
# additive leaf layer. Existing damage, status, timed-modifier, hazard, Aggro
# and targeting systems remain authoritative.

const V24_10_MOVE_PACK_PATH: String = "res://data/gen2_missing_moves_runtime_v24_10.json"
const V24_10_ATTACK_MODIFIER_KIND: String = "outgoing_damage_mod"
const V24_10_SPEED_MODIFIER_KIND: String = "atb_cycle_mod"
const V24_10_STICKY_WEB_MOVE_NAME: String = "Klebenetz"


func _load_data() -> void:
    super._load_data()
    _v24_10_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()


func _v24_10_load_move_pack() -> void:
    var parsed: Dictionary = _database_read_json_dictionary(V24_10_MOVE_PACK_PATH)
    if parsed.is_empty():
        push_error("V24-10-Attackenpaket konnte nicht gelesen werden: " + V24_10_MOVE_PACK_PATH)
        return

    var entries_value: Variant = parsed.get("moves", {})
    if not (entries_value is Dictionary):
        push_error("V24-10-Attackenpaket besitzt kein moves-Dictionary.")
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


func _start_battle() -> void:
    _v24_10_reset_sticky_web()
    super._start_battle()


func open_config() -> void:
    _v24_10_reset_sticky_web()
    super.open_config()


func _v24_10_reset_sticky_web() -> void:
    for side: String in ["player", "enemy"]:
        set_meta("v24_sticky_web_" + side, false)
        set_meta("v24_sticky_web_source_" + side, "")
        set_meta("v24_sticky_web_source_name_" + side, "")
        set_meta("v24_sticky_web_source_special_" + side, 0.0)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))

    match kind:
        "v24_power_swap":
            return _v24_10_power_swap(actor, target)
        "v24_psycho_shift":
            return _v24_10_psycho_shift(actor, target)
        "v24_sticky_web":
            return _v24_10_place_sticky_web(actor)
        "v24_toxic_thread":
            return _v24_10_toxic_thread(actor, target, mechanic)
        "db_clear_allied_hazards":
            var removed_web: bool = _v24_10_clear_sticky_web(str(actor.get("side", "")))
            var base_effect: float = super._effect(actor, target, mechanic)
            return maxf(base_effect, 1.0 if removed_web else 0.0)
        _:
            return super._effect(actor, target, mechanic)


func _v24_10_power_swap(actor: Dictionary, target: Dictionary) -> float:
    if actor.is_empty() or target.is_empty():
        return 0.0
    if not bool(actor.get("alive", false)) or not bool(target.get("alive", false)):
        return 0.0

    var actor_attack: Array = _v24_10_active_modifiers(actor, V24_10_ATTACK_MODIFIER_KIND)
    var target_attack: Array = _v24_10_active_modifiers(target, V24_10_ATTACK_MODIFIER_KIND)

    if actor_attack.is_empty() and target_attack.is_empty():
        _spawn_feedback_label(target, "🔄 KEINE ANG-ÄNDERUNGEN", Color("c8bfdc"))
        return 0.0

    var actor_before: float = _combined_timed_modifier(actor, V24_10_ATTACK_MODIFIER_KIND)
    var target_before: float = _combined_timed_modifier(target, V24_10_ATTACK_MODIFIER_KIND)

    _v24_10_replace_modifiers(actor, V24_10_ATTACK_MODIFIER_KIND, target_attack)
    _v24_10_replace_modifiers(target, V24_10_ATTACK_MODIFIER_KIND, actor_attack)

    var actor_after: float = _combined_timed_modifier(actor, V24_10_ATTACK_MODIFIER_KIND)
    var target_after: float = _combined_timed_modifier(target, V24_10_ATTACK_MODIFIER_KIND)

    _spawn_feedback_label(actor, "🔄 ANG GETAUSCHT", Color("d6c2ff"))
    _spawn_feedback_label(target, "🔄 ANG GETAUSCHT", Color("d6c2ff"))

    return (
        absf(actor_after - actor_before)
        + absf(target_after - target_before)
    ) * 10.0


func _v24_10_active_modifiers(combatant: Dictionary, kind: String) -> Array:
    var result: Array = []
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return result

    var current_action: int = int(combatant.get("action_serial", 0))
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        if str(modifier.get("kind", "")) != kind:
            continue

        var remaining: int = int(modifier.get("expires_after_action", current_action)) - current_action
        if remaining <= 0:
            continue

        var transferred: Dictionary = modifier.duplicate(true)
        transferred["_v24_10_remaining_actions"] = remaining
        result.append(transferred)
    return result


func _v24_10_replace_modifiers(
    combatant: Dictionary,
    kind: String,
    replacements: Array
) -> void:
    var kept: Array = []
    var modifiers_value: Variant = combatant.get("timed_modifiers", [])
    if modifiers_value is Array:
        for modifier_value: Variant in modifiers_value:
            if not (modifier_value is Dictionary):
                continue
            var modifier: Dictionary = modifier_value
            if str(modifier.get("kind", "")) != kind:
                kept.append(modifier)

    var current_action: int = int(combatant.get("action_serial", 0))
    for replacement_value: Variant in replacements:
        if not (replacement_value is Dictionary):
            continue
        var replacement: Dictionary = (replacement_value as Dictionary).duplicate(true)
        var remaining: int = maxi(0, int(replacement.get("_v24_10_remaining_actions", 0)))
        replacement.erase("_v24_10_remaining_actions")
        if remaining <= 0:
            continue
        replacement["expires_after_action"] = current_action + remaining
        kept.append(replacement)

    combatant["timed_modifiers"] = kept


func _v24_10_psycho_shift(actor: Dictionary, target: Dictionary) -> float:
    if actor.is_empty() or target.is_empty():
        return 0.0
    if not bool(actor.get("alive", false)) or not bool(target.get("alive", false)):
        return 0.0

    var status_id: String = str(actor.get("major_status", ""))
    if status_id.is_empty():
        _spawn_feedback_label(actor, "🌀 KEIN STATUS", Color("c8bfdc"))
        return 0.0

    var sleep_actions: int = maxi(0, int(actor.get("db_sleep_actions", 0)))
    var toxic_stage: int = maxi(1, int(actor.get("tf_bad_poison_stage", 1)))
    var applied: float = 0.0

    if status_id == "sleep":
        if (
            not str(target.get("major_status", "")).is_empty()
            or _database_status_is_blocked(target, "sleep")
        ):
            return 0.0
        target["major_status"] = "sleep"
        target["db_sleep_actions"] = maxi(1, sleep_actions)
        _spawn_feedback_label(target, "💤 SCHLAF", Color("c9c4ee"))
        applied = 40.0
    elif status_id == "bad_poison":
        if (
            not str(target.get("major_status", "")).is_empty()
            or _database_status_is_blocked(target, "bad_poison")
        ):
            return 0.0
        var target_types: Array = _type_array(target.get("types", []))
        if target_types.has("poison") or target_types.has("steel"):
            _spawn_feedback_label(target, "☣️ IMMUN", Color("b8d9ff"))
            return 0.0
        target["major_status"] = "bad_poison"
        target["paralyzed"] = false
        target["tf_bad_poison_stage"] = toxic_stage
        target["tf_bad_poison_source_id"] = str(actor.get("id", ""))
        _spawn_feedback_label(target, "☣️ SCHWER VERGIFTET", Color("bd86cf"))
        applied = 20.0
    else:
        applied = _zf_apply_status_direct(actor, target, status_id, 1.0)

    if applied <= 0.0:
        _spawn_feedback_label(actor, "🌀 ÜBERTRAGUNG BLOCKIERT", Color("d9a5a5"))
        return 0.0

    actor["major_status"] = ""
    actor["paralyzed"] = false
    actor["db_sleep_actions"] = 0
    actor["tf_bad_poison_stage"] = 0
    actor["tf_bad_poison_source_id"] = ""

    _spawn_feedback_label(actor, "🌀 STATUS ÜBERTRAGEN", Color("d6c2ff"))
    return applied


func _v24_10_place_sticky_web(actor: Dictionary) -> float:
    var target_side: String = _sand_opposite_side(str(actor.get("side", "")))
    if target_side.is_empty():
        return 0.0

    var key: String = "v24_sticky_web_" + target_side
    if bool(get_meta(key, false)):
        _spawn_feedback_label(actor, "🕸️ KLEBENETZ BEREITS AKTIV", Color("c8bfdc"))
        return 0.0

    set_meta(key, true)
    set_meta("v24_sticky_web_source_" + target_side, str(actor.get("id", "")))
    set_meta("v24_sticky_web_source_name_" + target_side, _actor_name(actor))
    set_meta("v24_sticky_web_source_special_" + target_side, float(actor.get("special", 0.0)))
    _spawn_feedback_label(actor, "🕸️ KLEBENETZ", Color("d6d0b8"))
    return 3.0


func _database_trigger_toxic_spikes_if_defined(
    actor: Dictionary,
    move: Dictionary,
    move_attempted: bool
) -> void:
    super._database_trigger_toxic_spikes_if_defined(actor, move, move_attempted)

    if (
        not move_attempted
        or not bool(actor.get("alive", false))
        or str(move.get("category", "")) != "physical"
        or not bool(move.get("contact", false))
        or not _tf_is_grounded(actor)
    ):
        return

    var own_side: String = str(actor.get("side", ""))
    if own_side.is_empty() or not bool(get_meta("v24_sticky_web_" + own_side, false)):
        return

    _v24_10_trigger_sticky_web(actor, own_side)


func _v24_10_trigger_sticky_web(target: Dictionary, side: String) -> void:
    var source_id: String = str(get_meta("v24_sticky_web_source_" + side, ""))
    var source_name: String = str(get_meta("v24_sticky_web_source_name_" + side, "Klebenetz"))
    var source_special: float = float(get_meta("v24_sticky_web_source_special_" + side, 0.0))
    var source: Dictionary = _tf_find_combatant(source_id)
    var scaling_source: Dictionary = source if not source.is_empty() else {"special": source_special}

    var multiplier: float = _status_modifier_multiplier(
        scaling_source,
        {"multiplier_from_special": 1.0},
        V24_10_SPEED_MODIFIER_KIND,
        false,
        false
    )
    if multiplier <= 1.0:
        return

    # Field is nonstacking: a new trigger refreshes its own temporary slow.
    _zf_remove_modifiers_from_move(target, V24_10_STICKY_WEB_MOVE_NAME)
    _add_timed_modifier(
        target,
        V24_10_SPEED_MODIFIER_KIND,
        multiplier,
        V24_10_STICKY_WEB_MOVE_NAME,
        source_name
    )

    var effect_aggro: float = _status_effect_aggro(V24_10_SPEED_MODIFIER_KIND, multiplier)
    if not source.is_empty() and effect_aggro > 0.0:
        source["aggro"] = float(source.get("aggro", 0.0)) + effect_aggro

    _spawn_feedback_label(target, "🕸️ GESCHWINDIGKEIT ↓", Color("d6d0b8"))
    _refresh_cards()


func _v24_10_clear_sticky_web(side: String) -> bool:
    if side.is_empty():
        return false
    var key: String = "v24_sticky_web_" + side
    var had_web: bool = bool(get_meta(key, false))
    set_meta(key, false)
    set_meta("v24_sticky_web_source_" + side, "")
    set_meta("v24_sticky_web_source_name_" + side, "")
    set_meta("v24_sticky_web_source_special_" + side, 0.0)
    return had_web


func _bfam_apply_defog_cleanup(actor: Dictionary) -> void:
    super._bfam_apply_defog_cleanup(actor)
    _v24_10_clear_sticky_web("player")
    _v24_10_clear_sticky_web("enemy")


func _v24_10_toxic_thread(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    if actor.is_empty() or target.is_empty() or not bool(target.get("alive", false)):
        return 0.0

    var poison_effect: float = _zf_apply_status_direct(actor, target, "poison", 1.0)
    var speed_mechanic: Dictionary = {
        "modifier_kind": V24_10_SPEED_MODIFIER_KIND,
        "multiplier_from_special": float(mechanic.get("multiplier_from_special", 1.0))
    }
    var speed_effect: float = _zf_apply_modifier(actor, target, speed_mechanic)

    if speed_effect > 0.0:
        _spawn_feedback_label(target, "🧵 GESCHWINDIGKEIT ↓", Color("c7a2dd"))

    return poison_effect + speed_effect
