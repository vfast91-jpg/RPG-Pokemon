extends "res://scripts/battle_demo_status_effect_migration_v1.gd"

# Active endgame battle layer for the 100-stage route.
# - Route/test combatants may exceed level 100.
# - Existing <=100 behaviour is left untouched.
# - Endgame bosses can display four continuous HP bars.

const ENDGAME_BOSS_CARD_HEIGHT: float = 94.0
const ENDGAME_BOSS_BAR_GAP: float = 8.0
const PRACTICAL_LEVEL_PICKER_MAX: float = 100000.0


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var requested_level: int = maxi(1, int(setup.get("level", 1)))
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    var resolved_level: int = maxi(1, int(combatant.get("level", 1)))

    if requested_level > resolved_level:
        _apply_uncapped_level_growth(combatant, requested_level, resolved_level)
    return combatant


func _apply_uncapped_level_growth(
    combatant: Dictionary,
    requested_level: int,
    resolved_level: int
) -> void:
    var species_id: String = str(combatant.get("species_id", ""))
    var species_value: Variant = (data.get("species", {}) as Dictionary).get(species_id, {}) if data.get("species", {}) is Dictionary else {}
    if not (species_value is Dictionary):
        combatant["level"] = requested_level
        return

    var base_value: Variant = (species_value as Dictionary).get("base_stats", {})
    if not (base_value is Dictionary):
        combatant["level"] = requested_level
        return
    var base_stats: Dictionary = base_value

    var old_max_hp: int = maxi(1, int(combatant.get("max_hp", 1)))
    var hp_delta: int = (
        _standard_hp_at_level(float(base_stats.get("hp", 35)), requested_level)
        - _standard_hp_at_level(float(base_stats.get("hp", 35)), resolved_level)
    )
    combatant["max_hp"] = maxi(1, old_max_hp + hp_delta)
    combatant["hp"] = int(combatant["max_hp"])

    for stat_key: String in ["attack", "defense", "special", "speed"]:
        var old_value: int = int(combatant.get(stat_key, 1))
        var base_stat: float = float(base_stats.get(stat_key, 40))
        var delta: int = (
            _standard_other_stat_at_level(base_stat, requested_level)
            - _standard_other_stat_at_level(base_stat, resolved_level)
        )
        combatant[stat_key] = maxi(1, old_value + delta)

    combatant["level"] = requested_level

    var route_moves: Array = route_moves_for_level(species_id, requested_level)
    var existing_value: Variant = combatant.get("moves", [])
    var merged: Array = existing_value.duplicate() if existing_value is Array else []
    for move_value: Variant in route_moves:
        var move_id: String = str(move_value)
        if not merged.has(move_id):
            merged.append(move_id)
    combatant["moves"] = merged


func _standard_hp_at_level(base_stat: float, level: int) -> int:
    var safe_level: int = maxi(1, level)
    return int(floor(2.0 * base_stat * float(safe_level) / 100.0)) + safe_level + 10


func _standard_other_stat_at_level(base_stat: float, level: int) -> int:
    var safe_level: int = maxi(1, level)
    return int(floor(2.0 * base_stat * float(safe_level) / 100.0)) + 5


func route_new_member(species_id: String, level: int) -> Dictionary:
    var requested_level: int = maxi(1, level)
    var member: Dictionary = super.route_new_member(species_id, requested_level)
    if requested_level <= int(member.get("level", requested_level)):
        return member

    var resolved_species: String = route_resolve_species_for_level(species_id, requested_level)
    if resolved_species.is_empty():
        resolved_species = str(member.get("species_id", species_id))

    var snapshot: Dictionary = route_stat_snapshot(resolved_species, requested_level)
    member["species_id"] = resolved_species
    member["name"] = route_species_name(resolved_species)
    member["level"] = requested_level
    member["max_hp"] = maxi(1, int(snapshot.get("max_hp", member.get("max_hp", 1))))
    member["hp"] = int(member["max_hp"])
    member["known_moves"] = route_moves_for_level(resolved_species, requested_level)
    return member


func _build_config(root: Control) -> void:
    super._build_config(root)
    if config_panel == null or config_panel.get_child_count() == 0:
        return
    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer != null and outer.get_child_count() > 1:
        var subtitle: Label = outer.get_child(1) as Label
        if subtitle != null:
            subtitle.text = "Pokémon wählen · Level 1+ · 1–4 pro Seite"


func _fill_rows(box: VBoxContainer, setup: Array, own: bool) -> void:
    super._fill_rows(box, setup, own)
    for row_value: Variant in box.get_children():
        if not (row_value is HBoxContainer):
            continue
        for child_value: Variant in (row_value as HBoxContainer).get_children():
            if child_value is SpinBox:
                var level_picker: SpinBox = child_value
                level_picker.max_value = PRACTICAL_LEVEL_PICKER_MAX
                level_picker.allow_greater = true


func _level_changed(value: float, own: bool, index: int) -> void:
    var setup: Array = player_setup if own else enemy_setup
    if index < 0 or index >= setup.size():
        return
    setup[index]["level"] = maxi(1, int(value))


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not route_mode or enemy_team.is_empty() or _route_enemy_party.is_empty():
        return

    var has_four_bar_boss: bool = false
    var count: int = mini(enemy_team.size(), _route_enemy_party.size())
    for index: int in range(count):
        var source_value: Variant = _route_enemy_party[index]
        var combatant_value: Variant = enemy_team[index]
        if not (source_value is Dictionary) or not (combatant_value is Dictionary):
            continue

        var source: Dictionary = source_value
        var combatant: Dictionary = combatant_value
        if not bool(source.get("boss", false)) or not bool(combatant.get("boss", false)):
            continue

        var hp_bars: int = maxi(
            1,
            int(source.get("hp_bars", round(float(source.get("hp_multiplier", 2.0)))))
        )
        combatant["boss_hp_bars"] = hp_bars
        if hp_bars > 2:
            _decorate_extra_boss_bars(combatant, hp_bars)
            has_four_bar_boss = has_four_bar_boss or hp_bars >= 4

    _refresh_cards()
    if has_four_bar_boss:
        _set_log("🔥 Superboss! Dieses Pokémon besitzt vier vollständige, zusammenhängende KP-Leisten.")


func _decorate_extra_boss_bars(combatant: Dictionary, hp_bars: int) -> void:
    var combatant_id: String = str(combatant.get("id", ""))
    var ui_value: Variant = cards.get(combatant_id, {})
    if not (ui_value is Dictionary):
        return
    var ui: Dictionary = ui_value
    var card: Control = ui.get("card") as Control
    if card == null:
        return

    var canvas: Control = card.get_node_or_null("CardCanvas") as Control
    var second_back: Panel = ui.get("boss_hp2_back") as Panel
    if canvas == null or second_back == null:
        return

    card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, ENDGAME_BOSS_CARD_HEIGHT)
    card.size.y = maxf(card.size.y, ENDGAME_BOSS_CARD_HEIGHT)
    canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y, ENDGAME_BOSS_CARD_HEIGHT - 4.0)

    for bar_index: int in range(3, hp_bars + 1):
        var back_name: String = "BossHP%dBack" % bar_index
        var fill_name: String = "BossHP%dFill" % bar_index
        var back: Panel = canvas.get_node_or_null(back_name) as Panel
        var fill: Panel = canvas.get_node_or_null(fill_name) as Panel

        if back == null:
            back = Panel.new()
            back.name = back_name
            back.position = Vector2(
                second_back.position.x,
                second_back.position.y + ENDGAME_BOSS_BAR_GAP * float(bar_index - 2)
            )
            back.size = second_back.size
            back.mouse_filter = Control.MOUSE_FILTER_IGNORE
            back.add_theme_stylebox_override("panel", _endgame_meter_style(Color("c8c8c2")))
            canvas.add_child(back)

        if fill == null:
            fill = Panel.new()
            fill.name = fill_name
            fill.position = back.position
            fill.size = back.size
            fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
            fill.add_theme_stylebox_override("panel", _endgame_meter_style(Color("55b85a")))
            canvas.add_child(fill)

        ui["boss_hp%d_back" % bar_index] = back
        ui["boss_hp%d_fill" % bar_index] = fill

    var meter_bottom: float = second_back.position.y + ENDGAME_BOSS_BAR_GAP * float(hp_bars - 1)
    var aggro_label: Label = ui.get("aggro_label") as Label
    var aggro_back: Panel = ui.get("aggro_back") as Panel
    var aggro_fill: Panel = ui.get("aggro_fill") as Panel
    var atb_text: Label = ui.get("atb_text") as Label
    var atb_back: Panel = ui.get("atb_back") as Panel
    var atb_fill: Panel = ui.get("atb_fill") as Panel

    if aggro_label != null:
        aggro_label.position.y = meter_bottom + 9.0
    if aggro_back != null:
        aggro_back.position.y = meter_bottom + 10.0
    if aggro_fill != null:
        aggro_fill.position.y = meter_bottom + 10.0
    if atb_text != null:
        atb_text.position.y = meter_bottom + 20.0
    if atb_back != null:
        atb_back.position.y = meter_bottom + 21.0
    if atb_fill != null:
        atb_fill.position.y = meter_bottom + 21.0

    cards[combatant_id] = ui


func _endgame_meter_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(2)
    return style


func _refresh_cards() -> void:
    super._refresh_cards()

    for combatant_value: Variant in combatants:
        if not (combatant_value is Dictionary):
            continue
        var combatant: Dictionary = combatant_value
        var hp_bars: int = maxi(1, int(combatant.get("boss_hp_bars", 2)))
        if not bool(combatant.get("boss", false)) or hp_bars <= 2:
            continue

        var ui_value: Variant = cards.get(str(combatant.get("id", "")), {})
        if not (ui_value is Dictionary):
            continue
        var ui: Dictionary = ui_value
        var base_max_hp: float = maxf(1.0, float(combatant.get("boss_base_max_hp", 1)))
        var total_hp: float = clampf(
            float(combatant.get("hp", 0)),
            0.0,
            float(combatant.get("max_hp", 1))
        )

        for bar_index: int in range(1, hp_bars + 1):
            var segment_hp: float = clampf(
                total_hp - base_max_hp * float(hp_bars - bar_index),
                0.0,
                base_max_hp
            )
            var fill: Panel
            if bar_index == 1:
                fill = ui.get("hp_fill") as Panel
            else:
                fill = ui.get("boss_hp%d_fill" % bar_index) as Panel
            if fill != null:
                _set_meter_fill(fill, segment_hp / base_max_hp)

        var hp_controller: ProgressBar = ui.get("hp") as ProgressBar
        if hp_controller != null:
            var first_segment: float = clampf(
                total_hp - base_max_hp * float(hp_bars - 1),
                0.0,
                base_max_hp
            )
            hp_controller.max_value = base_max_hp
            hp_controller.value = first_segment

        var hp_text: Label = ui.get("hp_text") as Label
        if hp_text != null:
            hp_text.text = "KP %d/%d" % [int(total_hp), int(combatant.get("max_hp", 1))]
