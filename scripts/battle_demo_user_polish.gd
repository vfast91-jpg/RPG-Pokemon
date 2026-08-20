extends "res://scripts/battle_demo_database.gd"

# Final player-requested combat-lab layer.
# Keeps route family roots separate from the unrestricted lab selection, fixes
# random level bounds, adds a universal aggro-control action and improves the
# always-visible combat information without changing move mechanics.

const LAB_RANDOM_LEVEL_MIN_DEFAULT: int = 1
const LAB_RANDOM_LEVEL_MAX_DEFAULT: int = 10
const READABLE_CARD_HEIGHT: float = 54.0

var lab_species_ids: Array = []
var random_level_min: SpinBox

var _readable_card_default: StyleBoxFlat
var _readable_card_active: StyleBoxFlat
var _readable_card_target: StyleBoxFlat


func _load_data() -> void:
    super._load_data()
    _refresh_lab_species_ids()


func _refresh_lab_species_ids() -> void:
    lab_species_ids.clear()
    var species_value: Variant = data.get("species", {})
    if not (species_value is Dictionary):
        return

    for species_id_value: Variant in (species_value as Dictionary).keys():
        var species_id: String = str(species_id_value)
        if not species_id.is_empty():
            lab_species_ids.append(species_id)
    lab_species_ids.sort()


func _build_config(root: Control) -> void:
    super._build_config(root)

    if config_panel != null and config_panel.get_child_count() > 0:
        var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
        if outer != null and outer.get_child_count() > 1:
            var subtitle: Label = outer.get_child(1) as Label
            if subtitle != null:
                subtitle.text = "Alle verfügbaren Pokémon-Formen · freie Levelwahl · 1–4 pro Seite"

    _build_random_level_range()


func _build_random_level_range() -> void:
    if random_level_limit == null:
        return

    var row: HBoxContainer = random_level_limit.get_parent() as HBoxContainer
    if row == null:
        return

    if row.get_child_count() > 0:
        var heading: Label = row.get_child(0) as Label
        if heading != null:
            heading.text = "Zufallslevel"

    var min_text := Label.new()
    min_text.text = "von"
    min_text.add_theme_font_size_override("font_size", 10)
    row.add_child(min_text)

    random_level_min = SpinBox.new()
    random_level_min.min_value = 1.0
    random_level_min.max_value = float(DATABASE_LEVEL_MAX)
    random_level_min.step = 1.0
    random_level_min.value = float(LAB_RANDOM_LEVEL_MIN_DEFAULT)
    random_level_min.custom_minimum_size = Vector2(62, 24)
    random_level_min.tooltip_text = "Untergrenze für den ZUFALL-Button."
    random_level_min.value_changed.connect(_on_random_level_min_changed)
    row.add_child(random_level_min)

    var max_text := Label.new()
    max_text.text = "bis"
    max_text.add_theme_font_size_override("font_size", 10)
    row.add_child(max_text)

    random_level_limit.min_value = 1.0
    random_level_limit.max_value = float(DATABASE_LEVEL_MAX)
    random_level_limit.allow_greater = false
    random_level_limit.value = float(LAB_RANDOM_LEVEL_MAX_DEFAULT)
    random_level_limit.tooltip_text = "Obergrenze für den ZUFALL-Button."
    random_level_limit.value_changed.connect(_on_random_level_max_changed)

    row.move_child(min_text, 1)
    row.move_child(random_level_min, 2)
    row.move_child(max_text, 3)
    row.move_child(random_level_limit, 4)


func _on_random_level_min_changed(value: float) -> void:
    if random_level_limit == null:
        return
    if value > random_level_limit.value:
        random_level_limit.set_value_no_signal(value)


func _on_random_level_max_changed(value: float) -> void:
    if random_level_min == null:
        return
    if value < random_level_min.value:
        random_level_min.set_value_no_signal(value)


func _fill_rows(box: VBoxContainer, setup: Array, own: bool) -> void:
    if lab_species_ids.is_empty():
        super._fill_rows(box, setup, own)
        return

    # species_ids remains the route-family-root list because the route and the
    # mandatory evolution resolver depend on it. Only the lab picker temporarily
    # sees every loaded form.
    var route_root_ids: Array = species_ids
    species_ids = lab_species_ids.duplicate()
    super._fill_rows(box, setup, own)
    species_ids = route_root_ids


func _randomize_setup() -> void:
    if lab_species_ids.is_empty():
        return

    var min_level: int = LAB_RANDOM_LEVEL_MIN_DEFAULT
    var max_level: int = LAB_RANDOM_LEVEL_MAX_DEFAULT
    if random_level_min != null:
        min_level = clampi(int(random_level_min.value), 1, DATABASE_LEVEL_MAX)
    if random_level_limit != null:
        max_level = clampi(int(random_level_limit.value), 1, DATABASE_LEVEL_MAX)
    if min_level > max_level:
        min_level = max_level

    var player_amount: int = randi_range(1, TEAM_MAX)
    var enemy_amount: int = randi_range(1, TEAM_MAX)
    player_setup.clear()
    enemy_setup.clear()

    for _index: int in range(player_amount):
        player_setup.append({
            "species_id": str(lab_species_ids.pick_random()),
            "level": randi_range(min_level, max_level)
        })
    for _index: int in range(enemy_amount):
        enemy_setup.append({
            "species_id": str(lab_species_ids.pick_random()),
            "level": randi_range(min_level, max_level)
        })

    player_count.set_value_no_signal(float(player_amount))
    enemy_count.set_value_no_signal(float(enemy_amount))
    _refresh_setup()


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    if log_label != null:
        log_label.custom_minimum_size.y = 34.0
        log_label.add_theme_font_size_override("normal_font_size", 11)
        log_label.add_theme_font_size_override("bold_font_size", 11)


func _positions_for_count(count: int) -> Array:
    match count:
        1:
            return [81.0]
        2:
            return [54.0, 108.0]
        3:
            return [27.0, 81.0, 135.0]
        _:
            return [0.0, 54.0, 108.0, 162.0]


func _make_card(combatant: Dictionary, enemy: bool) -> Control:
    var card: Control = super._make_card(combatant, enemy)
    card.custom_minimum_size.y = READABLE_CARD_HEIGHT
    card.size.y = READABLE_CARD_HEIGHT

    var combatant_id: String = str(combatant.get("id", ""))
    var ui_value: Variant = cards.get(combatant_id, {})
    if not (ui_value is Dictionary):
        return card
    var ui: Dictionary = ui_value

    var hp_bar: ProgressBar = ui.get("hp") as ProgressBar
    if hp_bar != null:
        hp_bar.custom_minimum_size.y = 10.0
        var hp_text: Label = ui.get("hp_text") as Label
        if hp_text != null:
            hp_text.add_theme_font_size_override("font_size", 8)

        var content: VBoxContainer = hp_bar.get_parent() as VBoxContainer
        if content != null and content.get_child_count() > 0:
            var name_label: Label = content.get_child(0) as Label
            if name_label != null:
                name_label.add_theme_font_size_override("font_size", 9)

            var type_row: HBoxContainer = content.get_node_or_null("TypeBadges") as HBoxContainer
            if type_row != null:
                for badge_value: Variant in type_row.get_children():
                    if badge_value is PanelContainer and (badge_value as PanelContainer).get_child_count() > 0:
                        var badge_label: Label = (badge_value as PanelContainer).get_child(0) as Label
                        if badge_label != null:
                            badge_label.add_theme_font_size_override("font_size", 7)

            var status_label: Label = ui.get("status") as Label
            if status_label != null:
                status_label.visible = false
                status_label.custom_minimum_size.y = 0.0

            var chip_row := HBoxContainer.new()
            chip_row.name = "ReadableStatusChips"
            chip_row.custom_minimum_size.y = 10.0
            chip_row.add_theme_constant_override("separation", 2)
            content.add_child(chip_row)
            ui["status_chips"] = chip_row

    var atb_bar: ProgressBar = ui.get("atb") as ProgressBar
    if atb_bar != null:
        atb_bar.custom_minimum_size.y = 5.0

    var aggro_bar: ProgressBar = ui.get("aggro") as ProgressBar
    if aggro_bar != null:
        aggro_bar.custom_minimum_size.y = 5.0

    var aggro_label: Label = ui.get("aggro_label") as Label
    if aggro_label != null:
        aggro_label.custom_minimum_size = Vector2(44.0, 8.0)
        aggro_label.add_theme_font_size_override("font_size", 7)

    var info_button: Button = ui.get("info") as Button
    if info_button != null:
        info_button.custom_minimum_size = Vector2(24, 32)
        info_button.add_theme_font_size_override("font_size", 10)

    cards[combatant_id] = ui
    return card


func _status_tokens(combatant: Dictionary) -> Array[String]:
    var inherited_tokens: Array[String] = super._status_tokens(combatant)
    var result: Array[String] = []

    for token: String in inherited_tokens:
        if token.contains("ZIEL"):
            continue
        result.append(token)

    var incoming_count: int = _incoming_target_count(combatant)
    if incoming_count > 0:
        result.push_front("🎯 ZIEL ×%d" % incoming_count)
    return result


func _incoming_target_count(combatant: Dictionary) -> int:
    if not bool(combatant.get("alive", false)):
        return 0

    var opponents: Array = enemy_team if str(combatant.get("side", "")) == "player" else player_team
    var count: int = 0
    var combatant_id: String = str(combatant.get("id", ""))

    for opponent_value: Variant in opponents:
        if not (opponent_value is Dictionary):
            continue
        var opponent: Dictionary = opponent_value
        if not bool(opponent.get("alive", false)):
            continue
        var target: Dictionary = _highest_aggro(opponent)
        if not target.is_empty() and str(target.get("id", "")) == combatant_id:
            count += 1
    return count


func _refresh_cards() -> void:
    super._refresh_cards()
    _ensure_readable_card_styles()

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

        var aggro_label: Label = ui.get("aggro_label") as Label
        if aggro_label != null:
            aggro_label.text = "AGGRO %.0f" % float(combatant.get("aggro", 0.0))

        var tokens: Array[String] = _status_tokens(combatant)
        if combatant_id == active_id:
            tokens.push_front("▶ AM ZUG")
        _refresh_status_chips(ui.get("status_chips") as HBoxContainer, tokens)

        var card: PanelContainer = ui.get("card") as PanelContainer
        var target_count: int = _incoming_target_count(combatant)
        if card != null:
            if combatant_id == active_id:
                card.add_theme_stylebox_override("panel", _readable_card_active)
            elif target_count > 0:
                card.add_theme_stylebox_override("panel", _readable_card_target)
            else:
                card.add_theme_stylebox_override("panel", _readable_card_default)

        var sprite: TextureRect = ui.get("texture") as TextureRect
        if sprite != null:
            if combatant_id == active_id:
                sprite.modulate = Color("fff0a8")
            elif target_count > 0:
                sprite.modulate = Color("ffd4d4")
            else:
                sprite.modulate = Color("ffffff")


func _ensure_readable_card_styles() -> void:
    if _readable_card_default != null:
        return

    _readable_card_default = _panel(Color("f8f1dce8"), Color("34443d"), 6, 3.0)
    _readable_card_active = _panel(Color("fff4cdeF"), Color("f2b84b"), 6, 3.0)
    _readable_card_target = _panel(Color("ffe6e6ef"), Color("dc3f3f"), 6, 3.0)
    _readable_card_active.set_border_width_all(4)
    _readable_card_target.set_border_width_all(4)


func _refresh_status_chips(row: HBoxContainer, tokens: Array[String]) -> void:
    if row == null:
        return
    for child: Node in row.get_children():
        child.queue_free()

    if tokens.is_empty():
        row.add_child(_make_status_chip("OK"))
        return

    var visible_count: int = mini(3, tokens.size())
    for index: int in range(visible_count):
        row.add_child(_make_status_chip(tokens[index]))
    if tokens.size() > visible_count:
        row.add_child(_make_status_chip("+%d" % (tokens.size() - visible_count)))


func _make_status_chip(text: String) -> Control:
    var chip := PanelContainer.new()
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style := StyleBoxFlat.new()
    style.bg_color = _status_chip_color(text)
    style.set_corner_radius_all(3)
    style.content_margin_left = 3.0
    style.content_margin_right = 3.0
    style.content_margin_top = 0.0
    style.content_margin_bottom = 0.0
    chip.add_theme_stylebox_override("panel", style)

    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 7)
    label.add_theme_color_override("font_color", Color("ffffff"))
    label.add_theme_color_override("font_outline_color", Color("17211f"))
    label.add_theme_constant_override("outline_size", 1)
    chip.add_child(label)
    return chip


func _status_chip_color(text: String) -> Color:
    if text.contains("AM ZUG"):
        return Color("806213")
    if text.contains("ZIEL"):
        return Color("9b3434")
    if text.contains("PAR"):
        return Color("8d7614")
    if text.contains("K.O"):
        return Color("5a5a5a")
    if text.contains("+"):
        return Color("39734b")
    if text.contains("-") or text.contains("VERW") or text.contains("GIF") or text.contains("BRN"):
        return Color("74405f")
    return Color("42564e")


func _style_action_button(button: Button, type_id: String, utility: bool) -> void:
    super._style_action_button(button, type_id, utility)
    button.custom_minimum_size.y = 36.0
    button.add_theme_font_size_override("font_size", 11)


func _prompt_player(actor: Dictionary) -> void:
    super._prompt_player(actor)
    if action_grid == null or selected_actor.is_empty():
        return

    var front_button := Button.new()
    front_button.text = "🛡 VORNE! · Aggro ×2"
    front_button.custom_minimum_size = Vector2(176, 36)
    front_button.tooltip_text = ""
    front_button.mouse_entered.connect(_preview_front_action)
    front_button.focus_entered.connect(_preview_front_action)
    front_button.pressed.connect(_choose_front)
    action_grid.add_child(front_button)
    _style_action_button(front_button, "typeless", true)

    _refresh_cards()


func _preview_front_action() -> void:
    if selected_actor.is_empty():
        return
    _set_log(
        "[b]🛡 VORNE![/b] · " + _actor_name(selected_actor)
        + " verdoppelt seine aktuelle Aggro. Keine Schadensreduktion; die Aktion dient nur dazu, Angriffe gezielter auf dieses Pokémon zu ziehen."
    )


func _choose_front() -> void:
    if selected_actor.is_empty():
        return

    var actor: Dictionary = selected_actor
    selected_actor = {}
    paused = false
    _touch_preview_move_id = ""
    _clear_actions()

    actor["db_protect_chain"] = 0
    actor["db_fury_cutter_chain"] = 0
    actor["db_guaranteed_crit"] = false
    actor["db_charge_move"] = ""
    actor["db_charge_target_id"] = ""
    actor["db_charge_firing"] = false

    var before: float = float(actor.get("aggro", 0.0))
    actor["aggro"] = maxf(1.0, before * 2.0)
    actor["atb"] = 0.0
    actor["cycle"] = 1.0

    _set_log(
        _actor_name(actor) + " geht nach vorne: Aggro %.0f → %.0f."
        % [before, float(actor.get("aggro", 0.0))]
    )
    _refresh_cards()
