extends CanvasLayer

const TYPE_FEEDBACK_HOLD_SECONDS: float = 2.0
const ACTION_FEEDBACK_HOLD_SECONDS: float = 1.25

const ACTOR_COLOR: Color = Color("ffd85a")
const NEGATIVE_COLOR: Color = Color("ff665c")
const POSITIVE_COLOR: Color = Color("62df91")

var feedback_panel: PanelContainer
var feedback_header: Label
var feedback_label: Label
var ap_hint_panel: PanelContainer
var ap_hint_label: Label

var observed_demo: CanvasLayer
var last_log_text: String = ""
var feedback_time_left: float = 0.0
var action_time_left: float = 0.0
var restore_demo_processing: bool = false
var combatant_snapshot: Dictionary = {}
var action_markers: Array[Dictionary] = []

func _ready() -> void:
    layer = 80
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()

func _process(delta: float) -> void:
    var demo: CanvasLayer = _find_battle_demo()
    if demo == null or not demo.visible:
        last_log_text = ""
        combatant_snapshot.clear()
        ap_hint_panel.visible = false
        _cancel_type_feedback()
        _clear_action_feedback()
        return

    observed_demo = demo
    _format_move_buttons_and_ap_help(demo)
    _sync_action_markers()

    var log_variant: Variant = demo.get("log_label")
    if log_variant is RichTextLabel:
        var current_text: String = str((log_variant as RichTextLabel).text)
        if current_text != last_log_text:
            var changes: Dictionary = _detect_action_changes(demo)
            last_log_text = current_text
            _show_action_feedback(demo, current_text, changes)

            var feedback: Dictionary = _feedback_from_log(current_text)
            if not feedback.is_empty():
                var accent: Color = feedback.get("color", Color.WHITE)
                _show_type_feedback(demo, str(feedback.get("text", "")), accent)

    _capture_snapshot(demo)

    if action_time_left > 0.0:
        action_time_left -= delta
        if action_time_left <= 0.0:
            _clear_action_feedback()

    if feedback_time_left > 0.0:
        feedback_time_left -= delta
        if feedback_time_left <= 0.0:
            _finish_type_feedback()

func _find_battle_demo() -> CanvasLayer:
    var node: Node = get_tree().root.find_child("BattleDemo", true, false)
    if node is CanvasLayer:
        return node as CanvasLayer
    return null

func _format_move_buttons_and_ap_help(demo: CanvasLayer) -> void:
    var buttons_variant: Variant = demo.get("move_buttons")
    var data_variant: Variant = demo.get("data")
    if not (buttons_variant is Array) or not (data_variant is Dictionary):
        ap_hint_panel.visible = false
        return

    var buttons: Array = buttons_variant
    var battle_data: Dictionary = data_variant
    var moves: Dictionary = battle_data.get("moves", {})
    var any_enabled: bool = false

    for button_variant: Variant in buttons:
        if not (button_variant is Button):
            continue
        var button: Button = button_variant
        if not button.disabled:
            any_enabled = true

        var matched_move: Dictionary = {}
        for move_key: Variant in moves.keys():
            var move_variant: Variant = moves.get(move_key, {})
            if not (move_variant is Dictionary):
                continue
            var move: Dictionary = move_variant
            var move_name: String = str(move.get("name", move_key))
            if button.text.begins_with(move_name):
                matched_move = move
                break

        if matched_move.is_empty():
            continue

        var ap: int = int(matched_move.get("ap_cost", 1))
        var display_name: String = str(matched_move.get("name", "Attacke"))
        button.text = display_name + "  AP " + str(ap)
        button.tooltip_text = _ap_tooltip(battle_data, ap)

    ap_hint_panel.visible = any_enabled

func _ap_tooltip(battle_data: Dictionary, ap: int) -> String:
    var rules: Dictionary = battle_data.get("rules", {})
    var ap_rules: Dictionary = rules.get("ap_costs_demo", {})
    var curve: Dictionary = ap_rules.get("demo_atb_cycle_multiplier", {})
    var multiplier: float = float(curve.get(str(ap), 1.0))

    if multiplier <= 1.001:
        return "AP %d: keine zusätzliche ATB-Verlangsamung.\nAP werden nicht verbraucht." % ap

    var extra_percent: int = int(round((multiplier - 1.0) * 100.0))
    return "AP %d: nächster ATB-Zyklus ca. %d %% länger als bei AP 1.\nAP werden nicht verbraucht." % [ap, extra_percent]

func _combatants(demo: CanvasLayer) -> Array:
    var combatants_variant: Variant = demo.get("combatants")
    if combatants_variant is Array:
        return combatants_variant
    return []

func _capture_snapshot(demo: CanvasLayer) -> void:
    var next_snapshot: Dictionary = {}
    for combatant_variant: Variant in _combatants(demo):
        if not (combatant_variant is Dictionary):
            continue
        var combatant: Dictionary = combatant_variant
        var id: String = str(combatant.get("id", ""))
        if id.is_empty():
            continue
        next_snapshot[id] = {
            "hp": int(combatant.get("hp", 0)),
            "attack_stage": int(combatant.get("attack_stage", 0)),
            "paralyzed": bool(combatant.get("paralyzed", false)),
            "atb": float(combatant.get("atb", 0.0)),
            "alive": bool(combatant.get("alive", false))
        }
    combatant_snapshot = next_snapshot

func _detect_action_changes(demo: CanvasLayer) -> Dictionary:
    var result: Dictionary = {
        "actor": {},
        "targets": []
    }

    for combatant_variant: Variant in _combatants(demo):
        if not (combatant_variant is Dictionary):
            continue
        var combatant: Dictionary = combatant_variant
        var id: String = str(combatant.get("id", ""))
        if id.is_empty() or not combatant_snapshot.has(id):
            continue

        var previous: Dictionary = combatant_snapshot[id]
        var old_atb: float = float(previous.get("atb", 0.0))
        var new_atb: float = float(combatant.get("atb", 0.0))
        if old_atb >= 80.0 and new_atb <= 10.0 and old_atb - new_atb >= 60.0:
            result["actor"] = combatant

        var effect_kind: String = ""
        var old_hp: int = int(previous.get("hp", 0))
        var new_hp: int = int(combatant.get("hp", 0))
        var old_stage: int = int(previous.get("attack_stage", 0))
        var new_stage: int = int(combatant.get("attack_stage", 0))
        var was_paralyzed: bool = bool(previous.get("paralyzed", false))
        var is_paralyzed: bool = bool(combatant.get("paralyzed", false))
        var was_alive: bool = bool(previous.get("alive", true))
        var is_alive: bool = bool(combatant.get("alive", true))

        if new_hp < old_hp or new_stage < old_stage or (not was_paralyzed and is_paralyzed) or (was_alive and not is_alive):
            effect_kind = "negative"
        elif new_hp > old_hp or new_stage > old_stage:
            effect_kind = "positive"

        if not effect_kind.is_empty():
            var targets: Array = result["targets"]
            targets.append({
                "combatant": combatant,
                "effect": effect_kind
            })
            result["targets"] = targets

    return result

func _show_action_feedback(demo: CanvasLayer, log_text: String, changes: Dictionary) -> void:
    var lower: String = log_text.to_lower()
    if not lower.contains("nutzt") and not lower.contains("setzt"):
        return

    _clear_action_feedback()

    var actor_variant: Variant = changes.get("actor", {})
    if actor_variant is Dictionary and not (actor_variant as Dictionary).is_empty():
        _mark_combatant(demo, actor_variant as Dictionary, "AKTION", ACTOR_COLOR)

    var targets_variant: Variant = changes.get("targets", [])
    if targets_variant is Array:
        for target_change_variant: Variant in targets_variant:
            if not (target_change_variant is Dictionary):
                continue
            var target_change: Dictionary = target_change_variant
            var combatant_variant: Variant = target_change.get("combatant", {})
            if not (combatant_variant is Dictionary):
                continue
            var effect_kind: String = str(target_change.get("effect", ""))
            if effect_kind == "positive":
                _mark_combatant(demo, combatant_variant as Dictionary, "POSITIV", POSITIVE_COLOR)
            elif effect_kind == "negative":
                _mark_combatant(demo, combatant_variant as Dictionary, "NEGATIV", NEGATIVE_COLOR)

    if not action_markers.is_empty():
        action_time_left = ACTION_FEEDBACK_HOLD_SECONDS

func _mark_combatant(demo: CanvasLayer, combatant: Dictionary, marker_text: String, accent: Color) -> void:
    var controls_variant: Variant = demo.get("team_controls")
    if not (controls_variant is Dictionary):
        return
    var controls: Dictionary = controls_variant
    var id: String = str(combatant.get("id", ""))
    var ui_variant: Variant = controls.get(id, {})
    if not (ui_variant is Dictionary):
        return
    var ui: Dictionary = ui_variant
    var card_variant: Variant = ui.get("card")
    if not (card_variant is Control):
        return

    var card: Control = card_variant
    var marker: Panel = Panel.new()
    marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    marker.add_theme_stylebox_override("panel", _marker_style(accent))
    add_child(marker)

    var tag: Label = Label.new()
    tag.text = marker_text
    tag.position = Vector2(4, -14)
    tag.size = Vector2(72, 14)
    tag.add_theme_font_size_override("font_size", 9)
    tag.add_theme_color_override("font_color", accent)
    tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
    tag.add_theme_constant_override("shadow_offset_x", 1)
    tag.add_theme_constant_override("shadow_offset_y", 1)
    marker.add_child(tag)

    action_markers.append({
        "marker": marker,
        "card": card
    })
    _sync_marker(marker, card)

func _sync_action_markers() -> void:
    for entry_variant: Variant in action_markers:
        if not (entry_variant is Dictionary):
            continue
        var entry: Dictionary = entry_variant
        var marker_variant: Variant = entry.get("marker")
        var card_variant: Variant = entry.get("card")
        if marker_variant is Control and card_variant is Control:
            _sync_marker(marker_variant as Control, card_variant as Control)

func _sync_marker(marker: Control, card: Control) -> void:
    if not is_instance_valid(marker) or not is_instance_valid(card):
        return
    var rect: Rect2 = card.get_global_rect()
    marker.position = rect.position - Vector2(2, 2)
    marker.size = rect.size + Vector2(4, 4)

func _clear_action_feedback() -> void:
    action_time_left = 0.0
    for entry_variant: Variant in action_markers:
        if not (entry_variant is Dictionary):
            continue
        var marker_variant: Variant = (entry_variant as Dictionary).get("marker")
        if marker_variant is Node and is_instance_valid(marker_variant):
            (marker_variant as Node).queue_free()
    action_markers.clear()

func _marker_style(accent: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0)
    style.border_color = accent
    style.set_border_width_all(3)
    style.set_corner_radius_all(6)
    return style

func _feedback_from_log(text: String) -> Dictionary:
    var lower: String = text.to_lower()

    if lower.contains("nicht sehr effektiv"):
        return {
            "text": "NICHT SEHR EFFEKTIV!",
            "color": Color("79b9ff")
        }
    if lower.contains("sehr effektiv"):
        return {
            "text": "SEHR EFFEKTIV!",
            "color": Color("ffd34f")
        }
    if lower.contains("keine wirkung"):
        return {
            "text": "KEINE WIRKUNG!",
            "color": Color("c9ced6")
        }
    return {}

func _show_type_feedback(demo: CanvasLayer, text: String, accent: Color) -> void:
    if observed_demo != null and observed_demo != demo and restore_demo_processing and is_instance_valid(observed_demo):
        observed_demo.set_process(true)

    observed_demo = demo
    restore_demo_processing = demo.is_processing()
    demo.set_process(false)

    feedback_time_left = TYPE_FEEDBACK_HOLD_SECONDS
    feedback_label.text = text
    feedback_label.add_theme_color_override("font_color", accent)
    feedback_header.add_theme_color_override("font_color", accent.lightened(0.2))
    feedback_panel.add_theme_stylebox_override("panel", _feedback_style(accent))
    feedback_panel.visible = true

func _finish_type_feedback() -> void:
    feedback_time_left = 0.0
    feedback_panel.visible = false

    if observed_demo != null and is_instance_valid(observed_demo) and restore_demo_processing:
        observed_demo.set_process(true)

    restore_demo_processing = false

func _cancel_type_feedback() -> void:
    if feedback_time_left <= 0.0 and (feedback_panel == null or not feedback_panel.visible):
        observed_demo = null
        restore_demo_processing = false
        return

    _finish_type_feedback()
    observed_demo = null

func _build_ui() -> void:
    feedback_panel = PanelContainer.new()
    feedback_panel.position = Vector2(92, 4)
    feedback_panel.size = Vector2(296, 48)
    feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_panel.visible = false
    add_child(feedback_panel)

    var content: VBoxContainer = VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 0)
    feedback_panel.add_child(content)

    feedback_header = Label.new()
    feedback_header.text = "TYPENWIRKUNG"
    feedback_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_header.add_theme_font_size_override("font_size", 9)
    content.add_child(feedback_header)

    feedback_label = Label.new()
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    feedback_label.add_theme_font_size_override("font_size", 18)
    feedback_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    feedback_label.add_theme_constant_override("shadow_offset_x", 2)
    feedback_label.add_theme_constant_override("shadow_offset_y", 2)
    content.add_child(feedback_label)

    ap_hint_panel = PanelContainer.new()
    ap_hint_panel.position = Vector2(20, 295)
    ap_hint_panel.size = Vector2(440, 18)
    ap_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ap_hint_panel.add_theme_stylebox_override("panel", _ap_hint_style())
    ap_hint_panel.visible = false
    add_child(ap_hint_panel)

    ap_hint_label = Label.new()
    ap_hint_label.text = "AP = Erholungszeit · AP 1 schnell · höhere AP = längerer nächster ATB-Zyklus · kein Verbrauch"
    ap_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ap_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ap_hint_label.add_theme_font_size_override("font_size", 8)
    ap_hint_label.add_theme_color_override("font_color", Color("e8e2c2"))
    ap_hint_panel.add_child(ap_hint_label)

func _feedback_style(accent: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.065, 0.075, 0.97)
    style.border_color = accent
    style.set_border_width_all(3)
    style.set_corner_radius_all(9)
    style.content_margin_left = 10.0
    style.content_margin_right = 10.0
    style.content_margin_top = 3.0
    style.content_margin_bottom = 3.0
    return style

func _ap_hint_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color("111a19e8")
    style.border_color = Color("7e8d76")
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 4.0
    style.content_margin_right = 4.0
    style.content_margin_top = 1.0
    style.content_margin_bottom = 1.0
    return style