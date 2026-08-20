extends SceneTree

const CombatLabScript = preload("res://scripts/battle_demo_adaptive_family_ui.gd")
const RouteScript = preload("res://scripts/demo_route_team_panel_fit.gd")

var failures: int = 0


func _initialize() -> void:
    var lab = CombatLabScript.new()
    root.add_child(lab)

    var route = RouteScript.new()
    root.add_child(route)
    route.configure(lab)

    var data_value: Variant = lab.get("data")
    _check(data_value is Dictionary, "Kampfdaten fehlen für den Level-Up-Test.")
    if not (data_value is Dictionary):
        _finish(lab, route)
        return

    var data: Dictionary = data_value
    var moves_value: Variant = data.get("moves", {})
    _check(moves_value is Dictionary, "Attackendaten fehlen für den Level-Up-Test.")
    if not (moves_value is Dictionary):
        _finish(lab, route)
        return

    var moves: Dictionary = moves_value
    moves["levelup_detail_test"] = {
        "id": "levelup_detail_test",
        "name": "Leuchtstich",
        "description": "Eine präzise Testattacke mit sichtbarer Detailbeschreibung.",
        "type": "poison",
        "category": "physical",
        "power": 35,
        "accuracy": 80,
        "ap": 2,
        "target": "enemy_highest_aggro",
        "area": false,
        "priority": 0,
        "opening": false,
        "mechanics": [{"kind": "damage"}]
    }
    data["moves"] = moves
    lab.set("data", data)

    var detail: String = route._levelup_move_detail_text("levelup_detail_test")
    _check(detail.contains("Leuchtstich"), "Level-Up-Detail zeigt den Attackennamen nicht an.")
    _check(detail.contains("Stärke: 35"), "Level-Up-Detail zeigt die Stärke nicht an.")
    _check(detail.contains("Genauigkeit: 80%"), "Level-Up-Detail zeigt die Genauigkeit nicht an.")
    _check(
        detail.contains("Eine präzise Testattacke mit sichtbarer Detailbeschreibung."),
        "Level-Up-Detail zeigt die Attackenbeschreibung nicht an."
    )

    _check(route._levelup_move != null, "Scrollbarer Attackenbereich im Level-Up-Fenster fehlt.")
    if route._levelup_move != null:
        _check(route._levelup_move.scroll_active, "Attackenbereich im Level-Up-Fenster ist nicht scrollbar.")
        _check(
            route._levelup_move.custom_minimum_size.x >= 250.0,
            "Attackenbereich nutzt die rechte Popup-Seite nicht ausreichend."
        )

    var species_ids: Array = lab.route_species_ids()
    var species_id: String = str(species_ids[0]) if not species_ids.is_empty() else ""
    route._levelup_queue = [{
        "species_id": species_id,
        "name": "Testmon",
        "old_level": 3,
        "new_level": 4,
        "before": {"max_hp": 15, "attack": 8, "defense": 8, "special": 8, "speed": 8},
        "after": {"max_hp": 16, "attack": 9, "defense": 9, "special": 9, "speed": 9},
        "learned": ["Leuchtstich"],
        "learned_move_ids": ["levelup_detail_test"]
    }]
    route._show_next_levelup_popup()

    _check(route._levelup_overlay.visible, "Level-Up-Fenster wird für den Detailtest nicht angezeigt.")
    _check(
        route._levelup_move.text.contains("Genauigkeit: 80%")
        and route._levelup_move.text.contains("Leuchtstich"),
        "Level-Up-Fenster übernimmt die vollständigen Attackendetails nicht."
    )

    _finish(lab, route)


func _finish(lab: Node, route: Node) -> void:
    route.queue_free()
    lab.queue_free()

    if failures == 0:
        print("Route level-up move details test: PASS")
        quit(0)
    else:
        push_error("Route level-up move details test: %d Fehler" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
