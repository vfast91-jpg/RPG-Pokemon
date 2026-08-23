extends SceneTree

const RouteScript = preload("res://scripts/demo_route_landscape_choice_v1.gd")
const EXPECTED_LANDSCAPE_COUNT: int = 18


func _initialize() -> void:
    var route = RouteScript.new()
    route._tf_load_landscape_registry()

    var pool: Array[String] = route._tf_available_landscape_ids()
    assert(pool.size() == EXPECTED_LANDSCAPE_COUNT, "Die Landschaftsauswahl muss alle 18 gültigen Landschaften kennen.")
    assert(pool.has("meadow"), "Wiese muss nach Etappe 1 weiterhin normal im Zufallspool liegen.")

    var unique_pool: Dictionary = {}
    for landscape_id: String in pool:
        assert(not unique_pool.has(landscape_id), "Landschafts-IDs im Auswahlpool müssen eindeutig sein.")
        unique_pool[landscape_id] = true

    for _iteration: int in range(50):
        var choices: Array[String] = route._tf_random_landscape_choice_ids()
        assert(choices.size() == 2, "Jede Landschaftsauswahl muss genau zwei Angebote enthalten.")
        assert(choices[0] != choices[1], "Die beiden Landschaftsangebote müssen verschieden sein.")
        assert(unique_pool.has(choices[0]) and unique_pool.has(choices[1]), "Angebote müssen aus dem registrierten Landschaftspool stammen.")

    route.stage = 1
    route._tf_landscape_prepared_stage = 1
    assert(not route._tf_should_offer_landscape_choice(), "Etappe 1 darf keine Zufallsauswahl erhalten.")

    route.stage = 2
    route._tf_landscape_prepared_stage = 1
    assert(route._tf_should_offer_landscape_choice(), "Vor Etappe 2 muss die erste Landschaftsauswahl erscheinen.")
    route._tf_landscape_prepared_stage = 2
    assert(not route._tf_should_offer_landscape_choice(), "Eine bereits gewählte Etappe darf nicht erneut fragen.")

    route.stage = 95
    route._tf_landscape_prepared_stage = 94
    assert(route._tf_should_offer_landscape_choice(), "Etappe 95 muss noch eine Zufallsauswahl erhalten.")

    route.stage = 96
    route._tf_landscape_prepared_stage = 95
    assert(not route._tf_should_offer_landscape_choice(), "Etappen 96-100 sind für feste Endgame-Landschaften reserviert.")

    # Regression: Nach einem Kampf kann ein geerbter Route-Zustand den Wegbereich
    # unsichtbar bzw. den Textbereich scrollbar/expandierend hinterlassen. Die
    # Landschaftsauswahl muss diese UI-Zustände selbst reparieren, sonst sieht
    # man zwar den Titel, aber keine der zwei anwählbaren Landschaftskarten.
    route.path_box = VBoxContainer.new()
    route.path_box.visible = false
    route.event_label = RichTextLabel.new()
    route.event_label.fit_content = false
    route.event_label.scroll_active = true
    route.event_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    route.progress_label = Label.new()
    route.progress_label.visible = true

    route._tf_prepare_route_choice_layout(true)
    assert(route.path_box.visible, "Die Landschaftskarten müssen nach jedem Route-Zustand sichtbar geschaltet werden.")
    assert(route.event_label.fit_content, "Der Landschaftstext muss vollständig in den Inhalt einpassen.")
    assert(not route.event_label.scroll_active, "Die Landschaftsauswahl darf keine eigene Text-Scrollbar benötigen.")
    assert(route.event_label.size_flags_vertical == Control.SIZE_FILL, "Der Landschaftstext darf den Kartenbereich nicht verdrängen.")
    assert(not route.progress_label.visible, "Die redundante Fortschritts-Prozentzeile muss verborgen bleiben.")

    route.path_box.free()
    route.event_label.free()
    route.progress_label.free()
    route.free()
    print("Route landscape choice test: OK")
    quit(0)
