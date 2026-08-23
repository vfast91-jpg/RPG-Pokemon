extends "res://scripts/demo_route_endgame_legendary_landscapes_v1.gd"

# Central route UI for every current "choose a team Pokémon" decision.
# One shared card builder is used for:
# - training
# - TM recipients
# - healing-item recipients
# - revive recipients
# - vitamin recipients
#
# This deliberately sits at the active top of the route inheritance chain so
# later feature layers cannot accidentally fall back to the old plain text rows.

const POKEMON_CHOICE_CARD_HEIGHT: float = 58.0
const POKEMON_CHOICE_SPRITE_SIZE: Vector2 = Vector2(44.0, 44.0)


func _make_route_pokemon_choice_card(
    member: Dictionary,
    subtitle: String,
    tooltip: String,
    action: Callable
) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0.0, POKEMON_CHOICE_CARD_HEIGHT)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override(
        "panel",
        _panel(Color("182822"), Color("55796a"), 8, 5.0)
    )

    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 9)
    card.add_child(row)

    var sprite := TextureRect.new()
    sprite.custom_minimum_size = POKEMON_CHOICE_SPRITE_SIZE
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.texture = _route_member_texture(str(member.get("name", "Pokémon")))
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(sprite)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.alignment = BoxContainer.ALIGNMENT_CENTER
    info.add_theme_constant_override("separation", 1)
    row.add_child(info)

    var identity := Label.new()
    identity.text = "%s · Lv.%d" % [
        str(member.get("name", "Pokémon")),
        maxi(1, int(member.get("level", 1)))
    ]
    identity.add_theme_font_size_override("font_size", 12)
    identity.add_theme_color_override("font_color", Color("f4f7f5"))
    identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
    info.add_child(identity)

    var detail := Label.new()
    detail.text = subtitle
    detail.add_theme_font_size_override("font_size", 9)
    detail.add_theme_color_override("font_color", Color("9fe7bd"))
    detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    info.add_child(detail)

    var click_area := Button.new()
    click_area.text = ""
    click_area.focus_mode = Control.FOCUS_NONE
    click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    click_area.tooltip_text = tooltip
    click_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    click_area.add_theme_stylebox_override(
        "normal",
        _route_choice_overlay_style(Color("00000000"), Color("00000000"), 0)
    )
    click_area.add_theme_stylebox_override(
        "hover",
        _route_choice_overlay_style(Color("d7f5e60d"), Color("83b59f"), 2)
    )
    click_area.add_theme_stylebox_override(
        "pressed",
        _route_choice_overlay_style(Color("d7f5e614"), Color("e0c968"), 2)
    )
    click_area.add_theme_stylebox_override(
        "focus",
        _route_choice_overlay_style(Color("d7f5e60d"), Color("83b59f"), 2)
    )
    click_area.pressed.connect(action)
    card.add_child(click_area)

    return card


func _make_training_choice_card(member: Dictionary, index: int, required_xp: int) -> Control:
    return _make_route_pokemon_choice_card(
        member,
        "🏋️ Training → +%d EP · garantierter Levelaufstieg" % required_xp,
        (
            "Dieses Pokémon erhält genau %d EP gemäß seiner eigenen EP-Kurve. "
            + "Der bestehende EP-Stand bleibt erhalten. Nach dem Levelaufstieg verliert es "
            + "15%% seiner neuen Max-KP; ein lebendes Pokémon behält mindestens 1 KP."
        ) % required_xp,
        _train_team_member.bind(index)
    )


func _choose_tm_offer(entry: Dictionary) -> void:
    var recipients: Array[Dictionary] = _tm_recipients(entry)
    if recipients.is_empty():
        _begin_tm_event()
        return

    _clear_container(capture_actions)
    continue_button.visible = false

    var tm_label: String = _database_tm_label(str(entry.get("number", "")))
    var move_name: String = str(entry.get("name", entry.get("move_id", "TM")))
    event_label.text = "[b]%s · %s[/b]\nWelches Pokémon soll diese Attacke erhalten?" % [
        tm_label,
        move_name
    ]

    for recipient: Dictionary in recipients:
        var team_index: int = int(recipient.get("team_index", -1))
        var member_value: Variant = recipient.get("member", {})
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        capture_actions.add_child(
            _make_route_pokemon_choice_card(
                member,
                "💿 %s lernen" % move_name,
                "%s %s zuweisen." % [tm_label, str(member.get("name", "Pokémon"))],
                _assign_tm.bind(entry, team_index)
            )
        )

    _add_polished_selection_back_button("ZURÜCK ZUR TM-AUSWAHL", _show_tm_offer_buttons)


func _choose_healing_item(item: Dictionary) -> void:
    _clear_container(capture_actions)
    continue_button.visible = false

    var item_name: String = str(item.get("name", "Trank"))
    var amount: int = int(item.get("amount", 0))
    event_label.text = "[b]🧪 %s[/b]\nAuf welches kampffähige Pokémon möchtest du das Heilitem jetzt anwenden?" % item_name

    var recipient_count: int = 0
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        var current_hp: int = int(member.get("hp", 0))
        if current_hp <= 0:
            continue

        recipient_count += 1
        var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
        var new_hp: int = max_hp if amount < 0 else mini(max_hp, current_hp + maxi(0, amount))
        var healed_hp: int = maxi(0, new_hp - current_hp)
        var subtitle: String = "🧪 %s → %d/%d KP" % [item_name, new_hp, max_hp]
        if amount >= 0:
            subtitle = "🧪 %s → +%d KP · %d/%d → %d/%d" % [
                item_name,
                healed_hp,
                current_hp,
                max_hp,
                new_hp,
                max_hp
            ]

        capture_actions.add_child(
            _make_route_pokemon_choice_card(
                member,
                subtitle,
                "%s sofort auf %s anwenden." % [item_name, str(member.get("name", "Pokémon"))],
                _apply_healing_item.bind(index, item)
            )
        )

    if recipient_count == 0:
        event_label.text += "\nEs gibt derzeit kein kampffähiges Ziel für dieses Heilitem."

    _add_polished_selection_back_button("ZURÜCK ZUR FUNDSTELLE", _show_fundstelle_options)


func _choose_vitamin(vitamin: Dictionary) -> void:
    _clear_container(capture_actions)
    continue_button.visible = false

    var stat_key: String = str(vitamin.get("stat", ""))
    var vitamin_name: String = str(vitamin.get("name", "Vitamin"))
    var vitamin_emoji: String = str(vitamin.get("emoji", "✨"))
    var stat_label: String = str(vitamin.get("label", "Wert"))

    event_label.text = "[b]%s %s[/b]\nWelches Pokémon soll dauerhaft +%d %s erhalten?" % [
        vitamin_emoji,
        vitamin_name,
        VITAMIN_BONUS_PER_USE,
        stat_label
    ]

    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        var bonuses: Dictionary = _vitamin_bonuses_for_member(member)
        var current_bonus: int = int(bonuses.get(stat_key, 0))
        if current_bonus >= VITAMIN_STAT_CAP:
            continue

        var next_bonus: int = mini(VITAMIN_STAT_CAP, current_bonus + VITAMIN_BONUS_PER_USE)
        capture_actions.add_child(
            _make_route_pokemon_choice_card(
                member,
                "%s %s +%d/%d → +%d/%d" % [
                    vitamin_emoji,
                    stat_label,
                    current_bonus,
                    VITAMIN_STAT_CAP,
                    next_bonus,
                    VITAMIN_STAT_CAP
                ],
                "%s erhält dauerhaft +%d %s." % [
                    str(member.get("name", "Pokémon")),
                    VITAMIN_BONUS_PER_USE,
                    stat_label
                ],
                _apply_vitamin.bind(index, vitamin)
            )
        )

    _add_polished_selection_back_button("ZURÜCK ZUR FUNDSTELLE", _show_fundstelle_options)


func _choose_revive() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    event_label.text = "[b]✨ Beleber[/b]\nWelches kampfunfähige Pokémon möchtest du wiederbeleben?"

    var recipient_count: int = 0
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) > 0:
            continue

        recipient_count += 1
        var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
        var revived_hp: int = _revive_hp_amount(max_hp)
        capture_actions.add_child(
            _make_route_pokemon_choice_card(
                member,
                "✨ Beleber → %d/%d KP" % [revived_hp, max_hp],
                "%s mit %d/%d KP wiederbeleben." % [
                    str(member.get("name", "Pokémon")),
                    revived_hp,
                    max_hp
                ],
                _apply_revive.bind(index)
            )
        )

    if recipient_count == 0:
        event_label.text += "\nEs gibt derzeit kein kampfunfähiges Ziel für den Beleber."

    _add_polished_selection_back_button("ZURÜCK ZUR FUNDSTELLE", _show_fundstelle_options)


func _add_polished_selection_back_button(text: String, action: Callable) -> void:
    var back_button := Button.new()
    back_button.text = "↩  " + text
    back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    back_button.pressed.connect(action)
    _style_route_decision_button(back_button, false)
    back_button.custom_minimum_size.y = 36.0
    capture_actions.add_child(back_button)
