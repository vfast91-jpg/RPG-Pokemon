extends SceneTree

const RouteScript = preload("res://scripts/demo_route_landscape_overview_v1.gd")
const ACTIVE_ROUTE_SCRIPT: String = "res://scripts/demo_route_landscape_overview_v1.gd"


func _initialize() -> void:
    var route = RouteScript.new()
    route._tf_load_landscape_registry()

    assert(route.route_current_landscape_id() == "meadow", "Startzustand muss weiterhin Wiese sein.")
    assert(route.route_current_landscape_name() == "Wiese / Ebene", "Wiese muss im Routenbildschirm korrekt benannt sein.")

    var meadow: Dictionary = route.route_current_landscape()
    var meadow_card: Control = route._tf_make_current_landscape_card(meadow)
    assert(meadow_card.name == "CurrentLandscapeCard", "Die aktuelle Landschaft braucht eine eindeutige Übersichtskarte.")

    var meadow_name := meadow_card.find_child("CurrentLandscapeName", true, false) as Label
    var meadow_thumb := meadow_card.find_child("CurrentLandscapeThumbnail", true, false) as TextureRect
    assert(meadow_name != null, "Die Übersichtskarte braucht einen Landschaftsnamen.")
    assert(meadow_name.text == "Wiese / Ebene", "Die Übersichtskarte muss die aktuelle Landschaft anzeigen.")
    assert(meadow_thumb != null and meadow_thumb.texture != null, "Die Übersichtskarte braucht das echte Landschaftsbild als Vorschau.")
    meadow_card.free()

    route.current_landscape_id = "forest"
    assert(route.route_current_landscape_name() == "Wald", "Ein Landschaftswechsel muss sofort im Route-Zustand sichtbar sein.")
    var forest_card: Control = route._tf_make_current_landscape_card(route.route_current_landscape())
    var forest_name := forest_card.find_child("CurrentLandscapeName", true, false) as Label
    assert(forest_name != null and forest_name.text == "Wald", "Die Übersicht muss nach einem Wechsel den neuen Namen zeigen.")
    forest_card.free()

    var main_file := FileAccess.open("res://main.tscn", FileAccess.READ)
    assert(main_file != null, "main.tscn muss lesbar sein.")
    assert(main_file.get_as_text().contains(ACTIVE_ROUTE_SCRIPT), "Der Landschafts-Übersichtslayer muss in main.tscn aktiv sein.")

    route.free()
    print("Route landscape overview test: OK")
    quit(0)
