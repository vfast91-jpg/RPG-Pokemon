extends "res://scripts/battle_demo_timeflow_weather.gd"

# Final combat-lab configuration overflow guard.
#
# The 640x360 virtual viewport can no longer assume that every setup option fits
# vertically. TM test controls and future lab options may legitimately make the
# configuration taller than the viewport, so the complete setup area is placed
# inside a vertical ScrollContainer instead of being clipped at the bottom.
#
# This final layer also owns the current Lockduft runtime correction. The
# spreadsheet definition uses the Status soft-cap R = Status / (75 + Status),
# and affected targets must visibly show that attacks against them are more
# accurate for their next three own actions.
#
# Fassade is also finalized here: its conditional power boost already comes
# from the TM runtime layer, while this layer makes the player-facing special
# rule explicit and prevents the generic burn Attack penalty from reducing
# Fassade itself.

var config_scroll: ScrollContainer = null


func _build_config(root: Control) -> void:
    super._build_config(root)
    _wrap_config_in_vertical_scroll()


func _wrap_config_in_vertical_scroll() -> void:
    if config_panel == null:
        return

    var existing_scroll: ScrollContainer = config_panel.get_node_or_null("ConfigScroll") as ScrollContainer
    if existing_scroll != null:
        config_scroll = existing_scroll
        return

    if config_panel.get_child_count() == 0:
        return

    # All inherited config layers have finished at this point. They intentionally
    # see the historic direct VBox child while building; only the final layer
    # reparents it, so older setup code remains compatible.
    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer == null:
        return

    config_panel.remove_child(outer)

    config_scroll = ScrollContainer.new()
    config_scroll.name = "ConfigScroll"
    config_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    config_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    config_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    config_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    config_scroll.follow_focus = true
    config_panel.add_child(config_scroll)

    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    config_scroll.add_child(outer)


func open_config() -> void:
    super.open_config()
    if config_scroll != null:
        config_scroll.scroll_vertical = 0


func _compact_effect_summary(move: Dictionary) -> String:
    var move_id: String = str(move.get("id", ""))

    # Sorgensamen has two technical database mechanics. Those internal db_*
    # identifiers must never leak into the player-facing attack description.
    if move_id == "worry_seed":
        return "Schlaf entfernen · Schutz vor neuem Schlaf für 3 eigene Aktionen"

    # Canonical Fassade rule from the attack database. The inherited generic
    # summary sees only a damage mechanic and would otherwise show nothing but
    # "direkter Schaden".
    if move_id == "facade":
        return (
            "direkter Schaden · Stärke 140 bei Verbrennung, Vergiftung, "
            + "schwerer Vergiftung oder Paralyse · bei Verbrennung ohne "
            + "Verbrennungs-Angriffsmalus"
        )

    return super._compact_effect_summary(move)


func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var active_move_id: String = str(_active_special_move.get("id", ""))
    var major_status: String = str(actor.get("major_status", ""))

    # The generic status layer halves physical damage while burned. Fassade is
    # the explicit exception: it keeps every other Attack modifier, but the burn
    # penalty itself must not apply to this move. Temporarily hiding only the
    # burn status from the inherited damage calculation isolates exactly that
    # penalty; the status is restored before after-action burn damage resolves.
    if active_move_id == "facade" and major_status == "burn" and category == "physical":
        actor["major_status"] = ""
        var facade_damage: int = super._damage(actor, target, power, move_type, category)
        actor["major_status"] = major_status
        return facade_damage

    return super._damage(actor, target, power, move_type, category)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) != "db_incoming_accuracy":
        return super._effect(actor, target, mechanic)

    # Lockduft/current incoming-accuracy support follows the canonical Status
    # soft-cap instead of the older linear special/100 implementation.
    var status_value: float = maxf(0.0, float(actor.get("special", 0.0)))
    var softcap_base: float = maxf(0.001, float(mechanic.get("softcap_base", 75.0)))
    var ratio: float = status_value / (softcap_base + status_value)
    var multiplier: float = absf(float(mechanic.get("multiplier_from_special", 2.0)))
    var bonus: float = ratio * multiplier
    var direction: String = str(mechanic.get("direction", "bonus"))
    var accuracy_multiplier: float = 1.0 + bonus if direction == "bonus" else 1.0 - bonus
    var duration_actions: int = maxi(1, int(mechanic.get("duration_actions", 3)))

    target["db_incoming_accuracy_mult"] = clampf(accuracy_multiplier, 0.2, 2.5)
    target["db_incoming_accuracy_expires"] = int(target.get("action_serial", 0)) + duration_actions

    if battle_panel != null:
        var percent: int = int(round(bonus * 100.0))
        var label_text: String = (
            "🌸 LEICHTER TREFFBAR +" + str(percent) + "% · "
            + str(duration_actions) + " AKT."
            if direction == "bonus"
            else "🌸 SCHWERER TREFFBAR · " + str(duration_actions) + " AKT."
        )
        _spawn_feedback_label(target, label_text, Color("f1b6d8"))

    return bonus * 8.0


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    var current_action: int = int(combatant.get("action_serial", 0))
    var expires_after: int = int(combatant.get("db_incoming_accuracy_expires", 0))
    if current_action >= expires_after:
        return tokens

    var multiplier: float = float(combatant.get("db_incoming_accuracy_mult", 1.0))
    var remaining: int = maxi(0, expires_after - current_action)
    if multiplier > 1.001:
        tokens.append("TREFFER↑" + str(remaining) + "A")
    elif multiplier < 0.999:
        tokens.append("TREFFER↓" + str(remaining) + "A")
    return tokens
