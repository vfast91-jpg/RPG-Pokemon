extends SceneTree

const BattleScript = preload("res://scripts/battle_demo_ad_final_v1.gd")
const RouteScript = preload("res://scripts/demo_route_global_pokemon_choice_ui_v1.gd")

var failures: int = 0


func _initialize() -> void:
    var battle = BattleScript.new()
    root.add_child(battle)

    var route = RouteScript.new()
    route.battle_demo = battle
    route.team = [
        {
            "species_id": "bellsprout",
            "name": "Knofensa",
            "level": 5,
            "moves": [],
            "tm_moves": [],
            "learned_tms": []
        },
        {
            "species_id": "paras",
            "name": "Paras",
            "level": 3,
            "moves": [],
            "tm_moves": [],
            "learned_tms": []
        }
    ]

    _check(
        battle.has_method("species_can_receive_tm_move"),
        "BattleDemo muss die zentrale Pokemon->TM-Kompatibilitaetsabfrage bereitstellen."
    )
    _check(
        bool(battle.call("species_can_receive_tm_move", "paras", "protect")),
        "Paras muss Schutzschild laut Pokemon-Datenbank als TM lernen duerfen."
    )
    _check(
        bool(battle.call("species_can_receive_tm_move", "bellsprout", "protect")),
        "Knofensa muss Schutzschild laut Pokemon-Datenbank als TM lernen duerfen."
    )

    var runtime_data_value: Variant = battle.get("data")
    _check(runtime_data_value is Dictionary, "BattleDemo braucht eine zentrale Runtime-Datenbank.")
    var runtime_moves: Dictionary = {}
    if runtime_data_value is Dictionary:
        var moves_value: Variant = (runtime_data_value as Dictionary).get("moves", {})
        if moves_value is Dictionary:
            runtime_moves = moves_value
    _check(runtime_moves.has("protect"), "Schutzschild muss genau einmal in der zentralen Attacken-Runtime existieren.")

    route._reload_tm_catalog()
    _check(not route._tm_catalog.is_empty(), "Der Routen-TM-Katalog darf mit Knofensa + Paras nicht leer sein.")
    _check(route._tm_catalog.has("protect"), "Die zentrale TM-Verknuepfung muss Schutzschild automatisch in den Routen-Katalog aufnehmen.")

    var protect_entry_value: Variant = route._tm_catalog.get("protect", {})
    _check(protect_entry_value is Dictionary, "Der Schutzschild-Katalogeintrag muss ein Dictionary sein.")
    if protect_entry_value is Dictionary:
        var protect_entry: Dictionary = protect_entry_value
        var compatible_value: Variant = protect_entry.get("species_ids", [])
        _check(
            compatible_value is Array and (compatible_value as Array).has("paras"),
            "Der Schutzschild-Katalogeintrag muss Paras aus der Pokemon-Datenbank referenzieren."
        )
        _check(
            compatible_value is Array and (compatible_value as Array).has("bellsprout"),
            "Der Schutzschild-Katalogeintrag muss Knofensa aus der Pokemon-Datenbank referenzieren."
        )
        _check(
            route._member_can_receive_tm(route.team[1], protect_entry),
            "Paras Lv.3 muss Schutzschild an der Fundstelle angeboten bekommen koennen."
        )
        _check(
            route._member_can_receive_tm(route.team[0], protect_entry),
            "Knofensa Lv.5 muss Schutzschild an der Fundstelle angeboten bekommen koennen."
        )

        # Regression fuer moderne TM-Daten ohne historische Nummer: Nach einer
        # gelernten nummernlosen TM duerfen andere nummernlose TMs nicht pauschal
        # als bereits gelernt gelten.
        var paras_after_tm: Dictionary = route.team[1].duplicate(true)
        paras_after_tm["learned_tms"] = [{"number": "", "move_id": "protect"}]
        paras_after_tm["tm_moves"] = ["protect"]
        var another_entry: Dictionary = _first_other_compatible_entry(route, "paras", "protect")
        if not another_entry.is_empty():
            _check(
                route._member_can_receive_tm(paras_after_tm, another_entry),
                "Eine nummernlose gelernte TM darf keine andere kompatible nummernlose TM blockieren."
            )

    var eligible: Array[Dictionary] = route._eligible_tm_entries()
    _check(
        not eligible.is_empty(),
        "Die Fundstelle muss fuer das Screenshot-Team mindestens eine implementierte kompatible TM finden."
    )

    # Cross-database contract: every route catalog entry must point to one
    # central runtime move and every cached recipient must be approved by the
    # Pokemon compatibility database. There is no per-Pokemon move copy here.
    for entry_value: Variant in route._tm_catalog.values():
        if not (entry_value is Dictionary):
            _check(false, "Jeder TM-Katalogeintrag muss ein Dictionary sein.")
            continue
        var entry: Dictionary = entry_value
        var move_id: String = str(entry.get("move_id", ""))
        _check(runtime_moves.has(move_id), "TM-Katalog verweist auf fehlende Runtime-Attacke: %s" % move_id)
        var species_ids_value: Variant = entry.get("species_ids", [])
        if not (species_ids_value is Array):
            _check(false, "TM-Katalog braucht species_ids: %s" % move_id)
            continue
        for species_id_value: Variant in species_ids_value:
            var species_id: String = str(species_id_value)
            _check(
                bool(battle.call("species_can_receive_tm_move", species_id, move_id)),
                "TM-Katalog enthaelt eine nicht von der Pokemon-Datenbank bestaetigte Verbindung: %s -> %s" % [species_id, move_id]
            )

    route.free()
    battle.queue_free()

    if failures == 0:
        print("Route TM database bridge test: PASS")
        quit(0)
    else:
        push_error("Route TM database bridge test: %d Fehler" % failures)
        quit(1)


func _first_other_compatible_entry(route, species_id: String, excluded_move_id: String) -> Dictionary:
    for entry_value: Variant in route._tm_catalog.values():
        if not (entry_value is Dictionary):
            continue
        var entry: Dictionary = entry_value
        if str(entry.get("move_id", "")) == excluded_move_id:
            continue
        var species_ids_value: Variant = entry.get("species_ids", [])
        if species_ids_value is Array and (species_ids_value as Array).has(species_id):
            return entry
    return {}


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
