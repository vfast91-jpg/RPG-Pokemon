extends "res://scripts/battle_demo_typenspiegel_ui_fix_v1.gd"

# Final V22 consistency layer.
#
# The battle stack is intentionally layered by family. Several legacy family
# packs are loaded *after* the original move-contract compiler. This layer runs
# after every loader and normalizes the final composed move dictionary without
# rejecting the newer family-specific mechanic IDs. It also centralizes V22
# rules that must be identical across generations of move packs.

const V22_FlinchRules = preload("res://scripts/battle/flinch_rules.gd")
const V22_EXPECTED_MOVE_COUNT: int = 479

const V22_PER_TARGET_ACCURACY_IDS: Array[String] = [
    "string_shot", "razor_leaf", "heat_wave", "electroweb", "hurricane",
    "rock_slide", "air_cutter", "icy_wind", "blizzard", "muddy_water",
    "snarl", "poison_gas"
]

const V22_FLINCH_IDS: Array[String] = [
    "bite", "fire_fang", "air_slash", "twister", "ice_fang",
    "thunder_fang", "rock_slide", "zen_headbutt", "dark_pulse", "snore",
    "iron_head", "extrasensory", "sky_attack", "astonish", "waterfall",
    "stomp", "headbutt", "icicle_crash", "mountain_gale", "dragon_rush"
]

const V22_SINGLE_ENEMY_IDS: Array[String] = [
    "switcheroo", "transform", "conversion_2"
]

const V22_ALL_OTHERS_IDS: Array[String] = [
    "self_destruct", "explosion", "brutal_swing"
]

const V22_UNCONDITIONAL_SELF_KO_IDS: Array[String] = [
    "self_destruct", "explosion"
]

var _v22_active_move_id: String = ""
var _v22_per_target_misses: Dictionary = {}
var _v22_per_target_miss_feedback: Dictionary = {}
var _v22_missed_target_aggro_before: Dictionary = {}


func _load_data() -> void:
    super._load_data()
    _v22_normalize_final_move_shapes()
    _v22_apply_runtime_fixes()
    _v22_audit_final_move_set()


func _v22_normalize_final_move_shapes() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        push_error("V22: data.moves fehlt nach Abschluss aller Familien-Lader.")
        return

    var moves: Dictionary = moves_value
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var source_value: Variant = moves.get(move_id, {})
        if not (source_value is Dictionary):
            push_error("V22: ungültige Attackendefinition: " + move_id)
            continue

        var move: Dictionary = (source_value as Dictionary).duplicate(true)
        if not move.has("ap") and move.has("rpg_ap"):
            move["ap"] = move.get("rpg_ap")
        if not move.has("opening") and move.has("opening_phase"):
            move["opening"] = move.get("opening_phase")
        if not move.has("priority") and move.has("priority_reference"):
            move["priority"] = move.get("priority_reference")

        if not move.has("mechanics") and move.get("effects", null) is Array:
            var normalized: Array = []
            for mechanic_value: Variant in move.get("effects", []):
                normalized.append(_v22_normalize_mechanic(mechanic_value))
            move["mechanics"] = normalized
        elif move.get("mechanics", null) is Array:
            var normalized_existing: Array = []
            for mechanic_value: Variant in move.get("mechanics", []):
                normalized_existing.append(_v22_normalize_mechanic(mechanic_value))
            move["mechanics"] = normalized_existing

        var runtime_value: Variant = move.get("runtime", {})
        if not (runtime_value is Dictionary):
            move["runtime"] = {}

        moves[move_id] = move

    data["moves"] = moves

    # Keep the canonical cache in lockstep so later species rebuilds and UI
    # lookups cannot resurrect the pre-normalized legacy shape.
    var canonical_value: Variant = _canonical_pack.get("moves", {})
    if canonical_value is Dictionary:
        var canonical_moves: Dictionary = canonical_value
        for move_id_value: Variant in moves.keys():
            canonical_moves[str(move_id_value)] = (moves[move_id_value] as Dictionary).duplicate(true)
        _canonical_pack["moves"] = canonical_moves


func _v22_normalize_mechanic(value: Variant) -> Variant:
    if not (value is Dictionary):
        return value
    var mechanic: Dictionary = (value as Dictionary).duplicate(true)
    if str(mechanic.get("kind", "")) == "apply_status":
        mechanic["kind"] = "status"
    if (
        str(mechanic.get("kind", "")) == "db_chance_mechanic"
        and mechanic.get("mechanic", null) is Dictionary
    ):
        mechanic["mechanic"] = _v22_normalize_mechanic(mechanic.get("mechanic"))
    return mechanic


func _v22_apply_runtime_fixes() -> void:
    for move_id: String in V22_PER_TARGET_ACCURACY_IDS:
        _v22_set_runtime_flag(move_id, "v22_per_target_accuracy", true)

    for move_id: String in V22_SINGLE_ENEMY_IDS:
        _v22_set_target(move_id, "single_enemy", false)
        _v22_set_runtime_flag(move_id, "requires_enemy_selection", true)

    for move_id: String in V22_ALL_OTHERS_IDS:
        _v22_set_target(move_id, "all_others", true)

    for move_id: String in V22_UNCONDITIONAL_SELF_KO_IDS:
        _v22_set_runtime_flag(move_id, "v22_unconditional_self_ko", true)
        _v22_set_runtime_flag(move_id, "f40_self_ko_on_any_damage", false)

    # V22: Rock Slide's secondary effect is real flinch, not legacy numeric
    # ATB knockback, and a successful flinch is a status-aggro source.
    _v22_set_aggro_flag("rock_slide", "status", true)
    _v22_patch_text(
        "rock_slide",
        "Ein Steinhagel trifft alle Gegner und kann sie zurückschrecken lassen.",
        [
            "Genauigkeit und Volltreffer werden pro Ziel separat aufgelöst.",
            "30 % Zurückschrecken pro getroffenem Ziel; Zurückschrecken setzt die aktuelle ATB-Leiste auf 0 %."
        ]
    )

    # V22: Psychic Noise blocks healing for exactly three target actions and a
    # recast during an existing block must not refresh/extend that duration.
    _v22_patch_mechanic_field("psychic_noise", "f40_heal_block_on_damage", "duration_actions", 3)
    _v22_patch_mechanic_field("psychic_noise", "f40_heal_block_on_damage", "refresh", false)
    _v22_set_aggro_flag("psychic_noise", "status", true)

    # V22: a newly applied Blaze Kick burn is status-generated aggro.
    _v22_set_aggro_flag("blaze_kick", "status", true)

    # Update player-facing descriptions for the two self-KO moves to match the
    # V22 all-others / unconditional self-KO contract.
    _v22_patch_text(
        "explosion",
        "Der Anwender verursacht eine gewaltige Explosion, die alle anderen aktiven Pokémon trifft. Danach wird er selbst kampfunfähig.",
        [
            "Trifft Gegner und Verbündete, nicht den Anwender selbst.",
            "Der eigene K. o. erfolgt nach vollständiger Auflösung auch dann, wenn kein Ziel Schaden nimmt."
        ]
    )
    _v22_patch_text(
        "self_destruct",
        "Der Anwender explodiert und trifft alle anderen aktiven Pokémon mit enormer Kraft. Danach wird er selbst kampfunfähig.",
        [
            "Trifft Gegner und Verbündete, nicht den Anwender selbst.",
            "Der eigene K. o. erfolgt nach vollständiger Auflösung auch dann, wenn kein Ziel Schaden nimmt."
        ]
    )


func _v22_set_target(move_id: String, target_rule: String, area: bool) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return
    move["target"] = target_rule
    move["area"] = area
    _v22_replace_runtime_move(move_id, move)


func _v22_set_runtime_flag(move_id: String, key: String, value: Variant) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    runtime[key] = value
    move["runtime"] = runtime
    _v22_replace_runtime_move(move_id, move)


func _v22_set_aggro_flag(move_id: String, source: String, enabled: bool) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return
    var aggro_value: Variant = move.get("aggro", {})
    var aggro: Dictionary = aggro_value if aggro_value is Dictionary else {}
    aggro[source] = enabled
    aggro["from_" + source] = enabled
    move["aggro"] = aggro
    _v22_replace_runtime_move(move_id, move)


func _v22_patch_mechanic_field(
    move_id: String,
    mechanic_kind: String,
    field: String,
    value: Variant
) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return
    var mechanics: Array = mechanics_value
    for index: int in range(mechanics.size()):
        var mechanic_value: Variant = mechanics[index]
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        if str(mechanic.get("kind", "")) != mechanic_kind:
            continue
        mechanic[field] = value
        mechanics[index] = mechanic
    move["mechanics"] = mechanics
    _v22_replace_runtime_move(move_id, move)


func _v22_patch_text(move_id: String, description: String, special_rules: Array) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return
    move["description"] = description
    move["special_rules"] = special_rules.duplicate(true)
    _v22_replace_runtime_move(move_id, move)


func _v22_replace_runtime_move(move_id: String, move: Dictionary) -> void:
    var moves_value: Variant = data.get("moves", {})
    if moves_value is Dictionary:
        var moves: Dictionary = moves_value
        moves[move_id] = move.duplicate(true)
        data["moves"] = moves

    var canonical_value: Variant = _canonical_pack.get("moves", {})
    if canonical_value is Dictionary:
        var canonical_moves: Dictionary = canonical_value
        canonical_moves[move_id] = move.duplicate(true)
        _canonical_pack["moves"] = canonical_moves


func _targets(actor: Dictionary, rule: String) -> Array:
    match rule:
        "single_enemy":
            if not _zf_selected_target_id.is_empty():
                var selected: Dictionary = _zf_find_combatant(_zf_selected_target_id)
                if (
                    not selected.is_empty()
                    and bool(selected.get("alive", false))
                    and str(selected.get("side", "")) != str(actor.get("side", ""))
                ):
                    return [selected]
            var enemy: Dictionary = _highest_aggro(actor)
            return [] if enemy.is_empty() else [enemy]
        "all_others":
            var everyone_else: Array = []
            for candidate_value: Variant in combatants:
                if not (candidate_value is Dictionary):
                    continue
                var candidate: Dictionary = candidate_value
                if not bool(candidate.get("alive", false)):
                    continue
                if str(candidate.get("id", "")) == str(actor.get("id", "")):
                    continue
                everyone_else.append(candidate)
            return everyone_else
        "all_combatants":
            var everyone: Array = []
            for candidate_value: Variant in combatants:
                if candidate_value is Dictionary and bool((candidate_value as Dictionary).get("alive", false)):
                    everyone.append(candidate_value)
            return everyone
        "all_allies_except_self":
            var allies: Array = []
            for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
                if not (candidate_value is Dictionary):
                    continue
                var candidate: Dictionary = candidate_value
                if not bool(candidate.get("alive", false)):
                    continue
                if str(candidate.get("id", "")) == str(actor.get("id", "")):
                    continue
                allies.append(candidate)
            return allies
        "enemy_highest_aggro_or_single_ally":
            if not _zf_selected_target_id.is_empty():
                var selected_ally: Dictionary = _zf_find_combatant(_zf_selected_target_id)
                if (
                    not selected_ally.is_empty()
                    and bool(selected_ally.get("alive", false))
                    and str(selected_ally.get("side", "")) == str(actor.get("side", ""))
                    and str(selected_ally.get("id", "")) != str(actor.get("id", ""))
                ):
                    return [selected_ally]
            return super._targets(actor, "enemy_highest_aggro")
        _:
            return super._targets(actor, rule)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        super._execute_move(actor, move_id)
        return

    var serial_before: int = int(actor.get("action_serial", 0))
    var original_move: Dictionary = move.duplicate(true)
    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var per_target_accuracy: bool = (
        bool(runtime.get("v22_per_target_accuracy", false))
        and move.get("accuracy", null) != null
    )

    _v22_active_move_id = move_id
    _v22_per_target_misses.clear()
    _v22_per_target_miss_feedback.clear()
    _v22_missed_target_aggro_before.clear()

    if per_target_accuracy:
        _v22_prepare_per_target_accuracy(actor, move)
        var temp: Dictionary = move.duplicate(true)
        # The inherited global accuracy gate must not run as well. Per-target
        # rolls were already resolved above and _damage/_effect skip misses.
        temp["accuracy"] = null
        _v22_replace_runtime_move(move_id, temp)

    super._execute_move(actor, move_id)

    if per_target_accuracy:
        _v22_replace_runtime_move(move_id, original_move)
        _v22_restore_missed_target_aggro()

    var action_completed: bool = int(actor.get("action_serial", 0)) > serial_before
    if (
        action_completed
        and bool(runtime.get("v22_unconditional_self_ko", false))
        and bool(actor.get("alive", false))
    ):
        _ad_self_ko(actor)
        _refresh_cards()
        _check_end()

    _v22_active_move_id = ""
    _v22_per_target_misses.clear()
    _v22_per_target_miss_feedback.clear()
    _v22_missed_target_aggro_before.clear()


func _v22_prepare_per_target_accuracy(actor: Dictionary, move: Dictionary) -> void:
    var base_accuracy: float = float(move.get("accuracy", 100.0))
    var actor_accuracy: float = maxf(0.0, float(actor.get("accuracy_mult", 1.0)))
    var hit_percent: float = clampf(base_accuracy * actor_accuracy, 0.0, 100.0)
    var targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))

    for target_value: Variant in targets:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var target_id: String = str(target.get("id", ""))
        if target_id.is_empty():
            continue
        if randf() * 100.0 >= hit_percent:
            _v22_per_target_misses[target_id] = true
            _v22_missed_target_aggro_before[target_id] = float(target.get("aggro", 0.0))


func _damage(
    actor: Dictionary,
    target: Dictionary,
    power: int,
    move_type: String,
    category: String
) -> int:
    if _v22_target_missed(target):
        _v22_show_target_miss(target)
        return 0
    return super._damage(actor, target, power, move_type, category)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if _v22_target_missed(target):
        _v22_show_target_miss(target)
        return 0.0

    var kind: String = str(mechanic.get("kind", ""))

    # Route every legacy flinch implementation through the canonical Timeflow
    # flinch helper: proc => current ATB exactly 0 %. The helper also requires
    # actual damage before a damage-attached flinch can proc.
    if (
        V22_FLINCH_IDS.has(_v22_active_move_id)
        and kind in ["atb_knockback", "f40_flinch_on_damage"]
    ):
        return _zf_flinch(target, mechanic)

    # Psychic Noise V22: no refresh while an existing heal block is active.
    if _v22_active_move_id == "psychic_noise" and kind == "f40_heal_block_on_damage":
        return _v22_psychic_noise_heal_block(target, mechanic)

    return super._effect(actor, target, mechanic)


func _v22_psychic_noise_heal_block(target: Dictionary, mechanic: Dictionary) -> float:
    if _zf_actual_damage(target) <= 0:
        return 0.0
    if _f40_heal_block_active(target):
        return 0.0

    var duration: int = maxi(1, int(mechanic.get("duration_actions", 3)))
    target["f40_heal_block_expires_before_serial"] = int(target.get("action_serial", 0)) + duration
    _spawn_feedback_label(
        target,
        "🔇 HEILUNG GESPERRT · " + str(duration) + " AKTIONEN",
        Color("d7b6df")
    )
    return 4.0


func _v22_target_missed(target: Dictionary) -> bool:
    if _v22_active_move_id.is_empty():
        return false
    var target_id: String = str(target.get("id", ""))
    return not target_id.is_empty() and bool(_v22_per_target_misses.get(target_id, false))


func _v22_show_target_miss(target: Dictionary) -> void:
    var target_id: String = str(target.get("id", ""))
    if target_id.is_empty() or bool(_v22_per_target_miss_feedback.get(target_id, false)):
        return
    _v22_per_target_miss_feedback[target_id] = true
    _spawn_feedback_label(target, "✖ VERFEHLT", Color("d9a5a5"))


func _v22_restore_missed_target_aggro() -> void:
    for target_id_value: Variant in _v22_missed_target_aggro_before.keys():
        var target_id: String = str(target_id_value)
        var target: Dictionary = _zf_find_combatant(target_id)
        if target.is_empty():
            continue
        target["aggro"] = float(_v22_missed_target_aggro_before.get(target_id, target.get("aggro", 0.0)))


func _v22_audit_final_move_set() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        push_error("V22-Audit: finaler Attackenbestand fehlt.")
        return

    var moves: Dictionary = moves_value
    if moves.size() < V22_EXPECTED_MOVE_COUNT:
        push_error(
            "V22-Audit: finaler Runtime-Bestand enthält nur %d von erwarteten %d Attacken."
            % [moves.size(), V22_EXPECTED_MOVE_COUNT]
        )

    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            push_error("V22-Audit: " + move_id + " ist kein Dictionary.")
            continue
        var move: Dictionary = move_value
        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        if not bool(runtime.get("runtime_supported", true)):
            push_error("V22-Audit: " + move_id + " ist als runtime_supported=false markiert.")
        var mechanics_value: Variant = move.get("mechanics", [])
        if not (mechanics_value is Array) or (mechanics_value as Array).is_empty():
            push_error("V22-Audit: " + move_id + " besitzt keine ausführbare Mechanik.")

    for required_id: String in V22_PER_TARGET_ACCURACY_IDS + V22_FLINCH_IDS + V22_SINGLE_ENEMY_IDS + V22_ALL_OTHERS_IDS:
        if not moves.has(required_id):
            push_error("V22-Audit: benötigte Attacke fehlt: " + required_id)
