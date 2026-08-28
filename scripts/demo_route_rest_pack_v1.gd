extends "res://scripts/demo_route_gen3_legendary_endgame_v1.gd"

# Poké-Rastpaket
#
# After every completed milestone stage ending in 5 (5..95), the active
# adventure receives one stackable full-team rest pack. Rewards are committed
# exactly on the transition into the next stage. The claimed-stage list makes
# repeated redraws, save/load resumes and duplicate transition calls harmless.
# Both regular variables are persisted automatically by RunSaveManager.

const REST_PACK_REWARD_STAGES: Array[int] = [5, 15, 25, 35, 45, 55, 65, 75, 85, 95]

var rest_pack_count: int = 0
var rest_pack_claimed_stages: Array = []

var _rest_pack_panel: PanelContainer
var _rest_pack_count_label: Label
var _rest_pack_use_button: Button


func _ready() -> void:
    super._ready()
    _build_rest_pack_ui()
    _refresh_rest_pack_ui()


func start_route() -> void:
    # A genuinely new adventure always starts without carried-over packs.
    # Saved adventures restore these values through RunSaveManager instead.
    rest_pack_count = 0
    rest_pack_claimed_stages.clear()
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    # Stage N+1 can only be reached after stage N was successfully completed.
    # Grant before super so the inherited stage-checkpoint autosave already
    # contains the reward. A redraw of the same stage cannot grant it twice.
    var completed_stage: int = stage - 1
    if _grant_rest_pack_for_completed_stage(completed_stage):
        var reward_text: String = (
            "[b]🎒 Poké-Rastpaket erhalten![/b]\n"
            + "Du kannst dein Team damit jederzeit zwischen den Kämpfen vollständig heilen. "
            + "Bestand: [b]%d[/b]" % rest_pack_count
        )
        message = reward_text if message.is_empty() else message + "\n\n" + reward_text

    super._show_stage_choices(message)


func _refresh_team_panel() -> void:
    super._refresh_team_panel()
    _refresh_rest_pack_ui()


func _grant_rest_pack_for_completed_stage(completed_stage: int) -> bool:
    if not REST_PACK_REWARD_STAGES.has(completed_stage):
        return false
    if rest_pack_claimed_stages.has(completed_stage):
        return false

    rest_pack_claimed_stages.append(completed_stage)
    rest_pack_count += 1
    return true


func _build_rest_pack_ui() -> void:
    if storage_label == null or not is_instance_valid(storage_label):
        return
    if _rest_pack_panel != null and is_instance_valid(_rest_pack_panel):
        return

    var team_content: Node = storage_label.get_parent()
    if team_content == null:
        return

    _rest_pack_panel = PanelContainer.new()
    _rest_pack_panel.name = "RestPackPanel"
    _rest_pack_panel.custom_minimum_size = Vector2(0.0, 48.0)
    _rest_pack_panel.add_theme_stylebox_override(
        "panel",
        _panel(Color("14261f"), Color("9a8740"), 6, 4.0)
    )
    team_content.add_child(_rest_pack_panel)
    team_content.move_child(_rest_pack_panel, storage_label.get_index())

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 2)
    _rest_pack_panel.add_child(content)

    _rest_pack_count_label = Label.new()
    _rest_pack_count_label.name = "RestPackCountLabel"
    _rest_pack_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _rest_pack_count_label.add_theme_font_size_override("font_size", 9)
    _rest_pack_count_label.add_theme_color_override("font_color", Color("f3dda0"))
    content.add_child(_rest_pack_count_label)

    _rest_pack_use_button = Button.new()
    _rest_pack_use_button.name = "RestPackUseButton"
    _rest_pack_use_button.text = "BENUTZEN"
    _rest_pack_use_button.custom_minimum_size = Vector2(0.0, 24.0)
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

    if rest_pack_count <= 0:
        _rest_pack_use_button.tooltip_text = "Du besitzt aktuell kein Poké-Rastpaket."
    elif not team_needs_healing:
        _rest_pack_use_button.tooltip_text = "Dein Team ist bereits vollständig geheilt."
    else:
        _rest_pack_use_button.tooltip_text = "Verbraucht 1 Poké-Rastpaket und heilt das gesamte Team vollständig."


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
