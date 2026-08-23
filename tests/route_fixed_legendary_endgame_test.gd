extends SceneTree

const RouteScript = preload("res://scripts/demo_route_endgame_legendary_landscapes_v1.gd")
const BossRules = preload("res://scripts/route_boss_rules.gd")

const EXPECTED: Dictionary = {
    96: {"species_id": "articuno", "display_name": "Arktos", "landscape_id": "glacier"},
    97: {"species_id": "zapdos", "display_name": "Zapdos", "landscape_id": "industry"},
    98: {"species_id": "moltres", "display_name": "Lavados", "landscape_id": "volcano"},
    99: {"species_id": "mew", "display_name": "Mew", "landscape_id": "mystic"},
    100: {"species_id": "mewtwo", "display_name": "Mewtu", "landscape_id": "cave"}
}


class FakeBattleDemo:
    extends Node

    var last_background_path: String = ""

    func set_battle_background(path: String) -> bool:
        last_background_path = path
        return true

    func route_species_is_available(species_id: String) -> bool:
        return ["articuno", "zapdos", "moltres", "mew", "mewtwo"].has(species_id)

    func route_species_ids_for_level(_level: int) -> Array:
        # Für einen festen Endgame-Boss darf dieser Fallback nie gebraucht werden.
        return []


func _initialize() -> void:
    var route = RouteScript.new()
    var battle_demo = FakeBattleDemo.new()
    route.battle_demo = battle_demo
    route._tf_load_landscape_registry()

    # 91-95 bleiben durch Schritt 7 bewusst unverändert: verpflichtende,
    # zufällige nicht-legendäre Superbosse. Diese offene Designentscheidung wird
    # nicht still in diesem Schritt mitverändert.
    for stage_value: int in [91, 92, 93, 94, 95]:
        var early_profile: Dictionary = BossRules.boss_profile_for_stage(stage_value)
        assert(
            str(early_profile.get("species_mode", "")) == "random_non_legendary",
            "Etappe %d muss in Schritt 7 unverändert zufällig nicht-legendär bleiben." % stage_value
        )

    route.current_landscape_id = "meadow"
    assert(
        not route._tf_apply_fixed_endgame_landscape_for_stage(95),
        "Etappe 95 darf noch keine feste legendäre Landschaft erzwingen."
    )
    assert(route.current_landscape_id == "meadow", "Etappe 95 darf die Landschaft nicht verändern.")

    for stage_value: int in [96, 97, 98, 99, 100]:
        var expected: Dictionary = EXPECTED[stage_value]
        var profile: Dictionary = BossRules.boss_profile_for_stage(stage_value)

        assert(str(profile.get("species_mode", "")) == "fixed", "Etappe %d braucht einen festen Boss." % stage_value)
        assert(str(profile.get("species_id", "")) == str(expected.get("species_id", "")), "Falscher legendärer Boss auf Etappe %d." % stage_value)
        assert(str(profile.get("display_name", "")) == str(expected.get("display_name", "")), "Falscher Anzeigename auf Etappe %d." % stage_value)
        assert(str(profile.get("landscape_id", "")) == str(expected.get("landscape_id", "")), "Falsche feste Landschaft auf Etappe %d." % stage_value)
        assert(int(profile.get("level_offset", 0)) == 5, "Legendärer Endgame-Boss muss +5 Level behalten.")
        assert(is_equal_approx(float(profile.get("hp_multiplier", 0.0)), 4.0), "Legendärer Endgame-Boss muss 4x KP behalten.")
        assert(int(profile.get("hp_bars", 0)) == 4, "Legendärer Endgame-Boss muss vier KP-Leisten behalten.")

        route.stage = stage_value
        route.current_landscape_id = "meadow"
        battle_demo.last_background_path = ""
        assert(route._tf_is_fixed_legendary_stage(stage_value), "Etappe %d muss als feste legendäre Etappe erkannt werden." % stage_value)
        assert(route._tf_apply_fixed_endgame_landscape_for_stage(stage_value), "Feste Landschaft konnte auf Etappe %d nicht angewendet werden." % stage_value)
        assert(route.current_landscape_id == str(expected.get("landscape_id", "")), "Aktive Landschaft stimmt auf Etappe %d nicht." % stage_value)

        var landscape: Dictionary = route.route_current_landscape()
        var expected_background: String = str(landscape.get("background", ""))
        assert(not expected_background.is_empty(), "Feste Landschaft auf Etappe %d braucht einen Hintergrund." % stage_value)
        assert(battle_demo.last_background_path == expected_background, "Kampfhintergrund stimmt auf Etappe %d nicht." % stage_value)

        var resolved_species: String = route._endgame_species_for_profile(profile, 77)
        assert(resolved_species == str(expected.get("species_id", "")), "Fester Boss darf auf Etappe %d nicht durch Zufallsgewichtung ersetzt werden." % stage_value)

    route.free()
    battle_demo.free()
    print("Route fixed legendary endgame test: OK")
    quit(0)
