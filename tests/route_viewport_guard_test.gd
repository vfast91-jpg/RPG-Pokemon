extends SceneTree

const RouteScript = preload("res://scripts/demo_route_viewport_guard_v1.gd")
const INTERNAL_VIEWPORT_HEIGHT: float = 360.0
const FRAME_VERTICAL_MARGIN: float = 8.0


func _initialize() -> void:
    var route = RouteScript.new()
    route._build_ui()
    route._tf_install_local_path_scroll()
    route._tf_install_local_action_scroll()
    route._tf_bound_event_log()
    route._tf_refresh_local_scroll_state()
    route._tf_install_route_viewport_guard()

    var frame := route.root.get_node_or_null("RouteViewportFrame") as PanelContainer
    assert(frame != null, "Der äußere Goldrahmen braucht den zentralen Viewport-Schutz.")
    assert(frame.clip_contents, "Der äußere Goldrahmen darf Inhalte außerhalb seiner Grenzen nicht zeichnen.")
    assert(frame.anchor_left == 0.0 and frame.anchor_top == 0.0, "Der Goldrahmen muss links/oben am Viewport verankert bleiben.")
    assert(frame.anchor_right == 1.0 and frame.anchor_bottom == 1.0, "Der Goldrahmen muss rechts/unten am Viewport verankert bleiben.")
    assert(frame.offset_left == 8.0 and frame.offset_top == 8.0, "Der Goldrahmen braucht den festen oberen/linken Innenabstand.")
    assert(frame.offset_right == -8.0 and frame.offset_bottom == -8.0, "Der Goldrahmen braucht den festen unteren/rechten Innenabstand.")

    # Regression: the complete route screen must never become scrollable. Only
    # descendants representing specific content regions may own scrollbars.
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
    assert(
        route.event_label.custom_minimum_size.y <= route.ROUTE_EVENT_LABEL_MAX_MIN_HEIGHT,
        "Der Routentext darf keine zu große Mindesthöhe in den Außenrahmen drücken."
    )

    var long_summary: String = "Etappe geschafft!"
    for index: int in range(40):
        long_summary += "\nLevel-Up-Zeile %d" % index
    route.event_label.text = long_summary

    # Regression for the landscape layer that historically re-enabled
    # fit_content, disabled local text scrolling and requested 72px minimum
    # height. The active top guard must always undo all three hazards.
    route._tf_prepare_route_choice_layout(true)
    assert(not route.event_label.fit_content, "Auch die Landschaftsauswahl darf fit_content nicht aktivieren.")
    assert(route.event_label.scroll_active, "Auch die Landschaftsauswahl muss den Ereignistext scrollbar lassen.")
    assert(
        route.event_label.custom_minimum_size.y <= route.ROUTE_EVENT_LABEL_MAX_MIN_HEIGHT,
        "Auch Landschaftstext darf die sichere lokale Mindesthöhe nicht überschreiten."
    )

    # Path/landscape content owns a local scroll boundary. This is essential
    # because landscape cards themselves can be taller than the remaining route
    # panel space after title, footer and event text are accounted for.
    var path_scroll := route.path_box.get_parent() as ScrollContainer
    assert(path_scroll != null, "Weg- und Landschaftsinhalte brauchen einen lokalen ScrollContainer.")
    assert(path_scroll.name == "RoutePathScroll", "Der lokale Weg-Scroller braucht einen stabilen Namen.")
    assert(path_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Zu hohe Wegauswahlen müssen lokal scrollbar sein.")
    assert(path_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Wegauswahlen dürfen keinen horizontalen Scroll-Overflow erzeugen.")

    var tall_landscape_row := PanelContainer.new()
    tall_landscape_row.name = "MockTallLandscapeChoice"
    tall_landscape_row.custom_minimum_size = Vector2(0.0, 220.0)
    route.path_box.add_child(tall_landscape_row)
    route._tf_refresh_local_scroll_state()
    route._tf_install_route_viewport_guard()
    assert(path_scroll.visible, "Gefüllte Weg-/Landschaftsinhalte müssen ihren lokalen Scrollbereich benutzen.")
    assert(
        route.event_label.size_flags_vertical == Control.SIZE_FILL,
        "Bei offener Wegauswahl darf der Infotext nicht den Platz des lokalen Scrollers auffressen."
    )

    # Most importantly, a deliberately oversized local choice must not make the
    # gold frame itself demand more height than the visible internal viewport.
    var maximum_frame_height: float = INTERNAL_VIEWPORT_HEIGHT - FRAME_VERTICAL_MARGIN * 2.0
    assert(
        frame.get_combined_minimum_size().y <= maximum_frame_height,
        "Lokaler Weg-Overflow darf die Mindesthöhe des Goldrahmens nicht über den Viewport vergrößern."
    )

    route._clear_container(route.path_box)
    route._tf_refresh_local_scroll_state()

    # Dynamic selection areas (training, TM recipients, item recipients, capture
    # choices, etc.) need their OWN scrollbar as well.
    var action_scroll := route.capture_actions.get_parent() as ScrollContainer
    assert(action_scroll != null, "Dynamische Routenauswahlen brauchen einen lokalen ScrollContainer.")
    assert(action_scroll.name == "RouteActionScroll", "Der lokale Auswahl-Scroller braucht einen stabilen Namen.")
    assert(action_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Zu hohe Auswahlbereiche müssen lokal vertikal scrollbar sein.")
    assert(action_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Dynamische Routenauswahlen dürfen keinen horizontalen Scroll-Overflow erzeugen.")

    # Training has an explicit way back before any Pokemon is chosen.
    route._tf_add_training_back_button()
    for index: int in range(4):
        var mock_card := PanelContainer.new()
        mock_card.name = "MockTrainingCard%d" % index
        mock_card.custom_minimum_size = Vector2(0.0, 58.0)
        route.capture_actions.add_child(mock_card)
    route._tf_refresh_local_scroll_state()
    route._tf_install_route_viewport_guard()

    var training_back := route.capture_actions.get_node_or_null("TrainingBackButton") as Button
    assert(training_back != null, "Der Trainingsplatz braucht einen erreichbaren Zurück-Button.")
    assert(training_back.text.contains("ZURÜCK ZUR WEGAUSWAHL"), "Der Trainings-Zurück-Button muss klar zur Wegauswahl führen.")
    assert(action_scroll.visible, "Ein gefüllter Auswahlbereich muss als lokaler Scrollbereich sichtbar sein.")
    assert(not path_scroll.visible, "Eine aktive Unterauswahl darf nicht gleichzeitig mit einer alten Wegauswahl um Höhe konkurrieren.")
    assert(route.capture_actions.get_child_count() == 5, "Vier Trainingskarten plus Zurück-Button müssen im lokalen Scroller bleiben.")
    assert(route.capture_actions.get_parent() == action_scroll, "Auswahlkarten dürfen den lokalen Scrollbereich nicht verlassen.")
    assert(
        frame.get_combined_minimum_size().y <= maximum_frame_height,
        "Lokaler Aktions-Overflow darf die Mindesthöhe des Goldrahmens nicht über den Viewport vergrößern."
    )

    # The active route entry may gain future top layers (save system, UI polish,
    # etc.). Do not require main.tscn to point directly at the guard; instead
    # verify that whatever route script is active still inherits the guard API.
    var main_file := FileAccess.open("res://main.tscn", FileAccess.READ)
    assert(main_file != null, "main.tscn muss lesbar sein.")
    var active_route_path: String = _active_route_script_path(main_file.get_as_text())
    assert(not active_route_path.is_empty(), "Der aktive DemoRoute-Scriptpfad muss aus main.tscn ermittelbar sein.")
    assert(ResourceLoader.exists(active_route_path), "Der aktive DemoRoute-Scriptpfad muss existieren.")

    var active_script := load(active_route_path) as Script
    assert(active_script != null, "Der aktive DemoRoute-Script muss ladbar sein.")
    var active_route: Object = active_script.new()
    assert(
        active_route.has_method("_tf_install_route_viewport_guard"),
        "Auch neue Top-Layer müssen den zentralen Viewport-Schutz weiter erben."
    )
    assert(
        active_route.has_method("_tf_install_local_path_scroll")
        and active_route.has_method("_tf_install_local_action_scroll"),
        "Auch neue Top-Layer müssen die lokalen Overflow-Grenzen weiter erben."
    )

    active_route.free()
    route.free()
    print("Route viewport guard test: OK")
    quit(0)


func _active_route_script_path(main_text: String) -> String:
    for line_value: Variant in main_text.split("\n"):
        var line: String = str(line_value)
        if not line.contains('id="3_route"'):
            continue

        var path_marker: String = 'path="'
        var start_index: int = line.find(path_marker)
        if start_index < 0:
            return ""
        start_index += path_marker.length()
        var end_index: int = line.find('"', start_index)
        if end_index < 0:
            return ""
        return line.substr(start_index, end_index - start_index)
    return ""
