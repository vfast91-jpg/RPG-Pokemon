extends SceneTree

const RouteScript = preload("res://scripts/demo_route_viewport_guard_v1.gd")
const ACTIVE_ROUTE_SCRIPT: String = "res://scripts/demo_route_viewport_guard_v1.gd"


func _initialize() -> void:
    var route = RouteScript.new()
    route._build_ui()
    route._tf_install_route_viewport_guard()
    route._tf_install_local_action_scroll()
    route._tf_bound_event_log()
    route._tf_refresh_action_scroll_state()

    var frame := route.root.get_node_or_null("RouteViewportFrame") as PanelContainer
    assert(frame != null, "Der äußere Goldrahmen braucht den zentralen Viewport-Schutz.")
    assert(frame.clip_contents, "Der äußere Goldrahmen darf Inhalte außerhalb seiner Grenzen nicht zeichnen.")
    assert(frame.anchor_left == 0.0 and frame.anchor_top == 0.0, "Der Goldrahmen muss links/oben am Viewport verankert bleiben.")
    assert(frame.anchor_right == 1.0 and frame.anchor_bottom == 1.0, "Der Goldrahmen muss rechts/unten am Viewport verankert bleiben.")
    assert(frame.offset_left == 8.0 and frame.offset_top == 8.0, "Der Goldrahmen braucht den festen oberen/ linken Innenabstand.")
    assert(frame.offset_right == -8.0 and frame.offset_bottom == -8.0, "Der Goldrahmen braucht den festen unteren/rechten Innenabstand.")

    # Regression: the complete route screen must never become scrollable. The
    # previous safety wrapper caused the unwanted scrollbar on the far right.
    assert(
        frame.get_node_or_null("RouteViewportScroll") == null,
        "Der komplette Routenrahmen darf keinen globalen ScrollContainer besitzen."
    )
    for child: Node in frame.get_children():
        assert(
            not (child is ScrollContainer),
            "Direkt im Goldrahmen darf kein ScrollContainer die komplette Route scrollbar machen."
        )

    assert(route.event_label != null, "Die Route braucht weiterhin ihr Ereignis-/Ergebnisfeld.")
    assert(not route.event_label.fit_content, "Dynamischer Routentext darf die Höhe des Layouts nicht bestimmen.")
    assert(route.event_label.scroll_active, "Langer Routentext muss innerhalb seines eigenen Feldes scrollbar sein.")

    var long_summary: String = "Etappe geschafft!"
    for index: int in range(40):
        long_summary += "\nLevel-Up-Zeile %d" % index
    route.event_label.text = long_summary

    # Regression for the landscape layer that previously re-enabled fit_content
    # and disabled scrolling after every normal stage choice.
    route._tf_prepare_route_choice_layout(false)
    assert(not route.event_label.fit_content, "Normale Etappen dürfen fit_content nicht wieder aktivieren.")
    assert(route.event_label.scroll_active, "Normale Etappen müssen den Ereignistext scrollbar lassen.")

    route._tf_prepare_route_choice_layout(true)
    assert(not route.event_label.fit_content, "Auch die Landschaftsauswahl darf fit_content nicht aktivieren.")
    assert(route.event_label.scroll_active, "Auch die Landschaftsauswahl muss den Ereignistext scrollbar lassen.")

    # Dynamic selection areas (training, TM recipients, item recipients, capture
    # choices, etc.) need their OWN scrollbar. This is the missing guard that
    # previously let four training cards plus the back action disappear below
    # the fixed gold frame.
    var action_scroll := route.capture_actions.get_parent() as ScrollContainer
    assert(action_scroll != null, "Dynamische Routenauswahlen brauchen einen lokalen ScrollContainer.")
    assert(action_scroll.name == "RouteActionScroll", "Der lokale Auswahl-Scroller braucht einen stabilen Namen.")
    assert(
        action_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
        "Zu hohe Auswahlbereiche müssen lokal vertikal scrollbar sein."
    )
    assert(
        action_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
        "Dynamische Routenauswahlen dürfen keinen horizontalen Scroll-Overflow erzeugen."
    )
    assert(not action_scroll.visible, "Ein leerer Auswahlbereich darf keinen Platz im normalen Etappenlayout belegen.")

    # Training must also have an explicit way back before any Pokemon is chosen.
    route._tf_add_training_back_button()
    route._tf_refresh_action_scroll_state()
    var training_back := route.capture_actions.get_node_or_null("TrainingBackButton") as Button
    assert(training_back != null, "Der Trainingsplatz braucht einen erreichbaren Zurück-Button.")
    assert(
        training_back.text.contains("ZURÜCK ZUR WEGAUSWAHL"),
        "Der Trainings-Zurück-Button muss klar zur Wegauswahl führen."
    )
    assert(action_scroll.visible, "Ein gefüllter Auswahlbereich muss als lokaler Scrollbereich sichtbar sein.")
    assert(
        route.event_label.size_flags_vertical == Control.SIZE_FILL,
        "Bei offener Auswahl darf der Infotext nicht den Platz der scrollbaren Auswahl auffressen."
    )

    # Simulate a full four-Pokemon team. The cards are intentionally taller than
    # the available compact region; accessibility is guaranteed by the local
    # scroller rather than by moving or scrolling the complete route screen.
    for index: int in range(4):
        var mock_card := PanelContainer.new()
        mock_card.name = "MockTrainingCard%d" % index
        mock_card.custom_minimum_size = Vector2(0.0, 58.0)
        route.capture_actions.add_child(mock_card)
    route._tf_refresh_action_scroll_state()
    assert(route.capture_actions.get_child_count() == 5, "Vier Trainingskarten plus Zurück-Button müssen im lokalen Scroller bleiben.")
    assert(route.capture_actions.get_parent() == action_scroll, "Auswahlkarten dürfen den lokalen Scrollbereich nicht verlassen.")

    var main_file := FileAccess.open("res://main.tscn", FileAccess.READ)
    assert(main_file != null, "main.tscn muss lesbar sein.")
    assert(
        main_file.get_as_text().contains(ACTIVE_ROUTE_SCRIPT),
        "Der Viewport-Schutz muss als aktiver oberster Route-Layer in main.tscn eingetragen sein."
    )

    route.free()
    print("Route viewport guard test: OK")
    quit(0)
