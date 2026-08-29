extends "res://scripts/battle_demo_gen3_moves_v2.gd"

# Final boss residual-damage correction.
#
# Route bosses deliberately receive additional battle-only HP (normally 2x,
# endgame superbosses 4x). Those extra HP are survivability only: percentage
# damage-over-time must still be calculated from the Pokemon's unmultiplied HP.
# battle_demo_route_boss.gd already stores that exact pre-multiplier value in
# boss_base_max_hp, so this layer uses it directly instead of deriving the basis
# from visible HP bars or applying scattered /2 and /4 corrections.
#
# Covered shared residual systems:
# - burn and normal poison via _deal_periodic_damage
# - every binding move using the central binding mechanic (Wrap, Fire Spin,
#   Whirlpool, Sand Tomb, Bind, and future binding entries)
# - bad poison / Toxic
# - Leech Seed
# - Ghost Curse
#
# Confusion is intentionally untouched: its active self-hit formula is based on
# level/Attack/Defense, not max HP, so boss HP multipliers do not inflate it.

const BossResidualStatusEffects = preload("res://scripts/battle/status_effect_runtime.gd")
const ROUTE_SAVE_BOUNDARY_TEXT: String = "💾 Letzter Speicherpunkt: vor diesem Kampf · Beim Fortsetzen beginnt dieser Kampf erneut."

var _route_save_boundary_panel: PanelContainer = null


func _route_begin_wave() -> void:
    super._route_begin_wave()
    _sync_route_save_boundary_notice()


func _refresh_cards() -> void:
    super._refresh_cards()
    _sync_route_save_boundary_notice()


func _sync_route_save_boundary_notice() -> void:
    var should_show: bool = route_mode and battle_active
    if _route_save_boundary_panel == null or not is_instance_valid(_route_save_boundary_panel):
        if not should_show:
            return
        _route_save_boundary_panel = _create_route_save_boundary_notice()

    _route_save_boundary_panel.visible = should_show


func _create_route_save_boundary_notice() -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = "RouteSaveBoundaryNotice"
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.z_index = 200
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.offset_left = -330.0
    panel.offset_right = 330.0
    panel.offset_top = 12.0
    panel.offset_bottom = 62.0

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.035, 0.043, 0.065, 0.94)
    panel_style.border_color = Color(0.55, 0.72, 0.95, 0.72)
    panel_style.set_border_width_all(1)
    panel_style.corner_radius_top_left = 9
    panel_style.corner_radius_top_right = 9
    panel_style.corner_radius_bottom_left = 9
    panel_style.corner_radius_bottom_right = 9
    panel.add_theme_stylebox_override("panel", panel_style)

    var label := Label.new()
    label.name = "RouteSaveBoundaryText"
    label.text = ROUTE_SAVE_BOUNDARY_TEXT
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(label)

    add_child(panel)
    return panel


func _residual_damage_max_hp(combatant: Dictionary) -> int:
    var runtime_max_hp: int = maxi(1, int(combatant.get("max_hp", 1)))
    if not bool(combatant.get("boss", false)):
        return runtime_max_hp

    # Authoritative route-boss value: captured before the battle-only HP
    # multiplier is applied. This is exact for both 2x and 4x bosses.
    var stored_base_max_hp: int = int(combatant.get("boss_base_max_hp", 0))
    if stored_base_max_hp > 0:
        return stored_base_max_hp

    # Defensive compatibility for a boss object created by an older/custom
    # caller that carries the explicit multiplier but not the stored base value.
    var multiplier: float = maxf(1.0, float(combatant.get("boss_hp_multiplier", 1.0)))
    if multiplier > 1.000001:
        return maxi(1, int(round(float(runtime_max_hp) / multiplier)))

    return runtime_max_hp


func _deal_periodic_damage(combatant: Dictionary, fraction: float, label_text: String) -> int:
    var amount: int = maxi(
        1,
        int(floor(float(_residual_damage_max_hp(combatant)) * maxf(0.0, fraction)))
    )
    var actual: int = mini(amount, int(combatant.get("hp", 0)))
    if actual <= 0:
        return 0

    combatant["hp"] = maxi(0, int(combatant.get("hp", 0)) - actual)
    combatant["damage_since_last_action"] = true
    _spawn_feedback_label(combatant, label_text + " −" + str(actual), Color("ff9a83"))

    if int(combatant.get("hp", 0)) <= 0:
        combatant["alive"] = false
    return actual


func _tf_tick_bad_poison(target: Dictionary) -> int:
    var stage: int = clampi(
        int(target.get("tf_bad_poison_stage", 1)),
        1,
        TF_BAD_POISON_MAX_STAGE
    )
    var amount: int = maxi(
        1,
        int(
            floor(
                float(_residual_damage_max_hp(target))
                * float(stage)
                / 16.0
            )
        )
    )
    var actual: int = mini(amount, int(target.get("hp", 0)))
    if actual <= 0:
        return 0

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    target["tf_bad_poison_stage"] = mini(TF_BAD_POISON_MAX_STAGE, stage + 1)
    _spawn_feedback_label(target, "☠️ SCHWERES GIFT −" + str(actual), Color("bd86cf"))

    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false
    return actual


func _resolve_seed_tick(target: Dictionary) -> void:
    var seed_value: Variant = target.get("seed_effect", {})
    if not (seed_value is Dictionary) or (seed_value as Dictionary).is_empty():
        return
    var seed_effect: Dictionary = seed_value

    var source: Dictionary = _effect_source_occupant(seed_effect)
    if source.is_empty():
        return

    var fraction: float = float(seed_effect.get("damage_fraction", 1.0 / 8.0))
    var amount: int = maxi(
        1,
        int(floor(float(_residual_damage_max_hp(target)) * maxf(0.0, fraction)))
    )
    var actual: int = mini(amount, int(target.get("hp", 0)))
    if actual <= 0:
        return

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    _spawn_feedback_label(target, "🌱 EGELSAMEN −" + str(actual), Color("a9db82"))

    # Preserve the current Status-dependent Leech Seed healing exactly; only
    # the target-side damage basis above changes for bosses.
    var stored_ratio: float = float(seed_effect.get(
        "status_ratio",
        BossResidualStatusEffects.ratio(_status_value(source))
    ))
    var heal_fraction: float = clampf(2.0 * stored_ratio, 0.0, 1.0)
    var missing_hp: int = maxi(0, int(source.get("max_hp", 0)) - int(source.get("hp", 0)))
    var healed: int = mini(
        missing_hp,
        BossResidualStatusEffects.positive_int(float(actual) * heal_fraction)
    )
    if healed > 0:
        source["hp"] = int(source.get("hp", 0)) + healed
        _spawn_feedback_label(source, "🌱 +" + str(healed) + " KP", Color("8fe39b"))

    source["aggro"] = float(source.get("aggro", 0.0)) + float(actual + healed)

    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false


func _tf_tick_curse(target: Dictionary) -> int:
    var curse_value: Variant = target.get("tf_curse_effect", {})
    if not (curse_value is Dictionary) or (curse_value as Dictionary).is_empty():
        return 0

    var amount: int = maxi(
        1,
        int(floor(float(_residual_damage_max_hp(target)) * 0.25))
    )
    var actual: int = mini(amount, int(target.get("hp", 0)))
    if actual <= 0:
        return 0

    target["hp"] = maxi(0, int(target.get("hp", 0)) - actual)
    target["damage_since_last_action"] = true
    _spawn_feedback_label(target, "👻 FLUCH −" + str(actual), Color("c6a7e8"))

    var source: Dictionary = _tf_find_combatant(
        str((curse_value as Dictionary).get("source_id", ""))
    )
    if not source.is_empty():
        source["aggro"] = float(source.get("aggro", 0.0)) + float(actual)

    if int(target.get("hp", 0)) <= 0:
        target["alive"] = false
        target["tf_curse_effect"] = {}
    return actual
