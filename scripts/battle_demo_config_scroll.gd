extends "res://scripts/battle_demo_timeflow_weather.gd"

# Final combat-lab configuration overflow guard.
#
# The 640x360 virtual viewport can no longer assume that every setup option fits
# vertically. TM test controls and future lab options may legitimately make the
# configuration taller than the viewport, so the complete setup area is placed
# inside a vertical ScrollContainer instead of being clipped at the bottom.

var config_scroll: ScrollContainer = null


func _build_config(root: Control) -> void:
    super._build_config(root)
    _wrap_config_in_vertical_scroll()


func _wrap_config_in_vertical_scroll() -> void:
    if config_panel == null:
        return

    var existing_scroll: ScrollContainer = config_panel.get_node_or_null("ConfigScroll") as ScrollContainer
    if existing_scroll != null:
        config_scroll = existing_scroll
        return

    if config_panel.get_child_count() == 0:
        return

    # All inherited config layers have finished at this point. They intentionally
    # see the historic direct VBox child while building; only the final layer
    # reparents it, so older setup code remains compatible.
    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer == null:
        return

    config_panel.remove_child(outer)

    config_scroll = ScrollContainer.new()
    config_scroll.name = "ConfigScroll"
    config_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    config_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    config_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    config_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    config_scroll.follow_focus = true
    config_panel.add_child(config_scroll)

    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    config_scroll.add_child(outer)


func open_config() -> void:
    super.open_config()
    if config_scroll != null:
        config_scroll.scroll_vertical = 0
