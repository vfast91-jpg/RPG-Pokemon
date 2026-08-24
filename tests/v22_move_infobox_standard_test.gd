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
    _test_responsive_layout_contract(battle)
    _test_compact_presentation_contract(battle)

    battle.free()
    if failures == 0:
        print("V22 move infobox standard test: PASS (479 Attacken + compact responsive Layout)")
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

    for move_id: String in ["whirlwind", "roar"]:
        var pause_text: String = battle._standardized_move_info_text(_move(moves, move_id))
        var pause_lower: String = pause_text.to_lower()
        _check(
            pause_lower.contains("atb") and (pause_lower.contains("paus") or pause_lower.contains("stoppt")),
            move_id + ": besondere ATB-Pause wird nicht verständlich erklärt."
        )


func _test_responsive_layout_contract(battle) -> void:
    _check(
        is_equal_approx(battle._infobox_shown_text_height(30.0), 36.0),
        "Kurze Zwei-Zeilen-Infoboxen müssen auf die kompakte Höhe schrumpfen."
    )
    _check(
        is_equal_approx(battle._infobox_shown_text_height(52.0), 52.0),
        "Mittellange Infoboxen sollen nur so hoch wie ihr Inhalt sein."
    )
    _check(
        is_equal_approx(battle._infobox_shown_text_height(180.0), 76.0),
        "Sehr lange Sonderfälle müssen früh in den Scrollmodus wechseln."
    )


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
