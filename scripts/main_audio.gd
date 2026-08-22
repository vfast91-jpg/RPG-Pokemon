extends "res://scripts/main_logo.gd"

# Thin top-level audio layer. The established main-menu/game-selection logic
# stays in main_logo.gd and its parents.


func _ready() -> void:
    super._ready()
    AudioManager.play_main_menu()


func _show_main_menu() -> void:
    super._show_main_menu()
    AudioManager.play_main_menu()
