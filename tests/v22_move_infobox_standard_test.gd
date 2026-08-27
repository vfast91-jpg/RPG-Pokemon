extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_target_marker_clean_v1.gd")
const V22MoveCatalog = preload("res://scripts/battle/v22_move_catalog.gd")

const EXPECTED_TARGET_LABELS: Dictionary = {
    "enemy_highest_aggro": "höchste Aggro",
    "all_enemies": "alle Gegner",
    "self": "Anwender",
    "all_allies": "alle Verbündeten",
    "all_other_active_pokemon": "alle anderen aktiven Pokémon",
    "enemy_field": "gegnerische Feldseite",
    "global_battlefield": "gesamtes Kampffeld",
    "battlefield": "gesamtes Kampffeld",
    "single_ally": "gewählter Verbündeter",
    "single_enemy": "gewählter Gegner",
    "all_others": "alle anderen Pokémon",
    "enemy_highest_aggro_or_single_ally": "höchste Aggro oder gewählter Verbündeter",
    "all_allies_except_self": "alle anderen Verbündeten",
    "all_combatants": "alle aktiven Pokémon",
    "self_or_single_ally": "Anwender oder gewählter Verbündeter"
}

const FORBIDDEN_PLAYER_TEXT: Array[String] = [
    "Datenbank-Effekt:",
    "effect_source",
    "runtime_supported",
    "multiplier_from_special",
    "duration_actions",
    "res://",
    "db ",
    "v22 ",
    "f30 ",
    "f40 ",
    "f64 ",
    "zf ",
    "bulba ",
    "tf "
]

var failures: int = 0


func _initialize() -> void:
    var battle = BattleScript.new()
    battle._load_data()

    var moves_value: Variant = battle.data.get("moves", {})
    var moves: Dictionary = moves_value if moves_value is Dictionary else {}

    _check(V22MoveCatalog.count() == 479, "Der kanonische V22-Katalog muss 479 Attacken enthalten.")

    for target_value: Variant in EXPECTED_TARGET_LABELS.keys():
        var target_id: String = str(target_value)
        _check_equal(
            battle._target_name(target_id),
            str(EXPECTED_TARGET_LABELS[target_id]),
            "Zieltext ist nicht standardisiert: " + target_id
        )

    for move_id: String in V22MoveCatalog.IDS:
        _check(moves.has(move_id), "Infobox-Audit: Attacke fehlt im finalen Runtime-Pool: " + move_id)
        if not moves.has(move_id):
            continue

        var move_value: Variant = moves.get(move_id, {})
        _check(move_value is Dictionary, "Infobox-Audit: ungültiger Datensatz: " + move_id)
        if not (move_value is Dictionary):
            continue
        var move: Dictionary = move_value
        var text: String = battle._standardized_move_info_text(move)
        var plain: String = text.replace("[b]", "").replace("[/b]", "")

        _check(not plain.strip_edges().is_empty(), move_id + ": Infobox ist leer.")
        _check(plain.contains(str(move.get("name", move_id))), move_id + ": Name fehlt in der Infobox.")
        _check(plain.contains("AP "), move_id + ": AP-/Zeitkostenzeile fehlt.")
        _check(plain.contains("Ziel: "), move_id + ": Zielangabe fehlt.")
        _check(plain.contains("Genauigkeit: "), move_id + ": Genauigkeitsangabe fehlt.")

        var power_value: Variant = move.get("power", null)
        if power_value != null:
            _check(plain.contains("Stärke: "), move_id + ": vorhandene Stärke wird nicht angezeigt.")
        elif str(move.get("category", "")) == "status":
            _check(not plain.contains("Stärke: "), move_id + ": Statusattacke zeigt eine erfundene Schadensstärke.")

        if _move_needs_effect_explanation(move):
            _check(plain.contains("Wirkung: "), move_id + ": erklärungsbedürftige Attacke hat keine Wirkungszeile.")

        _check(
            not plain.contains("_"),
            move_id + ": Infobox enthält noch einen internen snake_case-Bezeichner: " + plain
        )
        _check(
            not plain.to_lower().contains("wirkung: ad "),
            move_id + ": Infobox zeigt noch einen internen Abra-Doduo-Effektbezeichner: " + plain
        )
        for forbidden: String in FORBIDDEN_PLAYER_TEXT:
            _check(
                not plain.to_lower().contains(forbidden.to_lower()),
                move_id + ": technischer Text ist sichtbar ('" + forbidden + "'): " + plain
            )

        var target_rule: String = str(move.get("target", "enemy_highest_aggro"))
        if EXPECTED_TARGET_LABELS.has(target_rule):
            _check(
                plain.contains("Ziel: " + str(EXPECTED_TARGET_LABELS[target_rule])),
                move_id + ": kanonische Zielbezeichnung fehlt: " + target_rule
            )

    _test_representative_boxes(battle, moves)
    _test_collapsible_layout_contract(battle)
    _test_compact_presentation_contract(battle)
    _test_unified_combatant_detail(battle)

    battle.free()
    if failures == 0:
        print("V22 move infobox standard test: PASS (479 Attacken + collapsible two-line layout)")
        quit(0)
    push_error("V22 move infobox standard test: %d Fehler" % failures)
    quit(1)


func _move_needs_effect_explanation(move: Dictionary) -> bool:
    if str(move.get("category", "")) == "status":
        return true
    if move.get("power", null) == null:
        return true

    var mechanics_value: Variant = move.get("mechanics", move.get("effects", []))
    if mechanics_value is Array:
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                continue
            if str((mechanic_value as Dictionary).get("kind", "")) != "damage":
                return true
    return false


func _test_representative_boxes(battle, moves: Dictionary) -> void:
    var low_kick: Dictionary = _move(moves, "low_kick")
    var low_kick_text: String = battle._standardized_move_info_text(low_kick)
    _check(
        low_kick_text.contains("Stärke: 20–120 (Gewicht) · Ziel: höchste Aggro"),
        "Fußkick muss seine vollständige gewichtsabhängige Stärke in der kompakten Zeile zeigen."
    )
    _check(
        not low_kick_text.contains("Stärke: 20 · Ziel:"),
        "Fußkick darf nicht länger wie eine feste Stärke-20-Attacke erscheinen."
    )
    _check(
        int(low_kick.get("power", -1)) == 20,
        "Die Darstellungsänderung darf Fußkicks numerischen Runtime-Basiswert nicht verändern."
    )

    _check_equal(
        battle._standard_power_text({"power": 50}),
        "Stärke: 50",
        "Eine normale Attacke muss ihre feste Stärke unverändert anzeigen."
    )
    _check_equal(
        battle._standard_power_text({"category": "status", "power": null}),
        "",
        "Eine Statusattacke ohne Stärke darf keine erfundene Stärke erhalten."
    )

    battle.selected_actor = {
        "special": 75.0,
        "types": ["normal"],
        "accuracy_mult": 1.0,
        "timed_modifiers": [],
        "side": "player"
    }
    var growl_text: String = battle._standardized_move_info_text(_move(moves, "growl"))
    _check(
        growl_text.split("\n")[1].contains(
            "Effekt: " + battle._standard_status_percentage_text(_move(moves, "growl"))
        ) and growl_text.split("\n")[1].contains("Angriff −")
        and growl_text.split("\n")[1].contains(" %"),
        "Heulers berechnete Statuswirkung muss in der stets sichtbaren zweiten Zeile stehen."
    )
    var charm_text: String = battle._standardized_move_info_text(_move(moves, "charm"))
    _check(
        charm_text.split("\n")[1].contains("Effekt: Angriff −")
        and charm_text.split("\n")[1].contains(" %"),
        "Auch Attacken mit bislang nur verbaler Kurzbeschreibung müssen den berechneten Prozentwert zeigen."
    )
    var dragon_dance_text: String = battle._standardized_move_info_text(_move(moves, "dragon_dance"))
    _check(
        dragon_dance_text.split("\n")[1].contains("Angriff +")
        and dragon_dance_text.split("\n")[1].contains("Geschwindigkeit +")
        and dragon_dance_text.split("\n")[1].count(" %") >= 2,
        "Mehrteilige Statusattacken müssen alle berechenbaren Prozentwirkungen zeigen."
    )
    battle.selected_actor = {}

    var confuse_text: String = battle._standardized_move_info_text(_move(moves, "confuse_ray"))
    _check(
        confuse_text.contains("Wirkung: Verursacht garantiert Verwirrung"),
        "Konfusstrahl benennt die garantierte Verwirrung nicht eindeutig."
    )
    _check(not confuse_text.contains("Stärke:"), "Konfusstrahl zeigt fälschlich eine Stärke.")

    var fury_text: String = battle._standardized_move_info_text(_move(moves, "fury_attack"))
    _check(
        fury_text.contains("2–5 Treffer") and fury_text.contains("Stärke 15 je Treffer"),
        "Furienschlag verliert seine Mehrfachtreffer-Sonderregel im Standard."
    )

    var rage_text: String = battle._standardized_move_info_text(_move(moves, "rage_powder"))
    _check(
        rage_text.contains("Einzelzielattacken")
        and rage_text.contains("Aggro-Zielregel")
        and rage_text.contains("Flächenattacken nicht"),
        "Wutpulver verliert seine besondere Umlenkungsregel im Standard."
    )

    var ingrain_text: String = battle._standardized_move_info_text(_move(moves, "ingrain"))
    var ingrain_lower: String = ingrain_text.to_lower()
    _check(
        ingrain_lower.contains("verwurzel")
        and (ingrain_lower.contains("regener") or ingrain_lower.contains("heil")),
        "Verwurzler wird nicht verständlich als besondere Heil-/Rooted-Mechanik erklärt."
    )
    _check(not ingrain_text.contains("v22_"), "Verwurzler zeigt einen internen V22-Bezeichner.")

    var rock_polish_text: String = battle._standardized_move_info_text(_move(moves, "rock_polish"))
    _check(
        rock_polish_text.contains("Wirkung: Erhöht die eigene Geschwindigkeit stark für drei eigene Aktionen."),
        "Steinpolitur zeigt nicht die verständliche Geschwindigkeitswirkung."
    )
    _check(
        not rock_polish_text.to_lower().contains("ad modifier"),
        "Steinpolitur zeigt noch den internen Effekttext 'ad modifier'."
    )

    var retaliate_text: String = battle._standardized_move_info_text(_move(moves, "retaliate"))
    _check(
        retaliate_text.contains("Stärke: 70")
        and retaliate_text.contains("Wirkung: Hat Stärke 140, wenn seit der letzten eigenen Aktion ein Verbündeter kampfunfähig geworden ist."),
        "Heimzahlung erklärt die bedingte Verdopplung auf Stärke 140 nicht."
    )

    for move_id: String in ["whirlwind", "roar"]:
        var pause_text: String = battle._standardized_move_info_text(_move(moves, move_id))
        var pause_lower: String = pause_text.to_lower()
        _check(
            pause_lower.contains("atb") and (pause_lower.contains("paus") or pause_lower.contains("stoppt")),
            move_id + ": besondere ATB-Pause wird nicht verständlich erklärt."
        )


func _test_unified_combatant_detail(battle) -> void:
    var combatant: Dictionary = {
        "id": "detail_test",
        "name": "Woingenau",
        "alive": true,
        "hp": 100,
        "max_hp": 100,
        "atb": 14.0,
        "aggro": 21.7,
        "types": ["psychic"],
        "attack": 19,
        "defense": 30,
        "special": 15,
        "speed": 19,
        "moves": ["destiny_bond"],
        "timed_modifiers": [],
        "f30_destiny_bond_active": true
    }
    var inherited: String = (
        "[b]KAMPFSTATUS[/b]\nKP: 100/100\n\n"
        + "[b]AKTIVE EFFEKTE[/b]\n• Keine aktiven Veränderungen\n\n"
        + "[b]VERFÜGBARE ATTACKEN[/b]\n• Abgangsbund\n\n"
        + "[b]KONTROLLE[/b]\n• Beispielwirkung: noch 2 eigene Aktionen."
    )
    var detail: String = battle._standardized_combatant_detail(combatant, inherited)
    var effects_position: int = detail.find("[b]AKTIVE EFFEKTE[/b]")
    var destiny_position: int = detail.find("Abgangsbund: Wird dieses Pokémon")
    var trailing_position: int = detail.find("Beispielwirkung: noch 2 eigene Aktionen.")
    var attacks_position: int = detail.find("[b]VERFÜGBARE ATTACKEN[/b]")

    _check(
        effects_position >= 0
        and destiny_position > effects_position
        and trailing_position > effects_position
        and attacks_position > destiny_position
        and attacks_position > trailing_position,
        "Alle laufenden Wirkungen müssen geschlossen unter AKTIVE EFFEKTE und vor der Attackenliste stehen."
    )
    _check(
        not detail.contains("[b]KONTROLLE[/b]")
        and not detail.contains("Keine aktiven Veränderungen"),
        "Alte Effekt-Unterbereiche und der Leer-Platzhalter dürfen die einheitliche Ansicht nicht durchbrechen."
    )
    var attacks_text: String = detail.substr(attacks_position)
    _check(
        attacks_text.contains("Abgangsbund")
        and attacks_text.contains("Ziel: Anwender")
        and attacks_text.contains("Wirkung:"),
        "Jede verfügbare Attacke muss in der Pokémon-Detailansicht ihre vollständige Standarderklärung erhalten."
    )
    _check(
        not attacks_text.contains("Beispielwirkung"),
        "Aktive Wirkungen dürfen nicht mehr unter den verfügbaren Attacken landen."
    )


func _test_collapsible_layout_contract(battle) -> void:
    battle._attack_infobox_expanded = false
    _check(
        is_equal_approx(battle._infobox_shown_text_height(30.0), 36.0),
        "Kurzer Text muss in der normalen Zwei-Zeilen-Höhe bleiben."
    )
    _check(
        is_equal_approx(battle._infobox_shown_text_height(90.0), 36.0),
        "Langer Text darf die geschlossene Infobox nicht automatisch vergrößern."
    )
    _check(
        is_equal_approx(battle._infobox_shown_text_height(400.0), 36.0),
        "Auch sehr langer Text muss geschlossen bei zwei Zeilen bleiben."
    )
    _check_equal(
        battle._attack_infobox_toggle_text(),
        "Mehr anzeigen ▼",
        "Die geschlossene Infobox braucht eine eindeutige Aufklapp-Beschriftung."
    )
    _check(
        battle._attack_infobox_overlay_z_index(37) == 37,
        "Die geschlossene Infobox muss ihren ursprünglichen Ebenenwert behalten."
    )
    _check(
        battle._attack_infobox_overlay_mouse_filter(Control.MOUSE_FILTER_PASS)
        == Control.MOUSE_FILTER_PASS,
        "Die geschlossene Infobox muss ihr ursprüngliches Mausverhalten behalten."
    )

    battle._attack_infobox_is_move_preview = false
    _check(
        not battle._attack_infobox_has_hidden_content(90.0),
        "Warten und andere allgemeine Kampfmeldungen dürfen nie 'Mehr anzeigen' anbieten."
    )
    battle._attack_infobox_is_move_preview = true
    _check(
        battle._attack_infobox_has_hidden_content(90.0),
        "Eine lange Attacken-Vorschau muss 'Mehr anzeigen' anbieten."
    )
    _check(
        not battle._attack_infobox_has_hidden_content(36.0),
        "Eine kurze Attacken-Vorschau darf keinen unnötigen Aufklapp-Button zeigen."
    )

    battle._attack_infobox_expanded = true
    _check(
        is_equal_approx(battle._infobox_shown_text_height(90.0), 90.0),
        "Aufgeklappte Infobox muss den vorhandenen Text sichtbar machen."
    )
    _check(
        is_equal_approx(battle._infobox_shown_text_height(400.0), 220.0),
        "Extrem langer Text muss im aufgeklappten Zustand am sicheren Maximum scrollen."
    )
    _check_equal(
        battle._attack_infobox_toggle_text(),
        "Weniger anzeigen ▲",
        "Die offene Infobox braucht eine eindeutige Zuklapp-Beschriftung."
    )
    _check(
        battle._attack_infobox_overlay_z_index(37) == 900,
        "Die offene Infobox muss vor Pokemon und Statuskarten liegen."
    )
    _check(
        battle._attack_infobox_overlay_mouse_filter(Control.MOUSE_FILTER_PASS)
        == Control.MOUSE_FILTER_STOP,
        "Die offene Infobox muss Maus-Hover auf verdeckte Statuskarten blockieren."
    )
    battle._attack_infobox_expanded = false
    battle._attack_infobox_is_move_preview = false


func _test_compact_presentation_contract(battle) -> void:
    _check(
        not battle._standard_feature_bits({"contact": true}).has("Kontakt"),
        "Kontakt darf keine eigene Besonderheitszeile erzeugen."
    )

    var readable_special: Dictionary = {
        "category": "physical",
        "power": 30,
        "runtime": {"special_rule": true},
        "special_rules": ["Eine lange zusätzliche Spielerregel, die nicht automatisch eingeblendet werden soll."]
    }
    _check(
        not battle._summary_needs_player_fallback(readable_special, "Ziel-Aggro halbieren"),
        "Kurze verständliche Sonderwirkungs-Texte dürfen nicht zu Langtext aufgebläht werden."
    )
    _check(
        battle._summary_needs_player_fallback(readable_special, "v22_internal_rule"),
        "Interne Runtime-Texte müssen weiterhin auf sicheren Spielertext zurückfallen."
    )

    var dynamic_damage_special: Dictionary = {
        "category": "physical",
        "power": 70,
        "description": "Verdoppelt unter einer klaren Kampfbedingung seine Stärke.",
        "mechanics": [{"kind": "damage"}],
        "runtime": {"runtime_supported": true, "dynamic_power": true}
    }
    _check(
        battle._summary_needs_player_fallback(dynamic_damage_special, "Schaden"),
        "Ein bloßes 'Schaden' darf eine vorhandene dynamische Spezialregel nicht verschlucken."
    )
    _check(
        battle._summary_needs_player_fallback(dynamic_damage_special, "ad modifier"),
        "Abra-Doduo-Runtimebezeichner müssen auf Spielertext zurückfallen."
    )


func _move(moves: Dictionary, move_id: String) -> Dictionary:
    var value: Variant = moves.get(move_id, {})
    return (value as Dictionary) if value is Dictionary else {}


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)


func _check_equal(actual: String, expected: String, message: String) -> void:
    if actual == expected:
        return
    failures += 1
    push_error(message + " Erwartet: '" + expected + "', erhalten: '" + actual + "'.")
