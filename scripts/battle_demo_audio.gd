extends "res://scripts/battle_demo_igglybuff_family.gd"

# Legacy compatibility shim.
# Audio hooks now live inside the established battle inheritance chain
# (battle_demo_start_aggro_v1.gd). Keeping this filename as a no-op child makes
# older local project folders harmless when they still reference/open the former
# standalone audio layer.
