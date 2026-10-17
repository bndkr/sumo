extends Node2D

## Milestone 4 entry point. The roster lives in [GameManager], the round rules
## in [RoundManager]; this node only wires them together and owns the temporary
## boundary-wall toggle.

@onready var _manager: GameManager = $GameManager
@onready var _arena: Arena = $Arena
@onready var _camera: FitCamera = $Camera2D
@onready var _announcer: Announcer = $Announcer


func _ready() -> void:
	_camera.bind(_manager)


func _unhandled_input(event: InputEvent) -> void:
	# Temporary scaffold: Milestone 3's solid wall makes the death zone
	# unreachable on foot, so elimination cannot otherwise be tested until
	# Milestone 5 adds the shove. Milestone 5 should remove this.
	if not event.is_action_pressed("debug_toggle_wall"):
		return

	var now_enabled := not _arena.boundary_enabled
	_arena.set_boundary_enabled(now_enabled)
	_announcer.show_message("Boundary wall %s" % ("ON" if now_enabled else "OFF"), 1.0)