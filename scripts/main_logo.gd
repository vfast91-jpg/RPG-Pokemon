extends "res://scripts/main_pvp.gd"

const MAIN_MENU_POKEMON_LOGO: Texture2D = preload("res://assets/ui/main_menu/International_Pokémon_logo.svg.webp")
const MAIN_MENU_TIMEFLOW_LOGO: Texture2D = preload("res://assets/ui/main_menu/ChatGPT Image 21. Aug. 2026, 19_28_45.png")


func _build_main_menu() -> void:
    super._build_main_menu()
    _install_main_menu_title_logo()


func _install_main_menu_title_logo() -> void:
    var old_title := _find_label_by_text(menu_root, "POKEMON TIMEFLOW")
    if old_title != null:
        # Unsichtbar statt entfernt: So bleibt der bisherige Platz im VBox-Layout
        # exakt erhalten und Untertitel/Buttons springen nicht nach oben.
        old_title.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
        old_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    else:
        push_warning("Hauptmenü-Logo: Alter Titel 'POKEMON TIMEFLOW' wurde nicht gefunden.")

    var logo_layer := Control.new()
    logo_layer.name = "MainMenuTitleLogo"
    logo_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    logo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    logo_layer.z_index = 10
    menu_root.add_child(logo_layer)

    # Beide Grafiken bilden gemeinsam einen breiten Titel. Sie liegen über dem
    # oberen Rand der Menübox und ragen bewusst in das Hintergrundbild hinein.
    _add_title_logo_texture(
        logo_layer,
        "PokemonLogo",
        MAIN_MENU_POKEMON_LOGO,
        Rect2(-215.0, 4.0, 200.0, 74.0)
    )
    _add_title_logo_texture(
        logo_layer,
        "TimeflowLogo",
        MAIN_MENU_TIMEFLOW_LOGO,
        Rect2(-40.0, 6.0, 255.0, 76.0)
    )


func _add_title_logo_texture(parent: Control, node_name: String, texture: Texture2D, rect: Rect2) -> void:
    var logo := TextureRect.new()
    logo.name = node_name
    logo.texture = texture
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    logo.anchor_left = 0.5
    logo.anchor_right = 0.5
    logo.anchor_top = 0.0
    logo.anchor_bottom = 0.0
    logo.offset_left = rect.position.x
    logo.offset_top = rect.position.y
    logo.offset_right = rect.position.x + rect.size.x
    logo.offset_bottom = rect.position.y + rect.size.y
    parent.add_child(logo)


func _find_label_by_text(node: Node, text: String) -> Label:
    for child: Node in node.get_children():
        if child is Label and (child as Label).text == text:
            return child as Label
        var nested := _find_label_by_text(child, text)
        if nested != null:
            return nested
    return null
