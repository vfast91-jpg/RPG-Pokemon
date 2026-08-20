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

    var starter_species: Dictionary = {
        "charmander": {},
        "charmeleon": {},
        "charizard": {},
        "squirtle": {},
        "wartortle": {},
        "blastoise": {}
    }
    assert(
        resolver.resolve_species_for_level("charmander", 10, starter_species) == "charmander",
        "Glumanda-Familie auf Level 10 muss Glumanda sein."
    )
    assert(
        resolver.resolve_species_for_level("charmander", 18, starter_species) == "charmeleon",
        "Glumanda-Familie auf Level 18 muss Glutexo sein."
    )
    assert(
        resolver.resolve_species_for_level("charmander", 40, starter_species) == "charizard",
        "Glumanda-Familie auf Level 40 muss Glurak sein."
    )
    assert(
        resolver.resolve_species_for_level("squirtle", 10, starter_species) == "squirtle",
        "Schiggy-Familie auf Level 10 muss Schiggy sein; Turtok Level 10 darf nicht entstehen."
    )
    assert(
        resolver.resolve_species_for_level("squirtle", 18, starter_species) == "wartortle",
        "Schiggy-Familie auf Level 18 muss Schillok sein; Turtok Level 18 darf nicht entstehen."
    )
    assert(
        resolver.resolve_species_for_level("squirtle", 40, starter_species) == "blastoise",
        "Schiggy-Familie auf Level 40 muss Turtok sein."
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
