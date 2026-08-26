extends "res://scripts/battle_demo_zf_status_v1.gd"

# Final major-status Aggro integrity layer.
#
# Several later family/runtime handlers reintroduced historical fixed Aggro
# awards (for example 3 or 40) even though the central Timeflow rule values the
# effect that actually happened. This layer keeps those established status
# mechanics, immunities and durations intact, but normalizes their returned
# effect-Aggro through the central status helper.
#
# Burn / poison / severe poison use one status application unit. Freeze and
# sleep are valued by the actually imposed own-action opportunities. Confusion
# only values newly added confusion actions. Paralysis uses the central
# speed-loss + Max-HP formula.

const STATUS_AGGRO_CORE_IDS: Array[String] = [
    "burn",
    "poison",
    "bad_poison",
    "toxic",
    "paralysis",
    "sleep",
    "freeze",
    "confusion"
]


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    var status_id: String = str(mechanic.get("status", ""))
    if kind in ["status", "db_status"] and status_id in STATUS_AGGRO_CORE_IDS:
        var before: Dictionary = _status_aggro_snapshot(target)
        super._effect(actor, target, mechanic)
        return _status_aggro_for_transition(target, status_id, before)
    return super._effect(actor, target, mechanic)


func _zf_apply_status_direct(
    actor: Dictionary,
    target: Dictionary,
    status_id: String,
    chance: float
) -> float:
    var before: Dictionary = _status_aggro_snapshot(target)
    super._zf_apply_status_direct(actor, target, status_id, chance)

    # The legacy ZF confusion helper rerolled 1-4 actions even while confusion
    # was already active. A reroll must never shorten an existing effect; only
    # a real extension may create additional effect-Aggro.
    if status_id == "confusion":
        var before_turns: int = maxi(0, int(before.get("confused_turns", 0)))
        var after_turns: int = maxi(0, int(target.get("confused_turns", 0)))
        if after_turns < before_turns:
            target["confused_turns"] = before_turns

    return _status_aggro_for_transition(target, status_id, before)


func _zf_sleep(target: Dictionary, mechanic: Dictionary) -> float:
    var before: Dictionary = _status_aggro_snapshot(target)
    super._zf_sleep(target, mechanic)
    return _status_aggro_for_transition(target, "sleep", before)


func _zf_bad_poison(
    actor: Dictionary,
    target: Dictionary,
    mechanic: Dictionary
) -> float:
    var before: Dictionary = _status_aggro_snapshot(target)
    super._zf_bad_poison(actor, target, mechanic)
    return _status_aggro_for_transition(target, "bad_poison", before)


func _zf_cleanse_major(target: Dictionary) -> float:
    var before: Dictionary = _status_aggro_snapshot(target)
    super._zf_cleanse_major(target)

    var before_status: String = str(before.get("major_status", ""))
    var after_status: String = str(target.get("major_status", ""))
    if before_status.is_empty() or before_status == after_status:
        return 0.0
    return _status_aggro_for_removed_status(target, before_status, before)


func _status_aggro_snapshot(target: Dictionary) -> Dictionary:
    return {
        "major_status": str(target.get("major_status", "")),
        "paralyzed": bool(target.get("paralyzed", false)),
        "confused_turns": maxi(0, int(target.get("confused_turns", 0))),
        "sleep_actions": maxi(0, int(target.get("db_sleep_actions", 0))),
        "freeze_actions": maxi(0, int(target.get("zf_freeze_actions", 0))),
        "bad_poison_stage": maxi(0, int(target.get("tf_bad_poison_stage", 0)))
    }


func _status_aggro_for_transition(
    target: Dictionary,
    status_id: String,
    before: Dictionary
) -> float:
    var normalized: String = "bad_poison" if status_id == "toxic" else status_id
    var before_status: String = str(before.get("major_status", ""))
    var after_status: String = str(target.get("major_status", ""))

    match normalized:
        "confusion":
            var old_turns: int = maxi(0, int(before.get("confused_turns", 0)))
            var new_turns: int = maxi(0, int(target.get("confused_turns", 0)))
            var added_turns: int = maxi(0, new_turns - old_turns)
            if added_turns <= 0:
                return 0.0
            return _status_application_aggro(target, "confusion", added_turns)

        "sleep":
            if before_status == "sleep" or after_status != "sleep":
                return 0.0
            var sleep_actions: int = maxi(1, int(target.get("db_sleep_actions", 0)))
            return _status_application_aggro(target, "sleep", sleep_actions)

        "freeze":
            if before_status == "freeze" or after_status != "freeze":
                return 0.0
            var freeze_actions: int = maxi(1, int(target.get("zf_freeze_actions", 0)))
            return _status_application_aggro(target, "freeze", freeze_actions)

        "paralysis":
            var was_paralyzed: bool = (
                bool(before.get("paralyzed", false))
                or before_status == "paralysis"
            )
            var is_paralyzed: bool = (
                bool(target.get("paralyzed", false))
                or after_status == "paralysis"
            )
            if was_paralyzed or not is_paralyzed:
                return 0.0
            return _status_application_aggro(target, "paralysis")

        "burn", "poison":
            if before_status == normalized or after_status != normalized:
                return 0.0
            return _status_application_aggro(target, normalized)

        "bad_poison":
            var old_stage: int = maxi(0, int(before.get("bad_poison_stage", 0)))
            var new_stage: int = maxi(0, int(target.get("tf_bad_poison_stage", 0)))
            var status_changed: bool = (
                before_status != after_status
                and after_status in ["bad_poison", "toxic", "poison"]
            )
            if new_stage <= old_stage and not status_changed:
                return 0.0
            return _status_application_aggro(target, "bad_poison")

    return 0.0


func _status_aggro_for_removed_status(
    target: Dictionary,
    status_id: String,
    before: Dictionary
) -> float:
    var normalized: String = "bad_poison" if status_id == "toxic" else status_id
    match normalized:
        "sleep":
            return _status_application_aggro(
                target,
                "sleep",
                maxi(1, int(before.get("sleep_actions", 0)))
            )
        "freeze":
            return _status_application_aggro(
                target,
                "freeze",
                maxi(1, int(before.get("freeze_actions", 0)))
            )
        "paralysis":
            return _status_application_aggro(target, "paralysis")
        "burn", "poison", "bad_poison":
            return _status_application_aggro(target, normalized)
    return 0.0
