extends "res://scripts/demo_route_run_save_v1.gd"

# The route is no longer presented as a demo to the player. Keep the stage
# heading focused on the only information that belongs there.


func _show_stage_choices(message: String = "") -> void:
    super._show_stage_choices(message)
    _apply_clean_stage_header()


func _prepare_resume_surface() -> void:
    super._prepare_resume_surface()
    _apply_clean_stage_header()


func _apply_clean_stage_header() -> void:
    if title_label == null:
        return
    title_label.text = "Etappe %d von %d" % [stage, ENDGAME_ROUTE_STAGE_COUNT]
