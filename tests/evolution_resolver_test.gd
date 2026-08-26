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
    assert(not bool(evolution.get("requires_player_choice", false)), "Lineare Entwicklung darf keine Auswahl verlangen.")

    _test_canonical_runtime_evolutions(resolver)
    _test_branching_evolutions(resolver)

    print("Evolution resolver tests: OK")
    quit(0)


func _test_canonical_runtime_evolutions(resolver) -> void:
    # Gen-2 entries reach the resolver through the normalized runtime registry.
    # That schema uses target_species_id + level instead of the source-pack keys
    # evolves_into + evolution_level.
    var hoothoot_species: Dictionary = {
        "hoothoot": {
            "evolution": {
                "target_species_id": "noctowl",
                "level": 20,
                "mandatory": true
            }
        },
        "noctowl": {}
    }

    assert(
        resolver.resolve_species_for_level("hoothoot", 19, hoothoot_species) == "hoothoot",
        "Hoothoot muss vor Level 20 Hoothoot bleiben."
    )
    assert(
        resolver.resolve_species_for_level("hoothoot", 20, hoothoot_species) == "noctowl",
        "Hoothoot muss mit Runtime-Evolutionsdaten ab Level 20 zu Noctuh werden."
    )

    var hoothoot_evolution: Dictionary = resolver.required_level_evolution(
        "hoothoot",
        20,
        hoothoot_species
    )
    assert(
        str(hoothoot_evolution.get("target_species_id", "")) == "noctowl",
        "Die Etappen-Entwicklung muss Noctuh als verpflichtendes Ziel erhalten."
    )

    var gen2_starter_species: Dictionary = {
        "chikorita": {
            "evolution": {
                "target_species_id": "bayleef",
                "level": 16,
                "mandatory": true
            }
        },
        "bayleef": {
            "evolution": {
                "target_species_id": "meganium",
                "level": 32,
                "mandatory": true
            }
        },
        "meganium": {}
    }
    assert(
        resolver.resolve_species_for_level("chikorita", 15, gen2_starter_species) == "chikorita",
        "Endivie muss vor Level 16 Endivie bleiben."
    )
    assert(
        resolver.resolve_species_for_level("chikorita", 16, gen2_starter_species) == "bayleef",
        "Endivie muss ab Level 16 zu Lorblatt werden."
    )
    assert(
        resolver.resolve_species_for_level("chikorita", 50, gen2_starter_species) == "meganium",
        "Ein Gen-2-Starter muss auf Level 50 bis zur korrekten Endentwicklung aufgelöst werden."
    )


func _test_branching_evolutions(resolver) -> void:
    # Generic fixture on purpose: branching support must not be hard-coded to
    # Eevee, Tyrogue, Gloom, Poliwhirl, Scyther or any other specific family.
    var branching_species: Dictionary = {
        "branch_base": {
            "evolution": {
                "method": "level",
                "evolution_level": 20,
                "choices": [
                    {"target": "branch_a"},
                    {"target": "branch_b"},
                    {"target": "branch_c"}
                ]
            }
        },
        "branch_a": {},
        "branch_b": {},
        "branch_c": {}
    }

    assert(
        resolver.evolution_choices_for_level("branch_base", 19, branching_species).is_empty(),
        "Vor dem Entwicklungslevel darf noch keine Verzweigung angeboten werden."
    )

    var choices: Array = resolver.evolution_choices_for_level("branch_base", 20, branching_species)
    assert(choices.size() == 3, "Alle drei Entwicklungsziele müssen angeboten werden.")
    assert(
        resolver.requires_player_evolution_choice("branch_base", 20, branching_species),
        "Mehrere Ziele müssen zwingend eine Spielerwahl auslösen."
    )

    var branch_evolution: Dictionary = resolver.required_level_evolution(
        "branch_base",
        20,
        branching_species
    )
    assert(
        bool(branch_evolution.get("requires_player_choice", false)),
        "Verzweigte Entwicklung muss als Spielerwahl markiert sein."
    )
    assert(
        str(branch_evolution.get("target_species_id", "")).is_empty(),
        "Bei mehreren Zielen darf der Resolver niemals stillschweigend eines auswählen."
    )
    assert(
        resolver.resolve_species_for_level("branch_base", 20, branching_species).is_empty(),
        "Automatische Level-Auflösung darf eine Verzweigung nicht zufällig/implizit entscheiden."
    )

    assert(
        resolver.resolve_player_evolution_choice(
            "branch_base",
            "branch_b",
            20,
            branching_species
        ) == "branch_b",
        "Eine explizite gültige Spielerwahl muss akzeptiert werden."
    )
    assert(
        resolver.resolve_player_evolution_choice(
            "branch_base",
            "not_a_branch",
            20,
            branching_species
        ).is_empty(),
        "Ein Ziel außerhalb der angebotenen Verzweigung muss abgelehnt werden."
    )
    assert(
        resolver.resolve_species_for_level(
            "branch_base",
            20,
            branching_species,
            {"branch_base": "branch_b"}
        ) == "branch_b",
        "Mit explizit gewähltem Ziel muss die Kette deterministisch aufgelöst werden."
    )

    var missing_target_species: Dictionary = branching_species.duplicate(true)
    missing_target_species.erase("branch_c")
    var choices_with_missing_target: Array = resolver.evolution_choices_for_level(
        "branch_base",
        20,
        missing_target_species
    )
    assert(choices_with_missing_target.size() == 3, "Definierte Zweige dürfen nicht still verschwinden.")
    assert(
        not bool((choices_with_missing_target[2] as Dictionary).get("target_available", true)),
        "Ein noch nicht implementiertes Ziel muss als nicht verfügbar markiert werden."
    )
    assert(
        resolver.resolve_player_evolution_choice(
            "branch_base",
            "branch_c",
            20,
            missing_target_species
        ).is_empty(),
        "Ein noch nicht implementiertes Ziel darf nicht ausgewählt werden können."
    )
