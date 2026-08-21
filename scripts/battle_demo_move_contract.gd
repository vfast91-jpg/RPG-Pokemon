extends "res://scripts/battle_demo_aggro_scaling_final.gd"

# Final attack contract layer.
# New attack packages are compiled/validated here before they become selectable.
# Existing schema-v3 runtime data remains compatible, while V4-shaped entries
# opt into the strict contract automatically.

const MoveContract = preload("res://scripts/battle/move_contract.gd")
const MovePresenter = preload("res://scripts/battle/move_presenter.gd")


# Pokémon sprites have one canonical source. Older demo versions used the
# top-level assets folder, and orphaned local files there could otherwise win
# over the current images in assets/monsters/.
func _species_texture(display_name: String) -> Texture2D:
    for extension_value: Variant in ["png", "webp", "jpg", "jpeg", "svg"]:
        var extension: String = str(extension_value)
        var path: String = "res://assets/monsters/" + display_name + "." + extension
        if ResourceLoader.exists(path):
            var texture: Texture2D = load(path) as Texture2D
            if texture != null:
                return texture
    return null


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


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    if log_label != null:
        log_label.text = _humanize_action_load_time(log_label.text)


func _move_tooltip(move: Dictionary) -> String:
    var text: String = _humanize_action_load_time(super._move_tooltip(move))
    text = MovePresenter.sanitize_tooltip(text)
    var summary: String = _compact_effect_summary(move)
    if summary.is_empty() or not MovePresenter.is_player_safe(summary):
        summary = MovePresenter.effect_summary(move)
    if not summary.is_empty() and not text.contains(summary):
        text += "\nEffekt: " + summary
    return _humanize_action_load_time(text.strip_edges())


func _humanize_action_load_time(source: String) -> String:
    var text: String = source
    text = _replace_action_load_multiplier(text, "Ladezeit der Aktionsleiste ×")
    text = _replace_action_load_multiplier(text, "Ladezeit der Aktionsleiste x")
    text = _replace_action_load_percent_delta(text)
    return text


func _replace_action_load_multiplier(source: String, marker: String) -> String:
    var text: String = source
    var search_from: int = 0

    while true:
        var marker_index: int = text.find(marker, search_from)
        if marker_index < 0:
            break

        var number_start: int = marker_index + marker.length()
        var number_end: int = number_start
        while number_end < text.length():
            var character: String = text.substr(number_end, 1)
            if "0123456789.,".contains(character):
                number_end += 1
            else:
                break

        if number_end <= number_start:
            search_from = number_start
            continue

        var raw_number: String = text.substr(
            number_start,
            number_end - number_start
        ).replace(",", ".")
        if not raw_number.is_valid_float():
            search_from = number_end
            continue

        var multiplier: float = float(raw_number)
        var replacement: String = (
            "Ladezeit der Aktionsleiste "
            + _action_load_delta_words(multiplier)
        )
        text = (
            text.substr(0, marker_index)
            + replacement
            + text.substr(number_end)
        )
        search_from = marker_index + replacement.length()

    return text


func _replace_action_load_percent_delta(source: String) -> String:
    var text: String = source
    var marker: String = "Ladezeit der Aktionsleiste "
    var search_from: int = 0

    while true:
        var marker_index: int = text.find(marker, search_from)
        if marker_index < 0:
            break

        var value_start: int = marker_index + marker.length()
        if value_start >= text.length():
            break

        var sign: String = text.substr(value_start, 1)
        if sign != "+" and sign != "-" and sign != "−":
            search_from = value_start
            continue

        var number_start: int = value_start + 1
        var number_end: int = number_start
        while number_end < text.length() and "0123456789".contains(text.substr(number_end, 1)):
            number_end += 1

        if number_end <= number_start or number_end >= text.length() or text.substr(number_end, 1) != "%":
            search_from = number_start
            continue

        var amount: int = int(text.substr(number_start, number_end - number_start))
        var wording: String = str(amount) + " % länger" if sign == "+" else str(amount) + " % kürzer"
        if amount == 0:
            wording = "unverändert"

        var replacement: String = marker + wording
        text = (
            text.substr(0, marker_index)
            + replacement
            + text.substr(number_end + 1)
        )
        search_from = marker_index + replacement.length()

    return text


func _action_load_delta_words(multiplier: float) -> String:
    if multiplier > 1.0001:
        return "%d %% länger" % int(round((multiplier - 1.0) * 100.0))
    if multiplier < 0.9999:
        return "%d %% kürzer" % int(round((1.0 - multiplier) * 100.0))
    return "unverändert"


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
