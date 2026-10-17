extends Node2D

## Milestone 2 entry point. The roster itself lives in [GameManager]; this node
## only wires it to the camera.

@onready var _manager: GameManager = $GameManager
@onready var _camera: FitCamera = $Camera2D


func _ready() -> void:
	_camera.bind(_manager)