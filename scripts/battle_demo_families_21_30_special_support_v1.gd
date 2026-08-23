extends "res://scripts/battle_demo_families_21_30_status_support_v1.gd"

func _f30_ohko(actor: Dictionary, target: Dictionary, move_id: String) -> float:
    if target.is_empty() or not bool(target.get("alive", false)):
        return 0.0

    var actor_level: int = int(actor.get("level", 1))
    var target_level: int = int(target.get("level", 1))
    if actor_level < target_level:
        _spawn_feedback_label(target, "✖ LEVEL ZU HOCH", Color("d9a5a5"))
        return 0.0

    if bool(target.get("protective_guard", false)):
        target["protective_guard"] = false
        _spawn_feedback_label(target, "🛡️ GESCHÜTZT", Color("b8d9ff"))
        return 0.0

    var chance_percent: float = 0.0
    if move_id == "sheer_cold":
        if _type_array(target.get("types", [])).has("ice"):
            _spawn_feedback_label(target, "❄️ IMMUN", Color("b8d9ff"))
            return 0.0
        var actor_is_ice: bool = _type_array(actor.get("types", [])).has("ice")
        chance_percent = (30.0 if actor_is_ice else 20.0) + float(actor_level - target_level)
    else:
        if TypeSystem.get_multiplier("normal", _type_array(target.get("types", []))) <= 0.0:
            _spawn_feedback_label(target, "✖ WIRKUNGSLOS", Color("b8d9ff"))
            return 0.0
        chance_percent = 30.0 + float(actor_level - target_level)

    chance_percent = clampf(chance_percent, 0.0, 100.0)
    if randf() * 100.0 >= chance_percent:
        _spawn_feedback_label(target, "✖ VERFEHLT", Color("d9a5a5"))
        return 0.0

    var removed: int = maxi(0, int(target.get("hp", 0)))
    if removed <= 0:
        return 0.0
    target["hp"] = 0
    target["alive"] = false
    target["aggro"] = 0.0
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(removed)
    _spawn_feedback_label(target, "💥 K.O. · −" + str(removed) + " KP", Color("ff9d9d"))
    return 0.0

func _f30_capture_counter_damage(
    defender: Dictionary,
    source: Dictionary,
    hp_before: int,
    source_serial: int,
    source_move_id: String
) -> void:
    if (
        defender.is_empty()
        or source.is_empty()
        or not bool(defender.get("alive", false))
        or not bool(defender.get("ad_short_charging", false))
        or str(defender.get("ad_short_charge_move", "")) != "counter"
    ):
        return

    var lost: int = maxi(0, hp_before - int(defender.get("hp", 0)))
    if lost <= 0:
        return

    var same_move: bool = (
        str(defender.get("f30_counter_source_id", "")) == str(source.get("id", ""))
        and int(defender.get("f30_counter_source_serial", -1)) == source_serial
        and str(defender.get("f30_counter_source_move_id", "")) == source_move_id
    )
    defender["f30_counter_damage"] = (
        int(defender.get("f30_counter_damage", 0)) + lost if same_move else lost
    )
    defender["f30_counter_source_id"] = str(source.get("id", ""))
    defender["f30_counter_source_serial"] = source_serial
    defender["f30_counter_source_move_id"] = source_move_id

func _f30_counter(actor: Dictionary) -> float:
    var stored: int = maxi(0, int(actor.get("f30_counter_damage", 0)))
    var source: Dictionary = _zf_find_combatant(str(actor.get("f30_counter_source_id", "")))

    actor["f30_counter_damage"] = 0
    actor["f30_counter_source_id"] = ""
    actor["f30_counter_source_serial"] = -1
    actor["f30_counter_source_move_id"] = ""

    if stored <= 0 or source.is_empty() or not bool(source.get("alive", false)):
        _spawn_feedback_label(actor, "✖ KEIN KONTERZIEL", Color("d9a5a5"))
        return 0.0

    var dealt: int = _f30_apply_fixed_damage(actor, source, stored * 2, "fighting", true)
    if dealt > 0:
        # Counter is a hostile single-target exception even though its database
        # targeting rule is self during the preparation phase.
        F30_SingleTargetAggroRules.reduce(source)
    return 0.0

func _f30_final_gambit(actor: Dictionary, target: Dictionary) -> float:
    if actor.is_empty() or target.is_empty() or not bool(actor.get("alive", false)):
        return 0.0
    var wager: int = maxi(0, int(actor.get("hp", 0)))
    if wager <= 0:
        return 0.0
    var dealt: int = _f30_apply_fixed_damage(actor, target, wager, "fighting", true)
    if dealt <= 0:
        return 0.0
    _ad_self_ko(actor)
    return 0.0

func _f30_apply_fixed_damage(
    actor: Dictionary,
    target: Dictionary,
    amount: int,
    move_type: String,
    consume_protect: bool
) -> int:
    if target.is_empty() or not bool(target.get("alive", false)) or amount <= 0:
        return 0
    if bool(target.get("protective_guard", false)):
        if consume_protect:
            target["protective_guard"] = false
        _spawn_feedback_label(target, "🛡️ GESCHÜTZT", Color("b8d9ff"))
        return 0
    if TypeSystem.get_multiplier(move_type, _type_array(target.get("types", []))) <= 0.0:
        _spawn_feedback_label(target, "✖ WIRKUNGSLOS", Color("b8d9ff"))
        return 0

    var dealt: int = mini(amount, maxi(0, int(target.get("hp", 0))))
    if dealt <= 0:
        return 0
    target["hp"] = maxi(0, int(target.get("hp", 0)) - dealt)
    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false
        target["aggro"] = 0.0
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(dealt)
    _spawn_feedback_label(target, "💥 −" + str(dealt) + " KP", Color("ff9d9d"))
    return dealt

func _f30_advance_hail(delta: float) -> void:
    if not battle_active or paused or not _f30_hail_active():
        if not _f30_hail_active():
            _f30_hail_pulse_remaining = F30_HAIL_PULSE_SECONDS
        return

    var active_delta: float = minf(delta, maxf(0.0, battle_weather.remaining_seconds()))
    _f30_hail_pulse_remaining -= active_delta
    while _f30_hail_pulse_remaining <= 0.0 and _f30_hail_active():
        _f30_hail_pulse()
        _f30_hail_pulse_remaining += F30_HAIL_PULSE_SECONDS

func _f30_hail_active() -> bool:
    return battle_weather.is_active() and battle_weather.current_id() == "hail"

func _f30_hail_pulse() -> void:
    for candidate_value: Variant in combatants:
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if (
            not bool(candidate.get("alive", false))
            or _type_array(candidate.get("types", [])).has("ice")
        ):
            continue
        var max_hp: int = maxi(1, int(candidate.get("max_hp", 1)))
        var amount: int = maxi(1, int(floor(float(max_hp) * F30_HAIL_DAMAGE_FRACTION)))
        amount = mini(amount, maxi(0, int(candidate.get("hp", 0))))
        if amount <= 0:
            continue
        candidate["hp"] = maxi(0, int(candidate.get("hp", 0)) - amount)
        if int(candidate.get("hp", 0)) <= 0:
            candidate["alive"] = false
            candidate["aggro"] = 0.0
        _spawn_feedback_label(candidate, "🌨️ −" + str(amount) + " KP", Color("c9e7ff"))
    _refresh_cards()
    _check_end()
