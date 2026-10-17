class_name Player
extends CharacterBody2D

## A single sumo wrestler.
##
## Momentum is the point of the game: the stick sets a *target* velocity and the
## body eases toward it at [member acceleration], then coasts to a stop at
## [member friction] when the stick is released. Low friction relative to
## acceleration is what makes charges and shoves feel heavy.
##
## Velocity is kept in two parts. [member _move_velocity] is the stick-driven
## momentum, which steering and facing care about. [member _knockback_velocity]
## is an external impulse that decays on its own and ignores the stick. Keeping
## them separate is what lets a shoved player keep sliding even while holding
## the stick the other way.

## Emitted when [member player_index] changes, so presentation can react without
## the view having to poll.
signal player_index_changed(index: int)

## Emitted when a shove connects. Milestone 6 uses this for screen shake.
signal shove_landed(target: Player, power: float)

## Collision layer bit used by the arena's boundary wall. A player that is going
## fast enough to break through drops this from their mask.
const WALL_LAYER := 2

## Collision layer bit shared by all wrestlers.
const PLAYER_LAYER := 1

enum ShoveState {
	READY,    ## Can start a new shove.
	CHARGING, ## Button held; power is building.
}

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

## How fast an external shove impulse bleeds away. Lower values let a hit carry
## much further; this is the main dial for how violent a shove feels.
@export var knockback_decay: float = 480.0

@export_group("Shove")
## Seconds of holding for a full-power charge.
@export var charge_time: float = 1.5

## Hold longer than this and the shove counts as charged rather than a tap.
@export var tap_threshold: float = 0.12

## Knockback applied by a tap. Tuned up from 260 so a quick jab actually moves
## someone; still well short of [member charged_shove_impulse].
@export var quick_shove_impulse: float = 380.0

## Knockback applied by a full charge.
@export var charged_shove_impulse: float = 980.0

## Forward burst speed from a tap.
@export var quick_lunge_speed: float = 700.0

## Forward burst speed from a full charge.
@export var charged_lunge_speed: float = 1500.0

## How long the hitbox stays live after a shove.
@export var shove_active_time: float = 0.22

## Dead time before another shove can start.
@export var shove_cooldown: float = 0.3

## Hitbox radius for a tap, and for a fully charged lunge. Kept close to the
## body: the wrestlers are 42 px, so they touch at 84 px, and a hitbox much
## longer than that fires while the two are still visibly apart.
@export var hitbox_radius_min: float = 45.0
@export var hitbox_radius_max: float = 54.0

## Top-speed and acceleration multipliers while bracing for a charge.
@export var charge_speed_scale: float = 0.6
@export var charge_accel_scale: float = 0.35

## How far off-centre a hit may be before the victim is thrown along the
## attacker's line of attack instead of straight away from the attacker.
##
## A shove reads as an intended push, so a slightly glancing hit should still
## launch the victim the way the attacker was aiming - otherwise a near miss
## squirts them off to the side, which makes an aimed ring-out unreliable.
## Beyond this angle the contact is treated as a genuine glancing blow and the
## victim flies along the line between the two bodies, as billiards would.
##
## Set to 0 to disable the buffer and always use the centre-to-centre line.
@export_range(0.0, 90.0, 1.0) var shove_direction_buffer_degrees: float = 40.0

## Fraction of forward lunge speed kept after a shove connects. Low values stop
## the attacker dead; higher values let it carry through into the victim so the
## two visibly meet.
@export_range(0.0, 1.0, 0.05) var shove_self_recovery: float = 0.9

## Multiplier on [member friction] while a lunge is in progress. Ordinary
## friction bleeds a lunge off far faster than it can close on a victim, leaving
## the two visibly short of each other.
@export_range(0.0, 1.0, 0.05) var shove_friction_scale: float = 0.15

## Multiplier on [member friction] for the surface the player is standing on.
## [Arena] lowers this inside the warning track. Clamped so a bad zone value can
## never reverse or zero out braking.
var surface_friction_scale: float = 1.0:
	set(value):
		surface_friction_scale = clampf(value, 0.0, 1.0)

## False while eliminated: stops simulating, hides, and stops colliding.
var is_active: bool = true

## 0..1 charge progress, for presentation only.
var charge_ratio: float = 0.0

var shove_state: ShoveState = ShoveState.READY

var _move_velocity := Vector2.ZERO
var _knockback_velocity := Vector2.ZERO
var _charge_elapsed := 0.0
var _shove_timer := 0.0
var _cooldown_timer := 0.0
var _shove_impulse := 0.0
var _shove_direction := Vector2.RIGHT
var _shove_hits: Array[Player] = []
var _shove_was_down := false
var _ignores_wall := false
var _base_collision_mask := 1

@onready var _hitbox: Area2D = $Hitbox
@onready var _hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	_base_collision_mask = collision_mask
	# Sub-resources in a PackedScene are shared between instances, so the hitbox
	# needs its own copy before the radius can be scaled with charge.
	var shape := _hitbox_shape.shape as CircleShape2D
	if shape != null:
		_hitbox_shape.shape = shape.duplicate()
	_hitbox.body_entered.connect(_on_hitbox_body_entered)
	add_to_group(&"players")


## Recomputes which layers this body collides with. Only the arena's boundary
## wall is ever dropped - wrestlers always collide with each other, so a charge
## ends in a real collision rather than two bodies sliding through each other.
func _refresh_collision_mask() -> void:
	var mask := _base_collision_mask
	if _ignores_wall:
		mask &= ~WALL_LAYER
	set_deferred(&"collision_mask", mask)


func _set_hitbox_radius(radius: float) -> void:
	var shape := _hitbox_shape.shape as CircleShape2D
	if shape != null:
		shape.radius = radius


## Enters or leaves the round. An inactive player is inert rather than freed, so
## the controller that drives it stays bound and it can return for the next round.
##
## The collision shape is deliberately left enabled. Toggling it does not work
## here: re-enabling happens deferred, while the physics body is still parked
## wherever the player was eliminated, because a [CharacterBody2D] only syncs
## its transform during [method PhysicsBody2D.move_and_slide] on the next
## physics step. The arena's death zone would therefore see the body reappear
## inside itself and fire `body_entered` again, eliminating the player on the
## first frame of the new round. Moving the body back to its spawn mark (see
## [method GameManager.reset_players]) lets the area deregister it naturally.
## Eliminated players also stay solid to each other out in the void, which is
## harmless because the boundary wall keeps live players out there.
func set_active(active: bool) -> void:
	if active == is_active:
		return
	is_active = active
	set_physics_process(active)
	stop_motion()
	reset_shove()

	var view := get_node_or_null(^"BodyView") as Node2D
	if view != null:
		view.visible = active

	if not active:
		surface_friction_scale = 1.0


## Abandons any charge in progress and disarms the hitbox.
##
## Called whenever a player leaves or joins a round, so a wind-up cannot be
## carried across the boundary - a player still holding the button simply starts
## a fresh charge for the new round. Lives outside [method set_active] because
## that returns early when the player's active state is unchanged, which is
## exactly the case for a player who was never eliminated.
func reset_shove() -> void:
	shove_state = ShoveState.READY
	charge_ratio = 0.0
	_charge_elapsed = 0.0
	_cooldown_timer = 0.0
	_shove_timer = 0.0
	_shove_hits.clear()
	# Cleared so a button still held at reset time reads as a fresh press and
	# begins a new charge, rather than being swallowed as the release of the
	# charge we just cancelled.
	_shove_was_down = false

	if _hitbox != null:
		_hitbox.set_deferred(&"monitoring", false)
	_set_hitbox_radius(hitbox_radius_min)
	_refresh_collision_mask()
	_sync_charge_indicator()


## Bright-flashes the body. Presentation only; safe to call on an eliminated
## player whose view is hidden.
func flash() -> void:
	var view := get_node_or_null(^"BodyView") as PlayerBodyView
	if view != null:
		view.flash()


## Clears stick momentum, knockback, and the derived velocity.
## Clearing [member velocity] alone is not enough: it is rebuilt every physics
## frame from the two accumulators, so a player revived with knockback still in
## _knockback_velocity is launched straight back out of the ring the instant the
## new round begins.
func stop_motion() -> void:
	velocity = Vector2.ZERO
	_move_velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO


## Adds an external impulse, in the same units as [member velocity].
func add_knockback(impulse: Vector2) -> void:
	_knockback_velocity += impulse


## Kills stick-driven momentum, so a hit reads as landing on an off-balance
## opponent rather than being fought off.
func interrupt() -> void:
	_move_velocity = Vector2.ZERO


## Unit vector the body is facing, in world space.
func facing_direction() -> Vector2:
	return Vector2.from_angle(global_rotation)


## Lets the boundary wall stop colliding with this body. Used by [Arena] for
## players moving fast enough to break through.
func set_ignores_wall(value: bool) -> void:
	if value == _ignores_wall:
		return
	_ignores_wall = value
	_refresh_collision_mask()


func _physics_process(delta: float) -> void:
	_update_shove(delta)
	_sync_charge_indicator()

	var input_direction := PlayerInput.get_move_vector(player_index)
	var speed_cap := max_speed
	var accel := acceleration
	if shove_state == ShoveState.CHARGING:
		# Bracing: planted and slow, which is what sells the wind-up.
		speed_cap *= charge_speed_scale
		accel *= charge_accel_scale

	if input_direction.is_zero_approx():
		var braking := friction * surface_friction_scale
		if _shove_timer > 0.0:
			# Stay committed through the lunge so the attacker actually arrives.
			braking *= shove_friction_scale
		_move_velocity = _move_velocity.move_toward(Vector2.ZERO, braking * delta)
	else:
		_move_velocity = _move_velocity.move_toward(input_direction * speed_cap, accel * delta)
		_rotate_facing_toward(_move_velocity.angle(), delta)

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)

	velocity = _move_velocity + _knockback_velocity
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


func _update_shove(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	if _shove_timer > 0.0:
		_shove_timer -= delta
		if _shove_timer <= 0.0:
			_hitbox.set_deferred(&"monitoring", false)
			_refresh_collision_mask()

	# Tracked by hand rather than using is_action_just_pressed, which is tied to
	# the idle frame and can be missed entirely by a physics step.
	var down := PlayerInput.is_shove_pressed(player_index)
	var pressed := down and not _shove_was_down
	var released := not down and _shove_was_down
	_shove_was_down = down

	if shove_state == ShoveState.READY:
		charge_ratio = 0.0
		_set_hitbox_radius(hitbox_radius_min)
		if pressed and _cooldown_timer <= 0.0:
			shove_state = ShoveState.CHARGING
			_charge_elapsed = 0.0
		return

	_charge_elapsed += delta
	charge_ratio = clampf(_charge_elapsed / charge_time, 0.0, 1.0)
	_set_hitbox_radius(lerpf(hitbox_radius_min, hitbox_radius_max, charge_ratio))
	if released:
		_release_shove()


## Keeps the visual charge gauge in step with the logical charge.
func _sync_charge_indicator() -> void:
	var view := get_node_or_null(^"BodyView") as PlayerBodyView
	if view != null:
		view.charge_ratio = charge_ratio


func _release_shove() -> void:
	var ratio := clampf(_charge_elapsed / charge_time, 0.0, 1.0)
	var is_tap := _charge_elapsed < tap_threshold

	# A tap is a short, low push. A hold scales from there up to the full lunge.
	var impulse := lerpf(quick_shove_impulse, charged_shove_impulse, ratio)
	var lunge := lerpf(quick_lunge_speed, charged_lunge_speed, ratio)
	if is_tap:
		impulse = quick_shove_impulse
		lunge = quick_lunge_speed

	shove_state = ShoveState.READY
	charge_ratio = 0.0
	_cooldown_timer = shove_cooldown

	_shove_direction = facing_direction()
	_move_velocity = _shove_direction * lunge
	_knockback_velocity = Vector2.ZERO

	_shove_impulse = impulse
	_shove_hits.clear()
	_shove_timer = shove_active_time
	_set_hitbox_radius(lerpf(hitbox_radius_min, hitbox_radius_max, ratio))
	_hitbox.set_deferred(&"monitoring", true)
	_refresh_collision_mask()


func _on_hitbox_body_entered(body: Node2D) -> void:
	var target := body as Player
	if target == null or target == self or not target.is_active:
		return
	if target in _shove_hits:
		return
	_shove_hits.append(target)

	target.interrupt()
	target.add_knockback(_knockback_direction_for(target) * _shove_impulse)
	target.flash()

	# Carry some momentum into the victim so the two visibly meet. Stopping dead
	# instead would leave a gap between them, which reads as a shove that fired
	# from nowhere rather than a body hitting a body.
	_move_velocity *= shove_self_recovery

	shove_landed.emit(target, _shove_impulse / maxf(charged_shove_impulse, 1.0))


## Where a hit sends the victim.
##
## Inside [member shove_direction_buffer_degrees] of the attacker's line of
## attack the victim is thrown that way, so a shove lands where it was aimed
## even when it clips the edge of someone. Outside it the hit is a genuine
## glancing blow and the victim goes along the line joining the two bodies,
## which is what makes a proper miss deflect instead of shove.
func _knockback_direction_for(target: Player) -> Vector2:
	var to_target := target.global_position - global_position
	if to_target.length_squared() < 1.0:
		return _shove_direction

	var centre_line := to_target.normalized()
	if shove_direction_buffer_degrees <= 0.0:
		return centre_line

	var off_axis := rad_to_deg(absf(centre_line.angle_to(_shove_direction)))
	return _shove_direction if off_axis <= shove_direction_buffer_degrees else centre_line