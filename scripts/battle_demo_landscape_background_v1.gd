extends "res://scripts/battle_demo_zf_payday_v1.gd"

# Landschafts-Hintergründe für das aktive Kampffeld.
# Die 4:3-Originalbilder bleiben unverändert; im sehr breiten BattleArea-Fenster
# werden sie proportional gefüllt und nur für die Anzeige an den Rändern beschnitten.

const DEFAULT_LANDSCAPE_BACKGROUND: String = "res://assets/battle_backgrounds/landscapes/01_meadow_grassland.jpg"

var _tf_landscape_background: TextureRect = null
var _tf_landscape_background_path: String = ""


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    _tf_install_landscape_background()
    set_battle_background(DEFAULT_LANDSCAPE_BACKGROUND)


func _tf_install_landscape_background() -> void:
    if battle_panel == null:
        return
    var battle_area: Control = battle_panel.get_node_or_null("BattleArea") as Control
    if battle_area == null:
        push_warning("Landschaftshintergrund: BattleArea fehlt.")
        return

    _tf_landscape_background = TextureRect.new()
    _tf_landscape_background.name = "LandscapeBackground"
    _tf_landscape_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _tf_landscape_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _tf_landscape_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _tf_landscape_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    battle_area.add_child(_tf_landscape_background)
    battle_area.move_child(_tf_landscape_background, 0)


func set_battle_background(path: String) -> bool:
    var clean_path: String = path.strip_edges()
    if clean_path.is_empty():
        return false
    if _tf_landscape_background == null:
        _tf_install_landscape_background()
    if _tf_landscape_background == null:
        return false

    var texture: Resource = load(clean_path)
    if not (texture is Texture2D):
        push_warning("Landschaftshintergrund konnte nicht geladen werden: " + clean_path)
        return false

    _tf_landscape_background.texture = texture as Texture2D
    _tf_landscape_background_path = clean_path
    return true


func battle_background_path() -> String:
    return _tf_landscape_background_path
