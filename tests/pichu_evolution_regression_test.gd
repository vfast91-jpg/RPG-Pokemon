extends SceneTree

const EvolutionResolverScript = preload("res://scripts/evolution_resolver.gd")
const ActiveRouteScript = preload("res://scripts/demo_route_levelup_evolution_order_fix.gd")

var failures: int = 0


func _initialize() -> void:
    _test_pichu_level_threshold()
    _test_route_progression_queue_reset()

    if failures == 0:
        print("Pichu evolution regression test: PASS")
        quit(0)
    else:
        push_error("Pichu evolution regression test: %d Fehler" % failures)
        quit(1)


func _test_pichu_level_threshold() -> void:
    var resolver = EvolutionResolverScript.new()
    var species: Dictionary = {
        "pichu": {},
        "pikachu": {},
        "raichu": {}
    }

    _check(
        resolver.required_level_evolution("pichu", 14, species).is_empty(),
        "Pichu darf auf Level 14 noch keine Entwicklung auslösen."
    )
    _check(
        resolver.resolve_species_for_level("pichu", 14, species) == "pichu",
        "Pichu muss auf Level 14 Pichu bleiben."
    )

    var evolution: Dictionary = resolver.required_level_evolution("pichu", 15, species)
    _check(
        str(evolution.get("target_species_id", "")) == "pikachu",
        "Pichu muss auf Level 15 Pikachu als verpflichtendes Entwicklungsziel erhalten."
    )
    _check(
        resolver.resolve_species_for_level("pichu", 15, species) == "pikachu",
        "Pichu muss ab Level 15 als Pikachu aufgelöst werden."
    )


func _test_route_progression_queue_reset() -> void:
    var route = ActiveRouteScript.new()

    route._levelup_queue.append({"new_level": 14})
    route._evolution_queue.append({
        "before_species_id": "pichu",
        "after_species_id": "pikachu"
    })
    route._evolution_choice_queue.append({"before_species_id": "pichu"})
    route._active_evolution_choice = {"before_species_id": "pichu"}

    route._reset_progression_presentation_state()

    _check(route._levelup_queue.is_empty(), "Neue Route muss alte Level-Up-Meldungen verwerfen.")
    _check(route._evolution_queue.is_empty(), "Neue Route muss alte Evolutionsmeldungen verwerfen.")
    _check(route._evolution_choice_queue.is_empty(), "Neue Route muss alte Evolutionswahlen verwerfen.")
    _check(route._active_evolution_choice.is_empty(), "Neue Route darf keine alte Evolutionswahl behalten.")

    route.free()


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
