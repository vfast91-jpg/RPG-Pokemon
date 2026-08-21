extends SceneTree

const CombatLabScript = preload("res://scripts/battle_demo_type_help_button_polish.gd")
const RouteScript = preload("res://scripts/demo_route_xp_progress_bonus.gd")


func _initialize() -> void:
    var lab = CombatLabScript.new()
    root.add_child(lab)

    var route = RouteScript.new()
    root.add_child(route)
    route.configure(lab)

    var lv12: Array = lab.route_moves_for_level("ekans", 12)
    var lv17: Array = lab.route_moves_for_level("ekans", 17)
    var lv20: Array = lab.route_moves_for_level("ekans", 20)
    assert(lv12.has("glare"), "Rettan muss auf Lv.12 Schlangenblick freischalten.")
    assert(lv17.has("screech"), "Rettan muss auf Lv.17 Kreideschrei freischalten.")
    assert(lv20.has("acid"), "Rettan muss auf Lv.20 Säure freischalten.")

    var glare_detail: String = route._levelup_move_detail_text("glare")
    assert(glare_detail.contains("Schlangenblick"), "Das Level-Up-Fenster muss Schlangenblick statt der internen ID glare anzeigen.")
    assert(not glare_detail.contains("Details zu dieser Attacke sind nicht verfügbar"), "Schlangenblick darf im Level-Up-Fenster nicht mehr als fehlende Attacke erscheinen.")
    assert(glare_detail.contains("Genauigkeit: 100%"), "Schlangenblick muss seine Genauigkeit im Level-Up-Fenster anzeigen.")

    var screech_detail: String = route._levelup_move_detail_text("screech")
    assert(screech_detail.contains("Kreideschrei"), "Das Level-Up-Fenster muss Kreideschrei anzeigen.")
    assert(not screech_detail.contains("Details zu dieser Attacke sind nicht verfügbar"), "Kreideschrei darf im Level-Up-Fenster nicht als fehlende Attacke erscheinen.")

    var acid_detail: String = route._levelup_move_detail_text("acid")
    assert(acid_detail.contains("Säure"), "Das Level-Up-Fenster muss Säure anzeigen.")
    assert(acid_detail.contains("Stärke: 40"), "Säure muss ihre Stärke im Level-Up-Fenster anzeigen.")
    assert(not acid_detail.contains("Details zu dieser Attacke sind nicht verfügbar"), "Säure darf im Level-Up-Fenster nicht als fehlende Attacke erscheinen.")

    route.queue_free()
    lab.queue_free()
    print("Rettan level-up move regression test: PASS")
    quit(0)
