extends SceneTree

const PvpBattleScript = preload("res://scripts/battle_demo_pvp_active_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = PvpBattleScript.new()
    root.add_child(lab)

    # Owned Pokemon keep explicit branch choice, generated Pokemon get a random
    # valid endpoint. Eevee is the strongest regression fixture because all
    # eight branches must remain reachable without multiplying family weight.
    var eevee_options: Array = lab.route_generated_species_options_for_level("eevee", 30)
    var expected_eevee_options: Array[String] = [
        "vaporeon",
        "jolteon",
        "flareon",
        "espeon",
        "umbreon",
        "leafeon",
        "glaceon",
        "sylveon"
    ]
    _check(eevee_options.size() == expected_eevee_options.size(), "Evoli muss auf Level 30 alle acht System-Entwicklungen besitzen.")
    for species_id: String in expected_eevee_options:
        _check(eevee_options.has(species_id), "Evoli-Systemzweig fehlt im PvP/Generator: %s" % species_id)
    _check(
        lab.route_resolve_species_for_level("eevee", 30).is_empty(),
        "Ein eigenes Evoli darf trotz System-Zufall weiterhin keine Entwicklung ohne Spielerwahl erhalten."
    )

    var seen_generated_eevee: Dictionary = {}
    for _sample: int in range(128):
        var generated_id: String = lab.route_resolve_generated_species_for_level("eevee", 30)
        _check(eevee_options.has(generated_id), "Systemgenerierung darf nur einen gültigen Evoli-Zweig wählen.")
        if not generated_id.is_empty():
            seen_generated_eevee[generated_id] = true
    _check(seen_generated_eevee.size() > 1, "Systemgenerierung darf bei Evoli nicht auf einen einzigen festen Zweig verdrahtet sein.")

    var scyther_options: Array = lab.route_generated_species_options_for_level("scyther", 50)
    _check(scyther_options.has("scyther"), "Sichlor muss ohne erfundenes Entwicklungslevel systemgenerierbar bleiben.")
    _check(scyther_options.has("scizor"), "Scherox muss über den vollständigen Sichlor-Familienlink systemgenerierbar sein.")
    _check(scyther_options.has("kleavor"), "Axantor muss über den vollständigen Sichlor-Familienlink systemgenerierbar sein.")

    # The global Gen-1-family registry is independent from move implementation.
    # Every family remains registered even while later move batches are still
    # incomplete; actual combat falls back to Verzweifler where necessary.
    _check(lab.species_ids.size() == 78, "Der globale Roster muss alle 78 vollständigen Gen-1-Familien enthalten.")

    # Across the complete Level 1-100 range every registered species must be a
    # possible concrete system result of one route family. This catches future
    # branch/data additions that would otherwise silently disappear from enemy,
    # capture and PvP generation.
    var generated_reachable: Dictionary = {}
    for generated_level: int in range(1, 101):
        for root_value: Variant in lab.species_ids:
            var generated_options: Array = lab.route_generated_species_options_for_level(
                str(root_value),
                generated_level
            )
            for option_value: Variant in generated_options:
                generated_reachable[str(option_value)] = true

    var all_species_value: Variant = lab.data.get("species", {})
    _check(all_species_value is Dictionary, "Die vollständige Speziesdatenbank muss für den Erreichbarkeitstest geladen sein.")
    if all_species_value is Dictionary:
        var all_species: Dictionary = all_species_value
        _check(
            generated_reachable.size() == all_species.size(),
            "Systemgenerierung muss über Level 1-100 alle registrierten Pokémon erreichen können: %d/%d."
            % [generated_reachable.size(), all_species.size()]
        )
        for species_id_value: Variant in all_species.keys():
            var registered_id: String = str(species_id_value)
            _check(
                generated_reachable.has(registered_id),
                "Registriertes Pokémon ist für Gegner/Fang/PvP nicht systemgenerierbar: %s" % registered_id
            )

    _check(lab._pvp_species_is_available_at_level("bulbasaur", 15), "Bisasam muss bis Level 15 im PvP-Pool erlaubt sein.")
    _check(not lab._pvp_species_is_available_at_level("bulbasaur", 16), "Bisasam darf ab seiner Pflichtentwicklung auf Level 16 nicht mehr angeboten werden.")
    _check(lab._pvp_species_is_available_at_level("ivysaur", 16), "Bisaknosp muss ab Level 16 im PvP-Pool erlaubt sein.")
    _check(not lab._pvp_species_is_available_at_level("ivysaur", 32), "Bisaknosp darf ab der Pflichtentwicklung auf Level 32 nicht mehr angeboten werden.")
    _check(lab._pvp_species_is_available_at_level("vaporeon", 50), "Aquana muss als möglicher Evoli-Systemzweig im PvP erreichbar sein.")
    _check(lab._pvp_species_is_available_at_level("sylveon", 50), "Feelinara muss als möglicher Evoli-Systemzweig im PvP erreichbar sein.")

    var catalog: Array = lab.pvp_catalog(50)
    _check(catalog.size() >= 6, "PvP braucht auf Level 50 mindestens sechs Pokémon, damit jeder Pick drei unterschiedliche Optionen behalten kann.")
    if catalog.size() < 6:
        _finish(lab)
        return

    # PvP has no encounter/catch rarity weighting. Every registered species form
    # that is valid at the selected level must occur exactly once, regardless of
    # whether its regular move implementation is complete. Missing usable moves
    # are represented by the global Verzweifler fallback instead of filtering
    # the Pokemon out of the catalog.
    var catalog_ids: Dictionary = {}
    var catalog_moves_by_id: Dictionary = {}
    for entry_value: Variant in catalog:
        _check(entry_value is Dictionary, "Jeder PvP-Katalogeintrag muss ein Dictionary sein.")
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var entry_id: String = str(entry.get("id", ""))
        _check(not entry_id.is_empty(), "Jeder PvP-Katalogeintrag braucht eine Pokémon-ID.")
        _check(not catalog_ids.has(entry_id), "Jedes Pokémon darf im PvP-Katalog nur einmal vorkommen: %s" % entry_id)
        catalog_ids[entry_id] = true
        var moves_value: Variant = entry.get("moves", [])
        _check(moves_value is Array and not (moves_value as Array).is_empty(), "Jeder angebotene PvP-Kandidat braucht mindestens eine effektive Kampfattacke oder Verzweifler.")
        catalog_moves_by_id[entry_id] = (moves_value as Array).duplicate() if moves_value is Array else []

    var expected_catalog_ids: Dictionary = {}
    var expected_struggle_ids: Dictionary = {}
    if all_species_value is Dictionary:
        var all_species_for_catalog: Dictionary = all_species_value
        for species_id_value: Variant in all_species_for_catalog.keys():
            var species_id: String = str(species_id_value)
            if not lab._pvp_species_is_available_at_level(species_id, 50):
                continue

            expected_catalog_ids[species_id] = true

            var probe: Dictionary = lab._make_combatant(
                "player",
                0,
                {"species_id": species_id, "level": 50}
            )
            var normal_moves: Array = lab._database_normal_battle_moves(probe.get("moves", []))
            if normal_moves.is_empty():
                expected_struggle_ids[species_id] = true

    _check(
        catalog_ids.size() == expected_catalog_ids.size(),
        "PvP muss auf Level 50 jedes levelgültige Pokémon genau einmal aufnehmen, unabhängig vom Attacken-Implementierungsstand: %d/%d."
        % [catalog_ids.size(), expected_catalog_ids.size()]
    )
    for expected_id_value: Variant in expected_catalog_ids.keys():
        var expected_id: String = str(expected_id_value)
        _check(catalog_ids.has(expected_id), "Levelgültiges Pokémon fehlt im gleichgewichteten PvP-Pool: %s" % expected_id)

    for fallback_id_value: Variant in expected_struggle_ids.keys():
        var fallback_id: String = str(fallback_id_value)
        var listed_moves_value: Variant = catalog_moves_by_id.get(fallback_id, [])
        var listed_moves: Array = listed_moves_value if listed_moves_value is Array else []
        _check(
            listed_moves == ["Verzweifler"],
            "Pokémon ohne regulär nutzbare Attacke muss im PvP mit Verzweifler bleiben: %s" % fallback_id
        )

    var team_one: Array = []
    var team_two: Array = []
    for index: int in range(4):
        team_one.append(str((catalog[index] as Dictionary).get("id", "")))
        team_two.append(str((catalog[catalog.size() - 1 - index] as Dictionary).get("id", "")))

    var started: bool = lab.start_pvp_battle(team_one, team_two, 50)
    _check(started, "Ein vollständiger 4-gegen-4-PvP-Draft muss den Kampf starten können.")
    _check(lab.pvp_mode, "Nach PvP-Start muss der PvP-Controller aktiv sein.")
    _check(lab.player_team.size() == 4 and lab.enemy_team.size() == 4, "PvP muss exakt vier Pokémon pro Seite erzeugen.")

    for combatant_value: Variant in lab.player_team + lab.enemy_team:
        if combatant_value is Dictionary:
            _check(int((combatant_value as Dictionary).get("level", 0)) == 50, "Das gemeinsame PvP-Level muss für alle acht Pokémon gelten.")

    # Runde 0 gehört separat zum Hot-Seat-Fluss. Für diesen Controller-Test wird
    # sie beendet, damit direkt geprüft werden kann, dass die linke Seite keinen
    # KI-Zug mehr ausführt, sondern dieselbe menschliche Aktionsauswahl öffnet.
    lab.opening_phase_active = false
    lab._pvp_collecting_enemy_opening = false
    lab._hide_pvp_handoff()
    lab.paused = false
    lab.selected_actor = {}

    var enemy_actor: Dictionary = lab.enemy_team[0]
    enemy_actor["atb"] = 100.0
    lab._enemy_act(enemy_actor)
    _check(lab.paused, "Im aktiven PvP muss Spieler 2 den Timeflow während seiner Auswahl pausieren.")
    _check(str(lab.selected_actor.get("id", "")) == str(enemy_actor.get("id", "")), "Die Gegenseite muss im aktiven PvP als menschlich gesteuerter Akteur ausgewählt werden.")

    # Runde 0 darf die zweite Seite nicht per KI entscheiden. Nach Spieler 1
    # muss stattdessen zuerst ein neutraler Übergabebildschirm erscheinen.
    var opening_move_id: String = "pvp_opening_handoff_test"
    (lab.data.get("moves", {}) as Dictionary)[opening_move_id] = {
        "id": opening_move_id,
        "name": "PvP-Eröffnungstest",
        "type": "normal",
        "category": "status",
        "power": null,
        "accuracy": null,
        "ap": 8,
        "target": "self",
        "opening": true,
        "opening_only": true,
        "mechanics": []
    }
    enemy_actor["moves"] = [opening_move_id]
    lab.opening_phase_active = true
    lab.paused = true
    lab.selected_actor = {}
    lab._opening_player_candidates = []
    lab._opening_enemy_candidates = [enemy_actor]
    lab._opening_player_index = 0
    lab._opening_choices.clear()
    lab._pvp_collecting_enemy_opening = false
    lab._prompt_next_opening_actor()
    _check(lab._pvp_collecting_enemy_opening, "Nach Spieler 1 muss Runde 0 in die menschliche Auswahl von Spieler 2 wechseln.")
    _check(lab._pvp_handoff_overlay != null and lab._pvp_handoff_overlay.visible, "Vor Spieler 2 muss der neutrale Controller-Übergabebildschirm sichtbar sein.")
    lab._on_pvp_handoff_confirmed()
    _check(not lab._pvp_handoff_overlay.visible, "Nach der Übergabe muss der neutrale Bildschirm verschwinden.")
    _check(lab.log_label != null and lab.log_label.text.contains("SPIELER 2"), "Die Runde-0-Auswahl muss Spieler 2 klar als handelnde Person anzeigen.")

    lab.cancel_pvp_mode()
    _check(not lab.pvp_mode and not lab.opening_phase_active, "Ein Wechsel ins Hauptmenü muss jeden PvP-/Runde-0-Zustand vollständig beenden.")
    _check(lab._pvp_handoff_overlay != null and not lab._pvp_handoff_overlay.visible, "Beim Verlassen von PvP darf kein Übergabebildschirm aktiv bleiben.")

    lab.open_config()
    _check(not lab.pvp_mode, "Das normale Kampflabor muss beim Öffnen der Konfiguration wieder im KI/Testmodus sein.")
    _check(lab.config_panel != null and lab.config_panel.visible, "Die bestehende Testkampf-Konfiguration muss nach PvP weiterhin verfügbar sein.")

    _finish(lab)


func _finish(lab: Node) -> void:
    lab.queue_free()
    if failures == 0:
        print("PvP flow regression test: PASS")
        quit(0)
    else:
        push_error("PvP flow regression test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
