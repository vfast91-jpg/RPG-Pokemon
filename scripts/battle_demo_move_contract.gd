extends "res://scripts/battle_demo_miss_recovery.gd"

# Final attack contract layer.
# New attack packages are compiled/validated here before they become selectable.
# Existing schema-v3 runtime data remains compatible, while V4-shaped entries
# opt into the strict contract automatically.

const MoveContract = preload("res://scripts/battle/move_contract.gd")
const MovePresenter = preload("res://scripts/battle/move_presenter.gd")


func _load_data() -> void:
    super._load_data()
    _apply_move_contract()


func _apply_move_contract() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        push_error("Attackenvertrag: data.moves fehlt.")
        return

    var moves: Dictionary = moves_value
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var source_value: Variant = moves.get(move_id, {})
        if not (source_value is Dictionary):
            push_error("Attackenvertrag: " + move_id + " ist keine gültige Attackendefinition.")
            continue

        var source: Dictionary = source_value
        var runtime_value: Variant = source.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        var strict: bool = (
            bool(runtime.get("strict_contract", false))
            or source.has("required_behavior_tests")
            or source.has("rpg_ap")
            or source.has("effects")
        )

        var report: Dictionary = MoveContract.compile_move(source, strict)
        var compiled_value: Variant = report.get("move", source)
        var compiled: Dictionary = compiled_value if compiled_value is Dictionary else source.duplicate(true)
        var errors_value: Variant = report.get("errors", [])
        var errors: Array = errors_value if errors_value is Array else []
        var warnings_value: Variant = report.get("warnings", [])
        var warnings: Array = warnings_value if warnings_value is Array else []

        var compiled_runtime_value: Variant = compiled.get("runtime", {})
        var compiled_runtime: Dictionary = compiled_runtime_value if compiled_runtime_value is Dictionary else {}

        if not errors.is_empty():
            compiled_runtime["runtime_supported"] = false
            compiled_runtime["contract_errors"] = errors.duplicate()
            compiled["runtime"] = compiled_runtime
            push_error("Attackenvertrag blockiert " + move_id + ": " + _contract_join(errors))
        else:
            compiled_runtime["contract_validated"] = true
            if strict:
                compiled_runtime["strict_contract"] = true
            compiled["runtime"] = compiled_runtime

        if strict:
            for warning_value: Variant in warnings:
                push_warning("Attackenvertrag " + move_id + ": " + str(warning_value))

        moves[move_id] = compiled

    data["moves"] = moves


func _move_tooltip(move: Dictionary) -> String:
    var text: String = MovePresenter.sanitize_tooltip(super._move_tooltip(move))
    var summary: String = _compact_effect_summary(move)
    if summary.is_empty() or not MovePresenter.is_player_safe(summary):
        summary = MovePresenter.effect_summary(move)
    if not summary.is_empty() and not text.contains(summary):
        text += "\nEffekt: " + summary
    return text.strip_edges()


func _modifier_detail_text(kind: String, multiplier: float) -> String:
    return MovePresenter.modifier_text(kind, multiplier)


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var inherited: Array[String] = super._status_tokens(combatant)
    var tokens: Array[String] = []
    var managed_prefixes: Array[String] = [
        "ANG+", "ANG-", "DEF+", "DEF-", "GEN+", "GEN-",
        "ATB+", "ATB-", "GES+", "GES-"
    ]

    for token_value: Variant in inherited:
        var token: String = str(token_value)
        var managed: bool = false
        for prefix: String in managed_prefixes:
            if token.begins_with(prefix):
                managed = true
                break
        if not managed:
            tokens.append(token)

    var kinds: Array[String] = [
        "outgoing_damage_mod", "incoming_damage_mod",
        "accuracy_mod", "atb_cycle_mod"
    ]
    for kind: String in kinds:
        var count: int = _active_modifier_count(combatant, kind)
        if count <= 0:
            continue
        var token: String = MovePresenter.modifier_token(
            kind,
            _combined_timed_modifier(combatant, kind)
        )
        if token.is_empty():
            continue
        if count > 1:
            token += "×" + str(count)
        tokens.append(token)
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var source: String = super._detail_info(combatant)
    var output := PackedStringArray()

    for line: String in source.split("\n"):
        var clean: String = line.strip_edges()
        if clean.begins_with("Gesamt verursachter Schaden:"):
            output.append("  Gesamt " + MovePresenter.modifier_text(
                "outgoing_damage_mod",
                _combined_timed_modifier(combatant, "outgoing_damage_mod")
            ))
            continue
        if clean.begins_with("Gesamt eingehender Schaden:"):
            output.append("  Gesamt " + MovePresenter.modifier_text(
                "incoming_damage_mod",
                _combined_timed_modifier(combatant, "incoming_damage_mod")
            ))
            continue
        if clean.begins_with("Gesamt Genauigkeit:"):
            output.append("  Gesamt " + MovePresenter.modifier_text(
                "accuracy_mod",
                _combined_timed_modifier(combatant, "accuracy_mod")
            ))
            continue
        if clean.begins_with("Gesamt ATB-Zyklus:"):
            output.append("  Gesamt " + MovePresenter.modifier_text(
                "atb_cycle_mod",
                _combined_timed_modifier(combatant, "atb_cycle_mod")
            ))
            continue

        # Canonical V4 player wording in the small-i detail panel.
        var canonical: String = line
        canonical = canonical.replace("Spezial ", "Statuswert ")
        canonical = canonical.replace("Initiative ", "Geschwindigkeit ")
        canonical = canonical.replace("Initiative halbiert", "Geschwindigkeit halbiert")
        output.append(canonical)

    return "\n".join(output)


func _contract_join(values: Array) -> String:
    var parts := PackedStringArray()
    for value: Variant in values:
        parts.append(str(value))
    return " | ".join(parts)
