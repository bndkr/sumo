extends Node2D

## Milestone 4 entry point. The roster lives in [GameManager], the round rules
## in [RoundManager]; this node only wires them together and owns the temporary
## boundary-wall toggle.

@onready var _manager: GameManager = $GameManager
@onready var _camera: FitCamera = $Camera2D


func _ready() -> void:
	_camera.bind(_manager)