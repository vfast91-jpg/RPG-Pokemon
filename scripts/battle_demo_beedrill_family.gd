extends "res://scripts/battle_demo_caterpie_family_ui.gd"

# Hornliu -> Kokuna -> Bibor V4 runtime integration.
# The seven Bibor TM additions reuse the central move/effect systems wherever
# possible. Only Gegenstoß (reactive stance) and Auflockern (field cleanup)
# need family-level orchestration.

const BFAM_PAYBACK_MAX_CHARGES: int = 3
const BFAM_PAYBACK_POWER: int = 35
const BFAM_BARRIER_SOURCE_NAMES: Array[String] = [
    "reflektor", "lichtschild", "auroraschleier",
    "reflect", "light screen", "aurora veil"
]
const BFAM_TERRAIN_META_KEYS: Array[String] = [
    "db_active_terrain", "active_terrain", "terrain_id"
]

var _bfam_active_move_id: String = ""
var _bfam_selected_target_id: String = ""
var _bfam_pending_target_move_id: String = ""
var _bfam_pending_target_actor: Dictionary = {}
var _bfam_resolving_retaliation: bool = false


func _start_battle() -> void:
    _bfam_reset_battle_state()
    super._start_battle()


func _bfam_reset_battle_state() -> void:
    _bfam_active_move_id = ""
    _bfam_selected_target_id = ""
    _bfam_pending_target_move_id = ""
    _bfam_pending_target_actor = {}
    _bfam_resolving_retaliation = false
    for terrain_key: String in BFAM_TERRAIN_META_KEYS:
        if has_meta(terrain_key):
            set_meta(terrain_key, "")


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["bfam_payback_charges"] = 0
    return combatant


func _choose_move(move_id: String) -> void:
    if move_id != "swagger":
        super._choose_move(move_id)
        return
    if selected_actor.is_empty():
        return

    var actor: Dictionary = selected_actor
    var choices: Array = _bfam_swagger_target_choices(actor)
    if choices.is_empty():
        _set_log("[b]Angeberei[/b]: Kein gültiges Ziel verfügbar.")
        return

    if choices.size() == 1:
        _bfam_selected_target_id = str((choices[0] as Dictionary).get("id", ""))
        super._choose_move(move_id)
        return

    _bfam_pending_target_move_id = move_id
    _bfam_pending_target_actor = actor
    _clear_actions()
    _set_log("[b]Angeberei[/b]: Gegner oder Verbündeten wählen.")

    for target_value: Variant in choices:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        var same_side: bool = str(target.get("side", "")) == str(actor.get("side", ""))
        var button := Button.new()
        button.text = (
            ("🤝 Verbündeter: " if same_side else "🎯 Gegner: ")
            + _actor_name(target)
        )
        button.tooltip_text = (
            "Verwirrt dieses Pokémon und erhöht seinen Angriff stark für drei eigene Aktionen."
        )
        button.pressed.connect(
            _bfam_choose_swagger_target.bind(str(target.get("id", "")))
        )
        action_grid.add_child(button)

    var back := Button.new()
    back.text = "↩ Zurück"
    back.pressed.connect(_bfam_cancel_swagger_target)
    action_grid.add_child(back)


func _bfam_choose_swagger_target(target_id: String) -> void:
    if _bfam_pending_target_actor.is_empty():
        return
    _bfam_selected_target_id = target_id
    selected_actor = _bfam_pending_target_actor
    var move_id: String = _bfam_pending_target_move_id
    _bfam_pending_target_actor = {}
    _bfam_pending_target_move_id = ""
    super._choose_move(move_id)


func _bfam_cancel_swagger_target() -> void:
    if _bfam_pending_target_actor.is_empty():
        return
    var actor: Dictionary = _bfam_pending_target_actor
    _bfam_pending_target_actor = {}
    _bfam_pending_target_move_id = ""
    _bfam_selected_target_id = ""
    _prompt_player(actor)


func _bfam_swagger_target_choices(actor: Dictionary) -> Array:
    # The established Caterpie-family selector already means exactly what
    # Swagger needs: highest-Aggro enemy + every living other ally, never self.
    return _cfam_manual_target_choices(actor)


func _targets(actor: Dictionary, rule: String) -> Array:
    if _bfam_active_move_id == "swagger" and not _bfam_selected_target_id.is_empty():
        var selected: Dictionary = _cfam_find_combatant(_bfam_selected_target_id)
        if (
            not selected.is_empty()
            and bool(selected.get("alive", false))
            and str(selected.get("id", "")) != str(actor.get("id", ""))
        ):
            return [selected]
    return super._targets(actor, rule)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    if not bool(actor.get("alive", false)):
        return

    var source: Dictionary = _move_data(move_id)
    var damage_move: bool = _bfam_move_is_damaging(source)
    var hp_before: Dictionary = {}
    if damage_move and not _bfam_resolving_retaliation:
        for candidate_value: Variant in combatants:
            if not (candidate_value is Dictionary):
                continue
            var candidate: Dictionary = candidate_value
            hp_before[str(candidate.get("id", ""))] = int(candidate.get("hp", 0))

    _bfam_active_move_id = move_id
    super._execute_move(actor, move_id)
    _bfam_active_move_id = ""

    var attempted: bool = _database_move_was_attempted(move_id)
    if (
        move_id == "payback"
        and attempted
        and bool(actor.get("alive", false))
    ):
        _bfam_activate_payback(actor)

    if damage_move and attempted and not _bfam_resolving_retaliation:
        _bfam_trigger_reactive_stances(actor, hp_before)

    if move_id == "defog" and attempted:
        _bfam_apply_defog_cleanup(actor)

    _bfam_selected_target_id = ""
    _refresh_cards()
    _check_end()


func _bfam_move_is_damaging(move: Dictionary) -> bool:
    if move.is_empty():
        return false
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return false
    for mechanic_value: Variant in mechanics_value:
        if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == "damage":
            return true
    return false


func _bfam_activate_payback(actor: Dictionary) -> void:
    actor["bfam_payback_charges"] = BFAM_PAYBACK_MAX_CHARGES
    _spawn_feedback_label(
        actor,
        "↩️ GEGENSTOSS · " + str(BFAM_PAYBACK_MAX_CHARGES),
        Color("d4b7ff")
    )


func _bfam_trigger_reactive_stances(attacker: Dictionary, hp_before: Dictionary) -> void:
    if _bfam_resolving_retaliation or not bool(attacker.get("alive", false)):
        return

    for defender_value: Variant in combatants:
        if not (defender_value is Dictionary):
            continue
        var defender: Dictionary = defender_value
        if str(defender.get("side", "")) == str(attacker.get("side", "")):
            continue
        if not bool(defender.get("alive", false)):
            # A KO'd stance holder never retaliates.
            continue
        if int(defender.get("bfam_payback_charges", 0)) <= 0:
            continue

        var defender_id: String = str(defender.get("id", ""))
        var old_hp: int = int(hp_before.get(defender_id, int(defender.get("hp", 0))))
        var actual_hp_damage: int = maxi(0, old_hp - int(defender.get("hp", 0)))
        if actual_hp_damage <= 0:
            # Miss, immunity, Protect/substitute-only damage and other zero-HP
            # outcomes do not consume a charge.
            continue

        _bfam_resolve_payback_retaliation(defender, attacker)
        # A single executed move can make each hit stance-holder react at most
        # once; this loop visits every defender only once.


func _bfam_resolve_payback_retaliation(defender: Dictionary, attacker: Dictionary) -> int:
    if _bfam_resolving_retaliation:
        return 0
    if not bool(defender.get("alive", false)) or not bool(attacker.get("alive", false)):
        return 0
    if str(defender.get("side", "")) == str(attacker.get("side", "")):
        return 0

    var charges: int = int(defender.get("bfam_payback_charges", 0))
    if charges <= 0:
        return 0

    defender["bfam_payback_charges"] = charges - 1
    _bfam_resolving_retaliation = true

    var rolled_damage: int = _damage(
        defender,
        attacker,
        BFAM_PAYBACK_POWER,
        "dark",
        "physical"
    )
    var actual_damage: int = mini(maxi(0, rolled_damage), int(attacker.get("hp", 0)))

    if actual_damage > 0:
        attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - actual_damage)
        attacker["aggro"] = float(attacker.get("aggro", 0.0)) * 0.5
        defender["aggro"] = float(defender.get("aggro", 0.0)) + float(actual_damage)
        if int(attacker.get("hp", 0)) <= 0:
            attacker["alive"] = false

        _spawn_feedback_label(
            attacker,
            "↩️ GEGENSTOSS −" + str(actual_damage),
            Color("d4b7ff")
        )

    _spawn_feedback_label(
        defender,
        "↩️ " + str(int(defender.get("bfam_payback_charges", 0))) + " ÜBRIG",
        Color("d4b7ff")
    )
    _bfam_resolving_retaliation = false
    return actual_damage


func _bfam_apply_defog_cleanup(actor: Dictionary) -> void:
    # Preserve the earlier Sandshrew-family hazard cleanup (Spikes / Stealth
    # Rock) before adding Bibor's Toxic Spikes, barrier and terrain cleanup.
    super._bfam_apply_defog_cleanup(actor)

    # Current entry-hazard runtime: Toxic Spikes. Clear both sides, matching
    # Defog's approved Timeflow contract.
    set_meta("db_toxic_spikes_player", 0)
    set_meta("db_toxic_spikes_enemy", 0)

    var enemy_team_for_actor: Array = (
        enemy_team if str(actor.get("side", "")) == "player" else player_team
    )
    for target_value: Variant in enemy_team_for_actor:
        if not (target_value is Dictionary):
            continue
        var target: Dictionary = target_value
        _bfam_clear_team_barriers(target)

    # No terrain-producing move is live yet. These metadata keys establish the
    # central field slot now so Defog is already correct when terrain arrives.
    for terrain_key: String in BFAM_TERRAIN_META_KEYS:
        if has_meta(terrain_key):
            set_meta(terrain_key, "")

    _spawn_feedback_label(actor, "🌬️ FELD AUFGELOCKERT", Color("b9e4f0"))


func _bfam_clear_team_barriers(target: Dictionary) -> void:
    # Lichtschild already has a dedicated database runtime representation.
    target["db_light_screen_reduction"] = 0.0
    target["db_light_screen_source_id"] = ""
    target["db_light_screen_expires_source_action"] = 0

    # Reflect-like barriers use the central timed-modifier collection. Remove
    # only known team-barrier sources, never personal defense buffs.
    var modifiers_value: Variant = target.get("timed_modifiers", [])
    if not (modifiers_value is Array):
        return
    var kept: Array = []
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary):
            continue
        var modifier: Dictionary = modifier_value
        var source_name: String = str(modifier.get("source_move", "")).strip_edges().to_lower()
        if BFAM_BARRIER_SOURCE_NAMES.has(source_name):
            continue
        kept.append(modifier)
    target["timed_modifiers"] = kept


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var charges: int = int(combatant.get("bfam_payback_charges", 0))
    if charges > 0 and bool(combatant.get("alive", false)):
        tokens.append("↩" + str(charges))
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var text: String = super._detail_info(combatant)
    var charges: int = int(combatant.get("bfam_payback_charges", 0))
    if charges > 0 and bool(combatant.get("alive", false)):
        text += (
            "\n• Gegenstoß: noch " + str(charges)
            + " automatische Gegenangriff(e)"
        )
    return text


func _compact_effect_summary(move: Dictionary) -> String:
    match str(move.get("id", "")):
        "payback":
            return "3 Ladungen · nach tatsächlichem KP-Schaden automatischer Unlicht-Gegenangriff (Stärke 35)"
        "flash":
            return "Genauigkeit ↓ (Statuswert) · 3 Zielaktionen"
        "x_scissor":
            return "Stärke 80 · keine Zusatzwirkung"
        "swagger":
            return "Gegner oder Verbündeter · Verwirrung + Angriff stark ↑ (Statuswert) · 3 Zielaktionen"
        "cut":
            return "Stärke 50 · keine zusätzliche Kampfwirkung"
        "defog":
            return "trifft immer · Genauigkeit gegen Ziel ↑ · Giftspitzen beidseitig + gegnerische Barrieren + Terrain entfernen"
        "rock_smash":
            return "Stärke 40 · 50 %: Verteidigung ↓ (Statuswert) · 3 Zielaktionen"
    return super._compact_effect_summary(move)
