class_name Player
extends CharacterBody2D

## A single sumo wrestler.
##
## Momentum is the point of the game: the stick sets a *target* velocity and the
## body eases toward it at [member acceleration], then coasts to a stop at
## [member friction] when the stick is released. Low friction relative to
## acceleration is what makes charges and shoves (Milestone 5) feel heavy.

## Emitted when [member player_index] changes, so presentation can react without
## the view having to poll.
signal player_index_changed(index: int)

## 0-based player index. Selects which action set this player reads.
@export_range(0, 3) var player_index: int = 0:
	set(value):
		var clamped := clampi(value, 0, PlayerInput.MAX_PLAYERS - 1)
		if clamped == player_index:
			return
		player_index = clamped
		player_index_changed.emit(player_index)

## Top speed in pixels per second.
@export var max_speed: float = 620.0

## Rate at which the body closes the gap to the target velocity.
@export var acceleration: float = 2600.0

## Rate at which the body bleeds off speed when no input is given.
@export var friction: float = 1800.0

## Radians per second the facing chevron rotates to track movement.
@export var turn_speed: float = 14.0

## Multiplier on [member friction] for the surface the player is standing on.
## [Arena] lowers this inside the warning track. Clamped so a bad zone value can
## never reverse or zero out braking.
var surface_friction_scale: float = 1.0:
	set(value):
		surface_friction_scale = clampf(value, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	var input_direction := PlayerInput.get_move_vector(player_index)

	if input_direction.is_zero_approx():
		velocity = velocity.move_toward(Vector2.ZERO, friction * surface_friction_scale * delta)
	else:
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
		_rotate_facing_toward(velocity.angle(), delta)

	move_and_slide()


## Rotates the body toward [param target_global_angle], taking the shortest arc
## so crossing the +/-PI wrap-around does not spin the sprite the long way.
func _rotate_facing_toward(target_global_angle: float, delta: float) -> void:
	# The target must be expressed in the *parent's* frame. Subtracting this
	# body's own rotation here instead would make it a feedback loop that
	# parks halfway to the target.
	var parent := get_parent() as Node2D
	var parent_rotation := parent.get_global_rotation() if parent != null else 0.0
	rotation = lerp_angle(rotation, target_global_angle - parent_rotation, clampf(turn_speed * delta, 0.0, 1.0))