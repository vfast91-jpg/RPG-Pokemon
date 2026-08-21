extends SceneTree

const CombatLabTmScript = preload("res://scripts/battle_demo_bulbasaur_tm_runtime_audit.gd")

const EXPECTED_BULBASAUR_TMS: Array[String] = [
    "take_down", "charm", "protect", "trailblaze", "facade", "magical_leaf",
    "endure", "sunny_day", "bullet_seed", "sleep_talk", "seed_bomb",
    "grass_knot", "rest", "substitute", "giga_drain", "energy_ball",
    "helping_hand", "grassy_terrain", "grass_pledge", "sludge_bomb",
    "solar_beam"
]

const BULBASAUR_FAMILY: Array[String] = ["bulbasaur", "ivysaur", "venusaur"]

const NEW_MOVE_NAMES: Dictionary = {
    "trailblaze": "Wegbereiter",
    "magical_leaf": "Zauberblatt",
    "bullet_seed": "Kugelsaat",
    "giga_drain": "Gigasauger",
    "energy_ball": "Energieball",
    "facade": "Fassade",
    "endure": "Ausdauer",
    "rest": "Erholung",
    "sleep_talk": "Schlafrede",
    "substitute": "Delegator",
    "grass_knot": "Strauchler",
    "helping_hand": "Rechte Hand",
    "grassy_terrain": "Grasfeld",
    "grass_pledge": "Pflanzensäulen"
}

const REQUIRED_SUMMARY_FRAGMENTS: Dictionary = {
    "take_down": ["Rückstoß", "25 %", "KP-Schadens"],
    "charm": ["Angriff ↓", "Statuswert", "3 Zielaktionen"],
    "protect": ["nächste Feindattacke", "33", "laufende Effekte"],
    "trailblaze": ["Geschwindigkeit ↑", "Statuswert", "3 eigene Aktionen"],
    "facade": ["Stärke 140", "Verbrennung", "Vergiftung", "Paralyse", "Verbrennungs-Angriffsmalus"],
    "magical_leaf": ["keine Genauigkeitsprüfung", "Schutzschild", "Unverwundbarkeit"],
    "endure": ["direkte Feindattacken", "1 KP", "indirekter/eigener Schaden"],
    "sunny_day": ["Sonne 50 s", "Feuer +50 %", "Wasser −50 %", "Solarstrahl sofort", "Wachstum stärker"],
    "bullet_seed": ["2–5 Treffer", "35/35/15/15 %", "Genauigkeit 1×", "Volltreffer je Treffer"],
    "sleep_talk": ["nur schlafend", "1 Schlafaktion", "Zufallsattacke", "keine Extra-RPG-AP"],
    "seed_bomb": ["Schaden"],
    "grass_knot": ["Stärke 20–120", "Basisgewicht"],
    "rest": ["volle KP", "Hauptstatus", "2 Schlafaktionen", "Schlafschutz"],
    "substitute": ["25 % Max-KP", "Delegator", "Feindstatus/Senkungen", "kein Überschussschaden"],
    "giga_drain": ["50 %", "KP-Schadens", "0 Schaden = 0 Heilung"],
    "energy_ball": ["10 %", "Verteidigung ↓", "Statuswert", "3 Zielaktionen"],
    "helping_hand": ["Verbündeter", "Angriff ↑", "Statuswert", "3 Aktionen", "nicht auf sich selbst"],
    "grassy_terrain": ["3 eigene Aktionen", "Pflanze +30 %", "1/16 Max-KP"],
    "grass_pledge": ["Stärke 80", "Kombination 150", "1/8 Max-KP", "Geschwindigkeit −50 %"],
    "sludge_bomb": ["30 % Vergiftung"],
    "solar_beam": ["1 eigene Aktion laden", "automatisch angreifen", "Zielplatz fest", "Sonne: sofort"]
}

const FORBIDDEN_PLAYER_TERMS: Array[String] = [
    "db_", "bulba_", "enemy_highest_aggro", "effect_source",
    "Debuff", "debuff", "damage", "target", "ally", "runtime", "multi_hit"
]


func _initialize() -> void:
    var lab = CombatLabTmScript.new()
    root.add_child(lab)

    assert(lab.lab_all_tms_toggle != null, "TM-Testcheckbox fehlt.")
    lab.lab_all_tms_toggle.button_pressed = true

    _assert_tm_inventory(lab)
    _assert_new_move_contracts(lab)
    _assert_player_text(lab)
    _assert_no_tera_runtime(lab)
    _assert_behavior_regressions(lab)

    print("Bulbasaur family TM runtime/text/behavior test: PASS")
    lab.queue_free()
    quit(0)


func _assert_tm_inventory(lab) -> void:
    var available: Array = lab._lab_available_tm_moves("bulbasaur")
    assert(available.size() == 21, "Bisasam muss exakt 21 Nicht-Tera-TMs im Kampflabor erhalten.")
    for move_id: String in EXPECTED_BULBASAUR_TMS:
        assert(available.has(move_id), "Bisasam-TM fehlt: " + move_id)
    assert(not available.has("tera_blast"), "Tera-Ausbruch darf im Kampflabor nicht existieren.")

    var combatant: Dictionary = lab._make_combatant(
        "player", 0, {"species_id": "bulbasaur", "level": 5}
    )
    var combatant_moves: Array = combatant.get("moves", [])
    for move_id: String in EXPECTED_BULBASAUR_TMS:
        assert(combatant_moves.has(move_id), "Aktiviertes Bisasam erhält TM nicht: " + move_id)
    assert(is_equal_approx(float(combatant.get("db_weight_kg", 0.0)), 6.9), "Bisasams Gewichtsdaten fehlen.")

    for species_id: String in BULBASAUR_FAMILY:
        var family_moves: Array = lab._lab_available_tm_moves(species_id)
        assert(not family_moves.is_empty(), "TM-Runtime der Bisasam-Familie fehlt für: " + species_id)
        assert(not family_moves.has("tera_blast"), "Tera-Ausbruch blieb in der Familie aktiv: " + species_id)
        for move_id_value: Variant in family_moves:
            var move_id: String = str(move_id_value)
            assert(lab._runtime_has_move(move_id), "Familien-TM hat keine ausführbare Runtime: %s/%s" % [species_id, move_id])


func _assert_new_move_contracts(lab) -> void:
    for move_id_value: Variant in NEW_MOVE_NAMES.keys():
        var move_id: String = str(move_id_value)
        var move: Dictionary = lab._move_data(move_id)
        assert(not move.is_empty(), "Runtime-Attacke fehlt: " + move_id)
        assert(str(move.get("name", "")) == str(NEW_MOVE_NAMES[move_id]), "Deutscher Name falsch: " + move_id)
        var runtime_value: Variant = move.get("runtime", {})
        assert(runtime_value is Dictionary and bool((runtime_value as Dictionary).get("runtime_supported", false)), "Runtime nicht aktiv: " + move_id)

    var trailblaze: Dictionary = lab._move_data("trailblaze")
    assert(int(trailblaze.get("power", 0)) == 50, "Wegbereiter: Stärke muss 50 sein.")
    assert(bool((trailblaze.get("runtime", {}) as Dictionary).get("bulba_trailblaze_speed", false)), "Wegbereiter: Geschwindigkeits-Runtime fehlt.")

    var magical_leaf: Dictionary = lab._move_data("magical_leaf")
    assert(magical_leaf.get("accuracy", 999) == null, "Zauberblatt muss die normale Genauigkeitsprüfung umgehen.")
    assert(bool((magical_leaf.get("runtime", {}) as Dictionary).get("always_hit", false)), "Zauberblatt: Always-hit-Runtime fehlt.")

    var bullet_seed: Dictionary = lab._move_data("bullet_seed")
    var multi_hit: Dictionary = (bullet_seed.get("runtime", {}) as Dictionary).get("multi_hit", {})
    assert(int(multi_hit.get("min", 0)) == 2 and int(multi_hit.get("max", 0)) == 5, "Kugelsaat: 2–5 Treffer fehlen.")
    assert((multi_hit.get("weights", []) as Array) == [35, 35, 15, 15], "Kugelsaat: Trefferverteilung ist falsch.")

    var giga_drain: Dictionary = lab._move_data("giga_drain")
    assert(is_equal_approx(float((giga_drain.get("runtime", {}) as Dictionary).get("bulba_drain_fraction", 0.0)), 0.5), "Gigasauger: 50%-Heilung fehlt.")

    var energy_ball: Dictionary = lab._move_data("energy_ball")
    assert(is_equal_approx(float((energy_ball.get("runtime", {}) as Dictionary).get("bulba_energy_ball_debuff_chance", 0.0)), 0.1), "Energieball: 10%-Senkung fehlt.")

    var facade: Dictionary = lab._move_data("facade")
    assert(int(facade.get("power", 0)) == 70 and bool((facade.get("runtime", {}) as Dictionary).get("bulba_facade", false)), "Fassade: 70/140-Runtime fehlt.")

    var endure: Dictionary = lab._move_data("endure")
    assert(str(endure.get("target", "")) == "self", "Ausdauer muss Selbstziel sein.")
    assert(str((endure.get("mechanics", []) as Array)[0].get("kind", "")) == "bulba_endure", "Ausdauer-Runtime fehlt.")

    var rest: Dictionary = lab._move_data("rest")
    assert(str(rest.get("target", "")) == "self", "Erholung muss ausschließlich Selbstziel sein.")
    assert(str((rest.get("mechanics", []) as Array)[0].get("kind", "")) == "bulba_rest", "Erholung-Runtime fehlt.")
    assert(bool((rest.get("runtime", {}) as Dictionary).get("sleep_talk_eligible", false)), "Erholung muss für Schlafrede auswählbar sein.")

    var sleep_talk: Dictionary = lab._move_data("sleep_talk")
    assert(str(sleep_talk.get("target", "")) == "self", "Schlafrede muss Selbstziel sein.")
    assert(not bool((sleep_talk.get("runtime", {}) as Dictionary).get("sleep_talk_eligible", true)), "Schlafrede darf sich nicht selbst auswählen.")

    var substitute: Dictionary = lab._move_data("substitute")
    assert(str(substitute.get("target", "")) == "self", "Delegator muss Selbstziel sein.")
    assert(str((substitute.get("mechanics", []) as Array)[0].get("kind", "")) == "bulba_substitute", "Delegator-Runtime fehlt.")
    assert(str(substitute.get("emoji", "")) == "🧸", "Delegator muss das Teddybär-Emoji verwenden.")

    var grass_knot: Dictionary = lab._move_data("grass_knot")
    assert(bool((grass_knot.get("runtime", {}) as Dictionary).get("bulba_weight_power", false)), "Strauchler: Gewichtsruntime fehlt.")

    var helping_hand: Dictionary = lab._move_data("helping_hand")
    assert(str(helping_hand.get("target", "")) == "single_ally", "Rechte Hand muss einen einzelnen Verbündeten wählen.")

    var grassy_terrain: Dictionary = lab._move_data("grassy_terrain")
    assert(str(grassy_terrain.get("target", "")) == "battlefield", "Grasfeld muss das Kampffeld betreffen.")

    var grass_pledge: Dictionary = lab._move_data("grass_pledge")
    assert(int(grass_pledge.get("power", 0)) == 80, "Pflanzensäulen: normale Stärke muss 80 sein.")
    assert(str((grass_pledge.get("runtime", {}) as Dictionary).get("bulba_pledge", "")) == "grass", "Pflanzensäulen: Kombinationsruntime fehlt.")


func _assert_player_text(lab) -> void:
    for move_id: String in EXPECTED_BULBASAUR_TMS:
        var move: Dictionary = lab._move_data(move_id)
        assert(not move.is_empty(), "Textprüfung: Attacke fehlt: " + move_id)
        var summary: String = lab._compact_effect_summary(move)
        assert(not summary.is_empty(), "Textprüfung: Effektbeschreibung fehlt: " + move_id)

        var tooltip: String = lab._move_tooltip(move)
        assert(tooltip.contains("Effekt: " + summary), "Textprüfung: kanonische Beschreibung fehlt im Tooltip: " + move_id)
        assert(not tooltip.contains("Datenbank-Effekt:"), "Textprüfung: internes effect_source sichtbar: " + move_id)

        for forbidden: String in FORBIDDEN_PLAYER_TERMS:
            assert(not summary.contains(forbidden), "Textprüfung: technischer/englischer Begriff '%s' sichtbar bei %s" % [forbidden, move_id])
            assert(not tooltip.contains(forbidden), "Textprüfung: technischer/englischer Begriff '%s' im Tooltip bei %s" % [forbidden, move_id])

        var required_value: Variant = REQUIRED_SUMMARY_FRAGMENTS.get(move_id, [])
        if required_value is Array:
            for fragment_value: Variant in required_value:
                var fragment: String = str(fragment_value)
                assert(summary.contains(fragment), "Textprüfung: '%s' fehlt bei %s: %s" % [fragment, move_id, summary])


func _assert_no_tera_runtime(lab) -> void:
    var species_value: Variant = lab.data.get("species", {})
    if not (species_value is Dictionary):
        return
    for entry_value: Variant in (species_value as Dictionary).values():
        if not (entry_value is Dictionary):
            continue
        var learnset_value: Variant = (entry_value as Dictionary).get("source_learnset", {})
        if not (learnset_value is Dictionary):
            continue
        var tm_value: Variant = (learnset_value as Dictionary).get("tm_hm", {})
        if tm_value is Dictionary:
            assert(not (tm_value as Dictionary).values().has("tera_blast"), "Tera-Ausbruch blieb in einer Runtime-TM-Liste zurück.")


func _assert_behavior_regressions(lab) -> void:
    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id": "bulbasaur", "level": 5})
    var ally: Dictionary = lab._make_combatant("player", 1, {"species_id": "bulbasaur", "level": 5})
    var enemy: Dictionary = lab._make_combatant("enemy", 0, {"species_id": "bulbasaur", "level": 5})
    lab.combatants = [actor, ally, enemy]

    _assert_rest_behavior(lab, actor, enemy)
    _assert_sleep_talk_behavior(lab, actor)
    _assert_substitute_behavior(lab, actor)
    _assert_endure_behavior(lab, actor)
    _assert_support_and_status_scaling(lab, actor, ally, enemy)
    _assert_grass_knot_tiers(lab, actor, enemy)


func _reset_actor_for_test(actor: Dictionary) -> void:
    actor["alive"] = true
    actor["major_status"] = ""
    actor["paralyzed"] = false
    actor["db_sleep_actions"] = 0
    actor["db_sleep_talk_originally_asleep"] = false
    actor["db_substitute_hp"] = 0
    actor["db_substitute_max_hp"] = 0
    actor["db_guard_family_chain"] = 0
    actor["db_endure_expires_after_action"] = 0
    actor["action_serial"] = 0
    actor["timed_modifiers"] = []
    actor["aggro"] = 0.0


func _assert_rest_behavior(lab, actor: Dictionary, enemy: Dictionary) -> void:
    _reset_actor_for_test(actor)
    _reset_actor_for_test(enemy)
    var max_hp: int = int(actor.get("max_hp", 1))
    actor["hp"] = maxi(1, max_hp - 5)
    actor["major_status"] = "poison"
    enemy["major_status"] = ""

    lab._bulba_rest(actor)
    assert(int(actor.get("hp", 0)) == max_hp, "Erholung muss die KP vollständig auffüllen.")
    assert(str(actor.get("major_status", "")) == "sleep", "Erholung muss den eigenen Hauptstatus durch Schlaf ersetzen.")
    assert(int(actor.get("db_sleep_actions", 0)) == 2, "Erholung muss exakt zwei eigene Schlafaktionen setzen.")
    assert(str(enemy.get("major_status", "")) == "", "Erholung darf niemals den Gegner einschläfern.")

    _reset_actor_for_test(actor)
    actor["hp"] = max_hp
    var failed_value: float = float(lab._bulba_rest(actor))
    assert(is_zero_approx(failed_value), "Erholung muss bei vollen KP fehlschlagen.")
    assert(str(actor.get("major_status", "")) == "", "Fehlgeschlagene Erholung darf keinen Schlaf anwenden.")


func _assert_sleep_talk_behavior(lab, actor: Dictionary) -> void:
    _reset_actor_for_test(actor)
    var max_hp: int = int(actor.get("max_hp", 1))
    actor["hp"] = maxi(1, max_hp - 4)
    actor["major_status"] = "sleep"
    actor["db_sleep_actions"] = 2
    actor["moves"] = ["sleep_talk", "rest"]

    var candidates: Array[String] = lab._bulba_sleep_talk_candidates(actor)
    assert(candidates == ["rest"], "Schlafrede muss Erholung als einziges gültiges Ziel erkennen.")
    lab._bulba_execute_sleep_talk(actor)
    assert(int(actor.get("hp", 0)) == max_hp, "Schlafrede → Erholung muss tatsächlich heilen.")
    assert(str(actor.get("major_status", "")) == "sleep", "Schlafrede → Erholung muss Erholungs-Schlaf beibehalten.")
    assert(int(actor.get("db_sleep_actions", 0)) == 2, "Schlafrede darf die von Erholung neu gesetzten zwei Schlafaktionen nicht überschreiben.")
    assert(int(actor.get("action_serial", 0)) == 1, "Schlafrede darf nur eine eigene Aktion zählen.")

    _reset_actor_for_test(actor)
    actor["major_status"] = "sleep"
    actor["db_sleep_actions"] = 2
    actor["moves"] = ["sleep_talk", "solar_beam"]
    candidates = lab._bulba_sleep_talk_candidates(actor)
    assert(candidates.is_empty(), "Solarstrahl darf nicht durch Schlafrede ausgelöst werden.")
    lab._bulba_execute_sleep_talk(actor)
    assert(str(actor.get("major_status", "")) == "sleep", "Leere Schlafrede muss den bestehenden Schlaf erhalten.")
    assert(int(actor.get("db_sleep_actions", 0)) == 1, "Leere Schlafrede muss genau eine Schlafaktion verbrauchen.")
    assert(int(actor.get("action_serial", 0)) == 1, "Auch leere Schlafrede muss genau eine Aktion kosten.")


func _assert_substitute_behavior(lab, actor: Dictionary) -> void:
    _reset_actor_for_test(actor)
    var max_hp: int = int(actor.get("max_hp", 1))
    actor["hp"] = max_hp
    var expected_cost: int = maxi(1, int(floor(float(max_hp) * 0.25)))
    lab._bulba_create_substitute(actor)
    assert(int(actor.get("hp", 0)) == max_hp - expected_cost, "Delegator muss 25 % der Max-KP kosten.")
    assert(int(actor.get("db_substitute_hp", 0)) == expected_cost, "Delegator muss dieselbe KP-Menge erhalten, die bezahlt wurde.")

    var hp_after_first: int = int(actor.get("hp", 0))
    lab._bulba_create_substitute(actor)
    assert(int(actor.get("hp", 0)) == hp_after_first, "Ein aktiver Delegator darf nicht erneut KP kosten.")


func _assert_endure_behavior(lab, actor: Dictionary) -> void:
    _reset_actor_for_test(actor)
    actor["action_serial"] = 5
    lab._bulba_guard_attempt(actor, true)
    assert(int(actor.get("db_endure_expires_after_action", 0)) == 8, "Ausdauer muss drei eigene Aktionsfenster schützen.")
    assert(lab._bulba_endure_active(actor), "Ausdauer muss direkt nach Aktivierung wirken.")
    actor["action_serial"] = 7
    assert(lab._bulba_endure_active(actor), "Ausdauer muss bis vor die dritte Folgeaktion wirken.")
    actor["action_serial"] = 8
    assert(not lab._bulba_endure_active(actor), "Ausdauer muss nach drei eigenen Aktionsfenstern enden.")


func _assert_support_and_status_scaling(lab, actor: Dictionary, ally: Dictionary, enemy: Dictionary) -> void:
    _reset_actor_for_test(actor)
    _reset_actor_for_test(ally)
    _reset_actor_for_test(enemy)

    actor["special"] = maxi(10, int(actor.get("special", 10)))
    lab._bulba_helping_hand(actor, ally)
    var ally_modifiers: Array = ally.get("timed_modifiers", [])
    assert(ally_modifiers.size() == 1, "Rechte Hand muss genau einen erneuerbaren Schadensbonus setzen.")
    assert(str((ally_modifiers[0] as Dictionary).get("kind", "")) == "outgoing_damage_mod", "Rechte Hand muss ausgehenden Schaden verstärken.")
    assert(float((ally_modifiers[0] as Dictionary).get("multiplier", 1.0)) > 1.0, "Rechte Hand muss den Schaden erhöhen.")
    assert(int((ally_modifiers[0] as Dictionary).get("expires_after_action", 0)) == 3, "Rechte Hand muss drei Zielaktionen halten.")

    actor["action_serial"] = 4
    actor["timed_modifiers"] = []
    lab._bulba_apply_trailblaze_speed(actor)
    var speed_modifiers: Array = actor.get("timed_modifiers", [])
    assert(speed_modifiers.size() == 1, "Wegbereiter muss einen Geschwindigkeitsbonus erzeugen.")
    assert(str((speed_modifiers[0] as Dictionary).get("kind", "")) == "atb_cycle_mod", "Wegbereiter muss den ATB-Zyklus verändern.")
    assert(float((speed_modifiers[0] as Dictionary).get("multiplier", 1.0)) < 1.0, "Wegbereiter muss den ATB-Zyklus verkürzen.")
    assert(int((speed_modifiers[0] as Dictionary).get("expires_after_action", 0)) == 7, "Wegbereiter muss drei weitere eigene Aktionen halten.")

    actor["hp"] = maxi(1, int(actor.get("max_hp", 1)) - 10)
    var hp_before_drain: int = int(actor.get("hp", 0))
    lab._bulba_apply_drain_heal(actor, 6, 0.5)
    assert(int(actor.get("hp", 0)) == hp_before_drain + 3, "Gigasauger muss 50 % des tatsächlichen Schadens heilen.")

    enemy["timed_modifiers"] = []
    enemy["action_serial"] = 2
    var snapshot: Dictionary = {
        str(enemy.get("id", "enemy")): {
            "target": enemy,
            "hp": int(enemy.get("hp", 1)) + 1
        }
    }
    lab._bulba_apply_energy_ball_debuff(actor, snapshot)
    var enemy_modifiers: Array = enemy.get("timed_modifiers", [])
    assert(enemy_modifiers.size() == 1, "Energieball-Senkung muss einen Verteidigungsmodifikator erzeugen.")
    assert(str((enemy_modifiers[0] as Dictionary).get("kind", "")) == "incoming_damage_mod", "Energieball muss die zentrale Verteidigung abbilden.")
    assert(float((enemy_modifiers[0] as Dictionary).get("multiplier", 1.0)) < 1.0, "Energieball-Verteidigungssenkung muss eingehenden Schaden erhöhen.")
    assert(int((enemy_modifiers[0] as Dictionary).get("expires_after_action", 0)) == 5, "Energieball-Senkung muss drei Zielaktionen halten.")

    assert(not lab._bulba_facade_is_boosted(actor), "Fassade darf ohne relevanten Hauptstatus nicht verstärkt sein.")
    actor["major_status"] = "burn"
    assert(lab._bulba_facade_is_boosted(actor), "Fassade muss bei Verbrennung verstärkt sein.")
    actor["major_status"] = "poison"
    assert(lab._bulba_facade_is_boosted(actor), "Fassade muss bei Vergiftung verstärkt sein.")
    actor["major_status"] = ""
    actor["paralyzed"] = true
    assert(lab._bulba_facade_is_boosted(actor), "Fassade muss bei Paralyse verstärkt sein.")

    actor["action_serial"] = 10
    lab._bulba_activate_grassy_terrain(actor)
    assert(int(lab._bulba_grassy_terrain.get("expires_after_action", 0)) == 13, "Grasfeld muss drei eigene Aktionen des Anwenders dauern.")


func _assert_grass_knot_tiers(lab, actor: Dictionary, enemy: Dictionary) -> void:
    _reset_actor_for_test(actor)
    _reset_actor_for_test(enemy)
    actor["side"] = "player"
    enemy["side"] = "enemy"
    actor["alive"] = true
    enemy["alive"] = true
    enemy["aggro"] = 100.0
    lab.combatants = [actor, enemy]
    var move: Dictionary = lab._move_data("grass_knot")

    var tiers: Array = [
        [9.9, 20], [10.0, 40], [24.9, 40], [25.0, 60], [49.9, 60],
        [50.0, 80], [99.9, 80], [100.0, 100], [199.9, 100], [200.0, 120]
    ]
    for tier_value: Variant in tiers:
        var tier: Array = tier_value as Array
        enemy["db_weight_kg"] = float(tier[0])
        assert(lab._bulba_grass_knot_power(actor, move) == int(tier[1]), "Strauchler-Gewichtsstufe falsch bei %s kg." % str(tier[0]))
