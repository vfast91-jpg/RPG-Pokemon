extends Node2D

@onready var battle_demo: CanvasLayer = $BattleDemo

func _ready() -> void:
    battle_demo.open_config()
