extends SceneTree

const RouteScript = preload("res://scripts/demo_route_landscape_weighting_v1.gd")


class FakeBattleDemo:
    extends Node

    func route_species_ids_for_level(_level: int) -> Array:
        # Vulkan bevorzugt Feuer, schließt Käfer aus. Arktos ist legendär und
        # muss bereits durch den Standard-Bossfilter entfernt werden.
        return ["charmander", "caterpie", "articuno"]

    func route_species_types(species_id: String) -> Array:
        match species_id:
            "charmander":
                return ["fire"]
            "caterpie":
                return ["bug"]
            "articuno":
                return ["ice", "flying"]
            _:
                return []


func _initialize() -> void:
    var route = RouteScript.new()
    var battle_demo = FakeBattleDemo.new()
    route.battle_demo = battle_demo
    route.team = [
        {"species_id": "bulbasaur", "level": 15, "hp": 40, "max_hp": 40}
    ]
    route.current_landscape_id = "volcano"
    route._tf_load_landscape_registry()

    for milestone_stage: int in [20, 40, 60, 80]:
        route.stage = milestone_stage

        assert(
            route._is_milestone_double_boss_stage(milestone_stage),
            "Etappe %d muss als Doppelboss-Etappe markiert sein." % milestone_stage
        )
        assert(
            not route._route_event_pool_for_stage(milestone_stage).has(route.EVENT_RARE),
            "Etappe %d darf keine zusätzliche Besondere Begegnung anbieten." % milestone_stage
        )

        var party: Array = route._enemy_party_for_stage(milestone_stage)
        assert(
            party.size() == 2,
            "Etappe %d muss exakt zwei Milestone-Bosse erzeugen." % milestone_stage
        )

        for boss_value: Variant in party:
            assert(boss_value is Dictionary, "Jeder Milestone-Boss muss ein Dictionary sein.")
            var boss: Dictionary = boss_value as Dictionary

            # Im Vulkan ist Käfer x0 und Feuer x3. Da Arktos als legendär aus
            # dem Standardpool fällt, muss die Landschaft beide Picks sicher
            # auf Glumanda lenken. So wird bewiesen, dass auch beide Milestone-
            # Bossauswahlen den aktiven Landschaftsselector benutzen.
            assert(
                str(boss.get("species_id", "")) == "charmander",
                "Vulkan-Doppelboss darf keinen x0-Käfer oder legendären Kandidaten wählen."
            )
            assert(
                int(boss.get("level", 0)) == 20,
                "Milestone-Boss muss fünf Level über dem höchsten Team-Pokémon liegen."
            )
            assert(bool(boss.get("boss", false)), "Milestone-Gegner muss als Boss markiert sein.")
            assert(
                is_equal_approx(float(boss.get("hp_multiplier", 0.0)), 2.0),
                "Milestone-Boss muss den Standardwert 2x KP behalten."
            )
            assert(
                int(boss.get("hp_bars", 0)) == 2,
                "Milestone-Boss muss zwei KP-Balken behalten."
            )
            assert(
                bool(boss.get("milestone_double_boss", false)),
                "Milestone-Bossmarker muss erhalten bleiben."
            )

    # Der Test darf den gewählten Landschaftszustand nicht verändern.
    assert(
        route.current_landscape_id == "volcano",
        "Milestone-Bossauswahl darf die aktuelle Landschaft nicht verändern."
    )

    route.free()
    battle_demo.free()
    print("Route milestone landscape boss test: OK")
    quit(0)
