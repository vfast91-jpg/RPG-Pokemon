extends SceneTree

const PvpBattleScript = preload("res://scripts/battle_demo_pvp.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = PvpBattleScript.new()
    root.add_child(lab)

    _check(lab._pvp_species_is_available_at_level("bulbasaur", 15), "Bisasam muss bis Level 15 im PvP-Pool erlaubt sein.")
    _check(not lab._pvp_species_is_available_at_level("bulbasaur", 16), "Bisasam darf ab seiner Pflichtentwicklung auf Level 16 nicht mehr angeboten werden.")
    _check(lab._pvp_species_is_available_at_level("ivysaur", 16), "Bisaknosp muss ab Level 16 im PvP-Pool erlaubt sein.")
    _check(not lab._pvp_species_is_available_at_level("ivysaur", 32), "Bisaknosp darf ab der Pflichtentwicklung auf Level 32 nicht mehr angeboten werden.")

    var catalog: Array = lab.pvp_catalog(50)
    _check(catalog.size() >= 6, "PvP braucht auf Level 50 mindestens sechs spielbare Pokémon, damit jeder Pick drei unterschiedliche Optionen behalten kann.")
    if catalog.size() < 6:
        _finish(lab)
        return

    for entry_value: Variant in catalog:
        _check(entry_value is Dictionary, "Jeder PvP-Katalogeintrag muss ein Dictionary sein.")
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        var moves_value: Variant = entry.get("moves", [])
        _check(moves_value is Array and not (moves_value as Array).is_empty(), "Jeder angebotene PvP-Kandidat braucht mindestens eine normale Kampfattacke.")

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
    _check(lab.paused, "Im PvP muss Spieler 2 den Timeflow während seiner Auswahl pausieren.")
    _check(str(lab.selected_actor.get("id", "")) == str(enemy_actor.get("id", "")), "Die Gegenseite muss im PvP als menschlich gesteuerter aktiver Akteur ausgewählt werden.")

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
