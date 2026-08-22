extends "res://scripts/main_audio.gd"

# Small active main-menu layer for the 100-stage route.
# Keeps the established menu implementation intact and only corrects the
# player-facing route length text after the menu has been built.


func _ready() -> void:
    super._ready()
    _refresh_100_stage_menu_copy()


func _refresh_100_stage_menu_copy() -> void:
    if menu_root == null:
        return
    _rewrite_route_length_text(menu_root)


func _rewrite_route_length_text(node: Node) -> void:
    if node is Label:
        var label := node as Label
        label.text = label.text.replace("bis Etappe 90", "bis Etappe 100")
        label.text = label.text.replace("90 Etappen", "100 Etappen")
    elif node is Button:
        var button := node as Button
        button.tooltip_text = button.tooltip_text.replace("90 Etappen", "100 Etappen")
        button.tooltip_text = button.tooltip_text.replace("bis Etappe 90", "bis Etappe 100")

    for child: Node in node.get_children():
        _rewrite_route_length_text(child)
