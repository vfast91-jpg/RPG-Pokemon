extends "res://scripts/battle_demo_route_party.gd"

# Opening-phase balance polish:
# - Priority attacks remain usable during normal ATB combat.
# - If a priority attack is used in Runde 0, the user begins normal combat
#   with ATB debt. This makes the free opening hit a real tempo decision.
# - The default debt is loaded from the central opening balance rule; individual
#   moves may still override it with `opening_atb_debt` in their data.

const OPENING_BALANCE_RULE_PATH: String = "res://data/rules/opening_move_balance.json"
const FALLBACK_PRIORITY_OPENING_ATB_DEBT: float = 35.0

var _priority_opening_atb_debt: float = FALLBACK_PRIORITY_OPENING_ATB_DEBT


func _load_data() -> void:
    super._load_data()
    _load_opening_recovery_rule()


func _load_opening_recovery_rule() -> void:
    _priority_opening_atb_debt = FALLBACK_PRIORITY_OPENING_ATB_DEBT
    if not FileAccess.file_exists(OPENING_BALANCE_RULE_PATH):
        return

    var file: FileAccess = FileAccess.open(OPENING_BALANCE_RULE_PATH, FileAccess.READ)
    if file == null:
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return

    _priority_opening_atb_debt = maxf(
        0.0,
        float(parsed.get("default_priority_opening_atb_debt", FALLBACK_PRIORITY_OPENING_ATB_DEBT))
    )


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
            "[b]Runde 0 beendet.[/b] Prioritätsattacken kosten Tempo: "
            + ", ".join(paid_debts)
            + "."
        )
        _append_protocol_system(
            "Runde-0-Erholung · " + ", ".join(paid_debts)
        )
        _refresh_cards()


func _opening_debt_for_move(move: Dictionary) -> float:
    if move.has("opening_atb_debt"):
        return maxf(0.0, float(move.get("opening_atb_debt", 0.0)))
    if int(move.get("priority", 0)) > 0:
        return _priority_opening_atb_debt
    return 0.0


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if float(combatant.get("atb", 0.0)) < 0.0:
        tokens.append("⏳ ERHOLUNG")
    return tokens


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    if log_label == null:
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
