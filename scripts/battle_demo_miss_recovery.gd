extends "res://scripts/battle_demo_bulbasaur_tm_runtime_audit.gd"

# Timeflow miss compensation.
# A missed move keeps its normal AP/ATB recovery calculation, then receives a
# 25% recovery bonus. The inherited base currently applies a 15% miss bonus;
# this final layer converts that existing result from x0.85 to the desired x0.75
# without discarding any other recovery multipliers that were already applied.

const MISS_ATB_RECOVERY_MULTIPLIER: float = 0.75
const INHERITED_MISS_ATB_RECOVERY_MULTIPLIER: float = 0.85

var _miss_detection_stack: Array[bool] = []


func _build_battle(root: Control) -> void:
    super._build_battle(root)

    # The framed weather bar introduced a PanelContainer whose minimum-size
    # negotiation can stretch the timeline far beyond its intended compact lane.
    # Put the ProgressBar back directly on the battle panel so its geometry is
    # controlled only by these fixed center offsets at every window scale.
    if weather_bar == null or battle_panel == null:
        return

    if weather_bar.get_parent() != battle_panel:
        weather_bar.reparent(battle_panel, false)

    if weather_bar_frame != null:
        weather_bar_frame.queue_free()
        weather_bar_frame = null

    weather_bar.anchor_left = 0.5
    weather_bar.anchor_right = 0.5
    weather_bar.offset_left = -48.0
    weather_bar.offset_top = 47.0
    weather_bar.offset_right = 48.0
    weather_bar.offset_bottom = 54.0
    weather_bar.custom_minimum_size = Vector2.ZERO
    weather_bar.z_index = 150

    var background: StyleBoxFlat = StyleBoxFlat.new()
    background.bg_color = WEATHER_BAR_BACKGROUND
    background.border_color = WEATHER_BAR_BORDER
    background.set_border_width_all(1)
    background.set_corner_radius_all(3)
    weather_bar.add_theme_stylebox_override("background", background)

    weather_bar.visible = battle_weather.is_active()


func _execute_move(actor: Dictionary, move_id: String) -> void:
    _miss_detection_stack.append(false)
    super._execute_move(actor, move_id)

    var missed: bool = false
    if not _miss_detection_stack.is_empty():
        missed = bool(_miss_detection_stack.pop_back())

    if not missed:
        return

    actor["cycle"] = (
        float(actor.get("cycle", 1.0))
        * MISS_ATB_RECOVERY_MULTIPLIER
        / INHERITED_MISS_ATB_RECOVERY_MULTIPLIER
    )
    _refresh_cards()


func _set_log(text: String) -> void:
    if (
        not _miss_detection_stack.is_empty()
        and text.contains(" verfehlt mit ")
    ):
        _miss_detection_stack[_miss_detection_stack.size() - 1] = true

    super._set_log(text)
