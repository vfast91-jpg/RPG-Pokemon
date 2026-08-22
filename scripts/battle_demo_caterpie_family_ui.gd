extends "res://scripts/battle_demo_caterpie_family.gd"

const CaterpieFlinchRules = preload("res://scripts/battle/flinch_rules.gd")

# Small presentation bridge for the first additional single-ally move after
# Helping Hand. The older shared selector is mechanically generic but its label
# still says "Rechte Hand". Keep that legacy path untouched and present Baton
# Pass with its own correct player-facing wording here.
#
# This is also the final battle guardrail for the canonical flinch rule. Older
# move packs may still carry a historical numeric ATB-knockback amount. That
# number is ignored: a successful flinch always resets the current action bar
# to 0 %, and the infobox always explains exactly that rule.

func _choose_move(move_id: String) -> void:
    if move_id != "baton_pass":
        super._choose_move(move_id)
        return
    if selected_actor.is_empty():
        return

    var actor: Dictionary = selected_actor
    var allies: Array = _bulba_living_other_allies(actor)
    if allies.is_empty():
        _set_log("[b]Stafette[/b]: Kein aktiver Verbündeter als Ziel verfügbar.")
        _spawn_feedback_label(actor, "🔁 KEIN VERBÜNDETER", Color("b9d7ff"))
        return
    if allies.size() == 1:
        _bulba_selected_ally_id = str((allies[0] as Dictionary).get("id", ""))
        # Let the inherited single-ally path execute normally; with one ally it
        # does not open its old hard-coded selection menu.
        super._choose_move(move_id)
        return

    _bulba_pending_ally_move_id = move_id
    _bulba_pending_ally_actor = actor
    _clear_actions()
    _set_log("[b]Stafette[/b]: Verbündetes Pokémon wählen.")
    for ally_value: Variant in allies:
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        var button := Button.new()
        button.text = "🔁 " + _actor_name(ally)
        button.tooltip_text = "Temporäre positive und negative Attributsänderungen auf dieses Pokémon übertragen"
        button.pressed.connect(_bulba_choose_ally_target.bind(str(ally.get("id", ""))))
        action_grid.add_child(button)


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) != "atb_knockback":
        return super._effect(actor, target, mechanic)

    if CaterpieFlinchRules.apply(target, float(mechanic.get("chance", 1.0))):
        # Flinch is a fixed control effect. Status/type scaling may affect other
        # support effects, but it never turns this reset into a partial knockback.
        return 3.0
    return 0.0


func _compact_effect_summary(move: Dictionary) -> String:
    var text: String = super._compact_effect_summary(move)
    var flinch_mechanics: Array = _collect_flinch_mechanics(move.get("mechanics", []))
    for mechanic_value: Variant in flinch_mechanics:
        if mechanic_value is Dictionary:
            text = _replace_legacy_flinch_text(text, mechanic_value as Dictionary)
    return text


func _collect_flinch_mechanics(value: Variant, inherited_chance: float = 1.0) -> Array:
    var result: Array = []

    if value is Array:
        for item: Variant in value:
            result.append_array(_collect_flinch_mechanics(item, inherited_chance))
        return result

    if not (value is Dictionary):
        return result

    var mechanic: Dictionary = value
    var kind: String = str(mechanic.get("kind", ""))
    if kind == "atb_knockback":
        var normalized: Dictionary = mechanic.duplicate(true)
        normalized["chance"] = clampf(
            inherited_chance * float(mechanic.get("chance", 1.0)),
            0.0,
            1.0
        )
        result.append(normalized)
        return result

    if kind == "db_chance_mechanic":
        var outer_chance: float = float(mechanic.get("chance", 1.0))
        return _collect_flinch_mechanics(
            mechanic.get("mechanic", {}),
            clampf(inherited_chance * outer_chance, 0.0, 1.0)
        )

    return result


func _replace_legacy_flinch_text(source: String, mechanic: Dictionary) -> String:
    var chance: float = float(mechanic.get("chance", 1.0))
    var chance_percent: int = int(round(chance * 100.0))
    var canonical: String = CaterpieFlinchRules.player_summary(chance)
    var text: String = source

    # Historical summaries looked like "30% Aktionsleiste −25%". Remove any
    # numeric partial-knockback wording regardless of the old stored amount.
    var legacy_pattern: String = (
        str(chance_percent)
        + "\\s*%\\s*(ATB|Aktionsleiste)\\s*[−-]\\s*\\d+\\s*%"
    )
    var regex := RegEx.new()
    if regex.compile(legacy_pattern) == OK:
        text = regex.sub(text, canonical, true)

    text = text.replace(str(chance_percent) + " % Zurückschrecken", canonical)
    text = text.replace(str(chance_percent) + "% Zurückschrecken", canonical)

    if not text.contains(canonical):
        text += (" · " if not text.is_empty() else "") + canonical
    return text
