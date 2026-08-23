extends "res://scripts/demo_route_landscape_weighting_v1.gd"

# Schritt 7 des Landschaftssystems:
# Etappen 96-100 sind feste legendäre Ziele. Sie benutzen weder die zufällige
# Landschaftsauswahl noch die normale Begegnungsgewichtung für die Boss-Spezies.
# Die Bossprofile bleiben aber die bestehenden Endgame-Profile: +5 Level,
# vierfache KP und vier vollständige KP-Leisten.

const FixedEndgameBossRules = preload("res://scripts/route_boss_rules.gd")
const FIXED_LEGENDARY_STAGE_START: int = 96
const FIXED_LEGENDARY_STAGE_END: int = 100


func _show_stage_choices(message: String = "") -> void:
    # Die feste Landschaft wird gesetzt, bevor die geerbte Etappenansicht ihren
    # Landschafts-Infokasten baut. Dadurch zeigt auch die Übersicht sofort das
    # korrekte legendäre Ziel an.
    _tf_apply_fixed_endgame_landscape_for_stage(stage)
    super._show_stage_choices(message)

    if not _tf_is_fixed_legendary_stage(stage):
        return

    var profile: Dictionary = FixedEndgameBossRules.boss_profile_for_stage(stage)
    var display_name: String = str(profile.get("display_name", profile.get("species_id", "Legendärer Boss")))
    var landscape_name: String = route_current_landscape_name()
    var level_offset: int = int(profile.get("level_offset", 5))
    var hp_bars: int = maxi(1, int(profile.get("hp_bars", 4)))

    var prefix: String = ""
    if not message.is_empty():
        prefix = message + "\n\n"

    event_label.text = (
        prefix
        + "[b]✨ LEGENDÄRER SUPERBOSS · ETAPPE %d/%d[/b]\n"
        + "Dein nächstes festes Ziel ist [b]%s[/b].\n"
        + "Landschaft: [b]%s[/b].\n\n"
        + "Boss-Regel: höchstes eigenes Pokémon [b]+%d Level[/b] · [b]%d vollständige KP-Leisten[/b]."
    ) % [stage, ENDGAME_ROUTE_STAGE_COUNT, display_name, landscape_name, level_offset, hp_bars]

    # Der geerbte Endgame-Layer erstellt genau einen Herausforderungsbutton.
    # Für die letzten fünf Etappen bekommt er den konkreten Bossnamen.
    for child: Node in path_box.get_children():
        if child is Button:
            var boss_button: Button = child as Button
            boss_button.text = "✨ %s HERAUSFORDERN  →" % display_name.to_upper()
            boss_button.tooltip_text = "Starte den legendären Superboss %s auf Etappe %d." % [display_name, stage]


func _begin_endgame_boss() -> void:
    # Defensive Absicherung: Selbst wenn vor dem Klick irgendeine andere Demo
    # den sichtbaren Hintergrund geändert hat, startet 96-100 im festen Ziel.
    _tf_apply_fixed_endgame_landscape_for_stage(stage)
    super._begin_endgame_boss()


func _tf_is_fixed_legendary_stage(current_stage: int) -> bool:
    if current_stage < FIXED_LEGENDARY_STAGE_START or current_stage > FIXED_LEGENDARY_STAGE_END:
        return false

    var profile: Dictionary = FixedEndgameBossRules.boss_profile_for_stage(current_stage)
    return (
        str(profile.get("species_mode", "")) == "fixed"
        and not str(profile.get("species_id", "")).is_empty()
        and not str(profile.get("landscape_id", "")).is_empty()
    )


func _tf_apply_fixed_endgame_landscape_for_stage(current_stage: int) -> bool:
    if not _tf_is_fixed_legendary_stage(current_stage):
        return false

    var profile: Dictionary = FixedEndgameBossRules.boss_profile_for_stage(current_stage)
    var landscape_id: String = str(profile.get("landscape_id", "")).strip_edges()
    var landscape: Dictionary = route_landscape(landscape_id)
    if landscape.is_empty():
        push_error(
            "Legendärer Endgame-Boss auf Etappe %d verweist auf unbekannte Landschaft '%s'."
            % [current_stage, landscape_id]
        )
        return false

    current_landscape_id = landscape_id
    _tf_landscape_prepared_stage = current_stage
    _tf_apply_current_landscape_background()
    return true
