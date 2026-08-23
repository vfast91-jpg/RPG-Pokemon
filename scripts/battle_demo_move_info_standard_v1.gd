extends "res://scripts/battle_demo_v22_charge_integrity_v1.gd"

# Central, flexible presentation standard for every attack information box.
#
# The rule is intentionally a FRAME, not a rigid one-size-fits-all sentence:
# - Header always uses the same order: name, type, category, AP/time cost.
# - Combat facts always use the same labels: power (when applicable), target,
#   accuracy.
# - Ordinary effects use canonical wording (especially guaranteed/chance status).
# - Complex/special mechanics keep the detailed inherited summary instead of
#   being squeezed into a generic template.
# - Additional inherited preview lines (Runde 0, charge rules, etc.) are kept.
#
# Combat logic and move data are untouched; this layer changes presentation only.

const StandardEffectRegistry = preload("res://scripts/battle/move_effect_registry.gd")

const INFOBOX_MIN_TEXT_HEIGHT: float = 54.0
const INFOBOX_MIN_COMMAND_HEIGHT: float = 154.0
const INFOBOX_FONT_SIZE: int = 11


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    _configure_standard_infobox_layout()


func _configure_standard_infobox_layout() -> void:
    if log_label == null:
        return

    # Word wrapping is mandatory. Exceptional attacks are allowed to be longer;
    # when they exceed the normal space, scrolling keeps every word reachable
    # instead of clipping it outside the panel.
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_label.fit_content = false
    log_label.scroll_active = true
    log_label.scroll_following = false
    log_label.custom_minimum_size.y = maxf(
        log_label.custom_minimum_size.y,
        INFOBOX_MIN_TEXT_HEIGHT
    )
    log_label.add_theme_font_size_override("normal_font_size", INFOBOX_FONT_SIZE)
    log_label.add_theme_font_size_override("bold_font_size", INFOBOX_FONT_SIZE)

    # Give the text a little more guaranteed vertical room without changing the
    # battle mechanics or the action-grid structure. If an inherited layout is
    # already taller, keep that larger value.
    var content: VBoxContainer = log_label.get_parent() as VBoxContainer
    if content == null:
        return
    var command: PanelContainer = content.get_parent() as PanelContainer
    if command == null:
        return
    command.offset_top = minf(command.offset_top, -INFOBOX_MIN_COMMAND_HEIGHT)


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    # Let every inherited special-case layer run first. We deliberately preserve
    # extra lines added there, then replace only the common core with the new
    # standard presentation.
    super._preview_move(move_id, move, touch_confirm)
    if log_label == null:
        return

    var inherited_text: String = log_label.text
    var text: String = _standardized_move_info_text(move, touch_confirm)

    for extra_line: String in _inherited_preview_extra_lines(inherited_text):
        if extra_line.is_empty():
            continue
        var plain_extra: String = extra_line.replace("[b]", "").replace("[/b]", "").strip_edges()
        if plain_extra.is_empty():
            continue
        if text.contains(plain_extra):
            continue
        text += "\n" + extra_line

    log_label.text = text


func _move_tooltip(move: Dictionary) -> String:
    # Tooltips and the always-visible preview now speak the same language.
    return _standardized_move_info_text(move, false).replace("[b]", "").replace("[/b]", "")


func _compact_effect_summary(move: Dictionary) -> String:
    # Keep all inherited special-case knowledge. Only generic effect fragments
    # are normalized, so a bespoke attack never loses its bespoke explanation.
    return _standardize_effect_summary(move, super._compact_effect_summary(move))


func _standardized_move_info_text(move: Dictionary, touch_confirm: bool = false) -> String:
    var move_id: String = str(move.get("id", ""))
    var move_name: String = str(move.get("name", "Attacke"))
    var move_type: String = str(move.get("type", "normal"))
    var category: String = str(move.get("category", "physical"))
    var ap: int = _ap_value(move)
    var emoji: String = _move_emoji(move_id, move).strip_edges()

    var title: String = move_name
    if not emoji.is_empty():
        title = emoji + " " + title

    var lines: Array[String] = []
    lines.append(
        "[b]%s[/b] · %s · %s · AP %d → %s"
        % [
            title,
            _type_name(move_type),
            _category_name(category),
            ap,
            _standard_time_cost_text(ap)
        ]
    )

    var combat_bits: Array[String] = []
    var power_value: Variant = move.get("power", null)
    if power_value != null:
        combat_bits.append("Stärke: %d" % int(round(float(power_value))))
    combat_bits.append("Ziel: " + _target_name(str(move.get("target", "enemy_highest_aggro"))))
    combat_bits.append("Genauigkeit: " + _standard_accuracy_text(move))
    lines.append(" · ".join(combat_bits))

    var effect_summary: String = _compact_effect_summary(move).strip_edges()
    effect_summary = _effect_summary_without_redundant_damage(effect_summary, power_value != null)
    if not effect_summary.is_empty():
        lines.append("Wirkung: " + effect_summary)

    var feature_bits: Array[String] = _standard_feature_bits(move)
    if not feature_bits.is_empty():
        lines.append("Besonderheit: " + " · ".join(feature_bits))

    if touch_confirm:
        lines.append("Bestätigen: Attacke erneut antippen.")

    return "\n".join(lines)


func _standard_time_cost_text(ap: int) -> String:
    var multiplier: float = _ap_cycle(ap)
    var delta: int = int(round((multiplier - 1.0) * 100.0))
    if delta > 0:
        return "Ladezeit %d %% länger" % delta
    if delta < 0:
        return "Ladezeit %d %% kürzer" % absi(delta)
    return "normale Ladezeit"


func _standard_accuracy_text(move: Dictionary) -> String:
    var accuracy_value: Variant = move.get("accuracy", null)
    if accuracy_value == null:
        return "sicher"

    var accuracy: float = float(accuracy_value)
    if not selected_actor.is_empty():
        accuracy *= float(selected_actor.get("accuracy_mult", 1.0))
        accuracy *= _combined_timed_modifier(selected_actor, "accuracy_mod")

    accuracy = clampf(accuracy, 0.0, 100.0)
    return "%d %%" % int(round(accuracy))


func _standard_feature_bits(move: Dictionary) -> Array[String]:
    var bits: Array[String] = []
    var priority: int = int(round(float(move.get("priority", 0))))
    if priority != 0:
        bits.append("Priorität %s%d" % [("+" if priority > 0 else ""), priority])
    if bool(move.get("opening", false)) or bool(move.get("opening_phase", false)):
        bits.append("in Runde 0 nutzbar")
    if bool(move.get("opening_only", false)):
        bits.append("nur Runde 0")
    if bool(move.get("area", false)):
        bits.append("Flächenwirkung")
    if bool(move.get("contact", false)):
        bits.append("Kontakt")
    return bits


func _standardize_effect_summary(move: Dictionary, source: String) -> String:
    var text: String = source.strip_edges()
    if text.is_empty():
        return text

    # One canonical damage word. Details after it (variable power, multi-hit,
    # conditions, etc.) remain untouched.
    text = text.replace("direkter Schaden", "Schaden")

    var mechanics_value: Variant = move.get("mechanics", move.get("effects", []))
    if not (mechanics_value is Array):
        return _space_percentages(text)

    var segments: PackedStringArray = text.split(" · ")
    var normalized: Array[String] = []

    for segment_value: String in segments:
        var segment: String = segment_value.strip_edges()
        var replacement: String = _normalized_status_segment(segment, mechanics_value as Array)
        normalized.append(replacement if not replacement.is_empty() else segment)

    return _space_percentages(" · ".join(normalized))


func _normalized_status_segment(segment: String, mechanics: Array) -> String:
    for mechanic_value: Variant in mechanics:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value
        var kind: String = str(mechanic.get("kind", ""))
        if kind == "apply_status":
            kind = "status"
        if kind != "status" and kind != "db_status":
            continue

        var status_id: String = str(mechanic.get("status", ""))
        var status_label: String = StandardEffectRegistry.player_label_for_status(status_id)
        var chance: float = clampf(float(mechanic.get("chance", 1.0)), 0.0, 1.0)
        var chance_percent: int = int(round(chance * 100.0))

        var generic_forms: Array[String] = [status_label]
        generic_forms.append("%d%% %s" % [chance_percent, status_label])
        generic_forms.append("%d %% %s" % [chance_percent, status_label])

        if generic_forms.has(segment):
            return _status_effect_phrase(status_id, chance_percent)

    return ""


func _status_effect_phrase(status_id: String, chance_percent: int) -> String:
    var noun: String = StandardEffectRegistry.player_label_for_status(status_id)
    if status_id == "freeze":
        noun = "Einfrieren"
    elif status_id == "sleep":
        noun = "Schlaf"
    elif status_id == "bad_poison":
        noun = "schwere Vergiftung"

    if chance_percent >= 100:
        match status_id:
            "freeze":
                return "Friert das Ziel garantiert ein"
            "sleep":
                return "Versetzt das Ziel garantiert in Schlaf"
            _:
                return "Verursacht garantiert " + noun

    if status_id == "freeze":
        return "%d %% Chance, das Ziel einzufrieren" % chance_percent
    if status_id == "sleep":
        return "%d %% Chance auf Schlaf" % chance_percent
    return "%d %% Chance auf %s" % [chance_percent, noun]


func _effect_summary_without_redundant_damage(source: String, has_power: bool) -> String:
    var text: String = source.strip_edges()
    if not has_power:
        return text
    if text == "Schaden":
        return ""
    if text.begins_with("Schaden · "):
        return text.trim_prefix("Schaden · ")
    return text


func _space_percentages(source: String) -> String:
    var text: String = source
    for value: int in range(0, 101):
        text = text.replace(str(value) + "%", str(value) + " %")
    return text


func _inherited_preview_extra_lines(source: String) -> Array[String]:
    var result: Array[String] = []
    var lines: PackedStringArray = source.split("\n")
    if lines.size() <= 2:
        return result

    # The inherited first two lines are the old common core. Everything after
    # that is an explicit special-case addition and must survive the new frame.
    for index: int in range(2, lines.size()):
        var line: String = lines[index].strip_edges()
        if line.is_empty():
            continue
        if line.to_lower().contains("erneut") and line.to_lower().contains("antipp"):
            continue
        result.append(line)
    return result
