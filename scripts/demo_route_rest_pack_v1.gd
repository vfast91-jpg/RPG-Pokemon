extends "res://scripts/demo_route_gen3_legendary_endgame_v1.gd"

# Poké-Rastpaket
#
# When the player commits to a path into a milestone stage ending in 5 (5..95),
# the active adventure receives one stackable full-team rest pack. Merely opening
# the milestone's route-choice screen is not enough. The claimed-stage list makes
# repeated clicks, save/load resumes and duplicate transition calls harmless. The
# visual popup is transient and deliberately excluded from run saves.

const REST_PACK_REWARD_STAGES: Array[int] = [5, 15, 25, 35, 45, 55, 65, 75, 85, 95]
const REST_PACK_TOOLTIP: String = "Heilt dein gesamtes Team vollständig und entfernt Statusprobleme. Verbraucht 1 Poké-Rastpaket."

var rest_pack_count: int = 0
var rest_pack_claimed_stages: Array = []

var _rest_pack_panel: PanelContainer
var _rest_pack_count_label: Label
var _rest_pack_use_button: Button
var _rest_pack_footer_spacer: Control

# RunSaveManager intentionally ignores members beginning with _run_save_. These
# values describe only the currently visible notification and must never make a
# dismissed reward window reappear after loading a checkpoint.
var _run_save_rest_pack_reward_popup_queue: Array[int] = []
var _run_save_rest_pack_reward_overlay: Control
var _run_save_rest_pack_reward_popup_pending: bool = false


func _ready() -> void:
    super._ready()
    _build_rest_pack_ui()
    _refresh_rest_pack_ui()


func start_route() -> void:
    # A genuinely new adventure always starts without carried-over packs.
    # Saved adventures restore the persistent values through RunSaveManager
    # instead of calling start_route().
    rest_pack_count = 0
    rest_pack_claimed_stages.clear()
    _reset_rest_pack_reward_popup_state()
    super.start_route()


func _choose_path(choice: Dictionary) -> void:
    # The currently displayed stage begins only when the player actually commits
    # to one of its route choices. This keeps milestone rewards out of the choice
    # screen itself while still committing them before any inherited path autosave.
    _award_rest_pack_for_completed_stage(stage)
    super._choose_path(choice)


func _refresh_team_panel() -> void:
    super._refresh_team_panel()
    _refresh_rest_pack_ui()


func _award_rest_pack_for_completed_stage(completed_stage: int) -> bool:
    if not _grant_rest_pack_for_completed_stage(completed_stage):
        return false

    _schedule_rest_pack_reward_popup(completed_stage)
    return true


func _grant_rest_pack_for_completed_stage(completed_stage: int) -> bool:
    if not REST_PACK_REWARD_STAGES.has(completed_stage):
        return false
    if rest_pack_claimed_stages.has(completed_stage):
        return false

    rest_pack_claimed_stages.append(completed_stage)
    rest_pack_count += 1
    return true


func _schedule_rest_pack_reward_popup(completed_stage: int) -> void:
    _run_save_rest_pack_reward_popup_queue.append(completed_stage)
    _run_save_rest_pack_reward_popup_pending = true
    call_deferred("_try_show_rest_pack_reward_popup")


func _on_levelup_continue() -> void:
    super._on_levelup_continue()
    if _run_save_rest_pack_reward_popup_pending:
        call_deferred("_try_show_rest_pack_reward_popup")


func _dismiss_campfire_unlock_popup() -> void:
    super._dismiss_campfire_unlock_popup()
    if _run_save_rest_pack_reward_popup_pending:
        call_deferred("_try_show_rest_pack_reward_popup")


func _dismiss_companion_departure_popup() -> void:
    super._dismiss_companion_departure_popup()
    if _run_save_rest_pack_reward_popup_pending:
        call_deferred("_try_show_rest_pack_reward_popup")


func _try_show_rest_pack_reward_popup() -> void:
    if not _run_save_rest_pack_reward_popup_pending:
        return
    if _run_save_rest_pack_reward_popup_queue.is_empty():
        _run_save_rest_pack_reward_popup_pending = false
        return
    if not visible:
        return
    if (
        _run_save_rest_pack_reward_overlay != null
        and is_instance_valid(_run_save_rest_pack_reward_overlay)
    ):
        return

    # Existing post-battle presentations always get precedence. The rest-pack
    # popup retries when those windows are dismissed instead of overlapping them.
    if _levelup_presentation_pending():
        return
    if _campfire_unlock_popup_pending:
        return
    if _campfire_unlock_overlay != null and is_instance_valid(_campfire_unlock_overlay):
        return
    if _companion_departure_popup_pending:
        return
    if _companion_departure_overlay != null and is_instance_valid(_companion_departure_overlay):
        return

    _run_save_rest_pack_reward_popup_pending = false
    var completed_stage: int = _run_save_rest_pack_reward_popup_queue.pop_front()
    _show_rest_pack_reward_popup(completed_stage)


func _show_rest_pack_reward_popup(completed_stage: int) -> void:
    var overlay: Control = _build_rest_pack_reward_overlay(completed_stage)
    _run_save_rest_pack_reward_overlay = overlay
    overlay.visible = true


func _build_rest_pack_reward_overlay(completed_stage: int) -> Control:
    var overlay := ColorRect.new()
    overlay.name = "RestPackRewardOverlay"
    overlay.color = Color("07100de0")
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 130
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(470.0, 0.0)
    card.add_theme_stylebox_override("panel", _rest_pack_reward_card_style())
    center.add_child(card)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    card.add_child(content)

    var eyebrow := Label.new()
    eyebrow.text = "ETAPPE %d ERREICHT · BELOHNUNG" % completed_stage
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", Color("e0c968"))
    content.add_child(eyebrow)

    var title := Label.new()
    title.text = "🎒  Poké-Rastpaket erhalten!"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 19)
    title.add_theme_color_override("font_color", Color("fff0ad"))
    content.add_child(title)

    var intro := Label.new()
    intro.text = "Für deinen weiteren Weg erhältst du 1 Poké-Rastpaket."
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.add_theme_font_size_override("font_size", 11)
    intro.add_theme_color_override("font_color", Color("dce8e2"))
    content.add_child(intro)

    var feature := PanelContainer.new()
    feature.add_theme_stylebox_override(
        "panel",
        _panel(Color("182822"), Color("55796a"), 8, 9.0)
    )
    content.add_child(feature)

    var feature_row := HBoxContainer.new()
    feature_row.add_theme_constant_override("separation", 10)
    feature.add_child(feature_row)

    var icon := Label.new()
    icon.text = "💚"
    icon.custom_minimum_size = Vector2(34.0, 34.0)
    icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    icon.add_theme_font_size_override("font_size", 22)
    feature_row.add_child(icon)

    var feature_copy := VBoxContainer.new()
    feature_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    feature_copy.add_theme_constant_override("separation", 2)
    feature_row.add_child(feature_copy)

    var feature_title := Label.new()
    feature_title.text = "Vollständige Teamheilung"
    feature_title.add_theme_font_size_override("font_size", 13)
    feature_title.add_theme_color_override("font_color", Color("9fe7bd"))
    feature_copy.add_child(feature_title)

    var feature_text := Label.new()
    feature_text.text = (
        "Heilt dein gesamtes Team vollständig und entfernt Statusprobleme. "
        + "Nicht benutzte Rastpakete bleiben erhalten und stapeln sich."
    )
    feature_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feature_text.add_theme_font_size_override("font_size", 10)
    feature_text.add_theme_color_override("font_color", Color("dce8e2"))
    feature_copy.add_child(feature_text)

    var stock := Label.new()
    stock.text = "Aktueller Bestand:  ×%d" % rest_pack_count
    stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stock.add_theme_font_size_override("font_size", 11)
    stock.add_theme_color_override("font_color", Color("f1dda0"))
    content.add_child(stock)

    var continue_reward := Button.new()
    continue_reward.text = "WEITER  →"
    continue_reward.custom_minimum_size = Vector2(0.0, 36.0)
    continue_reward.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    continue_reward.pressed.connect(_dismiss_rest_pack_reward_popup)
    _style_route_decision_button(continue_reward, true)
    content.add_child(continue_reward)
    continue_reward.call_deferred("grab_focus")

    return overlay


func _rest_pack_reward_card_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = _panel(Color("12251f"), Color("e0c968"), 12, 16.0)
    style.set_border_width_all(2)
    style.shadow_color = Color("00000099")
    style.shadow_size = 10
    return style


func _dismiss_rest_pack_reward_popup() -> void:
    if (
        _run_save_rest_pack_reward_overlay != null
        and is_instance_valid(_run_save_rest_pack_reward_overlay)
    ):
        _run_save_rest_pack_reward_overlay.queue_free()
    _run_save_rest_pack_reward_overlay = null

    if not _run_save_rest_pack_reward_popup_queue.is_empty():
        _run_save_rest_pack_reward_popup_pending = true
        call_deferred("_try_show_rest_pack_reward_popup")


func _reset_rest_pack_reward_popup_state() -> void:
    _run_save_rest_pack_reward_popup_queue.clear()
    _run_save_rest_pack_reward_popup_pending = false
    if (
        _run_save_rest_pack_reward_overlay != null
        and is_instance_valid(_run_save_rest_pack_reward_overlay)
    ):
        _run_save_rest_pack_reward_overlay.queue_free()
    _run_save_rest_pack_reward_overlay = null


func _build_rest_pack_ui() -> void:
    if team_box == null or not is_instance_valid(team_box):
        return
    if _rest_pack_panel != null and is_instance_valid(_rest_pack_panel):
        return

    # Keep the complete TEAM panel exclusively for Pokemon cards. The route's
    # footer already sits directly below both main columns, so its right edge is
    # the natural home for a small team-wide consumable. HAUPTMENÜ stays in the
    # same footer but moves to the left; the expanding spacer aligns the pack
    # directly below the right TEAM column without stealing one pixel from it.
    var team_scroll_node: Node = team_box.get_parent()
    if team_scroll_node == null:
        return
    var team_content_node: Node = team_scroll_node.get_parent()
    if team_content_node == null:
        return
    var team_panel_node: Node = team_content_node.get_parent()
    if team_panel_node == null:
        return
    var columns_node: Node = team_panel_node.get_parent()
    if columns_node == null:
        return
    var outer_node: Node = columns_node.get_parent()
    if outer_node == null:
        return

    var footer: HBoxContainer = null
    for child: Node in outer_node.get_children():
        if child is HBoxContainer and child != columns_node and child.get_index() > columns_node.get_index():
            footer = child as HBoxContainer
            break
    if footer == null:
        return

    footer.alignment = BoxContainer.ALIGNMENT_BEGIN

    _rest_pack_footer_spacer = Control.new()
    _rest_pack_footer_spacer.name = "RestPackFooterSpacer"
    _rest_pack_footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _rest_pack_footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footer.add_child(_rest_pack_footer_spacer)

    _rest_pack_panel = PanelContainer.new()
    _rest_pack_panel.name = "RestPackPanel"
    _rest_pack_panel.custom_minimum_size = Vector2(178.0, 26.0)
    _rest_pack_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
    _rest_pack_panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("13231e"), Color("64705b"), 6, 2.0)
    )
    footer.add_child(_rest_pack_panel)

    var content := HBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    _rest_pack_panel.add_child(content)

    _rest_pack_count_label = Label.new()
    _rest_pack_count_label.name = "RestPackCountLabel"
    _rest_pack_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _rest_pack_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _rest_pack_count_label.add_theme_font_size_override("font_size", 8)
    _rest_pack_count_label.add_theme_color_override("font_color", Color("f1dda0"))
    _rest_pack_count_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    content.add_child(_rest_pack_count_label)

    _rest_pack_use_button = Button.new()
    _rest_pack_use_button.name = "RestPackUseButton"
    _rest_pack_use_button.text = "HEILEN"
    _rest_pack_use_button.custom_minimum_size = Vector2(52.0, 20.0)
    _rest_pack_use_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    _rest_pack_use_button.add_theme_font_size_override("font_size", 8)
    _rest_pack_use_button.pressed.connect(_use_rest_pack)
    content.add_child(_rest_pack_use_button)


func _refresh_rest_pack_ui() -> void:
    if _rest_pack_count_label == null or not is_instance_valid(_rest_pack_count_label):
        return
    if _rest_pack_use_button == null or not is_instance_valid(_rest_pack_use_button):
        return

    _rest_pack_count_label.text = "🎒 Poké-Rastpaket ×%d" % rest_pack_count

    var team_needs_healing: bool = _team_needs_rest_pack()
    _rest_pack_use_button.disabled = rest_pack_count <= 0 or not team_needs_healing

    var tooltip: String = REST_PACK_TOOLTIP
    if rest_pack_count <= 0:
        tooltip += "\nAktuell ist kein Rastpaket verfügbar."
    elif not team_needs_healing:
        tooltip += "\nDein Team ist bereits vollständig geheilt."

    _rest_pack_count_label.tooltip_text = tooltip
    _rest_pack_use_button.tooltip_text = tooltip
    if _rest_pack_panel != null and is_instance_valid(_rest_pack_panel):
        _rest_pack_panel.tooltip_text = tooltip


func _team_needs_rest_pack() -> bool:
    for member_value: Variant in team:
        if not (member_value is Dictionary):
            continue

        var member: Dictionary = member_value as Dictionary
        var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
        if int(member.get("hp", 0)) < max_hp:
            return true
        if not str(member.get("major_status", "")).is_empty():
            return true

    return false


func _use_rest_pack() -> void:
    if rest_pack_count <= 0 or not _team_needs_rest_pack():
        _refresh_rest_pack_ui()
        return

    # Reuse the route's one canonical full-heal implementation. This keeps the
    # pack in lockstep with Heilquelle and every future change to full healing.
    _heal_team()
    AudioManager.play_heal_sfx()
    rest_pack_count = maxi(0, rest_pack_count - 1)

    var result_text: String = (
        "[b]🎒 Poké-Rastpaket benutzt![/b]\n"
        + "Dein gesamtes Team wurde vollständig geheilt. "
        + "Verbleibend: [b]%d[/b]" % rest_pack_count
    )
    last_route_message = result_text
    if event_label != null and is_instance_valid(event_label):
        event_label.text = result_text

    _refresh_team_panel()
    _autosave_run("team_change")
