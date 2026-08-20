extends "res://scripts/demo_route_user_polish.gd"

# Route team-panel layout polish.
# The travelling team is capped at four Pokémon, so the sidebar should show
# all four cards at once instead of requiring vertical scrolling.


func _ready() -> void:
    super._ready()
    _fit_four_member_team_panel()


func _fit_four_member_team_panel() -> void:
    if team_box == null:
        return

    team_box.add_theme_constant_override("separation", 1)

    var parent := team_box.get_parent()
    if parent is ScrollContainer:
        var team_scroll := parent as ScrollContainer
        team_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        team_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        team_scroll.scroll_vertical = 0


func _refresh_team_panel() -> void:
    super._refresh_team_panel()

    # Keep the storage footer to a single compact line so it cannot steal
    # vertical room from the four fixed team cards.
    if storage_label != null:
        storage_label.text = "Lager: %d" % storage.size()

        var stored_names: Array[String] = []
        for stored_value: Variant in storage:
            if stored_value is Dictionary:
                stored_names.append(str((stored_value as Dictionary).get("name", "Pokémon")))
        storage_label.tooltip_text = (
            "Eingelagert: " + ", ".join(stored_names)
            if not stored_names.is_empty()
            else "Keine Pokémon eingelagert."
        )


func _make_route_team_card(member: Dictionary, index: int) -> Control:
    var card: Control = super._make_route_team_card(member, index)
    card.custom_minimum_size = Vector2(0.0, 44.0)

    if card is PanelContainer:
        (card as PanelContainer).add_theme_stylebox_override(
            "panel",
            _panel(Color("182822"), Color("55796a"), 6, 2.0)
        )

    var row: HBoxContainer = null
    for card_child: Node in card.get_children():
        if card_child is HBoxContainer:
            row = card_child as HBoxContainer
            break

    if row == null:
        return card

    row.add_theme_constant_override("separation", 3)

    var content: VBoxContainer = null
    for row_child: Node in row.get_children():
        if row_child is TextureRect:
            (row_child as TextureRect).custom_minimum_size = Vector2(36.0, 36.0)
        elif row_child is VBoxContainer:
            content = row_child as VBoxContainer

    if content == null:
        return card

    content.add_theme_constant_override("separation", 0)

    var first_label := true
    for content_child: Node in content.get_children():
        if content_child is ProgressBar:
            (content_child as ProgressBar).custom_minimum_size.y = 8.0
        elif content_child is Label:
            var label := content_child as Label
            label.add_theme_font_size_override("font_size", 9 if first_label else 6)
            first_label = false

    return card
