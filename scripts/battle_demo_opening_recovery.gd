extends "res://scripts/battle_demo_route_party.gd"

# Opening-phase and AP balance polish:
# - Opening-only attacks are selectable exclusively during Runde 0.
# - Ruckzuckhieb is restored to Stärke 30 and uses AP 8.
# - AP recovery uses the binding central curve in data/rules/ap_cycle_balance.json.
# - AP 8 creates 3.25x normal recovery, so opening-only attacks do not stack
#   an extra negative ATB debt unless explicitly configured.
# - Other priority attacks may still use explicit `opening_atb_debt` values.

const OPENING_BALANCE_RULE_PATH: String = "res://data/rules/opening_move_balance.json"
const AP_CYCLE_RULE_PATH: String = "res://data/rules/ap_cycle_balance.json"
const FALLBACK_PRIORITY_OPENING_ATB_DEBT: float = 0.0

var _priority_opening_atb_debt: float = FALLBACK_PRIORITY_OPENING_ATB_DEBT
var _opening_balance_rule: Dictionary = {}
var _ap_cycle_curve: Dictionary = {
    "1": 1.00,
    "2": 1.15,
    "3": 1.30,
    "4": 1.50,
    "5": 1.75,
    "6": 2.10,
    "7": 2.60,
    "8": 3.25
}


func _load_data() -> void:
    super._load_data()
    _load_ap_cycle_rule()
    _load_opening_balance_rule()
    _apply_opening_reference_move()


func _load_ap_cycle_rule() -> void:
    if FileAccess.file_exists(AP_CYCLE_RULE_PATH):
        var file: FileAccess = FileAccess.open(AP_CYCLE_RULE_PATH, FileAccess.READ)
        if file != null:
            var parsed: Variant = JSON.parse_string(file.get_as_text())
            if parsed is Dictionary:
                var curve_value: Variant = parsed.get("ap_cycle_multiplier", {})
                if curve_value is Dictionary and not curve_value.is_empty():
                    _ap_cycle_curve = curve_value.duplicate(true)

    # Keep the runtime data dictionary synchronized so every inherited combat
    # layer sees the same binding curve even if it reads `data.rules` directly.
    var rules_value: Variant = data.get("rules", {})
    var rules: Dictionary = rules_value if rules_value is Dictionary else {}
    rules["ap_cycle_multiplier"] = _ap_cycle_curve.duplicate(true)
    rules["ap_cycle_rule_source"] = AP_CYCLE_RULE_PATH
    data["rules"] = rules


func _ap_cycle(ap: int) -> float:
    var bounded_ap: int = clampi(ap, 1, 8)
    return maxf(0.01, float(_ap_cycle_curve.get(str(bounded_ap), 1.0)))


func _load_opening_balance_rule() -> void:
    _priority_opening_atb_debt = FALLBACK_PRIORITY_OPENING_ATB_DEBT
    _opening_balance_rule = {}
    if not FileAccess.file_exists(OPENING_BALANCE_RULE_PATH):
        return

    var file: FileAccess = FileAccess.open(OPENING_BALANCE_RULE_PATH, FileAccess.READ)
    if file == null:
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return

    _opening_balance_rule = parsed.duplicate(true)
    _priority_opening_atb_debt = maxf(
        0.0,
        float(parsed.get("default_priority_opening_atb_debt", FALLBACK_PRIORITY_OPENING_ATB_DEBT))
    )


func _apply_opening_reference_move() -> void:
    var reference_value: Variant = _opening_balance_rule.get("reference_move", {})
    var moves_value: Variant = data.get("moves", {})
    if not (reference_value is Dictionary) or not (moves_value is Dictionary):
        return

    var reference: Dictionary = reference_value
    var move_id: String = str(reference.get("id", ""))
    if move_id.is_empty():
        return

    var moves: Dictionary = moves_value
    var move_value: Variant = moves.get(move_id, {})
    if not (move_value is Dictionary):
        return

    var move: Dictionary = move_value
    for key_value: Variant in ["power", "priority", "ap", "opening", "opening_only", "opening_atb_debt"]:
        var key: String = str(key_value)
        if reference.has(key):
            move[key] = reference[key]

    moves[move_id] = move
    data["moves"] = moves


func _finish_opening_phase() -> void:
    var paid_debts: Array[String] = []

    for choice_value: Variant in _opening_choices:
        if not (choice_value is Dictionary):
            continue
        var choice: Dictionary = choice_value
        var actor_value: Variant = choice.get("actor", {})
        if not (actor_value is Dictionary):
            continue
        var actor: Dictionary = actor_value
        if not bool(actor.get("alive", false)):
            continue

        var move_id: String = str(choice.get("move_id", ""))
        var move: Dictionary = _move_data(move_id)
        var debt: float = _opening_debt_for_move(move)
        if debt <= 0.0:
            continue

        actor["atb"] = minf(float(actor.get("atb", 0.0)), -debt)
        paid_debts.append(
            "%s: −%d ATB" % [_actor_name(actor), int(round(debt))]
        )

    super._finish_opening_phase()

    if not paid_debts.is_empty():
        _set_log(
            "[b]Runde 0 beendet.[/b] Prioritätsattacken kosten zusätzlich Tempo: "
            + ", ".join(paid_debts)
            + "."
        )
        _append_protocol_system(
            "Runde-0-Zusatzschuld · " + ", ".join(paid_debts)
        )
        _refresh_cards()


func _opening_debt_for_move(move: Dictionary) -> float:
    if bool(move.get("opening_only", false)):
        return maxf(0.0, float(move.get("opening_atb_debt", 0.0)))
    if move.has("opening_atb_debt"):
        return maxf(0.0, float(move.get("opening_atb_debt", 0.0)))
    if int(move.get("priority", 0)) > 0:
        return _priority_opening_atb_debt
    return 0.0


func _prompt_player(actor: Dictionary) -> void:
    super._prompt_player(actor)
    _remove_opening_only_buttons(actor)


func _remove_opening_only_buttons(actor: Dictionary) -> void:
    if action_grid == null:
        return

    var hidden_names: Array[String] = []
    var actor_moves_value: Variant = actor.get("moves", [])
    if actor_moves_value is Array:
        for move_value: Variant in actor_moves_value:
            var move_id: String = str(move_value)
            var move: Dictionary = _move_data(move_id)
            if bool(move.get("opening_only", false)):
                hidden_names.append(str(move.get("name", move_id)))

    if hidden_names.is_empty():
        return

    for child: Node in action_grid.get_children():
        if not (child is Button):
            continue
        var button: Button = child as Button
        for hidden_name: String in hidden_names:
            if button.text.contains(hidden_name):
                button.queue_free()
                break


func _choose_move(move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    if bool(move.get("opening_only", false)):
        if not selected_actor.is_empty():
            var actor: Dictionary = selected_actor
            _set_log(
                "[b]%s[/b] kann %s nur in Runde 0 einsetzen."
                % [_actor_name(actor), str(move.get("name", move_id))]
            )
            _prompt_player(actor)
        return
    super._choose_move(move_id)


func _enemy_act(actor: Dictionary) -> void:
    var original_moves_value: Variant = actor.get("moves", [])
    if not (original_moves_value is Array):
        super._enemy_act(actor)
        return

    var original_moves: Array = original_moves_value.duplicate()
    var legal_moves: Array = []
    for move_value: Variant in original_moves:
        var move_id: String = str(move_value)
        if not bool(_move_data(move_id).get("opening_only", false)):
            legal_moves.append(move_id)

    if legal_moves.is_empty():
        actor["atb"] = 0.0
        actor["cycle"] = 0.70
        _set_log(_actor_name(actor) + " hat keine normale Attacke verfügbar und wartet.")
        _refresh_cards()
        return

    actor["moves"] = legal_moves
    super._enemy_act(actor)
    actor["moves"] = original_moves


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if float(combatant.get("atb", 0.0)) < 0.0:
        tokens.append("⏳ ERHOLUNG")
    return tokens


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    if log_label == null:
        return

    if bool(move.get("opening_only", false)):
        var recovery: float = _ap_cycle(int(move.get("ap", 8)))
        log_label.text += (
            "\n⚡ Nur Runde 0 · danach AP %d = %.2fx Erholungszeit."
            % [int(move.get("ap", 8)), recovery]
        )
        return

    var debt: float = _opening_debt_for_move(move)
    if debt <= 0.0:
        return
    if not (bool(move.get("opening", false)) or bool(move.get("opening_phase", false))):
        return

    log_label.text += (
        "\n⏳ Bei Einsatz in Runde 0: −%d ATB für die erste normale Aktion."
        % int(round(debt))
    )


func route_species_texture(species_id: String) -> Texture2D:
    return _species_texture(route_species_name(species_id))
