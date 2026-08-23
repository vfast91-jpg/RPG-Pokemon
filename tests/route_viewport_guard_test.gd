extends SceneTree

const RouteScript = preload("res://scripts/demo_route_viewport_guard_v1.gd")
const ACTIVE_ROUTE_SCRIPT: String = "res://scripts/demo_route_viewport_guard_v1.gd"


func _initialize() -> void:
    var route = RouteScript.new()
    route._build_ui()
    route._tf_install_route_viewport_guard()
    route._tf_bound_event_log()

    var frame := route.root.get_node_or_null("RouteViewportFrame") as PanelContainer
    assert(frame != null, "Der äußere Goldrahmen braucht den zentralen Viewport-Schutz.")
    assert(frame.clip_contents, "Der äußere Goldrahmen darf Inhalte außerhalb seiner Grenzen nicht zeichnen.")

    var frame_scroll := frame.get_node_or_null("RouteViewportScroll") as ScrollContainer
    assert(frame_scroll != null, "Der Goldrahmen braucht einen inneren ScrollContainer als Overflow-Sicherheitsnetz.")
    assert(
        frame_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
        "Vertikaler Overflow im Routenrahmen muss intern scrollbar sein."
    )
    assert(
        frame_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
        "Die Route darf keinen horizontalen Scroll-Overflow erzeugen."
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

    var main_file := FileAccess.open("res://main.tscn", FileAccess.READ)
    assert(main_file != null, "main.tscn muss lesbar sein.")
    assert(
        main_file.get_as_text().contains(ACTIVE_ROUTE_SCRIPT),
        "Der Viewport-Schutz muss als aktiver oberster Route-Layer in main.tscn eingetragen sein."
    )

    route.free()
    print("Route viewport guard test: OK")
    quit(0)
