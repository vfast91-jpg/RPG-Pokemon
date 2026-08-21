extends "res://scripts/battle_demo_toxic_spikes_final.gd"

# Final player-facing attack-information layer.
#
# The info strip must explain what a move really does. It is not enough to
# translate internal mechanic ids. Complex mechanics therefore get a canonical,
# player-readable summary that reflects the current runtime behavior. The normal
# preview supplies type, category, power, accuracy, target and AP timing; this
# layer adds the tactical rules a player needs to make an informed decision.

const TFEffectRegistry = preload("res://scripts/battle/move_effect_registry.gd")

const INFOBOX_EFFECT_OVERRIDES: Dictionary = {
    "feint": (
        "Schaden · entfernt einen vorhandenen Schutzschild und trifft trotzdem "
        + "· funktioniert auch ohne Schutzschild"
    ),
    "safeguard": (
        "Alle aktiven Verbündeten: jeweils 3 eigene Aktionen Schutz vor neuen "
        + "Hauptstatuszuständen · vorhandene Status bleiben · Reserve nicht betroffen"
    ),
    "rage_powder": (
        "3 eigene Aktionen: gegnerische Einzelzielattacken werden auf den Anwender "
        + "umgelenkt · überschreibt dafür die Aggro-Zielregel · Flächenattacken nicht "
        + "· endet bei K.O."
    ),
    "bug_bite": (
        "Schaden · Beereninteraktion ist noch nicht aktiv (Itemsystem fehlt) "
        + "· aktuell normale Stärke-60-Schadensattacke"
    )
}


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    if log_label == null:
        return

    var text: String = _sanitize_player_infobox(log_label.text)
    var special_bits: Array[String] = []
    var priority: int = int(round(float(move.get("priority", 0))))

    if priority != 0 and not text.contains("Priorität"):
        special_bits.append("Priorität " + ("+" if priority > 0 else "") + str(priority))
    if bool(move.get("opening", false)) and not text.contains("Runde 0"):
        special_bits.append("Runde 0")
    if bool(move.get("area", false)) and not text.contains("Flächenwirkung"):
        special_bits.append("Flächenwirkung")
    if bool(move.get("contact", false)) and not text.contains("Kontakt"):
        special_bits.append("Kontakt")

    if not special_bits.is_empty():
        var lines: PackedStringArray = text.split("\n")
        if not lines.is_empty():
            lines[0] = lines[0] + " · " + " · ".join(special_bits)
            text = "\n".join(lines)

    log_label.text = text


func _move_tooltip(move: Dictionary) -> String:
    return _sanitize_player_infobox(super._move_tooltip(move))


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))
    if INFOBOX_EFFECT_OVERRIDES.has(move_id):
        return str(INFOBOX_EFFECT_OVERRIDES[move_id])

    var bibor_summary: String = _bibor_infobox_summary(move)
    if not bibor_summary.is_empty():
        return _sanitize_player_infobox(bibor_summary)

    return _sanitize_player_infobox(super._compact_effect_summary(move))


func _bibor_infobox_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))

    match move_id:
        "fury_attack", "pin_missile":
            var power: int = int(round(float(move.get("power", 0))))
            return (
                "2–5 Treffer · Stärke %d je Treffer · 2/3 Treffer je 37,5%%, "
                + "4/5 je 12,5%% · Genauigkeit einmal pro Attacke · jeder Treffer eigener Volltrefferwurf"
            ) % power

        "string_shot":
            var string_mechanic: Dictionary = _infobox_mechanic(move, "atb_cycle_mod")
            var string_effect: String = (
                _infobox_attribute_modifier_summary(move, string_mechanic, "atb_cycle_mod")
                if not string_mechanic.is_empty()
                else "Geschwindigkeit ↓ nach Statuswert"
            )
            return (
                string_effect
                + " bei allen Gegnern · 3 eigene Aktionen je Ziel · Genauigkeit pro Ziel separat"
            )

        "poison_sting", "poison_jab":
            return "Schaden · bei erfolgreichem Treffer 30 % Chance auf Vergiftung"

        "focus_energy":
            if selected_actor.is_empty():
                return (
                    "Volltrefferchance steigt nach eigenem Statuswert · bis Wechsel/Kampfende "
                    + "· nicht stapelbar"
                )
            var bonus_pp: int = int(round(_status_percent(float(selected_actor.get("special", 0.0)))))
            return (
                "Volltrefferchance +%d Prozentpunkte · bis Wechsel/Kampfende · nicht stapelbar"
                % bonus_pp
            )

        "assurance":
            var assurance: String = (
                "Schaden · Stärke 120, wenn das Ziel seit seiner letzten eigenen Aktion KP verloren hat; "
                + "sonst Stärke 60"
            )
            var assurance_target: Dictionary = _infobox_single_target(move)
            if not assurance_target.is_empty():
                assurance += (
                    " · aktuell: Stärke 120 (Bedingung erfüllt)"
                    if bool(assurance_target.get("damage_since_last_action", false))
                    else " · aktuell: Stärke 60"
                )
            return assurance

        "harden":
            var harden_mechanic: Dictionary = _infobox_mechanic(move, "incoming_damage_mod")
            var harden_effect: String = (
                _infobox_attribute_modifier_summary(move, harden_mechanic, "incoming_damage_mod")
                if not harden_mechanic.is_empty()
                else "Verteidigung ↑ nach Statuswert"
            )
            return harden_effect + " · hält 3 eigene Aktionen des Anwenders"

        "fury_cutter":
            var cutter: String = (
                "Schaden · direkte Folgeeinsätze: Stärke 40 → 80 → 160 · Ziel darf wechseln "
                + "· Reset bei Miss, Fehlschlag, anderer eigener Aktion oder Warten"
            )
            if not selected_actor.is_empty():
                var chain: Array = [40, 80, 160]
                var chain_index: int = int(selected_actor.get("db_fury_cutter_chain", 0))
                if str(selected_actor.get("db_last_move", "")) != "fury_cutter":
                    chain_index = 0
                chain_index = clampi(chain_index, 0, chain.size() - 1)
                cutter += " · aktuell: Stärke %d" % int(chain[chain_index])
            return cutter

        "laser_focus":
            return (
                "Nächster eigener Aktionsversuch: Volltreffer garantiert · bei Mehrfachtreffern alle Treffer kritisch "
                + "· wird auch durch Statusattacke, Miss oder Fehlschlag verbraucht · nicht stapelbar"
            )

        "venoshock":
            var venoshock: String = (
                "Schaden · gegen vergiftete oder schwer vergiftete Ziele Stärke 130; sonst Stärke 65"
            )
            var venoshock_target: Dictionary = _infobox_single_target(move)
            if not venoshock_target.is_empty():
                var poisoned: bool = ["poison", "bad_poison"].has(
                    str(venoshock_target.get("major_status", ""))
                )
                venoshock += " · aktuell: Stärke %d" % (130 if poisoned else 65)
            return venoshock

        "toxic_spikes":
            var spikes: String = (
                "1 Lage: Vergiftung · 2 Lagen: schwere Vergiftung · Auslösung, wenn ein geerdeter Gegner "
                + "eine physische Kontaktattacke benutzt · Gift/Stahl immun · Turbodreher entfernt die Lagen"
            )
            if not selected_actor.is_empty():
                var enemy_side: String = (
                    "enemy" if str(selected_actor.get("side", "")) == "player" else "player"
                )
                var layers: int = int(get_meta("db_toxic_spikes_" + enemy_side, 0))
                spikes += " · aktuell: %d/2 Lagen" % layers
            return spikes

        "agility":
            var agility_mechanic: Dictionary = _infobox_mechanic(move, "atb_cycle_mod")
            var agility_effect: String = (
                _infobox_attribute_modifier_summary(move, agility_mechanic, "atb_cycle_mod")
                if not agility_mechanic.is_empty()
                else "Geschwindigkeit ↑ nach Statuswert"
            )
            return agility_effect + " · hält 3 eigene Aktionen des Anwenders"

        "endeavor":
            return (
                _endeavor_damage_summary(move)
                + " · ignoriert Angriff und Verteidigung · kein Volltreffer · Schutz und Typ-Immunität gelten"
            )

        "fell_stinger":
            var sting_mechanic: Dictionary = _infobox_mechanic(move, "db_on_ko_modifier")
            var ko_kind: String = str(sting_mechanic.get("modifier_kind", "outgoing_damage_mod"))
            var sting_effect: String = (
                _infobox_attribute_modifier_summary(move, sting_mechanic, ko_kind, false, false)
                if not sting_mechanic.is_empty()
                else "Angriff ↑ stark nach Statuswert"
            )
            return (
                "Schaden · nur bei K.O. durch diese Attacke: %s · 3 eigene Aktionen "
                + "· indirekter K.O. (z. B. Gift) zählt nicht"
            ) % sting_effect

    return ""


func _infobox_mechanic(move: Dictionary, kind: String) -> Dictionary:
    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        return {}
    for mechanic_value: Variant in mechanics_value:
        if mechanic_value is Dictionary and str((mechanic_value as Dictionary).get("kind", "")) == kind:
            return (mechanic_value as Dictionary).duplicate(true)
    return {}


func _infobox_attribute_modifier_summary(
    move: Dictionary,
    mechanic: Dictionary,
    kind: String,
    apply_type_bonus: bool = true,
    apply_sun_bonus: bool = false
) -> String:
    if selected_actor.is_empty():
        return _attribute_direction_summary(mechanic, kind)

    var adjusted: Dictionary = mechanic.duplicate(true)
    if apply_type_bonus:
        var move_type: String = str(move.get("type", "normal"))
        var actor_types: Array = _type_array(selected_actor.get("types", []))
        var type_bonus: float = TypeSystem.get_same_type_status_multiplier(move_type, actor_types)
        adjusted["multiplier_from_special"] = (
            float(adjusted.get("multiplier_from_special", 0.0)) * type_bonus
        )

    return _attribute_modifier_summary(
        adjusted,
        kind,
        false,
        apply_sun_bonus
    )


func _infobox_single_target(move: Dictionary) -> Dictionary:
    if selected_actor.is_empty():
        return {}
    var targets: Array = _targets(
        selected_actor,
        str(move.get("target", "enemy_highest_aggro"))
    )
    if targets.size() != 1 or not (targets[0] is Dictionary):
        return {}
    return targets[0] as Dictionary


func _player_text_cleanup(source: String) -> String:
    return _sanitize_player_infobox(super._player_text_cleanup(source))


func _sanitize_player_infobox(source: String) -> String:
    var text: String = _translate_internal_effect_labels(source)
    var kept := PackedStringArray()

    # Implementation metadata must never be visible to the player. All useful
    # behavior is represented by the normal fields or the compact effect summary.
    for line: String in text.split("\n"):
        var clean: String = line.strip_edges()
        var lower: String = clean.to_lower()
        if clean.begins_with("Datenbank-Effekt:"):
            continue
        if lower.contains("effect_source"):
            continue
        kept.append(line)

    return "\n".join(kept).strip_edges()


func _translate_internal_effect_labels(source: String) -> String:
    var text: String = source

    for kind_value: Variant in TFEffectRegistry.EFFECTS.keys():
        var kind: String = str(kind_value)
        if not kind.contains("_"):
            continue

        var label: String = TFEffectRegistry.player_label_for_effect(kind)
        if label.is_empty():
            continue

        text = text.replace(kind, label)
        text = text.replace(kind.replace("_", " "), label)

    return text
