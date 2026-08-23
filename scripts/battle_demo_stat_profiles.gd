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

var _active_battle_background_rect: TextureRect = null


func _build_battle(root: Control) -> void:
    # Use the landscape system's meadow as the initial fallback. The route can
    # replace this path at runtime through set_battle_background().
    battle_background_path = ACTIVE_BATTLE_BACKGROUND_PATH
    super._build_battle(root)

    # IMPORTANT: battle_demo_hd.gd creates a full-screen turquoise ColorRect
    # before BattleArea. A background placed as a child of BattleArea can end up
    # behind that sibling because of CanvasItem z-ordering. Install the arena as
    # its own battle_panel sibling immediately BEFORE BattleArea instead. This
    # makes the draw order unambiguous: fallback -> arena -> Pokemon/UI.
    var area: Control = battle_panel.get_node_or_null("BattleArea") as Control
    if area == null:
        push_error("BattleArea fehlt; Kampfhintergrund konnte nicht eingebaut werden.")
        return

    # Disable the old child background so there is only one authoritative image.
    if _battle_background_rect != null:
        _battle_background_rect.visible = false

    # Hide the turquoise full-screen fallback created by battle_demo_hd.gd.
    if battle_panel.get_child_count() > 0:
        var first_child: Node = battle_panel.get_child(0)
        if first_child is ColorRect:
            (first_child as ColorRect).visible = false

    var arena_texture: Texture2D = load(battle_background_path) as Texture2D
    if arena_texture == null:
        push_error("Kampfhintergrund konnte nicht geladen werden: " + battle_background_path)
        return

    _active_battle_background_rect = TextureRect.new()
    _active_battle_background_rect.name = "ActiveBattleBackground"
    _active_battle_background_rect.position = area.position
    _active_battle_background_rect.size = area.size
    _active_battle_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _active_battle_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _active_battle_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _active_battle_background_rect.texture = arena_texture
    battle_panel.add_child(_active_battle_background_rect)

    # Put it directly before BattleArea in sibling order. No negative z-index,
    # no cross-parent ordering assumptions.
    battle_panel.move_child(_active_battle_background_rect, area.get_index())


func set_battle_background(path: String) -> void:
    # The reusable presentation layer owns validation and the canonical path.
    # Keep the visible sibling arena in sync as well. Previously only the hidden
    # BattleArea child was updated, while this visible rect stayed hardcoded to
    # the old meadow_grassland_day.webp image.
    super.set_battle_background(path)
    if battle_background_path != path or _active_battle_background_rect == null:
        return

    var texture_value: Resource = load(battle_background_path)
    if texture_value is Texture2D:
        _active_battle_background_rect.texture = texture_value as Texture2D


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