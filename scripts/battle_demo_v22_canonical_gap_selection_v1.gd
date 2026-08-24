extends "res://scripts/battle_demo_v22_canonical_gap_fill_v1.gd"

# Player-facing integration for Heilopfer.
# The canonical rule requires one OTHER active ally to be selected. The older
# combat stack already has several move-specific ally selectors, so keep this
# V22 addition local instead of changing their historical labels/behavior.
#
# Paralyse is also represented by a dedicated boolean in parts of the current
# runtime. Treat that boolean as a major status for Heilopfer even when the
# generic major_status string is empty.

var _v22_gap_healing_wish_selected_id: String = ""
var _v22_gap_healing_wish_pending_actor: Dictionary = {}


func _start_battle() -> void:
    _v22_gap_reset_healing_wish_selection()
    super._start_battle()


func open_config() -> void:
    _v22_gap_reset_healing_wish_selection()
    super.open_config()


func _v22_gap_reset_healing_wish_selection() -> void:
    _v22_gap_healing_wish_selected_id = ""
    _v22_gap_healing_wish_pending_actor = {}


func _choose_move(move_id: String) -> void:
    if move_id != "healing_wish":
        super._choose_move(move_id)
        return
    if selected_actor.is_empty():
        return

    var actor: Dictionary = selected_actor
    var allies: Array = _v22_gap_living_other_allies(actor)
    if allies.is_empty():
        _set_log("[b]Heilopfer[/b]: Kein anderer aktiver Verbündeter als Ziel verfügbar.")
        _spawn_feedback_label(actor, "✨ KEIN VERBÜNDETER", Color("d9a5a5"))
        return

    if allies.size() == 1:
        _v22_gap_healing_wish_selected_id = str((allies[0] as Dictionary).get("id", ""))
        super._choose_move(move_id)
        return

    _v22_gap_healing_wish_pending_actor = actor
    _clear_actions()
    _set_log("[b]Heilopfer[/b]: Verbündetes Pokémon wählen.")

    for ally_value: Variant in allies:
        if not (ally_value is Dictionary):
            continue
        var ally: Dictionary = ally_value
        var button := Button.new()
        button.text = "✨ " + _actor_name(ally)
        button.tooltip_text = "Diesen aktiven Verbündeten mit Heilopfer unterstützen"
        button.pressed.connect(
            _v22_gap_choose_healing_wish_target.bind(str(ally.get("id", "")))
        )
        action_grid.add_child(button)

    var back := Button.new()
    back.text = "↩ Zurück"
    back.pressed.connect(_v22_gap_cancel_healing_wish_target)
    action_grid.add_child(back)


func _v22_gap_choose_healing_wish_target(target_id: String) -> void:
    if _v22_gap_healing_wish_pending_actor.is_empty() or target_id.is_empty():
        return
    var actor: Dictionary = _v22_gap_healing_wish_pending_actor
    _v22_gap_healing_wish_pending_actor = {}
    _v22_gap_healing_wish_selected_id = target_id
    selected_actor = actor
    super._choose_move("healing_wish")


func _v22_gap_cancel_healing_wish_target() -> void:
    if _v22_gap_healing_wish_pending_actor.is_empty():
        return
    var actor: Dictionary = _v22_gap_healing_wish_pending_actor
    _v22_gap_healing_wish_pending_actor = {}
    _v22_gap_healing_wish_selected_id = ""
    selected_actor = actor
    _prompt_player(actor)


func _v22_gap_living_other_allies(actor: Dictionary) -> Array:
    var result: Array = []
    var actor_id: String = str(actor.get("id", ""))
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if (
            bool(candidate.get("alive", false))
            and str(candidate.get("id", "")) != actor_id
        ):
            result.append(candidate)
    return result


func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == "single_ally" and not _v22_gap_healing_wish_selected_id.is_empty():
        var selected: Dictionary = _zf_find_combatant(_v22_gap_healing_wish_selected_id)
        if (
            not selected.is_empty()
            and bool(selected.get("alive", false))
            and str(selected.get("side", "")) == str(actor.get("side", ""))
            and str(selected.get("id", "")) != str(actor.get("id", ""))
        ):
            return [selected]
    return super._targets(actor, rule)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    super._execute_move(actor, move_id)
    if move_id == "healing_wish":
        _v22_gap_healing_wish_selected_id = ""
        _v22_gap_healing_wish_pending_actor = {}


func _v22_gap_healing_wish(actor: Dictionary, target: Dictionary) -> float:
    var valid_target: bool = (
        not target.is_empty()
        and bool(target.get("alive", false))
        and str(target.get("side", "")) == str(actor.get("side", ""))
        and str(target.get("id", "")) != str(actor.get("id", ""))
    )
    var had_separate_paralysis: bool = valid_target and bool(target.get("paralyzed", false))

    var effect_aggro: float = super._v22_gap_healing_wish(actor, target)

    # If major_status itself described the condition, the parent method already
    # cleared the paralysis flag together with it. Only the separate legacy form
    # reaches this branch.
    if had_separate_paralysis and bool(target.get("paralyzed", false)):
        target["paralyzed"] = false
        _v22_gap_healing_wish_succeeded = true
        _spawn_feedback_label(target, "✨ STATUS GEHEILT", Color("b9e2a8"))
        effect_aggro += float(target.get("max_hp", 1)) * F30_STATUS_CONTROL_HP_FRACTION

    return effect_aggro
