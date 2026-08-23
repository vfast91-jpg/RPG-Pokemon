extends "res://scripts/battle_demo_adaptive_family_ui.gd"

# Final stat-profile layer.
#
# The canonical spreadsheet snapshot remains responsible for species identity,
# evolution, types and learnsets. This layer applies the approved five-stat RPG
# silhouettes from 2026-08-21 after the canonical database has been loaded.
# That keeps the runtime values explicit without reintroducing the old averaging
# rules that flattened Attack/Defense/Special identities.

const STAT_PROFILE_PATH: String = "res://data/gen1_species_stat_profiles_v4.json"
const STAT_KEYS: Array[String] = ["hp", "attack", "defense", "special", "speed"]
const ACTIVE_BATTLE_BACKGROUND_PATH: String = "res://assets/battle_backgrounds/landscapes/01_meadow_grassland.jpg"
const DEFAULT_BATTLE_FRAMING: Dictionary = {
    "zoom": 1.18,
    "focus_x": 0.5,
    "focus_y": 0.5,
    "offset_x": 0.0,
    "offset_y": 0.0
}

var _active_battle_background_layer: Control = null
var _active_battle_background_rect: TextureRect = null
var _active_battle_focus_rect: TextureRect = null
var _battle_background_framing: Dictionary = DEFAULT_BATTLE_FRAMING.duplicate(true)


func _build_battle(root: Control) -> void:
    # Use the landscape system's meadow as the initial fallback. The route can
    # replace both image and framing at runtime.
    battle_background_path = ACTIVE_BATTLE_BACKGROUND_PATH
    _battle_background_framing = DEFAULT_BATTLE_FRAMING.duplicate(true)
    super._build_battle(root)

    # battle_demo_hd.gd creates a fallback ColorRect and BattleArea. The old
    # background implementation used COVER directly on the complete ultrawide
    # battle strip. The landscape JPGs are much less wide, so COVER had to crop
    # away a very large part of the image and made the scenery look unnaturally
    # close to the small Pokemon sprites.
    #
    # The permanent solution is a panoramic two-layer framing:
    # - an ambient COVER layer fills the far left/right edges behind the cards;
    # - a sharp focal layer in the middle keeps almost the complete source image
    #   and therefore preserves the intended camera distance.
    # The stat cards naturally cover the transition between both layers.
    var area: Control = battle_panel.get_node_or_null("BattleArea") as Control
    if area == null:
        push_error("BattleArea fehlt; Kampfhintergrund konnte nicht eingebaut werden.")
        return

    if _battle_background_rect != null:
        _battle_background_rect.visible = false

    if battle_panel.get_child_count() > 0:
        var first_child: Node = battle_panel.get_child(0)
        if first_child is ColorRect:
            (first_child as ColorRect).visible = false

    _active_battle_background_layer = Control.new()
    _active_battle_background_layer.name = "ActiveBattleBackgroundLayer"
    _active_battle_background_layer.position = area.position
    _active_battle_background_layer.size = area.size
    _active_battle_background_layer.clip_contents = true
    _active_battle_background_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    battle_panel.add_child(_active_battle_background_layer)

    _active_battle_background_rect = TextureRect.new()
    _active_battle_background_rect.name = "AmbientBattleBackground"
    _active_battle_background_rect.position = Vector2.ZERO
    _active_battle_background_rect.size = area.size
    _active_battle_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _active_battle_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _active_battle_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _active_battle_background_layer.add_child(_active_battle_background_rect)

    _active_battle_focus_rect = TextureRect.new()
    _active_battle_focus_rect.name = "FocusedBattleBackground"
    _active_battle_focus_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _active_battle_focus_rect.stretch_mode = TextureRect.STRETCH_SCALE
    _active_battle_focus_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _active_battle_background_layer.add_child(_active_battle_focus_rect)

    # Put the complete background layer directly before BattleArea. The Pokemon,
    # cards and connectors remain children of BattleArea and are therefore always
    # rendered above it.
    battle_panel.move_child(_active_battle_background_layer, area.get_index())
    area.resized.connect(_sync_visible_battle_background.bind(area))

    _update_visible_battle_background()


func set_battle_background(path: String) -> void:
    _battle_background_framing = DEFAULT_BATTLE_FRAMING.duplicate(true)
    super.set_battle_background(path)
    if battle_background_path != path:
        return
    _update_visible_battle_background()


func set_battle_background_framed(path: String, framing: Dictionary) -> void:
    _battle_background_framing = _normalized_battle_framing(framing)
    super.set_battle_background(path)
    if battle_background_path != path:
        return
    _update_visible_battle_background()


func _normalized_battle_framing(framing: Dictionary) -> Dictionary:
    var result: Dictionary = DEFAULT_BATTLE_FRAMING.duplicate(true)
    for key_value: Variant in result.keys():
        var key: String = str(key_value)
        if framing.has(key):
            result[key] = framing.get(key)

    # zoom=1 means "fit the whole source image into the battle height". Values
    # only slightly above 1 give a restrained crop. The old COVER-only behavior
    # effectively required roughly twice that zoom for the current 4:3 artwork.
    result["zoom"] = clampf(float(result.get("zoom", 1.18)), 1.0, 1.6)
    result["focus_x"] = clampf(float(result.get("focus_x", 0.5)), 0.0, 1.0)
    result["focus_y"] = clampf(float(result.get("focus_y", 0.5)), 0.0, 1.0)
    result["offset_x"] = float(result.get("offset_x", 0.0))
    result["offset_y"] = float(result.get("offset_y", 0.0))
    return result


func _sync_visible_battle_background(area: Control) -> void:
    if _active_battle_background_layer == null:
        return
    _active_battle_background_layer.position = area.position
    _active_battle_background_layer.size = area.size
    if _active_battle_background_rect != null:
        _active_battle_background_rect.position = Vector2.ZERO
        _active_battle_background_rect.size = area.size
    if _active_battle_focus_rect != null and _active_battle_focus_rect.texture != null:
        _layout_battle_focus(_active_battle_focus_rect.texture)


func _update_visible_battle_background() -> void:
    if _active_battle_background_rect == null or _active_battle_focus_rect == null:
        return

    var texture_value: Resource = load(battle_background_path)
    if not (texture_value is Texture2D):
        push_error("Kampfhintergrund konnte nicht geladen werden: " + battle_background_path)
        return

    var texture: Texture2D = texture_value as Texture2D
    _active_battle_background_rect.texture = texture
    _active_battle_focus_rect.texture = texture
    _layout_battle_focus(texture)


func _layout_battle_focus(texture: Texture2D) -> void:
    if _active_battle_background_layer == null or _active_battle_focus_rect == null:
        return

    var area_size: Vector2 = _active_battle_background_layer.size
    var texture_size := Vector2(float(texture.get_width()), float(texture.get_height()))
    if area_size.x <= 0.0 or area_size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
        return

    # Start from a contain/fit-height scale instead of COVER. The configurable
    # zoom can then add only a small deliberate crop, never the huge implicit
    # crop caused by the battle strip's very wide aspect ratio.
    var fit_scale: float = minf(area_size.x / texture_size.x, area_size.y / texture_size.y)
    var zoom: float = float(_battle_background_framing.get("zoom", 1.18))
    var render_size: Vector2 = texture_size * fit_scale * zoom

    var focus_x: float = float(_battle_background_framing.get("focus_x", 0.5))
    var focus_y: float = float(_battle_background_framing.get("focus_y", 0.5))
    var offset := Vector2(
        float(_battle_background_framing.get("offset_x", 0.0)),
        float(_battle_background_framing.get("offset_y", 0.0))
    )

    var target_point: Vector2 = area_size * 0.5 + offset
    var source_focus := Vector2(render_size.x * focus_x, render_size.y * focus_y)

    _active_battle_focus_rect.position = target_point - source_focus
    _active_battle_focus_rect.size = render_size


func _load_data() -> void:
    super._load_data()
    _apply_stat_profile_overrides()


func _apply_stat_profile_overrides() -> void:
    var pack: Dictionary = _database_read_json_dictionary(STAT_PROFILE_PATH)
    if pack.is_empty():
        push_error("Statprofil-Datei fehlt oder ist ungültig: " + STAT_PROFILE_PATH)
        return

    var profiles_value: Variant = pack.get("species", {})
    if not (profiles_value is Dictionary):
        push_error("Statprofil-Datei braucht ein species-Dictionary: " + STAT_PROFILE_PATH)
        return
    var profiles: Dictionary = profiles_value

    var runtime_value: Variant = data.get("species", {})
    if not (runtime_value is Dictionary):
        push_error("Statprofile können nicht angewendet werden: Runtime-Spezies fehlen.")
        return
    var runtime_species: Dictionary = runtime_value

    var canonical_value: Variant = _canonical_pack.get("species", {})
    var canonical_species: Dictionary = canonical_value if canonical_value is Dictionary else {}
    var applied: int = 0

    for species_id_value: Variant in profiles.keys():
        var species_id: String = str(species_id_value)
        var stats_value: Variant = profiles.get(species_id, {})
        if not (stats_value is Dictionary):
            push_error("Ungültiges Statprofil für " + species_id)
            continue
        var stats: Dictionary = stats_value

        var complete: bool = true
        for key: String in STAT_KEYS:
            if not stats.has(key):
                push_error("Statprofil " + species_id + " fehlt Wert: " + key)
                complete = false
        if not complete:
            continue

        var normalized_stats: Dictionary = {}
        for key: String in STAT_KEYS:
            normalized_stats[key] = int(stats.get(key, 0))

        var runtime_entry_value: Variant = runtime_species.get(species_id, {})
        if not (runtime_entry_value is Dictionary):
            push_warning("Statprofil verweist auf unbekannte Runtime-Spezies: " + species_id)
            continue
        var runtime_entry: Dictionary = runtime_entry_value
        runtime_entry["base_stats"] = normalized_stats.duplicate(true)
        runtime_species[species_id] = runtime_entry
        applied += 1

        var canonical_entry_value: Variant = canonical_species.get(species_id, {})
        if canonical_entry_value is Dictionary:
            var canonical_entry: Dictionary = canonical_entry_value
            canonical_entry["base_stats"] = normalized_stats.duplicate(true)
            canonical_species[species_id] = canonical_entry

    data["species"] = runtime_species
    _canonical_pack["species"] = canonical_species

    if applied != profiles.size():
        push_error(
            "Statprofile unvollständig angewendet: %d von %d Spezies."
            % [applied, profiles.size()]
        )
