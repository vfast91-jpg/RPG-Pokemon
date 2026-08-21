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

    # The weather ProgressBar was sitting inside a taller PanelContainer, so the
    # grey frame looked normal while the actual blue fill was rendered as only a
    # very thin strip. Keep the real ProgressBar directly on the battle panel and
    # give background and fill the exact same fixed height.
    if weather_bar == null or battle_panel == null:
        return

    if weather_bar.get_parent() != battle_panel:
        weather_bar.reparent(battle_panel, false)

    if weather_bar_frame != null:
        weather_bar_frame.queue_free()
        weather_bar_frame = null

    weather_bar.anchor_left = 0.5
    weather_bar.anchor_right = 0.5
    weather_bar.offset_left = -49.0
    weather_bar.offset_top = 47.0
    weather_bar.offset_right = 49.0
    weather_bar.offset_bottom = 56.0
    weather_bar.custom_minimum_size = Vector2(98.0, 9.0)
    weather_bar.z_index = 150

    var background: StyleBoxFlat = StyleBoxFlat.new()
    background.bg_color = WEATHER_BAR_BACKGROUND
    background.border_color = WEATHER_BAR_BORDER
    background.set_border_width_all(1)
    background.set_corner_radius_all(3)
    weather_bar.add_theme_stylebox_override("background", background)

    var fill: StyleBoxFlat = StyleBoxFlat.new()
    fill.bg_color = WEATHER_ATB_BLUE
    fill.set_corner_radius_all(3)
    weather_bar.add_theme_stylebox_override("fill", fill)

    weather_bar.visible = battle_weather.is_active()


func _compact_effect_summary(move: Dictionary) -> String:
    var summary: String = super._compact_effect_summary(move)
    var runtime_value: Variant = move.get("runtime", {})
    if not (runtime_value is Dictionary):
        return summary

    var runtime: Dictionary = runtime_value
    var sequence_value: Variant = runtime.get("forced_sequence", null)
    if not (sequence_value is Dictionary):
        return summary

    var sequence: Dictionary = sequence_value
    var minimum: int = maxi(1, int(sequence.get("min", 1)))
    var maximum: int = maxi(minimum, int(sequence.get("max", minimum)))
    var duration_text: String = str(minimum)
    if maximum != minimum:
        duration_text += "–" + str(maximum)

    var sequence_text: String = (
        duration_text
        + " eigene Aktion"
        + ("" if maximum == 1 else "en")
        + ": Attacke wird automatisch fortgesetzt"
    )
    if bool(sequence.get("confuse_after", false)):
        sequence_text += " · danach Verwirrung"

    if summary.is_empty():
        return sequence_text
    return summary + " · " + sequence_text


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


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var tokens: Array[String] = super._status_tokens(combatant)
    if str(combatant.get("major_status", "")) != "sleep":
        return tokens

    # Schlaf war bereits mechanisch aktiv, wurde aber in den persistenten
    # Statusanzeigen nicht dargestellt. Zeige zusätzlich die noch verbleibenden
    # eigenen Aktionsmöglichkeiten, damit Erholung jederzeit nachvollziehbar ist.
    for token: String in tokens:
        if token.contains("SCHLAF"):
            return tokens

    var remaining: int = maxi(0, int(combatant.get("db_sleep_actions", 0)))
    var sleep_token: String = "💤 SCHLAF"
    if remaining > 0:
        sleep_token += " " + str(remaining)
    tokens.append(sleep_token)
    return tokens


func _detail_info(combatant: Dictionary) -> String:
    var detail: String = super._detail_info(combatant)
    if str(combatant.get("major_status", "")) != "sleep":
        return detail
    if detail.contains("💤 Schlaf:"):
        return detail

    var remaining: int = maxi(0, int(combatant.get("db_sleep_actions", 0)))
    var duration_text: String = (
        str(remaining) + " eigene Aktionsmöglichkeit"
        + ("" if remaining == 1 else "en")
    )
    return (
        detail
        + "\n\n[b]HAUPTSTATUS[/b]\n"
        + "• 💤 Schlaf: noch " + duration_text
        + "; normale Aktionen werden verschlafen."
    )
