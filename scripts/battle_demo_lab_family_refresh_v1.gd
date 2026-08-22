extends "res://scripts/battle_demo_endgame_v2.gd"

# Final combat-lab family registry refresh.
# Lower family layers append their route roots during _load_data(). The family
# lab itself sits below those layers in the inheritance chain, so its earlier
# snapshot can be stale by the time the UI is built. Refresh once at the very
# top after every family loader has finished.


func _load_data() -> void:
    super._load_data()
    lab_species_ids = species_ids.duplicate()
