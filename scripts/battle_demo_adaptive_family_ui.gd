extends "res://scripts/battle_demo_adaptive_cards.gd"

# The family setup UI is now owned entirely by battle_demo_family_lab.gd.
# This top layer only keeps the compact explanatory subtitle. It deliberately
# does not rebuild, rename or append controls to setup rows anymore.


func _build_config(root: Control) -> void:
    super._build_config(root)

    if config_panel == null or config_panel.get_child_count() == 0:
        return
    var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
    if outer == null or outer.get_child_count() <= 1:
        return
    var subtitle: Label = outer.get_child(1) as Label
    if subtitle != null:
        subtitle.text = "Familie waehlen · Level bestimmt die Form · 1–4 pro Seite"
