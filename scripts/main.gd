class_name Main
extends Node2D

## Milestone 1 entry point: spawns a single player on a blank background and
## keeps it framed by following it with the camera.
##
## Milestone 2 replaces the hardcoded instance with a GameManager that reads
## connected joypads and spawns one Player per device.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var _player: Player = $World/Player
@onready var _camera: Camera2D = $World/Camera2D


func _ready() -> void:
	_player.player_index = 0
	_player_body_view().player_index = _player.player_index
	_camera.make_current()
	_camera.reset_smoothing()


func _physics_process(_delta: float) -> void:
	# Follow, but only once the player drifts past a margin, so small movements
	# around the spawn point do not make the whole screen swim.
	var offset := _player.global_position - _camera.global_position
	var margin := Vector2(220.0, 140.0)
	if absf(offset.x) > margin.x or absf(offset.y) > margin.y:
		var clamped := Vector2(
			clampf(offset.x, -margin.x, margin.x),
			clampf(offset.y, -margin.y, margin.y)
		)
		_camera.global_position += clamped


func _player_body_view() -> PlayerBodyView:
	return _player.get_node("BodyView")