extends SceneTree

const ActiveRouteScript = preload("res://scripts/demo_route_boss_gauntlet_test_v1.gd")
const ActiveBattleScript = preload("res://scripts/battle_demo_endgame_atb_v1.gd")
const BossRules = preload("res://scripts/route_boss_rules.gd")

var failures: int = 0


class FakeBattleDemo:
    extends Node

    var data: Dictionary = {
        "species": {
            "articuno": {"name": "Arktos", "types": ["ice", "flying"]},
            "groudon": {"name": "Groudon", "types": ["ground"]},
            "kyogre": {"name": "Kyogre", "types": ["water"]},
            "rayquaza": {"name": "Rayquaza", "types": ["dragon", "flying"]},
            "mewtwo": {"name": "Mewtu", "types": ["psychic"]}
        }
    }
    var last_background_path: String = ""
    var last_framing: Dictionary = {}

    func set_battle_background_framed(path: String, framing: Dictionary) -> bool:
        last_background_path = path
        last_framing = framing.duplicate(true)
        return true

    func set_battle_background(path: String) -> bool:
        last_background_path = path
        return true


func _initialize() -> void:
    var route = ActiveRouteScript.new()
    var battle_demo = FakeBattleDemo.new()
    route.battle_demo = battle_demo
    route._tf_load_landscape_registry()

    # Normal route and 91-95 must keep their selected route landscape. The new
    # encounter-only helper is strictly disabled outside legendary stages.
    route.current_landscape_id = "city"
    route.stage = 50
    _check(
        not route._tf_apply_legendary_endgame_battle_landscape_for_species(50, "articuno"),
        "Normale Kämpfe dürfen keinen legendären Landschafts-Override erhalten."
    )
    _check(route.current_landscape_id == "city", "Normale Kämpfe müssen die Routenlandschaft behalten.")

    for stage_value: int in [91, 92, 93, 94, 95]:
        route.stage = stage_value
        route.current_landscape_id = "city"
        battle_demo.last_background_path = ""
        _check(
            not route._tf_apply_legendary_endgame_battle_landscape_for_species(stage_value, "articuno"),
            "Etappe %d darf keinen legendären Landschafts-Override erhalten." % stage_value
        )
        _check(
            route.current_landscape_id == "city",
            "Etappe %d muss die aktuell gewählte Routenlandschaft behalten." % stage_value
        )
        _check(
            battle_demo.last_background_path.is_empty(),
            "Etappe %d darf den bestehenden Kampfhintergrund nicht ersetzen." % stage_value
        )

    # Type metadata determines the legendary battle location. Exclusions are
    # absolute, preferred types score stronger than rare types, ties are stable.
    route.stage = 96
    route.current_landscape_id = "city"
    var articuno_landscape: String = route._tf_legendary_landscape_id_for_species("articuno")
    _check(articuno_landscape == "tundra", "Arktos soll durch Ice+Flying stabil in der Tundra landen.")
    _check(articuno_landscape != "city", "Arktos darf niemals in der ausgeschlossenen Stadt landen.")

    for _repeat: int in range(20):
        _check(
            route._tf_legendary_landscape_id_for_species("articuno") == articuno_landscape,
            "Legendäre Landschaftsauswahl muss deterministisch bleiben."
        )

    _check(
        route._tf_apply_legendary_endgame_battle_landscape_for_species(96, "articuno"),
        "Arktos-Hintergrund konnte nicht angewendet werden."
    )
    _check(
        route.current_landscape_id == "city",
        "Legendäre Battle-Landschaft darf die gespeicherte Routenlandschaft nicht überschreiben."
    )
    var articuno_definition: Dictionary = route.route_landscape(articuno_landscape)
    _check(
        battle_demo.last_background_path == str(articuno_definition.get("background", "")),
        "Legendärer Kampfhintergrund muss aus landscapes_v1.json stammen."
    )
    _check(
        battle_demo.last_framing == (articuno_definition.get("battle_framing", {}) as Dictionary),
        "Legendärer Kampfhintergrund muss sein vorhandenes battle_framing übernehmen."
    )

    _check(
        route._tf_legendary_landscape_id_for_species("groudon") == "volcano",
        "Groudon braucht den kleinen ikonischen Vulkan-Override."
    )
    _check(
        ["coast", "glacier", "lakeshore"].has(route._tf_legendary_landscape_id_for_species("kyogre")),
        "Kyogre muss in einer der bestbewerteten Wasserlandschaften landen."
    )
    _check(
        route._tf_legendary_landscape_id_for_species("rayquaza") == "mystic",
        "Rayquaza braucht den kleinen ikonischen Mystik-Override."
    )
    _check(
        route._tf_legendary_landscape_id_for_species("mewtwo") == "mystic",
        "Mewtu soll typbasiert einen mystisch-psychischen Ort erhalten."
    )

    # A rebuild/reload does not need a saved landscape ID: the same species plus
    # the static registry deterministically resolves to the same location again.
    var rebuilt_route = ActiveRouteScript.new()
    var rebuilt_battle = FakeBattleDemo.new()
    rebuilt_route.battle_demo = rebuilt_battle
    rebuilt_route._tf_load_landscape_registry()
    rebuilt_route.stage = 96
    _check(
        rebuilt_route._tf_legendary_landscape_id_for_species("articuno") == articuno_landscape,
        "Neu aufgebauter Kampf muss dieselbe legendäre Landschaft wählen."
    )

    # Player-facing 96-100 terminology contains no Boss/Superboss labels.
    _check(
        route.LEGENDARY_ENDGAME_HEADING.to_lower().find("boss") == -1,
        "Legendärer Heading darf kein Boss-Wording enthalten."
    )
    _check(
        route.LEGENDARY_ENDGAME_BUTTON_TEXT.to_lower().find("boss") == -1,
        "Legendärer Herausforderungsbutton darf kein Boss-Wording enthalten."
    )
    var sanitized_transition: String = route._tf_legendary_visible_message(
        "Der nächste Superboss wartet. Bosskampf bereit."
    )
    _check(
        sanitized_transition.to_lower().find("boss") == -1,
        "Legendäre Übergangstexte müssen Boss/Superboss vollständig entfernen."
    )

    var battle = ActiveBattleScript.new()
    var legendary_card_name: String = battle._legendary_endgame_name_text({
        "name": "Arktos",
        "level": 100,
        "boss": true,
        "legendary_endgame": true
    })
    _check(
        legendary_card_name.to_lower().find("boss") == -1 and legendary_card_name.contains("LEGENDÄR"),
        "Legendäre Kampfkarte darf trotz internem boss=true kein BOSS-Label zeigen."
    )

    # Technical boss mechanics and the separate endgame balance remain intact.
    var stage_91_profile: Dictionary = BossRules.boss_profile_for_stage(91)
    var stage_96_profile: Dictionary = BossRules.boss_profile_for_stage(96)
    _check(not bool(stage_91_profile.get("legendary_stage", true)), "Etappe 91 muss technisch nicht-legendär bleiben.")
    _check(bool(stage_96_profile.get("legendary_stage", false)), "Etappe 96 muss technisch legendär bleiben.")
    _check(is_equal_approx(float(stage_96_profile.get("hp_multiplier", 0.0)), 4.0), "Legendäres Pokémon muss 4x KP behalten.")
    _check(int(stage_96_profile.get("hp_bars", 0)) == 4, "Legendäres Pokémon muss vier KP-Leisten behalten.")
    _check(float(stage_96_profile.get("atb_rate_multiplier", 0.0)) > 0.0, "Legendäres ATB-Profil muss erhalten bleiben.")

    var active_route_text: String = FileAccess.get_file_as_string("res://scripts/demo_route_boss_gauntlet_test_v1.gd")
    _check(active_route_text.contains("\"boss\": true"), "Aktive Route muss intern boss=true weiterhin setzen.")
    _check(active_route_text.contains("legendary_endgame"), "Aktive Route muss das Präsentationsflag an BattleDemo weiterreichen.")
    _check(active_route_text.contains("heading = LEGENDARY_ENDGAME_HEADING"), "Legendäre Kämpfe müssen den Boss-Heading vor BattleDemo ersetzen.")

    route.free()
    battle_demo.free()
    rebuilt_route.free()
    rebuilt_battle.free()
    battle.free()

    if failures == 0:
        print("Legendary landscape/UI regression test: PASS")
        quit(0)
    else:
        push_error("Legendary landscape/UI regression test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
