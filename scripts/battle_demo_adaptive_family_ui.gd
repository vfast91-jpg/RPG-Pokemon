extends "res://scripts/battle_demo_adaptive_cards.gd"

# The family setup UI is now owned entirely by battle_demo_family_lab.gd.
# This top layer keeps the compact explanatory subtitle and adds one final
# orientation cue to the battle formation: the soft ground shadow beneath each
# Pokemon mirrors the same tactical state as its card/connector.

const ROSTER_SHADOW_DEFAULT := Color("0a14103d")
const ROSTER_SHADOW_ACTIVE := Color("e0a52f66")
const ROSTER_SHADOW_TARGET := Color("cf343466")
const ROSTER_SHADOW_FAINTED := Color("6a6a6a33")


func _build_config(root: Control) -> void:
    super._build_config(root)

    if config_panel == null or config_panel.get_child_count() == 0:
        return
    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer == null or outer.get_child_count() <= 1:
        return
    var subtitle: Label = outer.get_child(1) as Label
    if subtitle != null:
        subtitle.text = "Familie waehlen · Level bestimmt die Form · 1–4 pro Seite"


func _refresh_cards() -> void:
    super._refresh_cards()

    var active_id: String = str(selected_actor.get("id", "")) if not selected_actor.is_empty() else ""

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var combatant_id: String = str(combatant.get("id", ""))
        var ui_value: Variant = cards.get(combatant_id, {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value

        var card: Control = ui.get("card") as Control
        if card == null or card.get_parent() == null:
            continue

        var shadow: Polygon2D = card.get_parent().get_node_or_null("SpriteShadow_" + combatant_id) as Polygon2D
        if shadow == null:
            continue

        var alive: bool = bool(combatant.get("alive", false))
        var active: bool = combatant_id == active_id
        var target_count: int = _incoming_target_count(combatant)

        if not alive:
            shadow.color = ROSTER_SHADOW_FAINTED
        elif active:
            # Warm amber, matching the active card border and connector, but
            # translucent enough to remain a ground cue rather than a glow.
            shadow.color = ROSTER_SHADOW_ACTIVE
        elif target_count > 0:
            # Aggro target: clearly red, again deliberately softer than the
            # card outline so multiple highlighted Pokemon do not become noisy.
            shadow.color = ROSTER_SHADOW_TARGET
        else:
            shadow.color = ROSTER_SHADOW_DEFAULT
