extends SceneTree

const EvolutionResolverScript = preload("res://scripts/evolution_resolver.gd")


func _initialize() -> void:
    var resolver = EvolutionResolverScript.new()

    var complete_species: Dictionary = {
        "caterpie": {},
        "metapod": {},
        "butterfree": {}
    }

    assert(
        resolver.resolve_species_for_level("caterpie", 6, complete_species) == "caterpie",
        "Raupy muss bis einschließlich Level 6 Raupy bleiben."
    )
    assert(
        resolver.resolve_species_for_level("caterpie", 7, complete_species) == "metapod",
        "Raupy muss ab Level 7 zwingend Safcon sein."
    )
    assert(
        resolver.resolve_species_for_level("caterpie", 9, complete_species) == "metapod",
        "Level 9 der Raupy-Reihe muss Safcon sein."
    )
    assert(
        resolver.resolve_species_for_level("caterpie", 10, complete_species) == "butterfree",
        "Ab Level 10 muss die Raupy-Reihe Smettbo sein."
    )

    var incomplete_species: Dictionary = {"caterpie": {}}
    assert(
        resolver.resolve_species_for_level("caterpie", 8, incomplete_species).is_empty(),
        "Fehlt Safcon als Spieldatensatz, darf kein Raupy Level 8 als Ersatz erzeugt werden."
    )

    var evolution: Dictionary = resolver.required_level_evolution("caterpie", 7, complete_species)
    assert(bool(evolution.get("mandatory", false)), "Level-Entwicklungen müssen verpflichtend sein.")
    assert(str(evolution.get("target_species_id", "")) == "metapod", "Ziel auf Level 7 muss Safcon sein.")

    print("Evolution resolver tests: OK")
    quit(0)
