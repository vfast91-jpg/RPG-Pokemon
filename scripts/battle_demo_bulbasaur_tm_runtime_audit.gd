extends "res://scripts/battle_demo_bulbasaur_tm_text.gd"

# Focused regression layer for Bisasam-family TM behavior.
# Keep the move data authoritative and only bridge state transitions that need
# battle-runtime context (most importantly Schlafrede -> Erholung).


func _bulba_rest(actor: Dictionary) -> float:
    if int(actor.get("hp", 0)) >= int(actor.get("max_hp", 1)):
        _spawn_feedback_label(actor, "✖ KP BEREITS VOLL", Color("d9a5a5"))
        return 0.0
    if _database_status_is_blocked(actor, "sleep"):
        _spawn_feedback_label(actor, "🛡️ SCHLAF VERHINDERT", Color("b8d9ff"))
        return 0.0

    var missing: int = maxi(0, int(actor.get("max_hp", 1)) - int(actor.get("hp", 0)))
    var had_major_status: bool = (
        not str(actor.get("major_status", "")).is_empty()
        or bool(actor.get("paralyzed", false))
    )

    # Erholung removes the existing major status first and then applies its own
    # exact two-action sleep. This also matters when Erholung is called by
    # Schlafrede: the newly created sleep must survive the Schlafrede wrapper.
    actor["major_status"] = ""
    actor["paralyzed"] = false
    actor["db_sleep_actions"] = 0
    actor["hp"] = int(actor.get("max_hp", 1))
    actor["major_status"] = "sleep"
    actor["db_sleep_actions"] = 2
    _spawn_feedback_label(actor, "🛌 VOLLE KP · SCHLAF 2", Color("bfc8ff"))
    return float(missing) + (3.0 if had_major_status else 0.0)


func _bulba_sleep_talk_candidates(actor: Dictionary) -> Array[String]:
    var candidates: Array[String] = []
    var moves_value: Variant = actor.get("moves", [])
    if not (moves_value is Array):
        return candidates

    for move_value: Variant in moves_value:
        var candidate_id: String = str(move_value)
        if SLEEP_TALK_FORBIDDEN_IDS.has(candidate_id):
            continue
        var candidate: Dictionary = _move_data(candidate_id)
        if candidate.is_empty() or not _runtime_has_move(candidate_id):
            continue
        var runtime_value: Variant = candidate.get("runtime", {})
        if runtime_value is Dictionary and not bool((runtime_value as Dictionary).get("sleep_talk_eligible", true)):
            continue
        candidates.append(candidate_id)
    return candidates


func _bulba_execute_sleep_talk(actor: Dictionary) -> void:
    var sleep_left: int = maxi(0, int(actor.get("db_sleep_actions", 0)))
    var remaining: int = maxi(0, sleep_left - 1)
    var candidates: Array[String] = _bulba_sleep_talk_candidates(actor)

    if candidates.is_empty():
        _bulba_consume_empty_sleep_talk(actor)
        _bulba_finish_sleep_talk_status(actor, remaining)
        return

    var chosen_id: String = str(candidates.pick_random())
    var chosen: Dictionary = _move_data(chosen_id)
    var original: Dictionary = chosen.duplicate(true)
    var sleep_talk: Dictionary = _move_data("sleep_talk")
    var triggered: Dictionary = chosen.duplicate(true)
    triggered["ap"] = int(sleep_talk.get("ap", 7))
    triggered["name"] = "Schlafrede → " + str(chosen.get("name", chosen_id))

    data["moves"][chosen_id] = triggered
    actor["db_sleep_talk_originally_asleep"] = true
    actor["major_status"] = ""
    actor["db_sleep_actions"] = 0
    _spawn_feedback_label(actor, "😴 → " + str(chosen.get("name", chosen_id)), Color("c8b9e8"))
    _execute_move(actor, chosen_id)
    data["moves"][chosen_id] = original
    actor["db_sleep_talk_originally_asleep"] = false

    _bulba_finish_sleep_talk_status(actor, remaining)


func _bulba_consume_empty_sleep_talk(actor: Dictionary) -> void:
    var sleep_talk: Dictionary = _move_data("sleep_talk")
    if sleep_talk.is_empty():
        return
    var original: Dictionary = sleep_talk.duplicate(true)
    var neutral: Dictionary = sleep_talk.duplicate(true)
    neutral["mechanics"] = []
    data["moves"]["sleep_talk"] = neutral

    actor["major_status"] = ""
    actor["db_sleep_actions"] = 0
    _execute_move(actor, "sleep_talk")
    data["moves"]["sleep_talk"] = original
    _spawn_feedback_label(actor, "😴 KEINE GEEIGNETE ATTACKE", Color("c8b9e8"))


func _bulba_finish_sleep_talk_status(actor: Dictionary, remaining: int) -> void:
    if not bool(actor.get("alive", false)):
        return

    var post_status: String = str(actor.get("major_status", ""))
    var post_sleep_actions: int = maxi(0, int(actor.get("db_sleep_actions", 0)))

    # A called move may create a new major status of its own. Erholung is the
    # relevant Bisasam case: its fresh two-action sleep must not be overwritten
    # by the old sleep countdown from Schlafrede.
    if post_status == "sleep" and post_sleep_actions > 0:
        return
    if not post_status.is_empty():
        actor["db_sleep_actions"] = 0
        return

    if remaining > 0:
        actor["major_status"] = "sleep"
        actor["db_sleep_actions"] = remaining
        return

    actor["major_status"] = ""
    actor["db_sleep_actions"] = 0
    _spawn_feedback_label(actor, "✨ WACHT AUF", Color("f0e7a6"))
