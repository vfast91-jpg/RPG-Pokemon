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
# - If a newer special mechanic has no dedicated presentation yet, the box falls
#   back to its player-facing description/special rules instead of exposing an
#   internal runtime id.
# - Additional inherited preview lines (Runde 0, charge rules, etc.) are kept,
#   but pass through the same player-text safety filter.
#
# Combat logic and move data are untouched; this layer changes presentation only.

const StandardEffectRegistry = preload("res://scripts/battle/move_effect_registry.gd")

const INFOBOX_MIN_TEXT_HEIGHT: float = 54.0
const INFOBOX_MIN_COMMAND_HEIGHT: float = 154.0
const INFOBOX_FONT_SIZE: int = 11

# Canonical target vocabulary for the complete V22 move set. Keeping this here
# makes the combat surface independent from whichever historical layer first
# introduced a target rule.
const STANDARD_TARGET_LABELS: Dictionary = {
    "enemy_highest_aggro": "höchste Aggro",
    "all_enemies": "alle Gegner",
    "self": "Anwender",
    "all_allies": "alle Verbündeten",
    "all_other_active_pokemon": "alle anderen aktiven Pokémon",
    "enemy_field": "gegnerische Feldseite",
    "global_battlefield": "gesamtes Kampffeld",
    "battlefield": "gesamtes Kampffeld",
    "single_ally": "gewählter Verbündeter",
    "single_enemy": "gewählter Gegner",
    "all_others": "alle anderen Pokémon",
    "enemy_highest_aggro_or_single_ally": "höchste Aggro oder gewählter Verbündeter",
    "all_allies_except_self": "alle anderen Verbündeten",
    "all_combatants": "alle aktiven Pokémon",
    "self_or_single_ally": "Anwender oder gewählter Verbündeter"
}

const INTERNAL_INFOBOX_TOKENS: Array[String] = [
    "db_", "db ",
    "v22_", "v22 ",
    "f30_", "f30 ",
    "f40_", "f40 ",
    "f64_", "f64 ",
    "zf_", "zf ",
    "bulba_", "bulba ",
    "tf_", "tf ",
    "effect_source", "runtime_supported", "multiplier_from_special",
    "duration_actions", "res://"
]

const RUNTIME_PRESENTATION_METADATA_KEYS: Array[String] = [
    "runtime_supported",
    "strict_contract",
    "contract_validated",
    "contract_errors",
    "partial",
    "notes",
    "normal_battle_available"
]


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

    for inherited_line: String in _inherited_preview_extra_lines(inherited_text):
        var extra_line: String = _standardize_inherited_extra_line(inherited_line)
        if extra_line.is_empty():
            continue
        var plain_extra: String = extra_line.replace("[b]", "").replace("[/b]", "").strip_edges()
        if plain_extra.is_empty():
            continue
        if text.contains(plain_extra):
            continue
        text += "\n" + extra_line

    log_label.text = text


func _standardize_inherited_extra_line(source: String) -> String:
    var plain: String = source.replace("[b]", "").replace("[/b]", "").strip_edges()
    if plain.is_empty():
        return ""
    if plain.contains("_") or _contains_internal_infobox_token(plain):
        return ""
    return _space_percentages(source.strip_edges())


func _move_tooltip(move: Dictionary) -> String:
    # Tooltips and the always-visible preview now speak the same language.
    return _standardized_move_info_text(move, false).replace("[b]", "").replace("[/b]", "")


func _compact_effect_summary(move: Dictionary) -> String:
    # Keep all inherited special-case knowledge. Only generic effect fragments
    # are normalized, so a bespoke attack never loses its bespoke explanation.
    return _standardize_effect_summary(move, super._compact_effect_summary(move))


func _detail_info(combatant: Dictionary) -> String:
    # Older mechanic layers built the detail window incrementally. Some of them
    # appended live effects after the move list, while the base list showed only
    # move names. Normalize the finished inherited text once, at this central UI
    # boundary: every live effect belongs below AKTIVE EFFEKTE and every move gets
    # the same complete explanation used by the battle infobox.
    return _standardized_combatant_detail(
        combatant,
        super._detail_info(combatant)
    )


func _standardized_combatant_detail(
    combatant: Dictionary,
    inherited_text: String
) -> String:
    var effects_header: String = "[b]AKTIVE EFFEKTE[/b]"
    var attacks_header: String = "[b]VERFÜGBARE ATTACKEN[/b]"
    var effects_start: int = inherited_text.find(effects_header)
    var attacks_start: int = inherited_text.find(attacks_header)
    if effects_start < 0 or attacks_start < effects_start:
        return inherited_text

    var overview: String = inherited_text.substr(0, effects_start).strip_edges()
    var effects_source_start: int = effects_start + effects_header.length()
    var effects_source: String = inherited_text.substr(
        effects_source_start,
        attacks_start - effects_source_start
    )
    var attacks_source: String = inherited_text.substr(
        attacks_start + attacks_header.length()
    )
    var trailing_effects: String = _detail_text_without_inherited_move_rows(
        combatant,
        attacks_source
    )
    if not trailing_effects.strip_edges().is_empty():
        effects_source += "\n" + trailing_effects

    var effect_lines: Array[String] = _standard_detail_effect_lines(
        combatant,
        effects_source
    )
    var sections := PackedStringArray()
    if not overview.is_empty():
        sections.append(overview)
    sections.append(effects_header + "\n" + "\n".join(effect_lines))
    sections.append(
        attacks_header
        + "\n"
        + _standard_detail_move_text(combatant, attacks_source)
    )
    return "\n\n".join(sections)


func _detail_text_without_inherited_move_rows(
    combatant: Dictionary,
    attacks_source: String
) -> String:
    # Several newer mechanic layers still append live state after the inherited
    # name-only attack rows. Remove only those known rows and feed everything
    # else back into the unified active-effects section.
    if attacks_source.contains("für den anderen Spieler verborgen"):
        return ""

    var remaining_names: Array[String] = _move_names(combatant.get("moves", []))
    var extra_lines := PackedStringArray()
    for source_line: String in attacks_source.split("\n"):
        var clean: String = source_line.strip_edges()
        var move_row_index: int = -1
        if clean.begins_with("• "):
            move_row_index = remaining_names.find(clean.trim_prefix("• ").strip_edges())
        if move_row_index >= 0:
            remaining_names.remove_at(move_row_index)
            continue
        extra_lines.append(source_line)
    return "\n".join(extra_lines).strip_edges()


func _standard_detail_effect_lines(
    combatant: Dictionary,
    inherited_effects: String
) -> Array[String]:
    var lines: Array[String] = []
    var saw_empty_placeholder: bool = false

    for source_line: String in inherited_effects.split("\n"):
        var clean: String = source_line.strip_edges()
        if clean.is_empty():
            continue
        # Historical subheadings such as SONDEREFFEKTE, KONTROLLE or
        # HAUPTSTATUS describe the same thing. The player gets one stable home.
        if clean.begins_with("[b]") and clean.ends_with("[/b]"):
            continue
        clean = clean.trim_prefix("•").strip_edges()
        if clean == "Keine aktiven Veränderungen":
            saw_empty_placeholder = true
            continue
        var bullet: String = "• " + clean
        if not lines.has(bullet):
            lines.append(bullet)

    for central_line: String in _central_detail_effect_lines(combatant):
        var bullet: String = "• " + central_line
        if not lines.has(bullet):
            lines.append(bullet)

    if lines.is_empty() and saw_empty_placeholder:
        lines.append("• Keine aktiven Veränderungen")
    elif lines.is_empty():
        lines.append("• Keine aktiven Veränderungen")
    return lines


func _central_detail_effect_lines(combatant: Dictionary) -> Array[String]:
    # These newer battle states expose compact card markers but historically
    # never contributed a matching explanation to the detail window.
    var lines: Array[String] = []
    if bool(combatant.get("f30_destiny_bond_active", false)):
        lines.append(
            "🔗 Abgangsbund: Wird dieses Pokémon vor seiner nächsten eigenen "
            + "Aktionsmöglichkeit durch gegnerischen Schaden kampfunfähig, "
            + "wird der Angreifer ebenfalls kampfunfähig."
        )
    if bool(combatant.get("f30_aqua_ring_active", false)):
        lines.append(
            "💍 Wasserring: Heilt nach jeder eigenen Aktion KP; die Heilung "
            + "hängt vom Statuswert und den maximalen KP ab."
        )
    if _tf_has_state(combatant, "minimized"):
        var minimize_remaining: int = maxi(
            0,
            int(combatant.get("f30_minimize_expires_serial", 0))
            - int(combatant.get("action_serial", 0))
        )
        lines.append(
            "🤏 Komprimiert: Gegnerische Attacken treffen seltener · noch %d "
            % minimize_remaining
            + ("eigene Aktion." if minimize_remaining == 1 else "eigene Aktionen.")
        )
    if not str(combatant.get("f30_mean_look_source_id", "")).is_empty():
        lines.append(
            "👁️ Aggro-Lock: Die Aggro kann nicht unter den beim Einsatz von "
            + "Horrorblick erreichten Wert fallen, solange die Quelle aktiv ist."
        )
    if (
        bool(combatant.get("ad_short_charging", false))
        and str(combatant.get("ad_short_charge_move", "")) == "counter"
    ):
        lines.append(
            "🥊 Konter: Wartet auf gegnerischen physischen Schaden und fügt "
            + "dem Angreifer anschließend das Doppelte der erlittenen KP zu."
        )
    return lines


func _standard_detail_move_text(
    combatant: Dictionary,
    inherited_attack_text: String
) -> String:
    # Preserve the local-PvP information barrier from the inherited view.
    if inherited_attack_text.contains("für den anderen Spieler verborgen"):
        return "• In Runde 0 für den anderen Spieler verborgen"

    var move_ids_value: Variant = combatant.get("moves", [])
    if not (move_ids_value is Array) or (move_ids_value as Array).is_empty():
        return "• Keine Attacken verfügbar"

    var output := PackedStringArray()
    for move_id_value: Variant in move_ids_value:
        var move_id: String = str(move_id_value)
        var move: Dictionary = _move_data(move_id)
        if move.is_empty():
            output.append("• " + move_id)
            continue

        var info_lines: PackedStringArray = _standardized_move_info_text(move).split("\n")
        for line_index: int in range(info_lines.size()):
            var info_line: String = info_lines[line_index].strip_edges()
            if info_line.is_empty():
                continue
            output.append(("• " if line_index == 0 else "  ") + info_line)
    return "\n".join(output)


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
    var power_text: String = _standard_power_text(move)
    if not power_text.is_empty():
        combat_bits.append(power_text)
    var status_percentage_text: String = _standard_status_percentage_text(move)
    if not status_percentage_text.is_empty():
        combat_bits.append("Effekt: " + status_percentage_text)
    combat_bits.append("Ziel: " + _target_name(str(move.get("target", "enemy_highest_aggro"))))
    combat_bits.append("Genauigkeit: " + _standard_accuracy_text(move))
    lines.append(" · ".join(combat_bits))

    var effect_summary: String = _compact_effect_summary(move).strip_edges()
    effect_summary = _effect_summary_without_redundant_damage(
        effect_summary,
        not power_text.is_empty()
    )
    if not effect_summary.is_empty():
        lines.append("Wirkung: " + effect_summary)

    var feature_bits: Array[String] = _standard_feature_bits(move)
    if not feature_bits.is_empty():
        lines.append("Besonderheit: " + " · ".join(feature_bits))

    if touch_confirm:
        lines.append("Bestätigen: Attacke erneut antippen.")

    return "\n".join(lines)


func _standard_status_percentage_text(move: Dictionary) -> String:
    # Put the live, status-based result in the always-visible compact row. The
    # calculation is delegated to the same central helper used by combat and the
    # detailed effect text, so preview and execution cannot drift apart.
    if str(move.get("category", "")) != "status" or selected_actor.is_empty():
        return ""

    var mechanics_value: Variant = move.get("mechanics", move.get("effects", []))
    if not (mechanics_value is Array):
        return ""

    var results: Array[String] = []
    for mechanic_value: Variant in mechanics_value:
        if not (mechanic_value is Dictionary):
            continue
        var mechanic: Dictionary = mechanic_value as Dictionary
        var kind: String = str(mechanic.get("kind", ""))
        var calculation_kind: String = kind
        if kind == "db_team_modifier":
            calculation_kind = str(mechanic.get("modifier_kind", ""))
        if not _is_player_attribute_modifier(calculation_kind):
            continue

        var result: String = _infobox_attribute_modifier_summary(
            move,
            mechanic,
            calculation_kind,
            true,
            true
        ).strip_edges()
        result = _space_percentages(result)
        if result.contains("%") and not results.has(result):
            results.append(result)
    return " / ".join(results)


func _standard_power_text(move: Dictionary) -> String:
    var weight_range: String = _standard_weight_power_range(move)
    if not weight_range.is_empty():
        return "Stärke: " + weight_range + " (Gewicht)"

    var power_value: Variant = move.get("power", null)
    if power_value == null:
        return ""
    return "Stärke: %d" % int(round(float(power_value)))


func _standard_weight_power_range(move: Dictionary) -> String:
    # Weight-based attacks already expose their tiers as structured runtime data.
    # Reading that contract keeps the compact UI correct without parsing German
    # descriptions or hard-coding a particular move id.
    var runtime_value: Variant = move.get("runtime", {})
    if not (runtime_value is Dictionary):
        return ""

    var tiers_value: Variant = (runtime_value as Dictionary).get("weight_power_tiers", [])
    if not (tiers_value is Array):
        return ""

    var has_power: bool = false
    var minimum_power: int = 0
    var maximum_power: int = 0
    for tier_value: Variant in tiers_value:
        if not (tier_value is Array):
            continue
        var tier: Array = tier_value as Array
        if tier.size() < 2:
            continue
        var tier_power_value: Variant = tier[1]
        var power_type: int = typeof(tier_power_value)
        if power_type != TYPE_INT and power_type != TYPE_FLOAT:
            continue

        var tier_power: int = int(round(float(tier_power_value)))
        if not has_power:
            minimum_power = tier_power
            maximum_power = tier_power
            has_power = true
        else:
            minimum_power = mini(minimum_power, tier_power)
            maximum_power = maxi(maximum_power, tier_power)

    if not has_power:
        return ""
    if minimum_power == maximum_power:
        return str(minimum_power)
    return "%d–%d" % [minimum_power, maximum_power]


func _target_name(rule: String) -> String:
    if STANDARD_TARGET_LABELS.has(rule):
        return str(STANDARD_TARGET_LABELS[rule])

    # Preserve a future parent-layer translation if it already knows the rule.
    # Otherwise never expose snake_case to the player.
    var inherited: String = super._target_name(rule).strip_edges()
    if not inherited.is_empty() and inherited != rule and not inherited.contains("_"):
        return inherited
    var fallback: String = rule.replace("_", " ").strip_edges()
    return fallback if not fallback.is_empty() else "gültiges Ziel"


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

    # One canonical damage word. Details after it (variable power, multi-hit,
    # conditions, etc.) remain untouched.
    text = text.replace("direkter Schaden", "Schaden")

    var mechanics_value: Variant = move.get("mechanics", move.get("effects", []))
    if mechanics_value is Array:
        var segments: PackedStringArray = text.split(" · ")
        var normalized: Array[String] = []

        for segment_value: String in segments:
            var segment: String = segment_value.strip_edges()
            if segment.is_empty():
                continue
            var replacement: String = _normalized_status_segment(segment, mechanics_value as Array)
            normalized.append(replacement if not replacement.is_empty() else segment)

        text = " · ".join(normalized)

    text = _space_percentages(text)

    # The inherited stack contains hundreds of bespoke summaries. Keep those
    # whenever they are already good. Only fall back when a new mechanic leaks
    # an implementation name, or when a genuinely complex/status move would
    # otherwise be represented by a cryptic one-word label.
    if _summary_needs_player_fallback(move, text):
        return _player_fallback_effect_summary(move, text)

    return text


func _summary_needs_player_fallback(move: Dictionary, text: String) -> bool:
    if _contains_internal_infobox_token(text):
        return true
    if text.is_empty():
        return _move_has_complex_player_rule(move)
    if (
        text.length() <= 24
        and _move_has_complex_player_rule(move)
        and _has_player_special_rules(move)
    ):
        return true
    return false


func _move_requires_effect_line(move: Dictionary) -> bool:
    if str(move.get("category", "")) == "status":
        return true
    if move.get("power", null) == null:
        return true

    var mechanics_value: Variant = move.get("mechanics", move.get("effects", []))
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            if str((mechanic_value as Dictionary).get("kind", "")) != "damage":
                return true
    return false


func _move_has_complex_player_rule(move: Dictionary) -> bool:
    if _move_requires_effect_line(move):
        return true

    var runtime_value: Variant = move.get("runtime", {})
    if not (runtime_value is Dictionary):
        return false
    var runtime: Dictionary = runtime_value
    for key_value: Variant in runtime.keys():
        var key: String = str(key_value)
        if RUNTIME_PRESENTATION_METADATA_KEYS.has(key):
            continue
        if key.begins_with("contract_"):
            continue
        return true
    return false


func _player_fallback_effect_summary(move: Dictionary, source: String) -> String:
    var parts: Array[String] = []

    var description: String = _clean_player_fallback_fragment(str(move.get("description", "")))
    if not description.is_empty():
        parts.append(description)

    for rule: String in _player_special_rule_fragments(move):
        var duplicate: bool = false
        for existing: String in parts:
            if existing == rule or existing.contains(rule) or rule.contains(existing):
                duplicate = true
                break
        if not duplicate:
            parts.append(rule)

    if not parts.is_empty():
        return " · ".join(parts)

    # Last-resort safety for a future move that has no description yet: keep any
    # already readable segments but drop implementation identifiers entirely.
    var safe_segments: Array[String] = []
    for segment_value: String in source.split(" · "):
        var segment: String = _clean_player_fallback_fragment(segment_value)
        if not segment.is_empty():
            safe_segments.append(segment)
    if not safe_segments.is_empty():
        return " · ".join(safe_segments)
    return "Spezialwirkung"


func _has_player_special_rules(move: Dictionary) -> bool:
    return not _player_special_rule_fragments(move).is_empty()


func _player_special_rule_fragments(move: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var rules_value: Variant = move.get("special_rules", [])

    if rules_value is Array:
        for rule_value: Variant in rules_value:
            var clean: String = _clean_player_fallback_fragment(str(rule_value))
            if not clean.is_empty():
                result.append(clean)
    elif rules_value is String:
        var clean: String = _clean_player_fallback_fragment(str(rules_value))
        if not clean.is_empty():
            result.append(clean)

    return result


func _clean_player_fallback_fragment(source: String) -> String:
    var text: String = source.replace("\n", " ").replace("\r", " ").strip_edges()
    while text.contains("  "):
        text = text.replace("  ", " ")
    if text.is_empty():
        return ""
    if text.contains("_") or _contains_internal_infobox_token(text):
        return ""
    return _space_percentages(text)


func _contains_internal_infobox_token(source: String) -> bool:
    var lower: String = source.to_lower()
    for token: String in INTERNAL_INFOBOX_TOKENS:
        if lower.contains(token):
            return true
    return false


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
