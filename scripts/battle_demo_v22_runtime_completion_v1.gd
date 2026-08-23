extends "res://scripts/battle_demo_move_info_standard_v1.gd"

# Final V22 runtime completion layer. This sits above the presentation layer so
# newer UI work on main remains active while late runtime gaps are closed.

const V22_ROOTED_BLOCKED_PAUSE_MOVE_IDS: Array[String] = ["roar", "whirlwind"]


func _v22_apply_runtime_fixes() -> void:
    super._v22_apply_runtime_fixes()
    _v22_complete_whirlwind_and_roar()
    _v22_complete_ingrain()


func _v22_complete_whirlwind_and_roar() -> void:
    _v22_upsert_atb_pause_move(
        "whirlwind", "Wirbelwind",
        "Ein heftiger Wind stoppt die ATB-Leiste des Ziels vorübergehend.",
        100.0, "🌪️",
        "Keine Reserve und kein Zwangswechsel. Nach der Pause Fortsetzung vom vorherigen ATB-Füllstand. Gleiche zentrale ATB-Pause wie Brüller."
    )
    _v22_upsert_atb_pause_move(
        "roar", "Brüller",
        "Ein einschüchternder Ruf pausiert die Aktionsleiste des Ziels.",
        null, "📢",
        "Keine Reserve/kein Wechsel. Nach der Pause Fortsetzung vom vorherigen ATB-Füllstand. Exakt dieselbe zentrale Mechanik wie Wirbelwind."
    )


func _v22_upsert_atb_pause_move(
    move_id: String,
    display_name: String,
    description: String,
    accuracy_value: Variant,
    emoji: String,
    special_rule: String
) -> void:
    var move: Dictionary = _move_data(move_id)
    move = {} if move.is_empty() else move.duplicate(true)
    move["schema_version"] = move.get("schema_version", 3)
    move["id"] = move_id
    move["name"] = display_name
    move["description"] = description
    move["emoji"] = emoji
    move["type"] = "normal"
    move["category"] = "status"
    move["power"] = null
    move["accuracy"] = accuracy_value
    move["ap"] = 5
    move["target"] = "enemy_highest_aggro"
    move["area"] = false
    move["contact"] = false
    move["priority"] = 0
    move["opening"] = false
    move["opening_only"] = false
    move["mechanics"] = [{"kind": "db_atb_pause"}]
    move["status_scaling"] = "Soft-Cap-Dauer: Ziel-Vollzyklus × R; R=Status/(75+Status)"
    move["aggro"] = {
        "from_damage": false,
        "from_status": true,
        "from_healing": false
    }
    move["special_rules"] = [
        special_rule,
        "ATB-Pausendauer = normale volle ATB-Zyklusdauer des Ziels × Status/(75+Status)."
    ]
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true)
        if runtime_value is Dictionary else {}
    )
    runtime["runtime_supported"] = true
    runtime.erase("partial")
    runtime.erase("notes")
    move["runtime"] = runtime
    _v22_replace_runtime_move(move_id, move)


func _v22_complete_ingrain() -> void:
    var move: Dictionary = _move_data("ingrain")
    move = {} if move.is_empty() else move.duplicate(true)
    move["schema_version"] = 3
    move["id"] = "ingrain"
    move["name"] = "Verwurzler"
    move["description"] = (
        "Der Anwender verwurzelt sich und regeneriert nach jeder eigenen Aktion KP. "
        + "Die Heilung richtet sich nach seinem Statuswert. Brüller und Wirbelwind "
        + "können ihn nicht aus dem Rhythmus bringen."
    )
    move["emoji"] = "🌱"
    move["type"] = "grass"
    move["category"] = "status"
    move["power"] = null
    move["accuracy"] = null
    move["ap"] = 5
    move["target"] = "self"
    move["area"] = false
    move["contact"] = false
    move["priority"] = 0
    move["opening"] = false
    move["opening_only"] = false
    move["mechanics"] = [{"kind": "v22_ingrain"}]
    move["status_scaling"] = (
        "Zentrale Statuskurve: Heilung je Auslösung = Max-KP × 0,125 × R; "
        + "R=Status/(75+Status). Rooted ist binär und skaliert nicht."
    )
    move["aggro"] = {
        "from_damage": false,
        "from_status": false,
        "from_healing": true
    }
    move["special_rules"] = [
        "Nicht stapelbar; erneuter Einsatz während aktivem Verwurzler schlägt fehl.",
        "Heilt nach jeder vollständig ausgeführten eigenen Aktion um Max-KP × 0,125 × Status/(75+Status).",
        "Rooted verhindert ausschließlich Brüller und Wirbelwind; Drachenrute und andere ATB-Pausen bleiben erlaubt.",
        "Nur tatsächlich wiederhergestellte KP erzeugen Heilungs-Aggro."
    ]
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true)
        if runtime_value is Dictionary else {}
    )
    runtime["runtime_supported"] = true
    runtime["v22_persistent_ingrain"] = true
    runtime.erase("partial")
    runtime.erase("notes")
    move["runtime"] = runtime
    _v22_replace_runtime_move("ingrain", move)


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["v22_ingrain_active"] = false
    combatant["v22_ingrain_last_heal_serial"] = -1
    return combatant


func _process(delta: float) -> void:
    # V22 ATB pause freezes the exact fill. Hide paused combatants from the
    # inherited pause implementation, let the normal ATB loop advance everyone
    # else, then restore the frozen bar exactly. This also prevents a bar already
    # at 100 % from acting while paused.
    var frozen_states: Array = []
    var tick_pause: bool = battle_active and not paused and not opening_phase_active
    if tick_pause:
        for combatant_value: Variant in combatants:
            if not (combatant_value is Dictionary):
                continue
            var combatant: Dictionary = combatant_value
            var remaining: float = maxf(
                0.0,
                float(combatant.get("db_atb_pause_remaining_seconds", 0.0))
            )
            if remaining <= 0.0 or not bool(combatant.get("alive", false)):
                continue
            var stored_atb: float = float(combatant.get("atb", 0.0))
            frozen_states.append({
                "combatant": combatant,
                "cycle": float(combatant.get("cycle", 1.0)),
                "atb": stored_atb,
                "remaining": remaining
            })
            combatant["db_atb_pause_remaining_seconds"] = 0.0
            combatant["cycle"] = maxf(1.0, float(combatant.get("cycle", 1.0))) * 1000000.0
            if stored_atb >= 100.0:
                combatant["atb"] = 99.999

    super._process(delta)

    for frozen_value: Variant in frozen_states:
        if not (frozen_value is Dictionary):
            continue
        var frozen: Dictionary = frozen_value
        var combatant_value: Variant = frozen.get("combatant", {})
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        combatant["cycle"] = float(frozen.get("cycle", 1.0))
        if bool(combatant.get("alive", false)):
            combatant["atb"] = float(frozen.get("atb", combatant.get("atb", 0.0)))
            combatant["db_atb_pause_remaining_seconds"] = maxf(
                0.0,
                float(frozen.get("remaining", 0.0)) - delta
            )
        else:
            combatant["db_atb_pause_remaining_seconds"] = 0.0

    if not frozen_states.is_empty():
        _refresh_cards()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind == "v22_ingrain":
        return _v22_apply_ingrain(actor)
    if kind == "db_atb_pause":
        var move_id: String = _v22_completion_current_move_id()
        if V22_ROOTED_BLOCKED_PAUSE_MOVE_IDS.has(move_id) and _v22_is_rooted(target):
            _spawn_feedback_label(target, "🌱 VERWURZELT", Color("a8d59a"))
            _set_log(
                _actor_name(target) + " ist verwurzelt; "
                + str(_move_data(move_id).get("name", move_id))
                + " kann seine ATB-Leiste nicht pausieren."
            )
            return 0.0
    return super._effect(actor, target, mechanic)


func _v22_apply_ingrain(actor: Dictionary) -> float:
    if actor.is_empty() or not bool(actor.get("alive", false)):
        return 0.0
    if bool(actor.get("v22_ingrain_active", false)):
        _spawn_feedback_label(actor, "✖ VERWURZLER AKTIV", Color("d9a5a5"))
        return 0.0
    actor["v22_ingrain_active"] = true
    actor["v22_ingrain_last_heal_serial"] = -1
    _tf_set_state(actor, "rooted", true)
    _spawn_feedback_label(actor, "🌱 VERWURZELT", Color("a8d59a"))
    return 0.0


func _f30_trigger_aqua_ring_after_action(actor: Dictionary) -> void:
    super._f30_trigger_aqua_ring_after_action(actor)
    _v22_trigger_ingrain_after_action(actor)


func _v22_trigger_ingrain_after_action(actor: Dictionary) -> void:
    if (
        actor.is_empty()
        or not bool(actor.get("alive", false))
        or not bool(actor.get("v22_ingrain_active", false))
    ):
        return
    var serial: int = int(actor.get("action_serial", 0))
    if int(actor.get("v22_ingrain_last_heal_serial", -1)) == serial:
        return
    actor["v22_ingrain_last_heal_serial"] = serial

    var max_hp: int = maxi(1, int(actor.get("max_hp", 1)))
    var missing: int = maxi(0, max_hp - int(actor.get("hp", 0)))
    if missing <= 0:
        return
    var ratio: float = _status_ratio(float(actor.get("special", 0.0)))
    if ratio <= 0.0:
        return
    var requested: int = maxi(1, int(round(float(max_hp) * 0.125 * ratio)))
    var healed: int = mini(missing, requested)
    if healed <= 0:
        return
    actor["hp"] = int(actor.get("hp", 0)) + healed
    actor["aggro"] = float(actor.get("aggro", 0.0)) + float(healed)
    _spawn_feedback_label(actor, "🌱 +" + str(healed) + " KP", Color("8fe39b"))


func _v22_is_rooted(combatant: Dictionary) -> bool:
    if combatant.is_empty():
        return false
    return bool(combatant.get("v22_ingrain_active", false)) or _tf_has_state(combatant, "rooted")


func _v22_completion_current_move_id() -> String:
    if not _v22_active_move_id.is_empty():
        return _v22_active_move_id
    if not _database_move_id.is_empty():
        return _database_move_id
    if not _database_active_move.is_empty():
        return str(_database_active_move.get("id", ""))
    return ""


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if _v22_is_rooted(combatant):
        tokens.append("🌱 VERWURZELT")
    return tokens
