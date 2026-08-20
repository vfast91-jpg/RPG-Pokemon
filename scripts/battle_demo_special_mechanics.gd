extends "res://scripts/battle_demo_no_protocol_crit.gd"

# Central combat-lab layer for mechanics that do not fit the simple
# damage / temporary-stat-modifier path.
# Unknown mechanic kinds are reported loudly instead of silently doing nothing.

const KNOWN_MECHANIC_KINDS: Array[String] = [
    "damage",
    "status",
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod",
    "atb_knockback",
    "critical_focus",
    "seed",
    "binding",
    "cleanse_self"
]
const KNOWN_STATUS_IDS: Array[String] = [
    "paralysis", "confusion", "burn", "poison"
]

const BURN_DAMAGE_FRACTION: float = 1.0 / 16.0
const BURN_PHYSICAL_DAMAGE_MULTIPLIER: float = 0.50
const POISON_DAMAGE_FRACTION: float = 1.0 / 8.0
const SEED_DAMAGE_FRACTION: float = 1.0 / 8.0
const DEFAULT_BINDING_DAMAGE_FRACTION: float = 1.0 / 8.0

var _active_special_move: Dictionary = {}


func _load_data() -> void:
    super._load_data()
    _audit_move_mechanics()


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["major_status"] = ""
    combatant["seed_effect"] = {}
    combatant["binding_effect"] = {}
    combatant["damage_since_last_action"] = false
    return combatant


func _audit_move_mechanics() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        push_error("Attacken-Audit: moves-Dictionary fehlt.")
        return

    var moves: Dictionary = moves_value
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            push_error("Attacken-Audit: " + move_id + " ist keine gültige Attackendefinition.")
            continue

        var move: Dictionary = move_value
        var mechanics_value: Variant = move.get("mechanics", [])
        if not (mechanics_value is Array):
            push_error("Attacken-Audit: " + move_id + " besitzt keine gültige mechanics-Liste.")
            continue

        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                push_error("Attacken-Audit: " + move_id + " enthält einen ungültigen Mechanik-Eintrag.")
                continue

            var mechanic: Dictionary = mechanic_value
            var kind: String = str(mechanic.get("kind", ""))
            if not KNOWN_MECHANIC_KINDS.has(kind):
                push_error(
                    "Attacken-Audit: " + move_id + " verwendet unbekannte Mechanik '" + kind + "'."
                )
                continue

            if kind == "status":
                var status_id: String = str(mechanic.get("status", ""))
                if not KNOWN_STATUS_IDS.has(status_id):
                    push_error(
                        "Attacken-Audit: " + move_id + " verwendet nicht implementierten Status '"
                        + status_id + "'."
                    )


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    _active_special_move = _move_data(move_id)
    super._execute_move(actor, move_id)
    _active_special_move = {}

    # The target window for Gewissheit starts anew after this combatant's own
    # action has fully resolved. Damage that follows now (status/seed/binding)
    # belongs to the new window and sets the flag again.
    actor["damage_since_last_action"] = false

    if battle_active and bool(actor.get("alive", false)):
        _resolve_after_action_effects(actor)
        _refresh_cards()
        _check_end()


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    var resolved_target: Dictionary = target

    # Mechanic scope wins over the move's main target. This matters for moves
    # such as Turbodreher: it attacks an enemy but buffs/cleanses the user.
    if str(mechanic.get("scope", "")) == "self":
        resolved_target = actor

    match kind:
        "status":
            return _apply_status(actor, resolved_target, mechanic)
        "seed":
            return _apply_seed(actor, resolved_target, mechanic)
        "binding":
            return _apply_binding(actor, resolved_target, mechanic)
        "cleanse_self":
            return _cleanse_actor(actor, mechanic)
        _:
            return super._effect(actor, resolved_target, mechanic)


func _apply_status(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if randf() > float(mechanic.get("chance", 1.0)):
        return 0.0

    var status_id: String = str(mechanic.get("status", ""))
    if status_id == "confusion":
        target["confused_turns"] = randi_range(1, 4)
        return 3.0

    if not ["paralysis", "burn", "poison"].has(status_id):
        return 0.0

    # Only one major status may be active at a time.
    if not str(target.get("major_status", "")).is_empty():
        return 0.0

    var target_types: Array = _type_array(target.get("types", []))
    if status_id == "paralysis" and target_types.has("electric"):
        return 0.0
    if status_id == "burn" and target_types.has("fire"):
        return 0.0
    if status_id == "poison" and (target_types.has("poison") or target_types.has("steel")):
        return 0.0

    target["major_status"] = status_id
    if status_id == "paralysis":
        target["paralyzed"] = true
    return 3.0


func _apply_seed(actor: Dictionary, target: Dictionary, _mechanic: Dictionary) -> float:
    if not bool(target.get("alive", false)):
        return 0.0
    if _type_array(target.get("types", [])).has("grass"):
        _spawn_feedback_label(target, "🌿 KEIN EGELSAMEN", Color("b9d58d"))
        return 0.0

    var existing_value: Variant = target.get("seed_effect", {})
    if existing_value is Dictionary and not (existing_value as Dictionary).is_empty():
        return 0.0

    target["seed_effect"] = {
        "source_side": str(actor.get("side", "")),
        "source_index": int(actor.get("index", -1)),
        "damage_fraction": SEED_DAMAGE_FRACTION
    }
    return 5.0


func _apply_binding(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if not bool(target.get("alive", false)):
        return 0.0

    var existing_value: Variant = target.get("binding_effect", {})
    if existing_value is Dictionary and not (existing_value as Dictionary).is_empty():
        # Binding neither stacks nor refreshes while active.
        return 0.0

    var min_ticks: int = maxi(1, int(mechanic.get("min_ticks", 4)))
    var max_ticks: int = maxi(min_ticks, int(mechanic.get("max_ticks", min_ticks)))
    target["binding_effect"] = {
        "source_side": str(actor.get("side", "")),
        "source_index": int(actor.get("index", -1)),
        "ticks_left": randi_range(min_ticks, max_ticks),
        "damage_fraction": float(mechanic.get("damage_fraction", DEFAULT_BINDING_DAMAGE_FRACTION))
    }
    return 4.0


func _cleanse_actor(actor: Dictionary, mechanic: Dictionary) -> float:
    var removed: int = 0
    var effects_value: Variant = mechanic.get("effects", [])
    var effects: Array = effects_value if effects_value is Array else []

    if effects.has("seeded"):
        var seed_value: Variant = actor.get("seed_effect", {})
        if seed_value is Dictionary and not (seed_value as Dictionary).is_empty():
            actor["seed_effect"] = {}
            removed += 1

    if effects.has("binding"):
        var binding_value: Variant = actor.get("binding_effect", {})
        if binding_value is Dictionary and not (binding_value as Dictionary).is_empty():
            actor["binding_effect"] = {}
            removed += 1

    if removed > 0:
        _spawn_feedback_label(actor, "✨ BEFREIT", Color("9fe7bd"))
    return float(removed) * 3.0


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var effective_power: int = power

    if (
        str(actor.get("id", "")) != str(target.get("id", ""))
        and bool(target.get("damage_since_last_action", false))
        and _active_move_has_damage_flag("conditional_double_if_damaged_since_last_action")
    ):
        effective_power *= 2
        _spawn_feedback_label(target, "💢 GEWISSHEIT ×2", Color("ffe099"))

    var damage: int = super._damage(actor, target, effective_power, move_type, category)

    if (
        damage > 0
        and str(actor.get("id", "")) != str(target.get("id", ""))
        and str(actor.get("major_status", "")) == "burn"
        and category == "physical"
    ):
        damage = maxi(1, int(round(float(damage) * BURN_PHYSICAL_DAMAGE_MULTIPLIER)))

    if damage > 0:
        target["damage_since_last_action"] = true
    return damage


func _active_move_has_damage_flag(flag_name: String) -> bool:
    if _active_special_move.is_empty():
        return false
    var mechanics_value: Variant = _active_special_move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false
    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        if str(mechanic.get("kind", "")) == "damage" and bool(mechanic.get(flag_name, false)):
            return true
    return false


func _resolve_after_action_effects(combatant: Dictionary) -> void:
    if not bool(combatant.get("alive", false)):
        return

    var major_status: String = str(combatant.get("major_status", ""))
    if major_status == "burn":
        _deal_periodic_damage(combatant, BURN_DAMAGE_FRACTION, "🔥 VERBRENNUNG")
    elif major_status == "poison":
        _deal_periodic_damage(combatant, POISON_DAMAGE_FRACTION, "☠️ VERGIFTUNG")

    if not bool(combatant.get("alive", false)):
        return
    _resolve_seed_tick(combatant)

    if not bool(combatant.get("alive", false)):
        return
    _resolve_binding_tick(combatant)


func _deal_periodic_damage(combatant: Dictionary, fraction: float, label_text: String) -> int:
    var amount: int = maxi(1, int(floor(float(combatant.get("max_hp", 1)) * fraction)))
    var actual: int = mini(amount, int(combatant.get("hp", 0)))
    if actual <= 0:
        return 0

    combatant["hp"] = maxi(0, int(combatant.get("hp", 0)) - actual)
    combatant["damage_since_last_action"] = true
    _spawn_feedback_label(combatant, label_text + " −" + str(actual), Color("ff9a83"))

    if int(combatant.get("hp", 0)) <= 0:
        combatant["alive"] = false
    return actual


func _resolve_seed_tick(target: Dictionary) -> void:
    var seed_value: Variant = target.get("seed_effect", {})
    if not (seed_value is Dictionary) or (seed_value as Dictionary).is_empty():
        return
    var seed: Dictionary = seed_value

    var source: Dictionary = _effect_source_occupant(seed)
    if source.is_empty():
        # No current occupant in the source team position: no drain tick.
        return

    var fraction: float = float(seed.get("damage_fraction", SEED_DAMAGE_FRACTION))
    var amount: int = maxi(1, int(floor(float(target.get("max_hp", 1)) * fraction)))
    var actual: int = mini(amount, int(target.get("hp", 0)))
    if actual <= 0:
        return

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    _spawn_feedback_label(target, "🌱 EGELSAMEN −" + str(actual), Color("a9db82"))

    var missing_hp: int = maxi(0, int(source.get("max_hp", 0)) - int(source.get("hp", 0)))
    var healed: int = mini(actual, missing_hp)
    if healed > 0:
        source["hp"] = int(source.get("hp", 0)) + healed
        _spawn_feedback_label(source, "🌱 +" + str(healed) + " KP", Color("8fe39b"))

    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false


func _resolve_binding_tick(target: Dictionary) -> void:
    var binding_value: Variant = target.get("binding_effect", {})
    if not (binding_value is Dictionary) or (binding_value as Dictionary).is_empty():
        return
    var binding: Dictionary = binding_value

    if _effect_source_occupant(binding).is_empty():
        target["binding_effect"] = {}
        return

    var fraction: float = float(binding.get("damage_fraction", DEFAULT_BINDING_DAMAGE_FRACTION))
    _deal_periodic_damage(target, fraction, "🪢 WICKEL")

    var ticks_left: int = int(binding.get("ticks_left", 1)) - 1
    if ticks_left <= 0 or not bool(target.get("alive", false)):
        target["binding_effect"] = {}
    else:
        binding["ticks_left"] = ticks_left
        target["binding_effect"] = binding


func _effect_source_occupant(effect: Dictionary) -> Dictionary:
    var source_side: String = str(effect.get("source_side", ""))
    var source_index: int = int(effect.get("source_index", -1))
    if source_side.is_empty() or source_index < 0:
        return {}

    var team: Array = _team_for_side(source_side)
    if source_index >= team.size():
        return {}
    var candidate_value: Variant = team[source_index]
    if not (candidate_value is Dictionary):
        return {}
    var candidate: Dictionary = candidate_value
    return candidate if bool(candidate.get("alive", false)) else {}


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var major_status: String = str(combatant.get("major_status", ""))
    if major_status == "burn":
        tokens.append("🔥 BRN")
    elif major_status == "poison":
        tokens.append("☠️ GIF")

    var seed_value: Variant = combatant.get("seed_effect", {})
    if seed_value is Dictionary and not (seed_value as Dictionary).is_empty():
        tokens.append("🌱 SAMEN")

    var binding_value: Variant = combatant.get("binding_effect", {})
    if binding_value is Dictionary and not (binding_value as Dictionary).is_empty():
        var binding: Dictionary = binding_value
        tokens.append("🪢 BIND" + str(int(binding.get("ticks_left", 0))))
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var base_text: String = super._detail_info(combatant)
    var extras: Array[String] = []

    var major_status: String = str(combatant.get("major_status", ""))
    if major_status == "burn":
        extras.append("🔥 Verbrennung: 1/16 Max-KP nach eigener Aktion; physischer Schaden ×0,50")
    elif major_status == "poison":
        extras.append("☠️ Vergiftung: 1/8 Max-KP nach eigener Aktion")

    var seed_value: Variant = combatant.get("seed_effect", {})
    if seed_value is Dictionary and not (seed_value as Dictionary).is_empty():
        extras.append("🌱 Egelsamen: nach eigener Aktion 1/8 Max-KP; Schaden heilt die Quellposition")

    var binding_value: Variant = combatant.get("binding_effect", {})
    if binding_value is Dictionary and not (binding_value as Dictionary).is_empty():
        var binding: Dictionary = binding_value
        extras.append("🪢 Gebunden: noch " + str(int(binding.get("ticks_left", 0))) + " eigene Aktion(en)")

    var critical_bonus: float = float(combatant.get("critical_focus_bonus", 0.0))
    if critical_bonus > 0.0001:
        extras.append("🔥 Energiefokus: Krit-Chance +" + str(int(round(critical_bonus * 100.0))) + " Prozentpunkte")

    if extras.is_empty():
        return base_text
    return base_text + "\n\n[b]SONDEREFFEKTE[/b]\n• " + "\n• ".join(extras)


func _feedback_snapshot(target: Dictionary) -> Dictionary:
    var snapshot: Dictionary = super._feedback_snapshot(target)
    snapshot["major_status"] = str(target.get("major_status", ""))

    var seed_value: Variant = target.get("seed_effect", {})
    snapshot["seeded"] = seed_value is Dictionary and not (seed_value as Dictionary).is_empty()

    var binding_value: Variant = target.get("binding_effect", {})
    snapshot["bound"] = binding_value is Dictionary and not (binding_value as Dictionary).is_empty()
    return snapshot


func _feedback_result(target: Dictionary, before: Dictionary) -> Dictionary:
    var base_result: Dictionary = super._feedback_result(target, before)
    var lines: Array[String] = []
    var base_text: String = str(base_result.get("text", ""))
    if not base_text.is_empty() and base_text != "KEIN EFFEKT":
        lines.append(base_text)

    var negative: bool = str(base_result.get("kind", "neutral")) == "negative"
    var positive: bool = str(base_result.get("kind", "neutral")) == "positive"

    var before_status: String = str(before.get("major_status", ""))
    var after_status: String = str(target.get("major_status", ""))
    if before_status != after_status:
        if after_status == "burn":
            lines.append("VERBRANNT")
            negative = true
        elif after_status == "poison":
            lines.append("VERGIFTET")
            negative = true

    var seed_value: Variant = target.get("seed_effect", {})
    var seeded_now: bool = seed_value is Dictionary and not (seed_value as Dictionary).is_empty()
    if not bool(before.get("seeded", false)) and seeded_now:
        lines.append("EGELSAMEN")
        negative = true

    var binding_value: Variant = target.get("binding_effect", {})
    var bound_now: bool = binding_value is Dictionary and not (binding_value as Dictionary).is_empty()
    if not bool(before.get("bound", false)) and bound_now:
        lines.append("GEBUNDEN")
        negative = true

    if lines.is_empty():
        lines.append("KEIN EFFEKT")

    var kind: String = "neutral"
    if negative:
        kind = "negative"
    elif positive:
        kind = "positive"
    return {"kind": kind, "text": " · ".join(lines)}
