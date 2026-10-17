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

## Emitted when a charged shove whiffs and leaves the wrestler off balance.
signal whiffed()

## Emitted when this body drives a carried player into someone else.
signal knockback_transferred(target: Player, speed: float)

## Emitted when a guarded wrestler plants and when the stance drops.
signal guard_started()
signal guard_ended()

## Emitted when a guarded wrestler bounces a blow back at [param attacker].
signal guard_reflected(attacker: Player, coverage: float)

## Collision layer bit used by the arena's boundary wall. A player that is going
## fast enough to break through drops this from their mask.
const WALL_LAYER := 2

## Collision layer bit shared by all wrestlers.
const PLAYER_LAYER := 1

enum ShoveState {
	READY,    ## Can start a new shove.
	CHARGING, ## Button held; power is building.
}

enum RecoveryState {
	NONE,    ## Not off balance.
	WHIFFED, ## Charged at nothing; helpless for a moment.
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
##
## Only governs stick-driven cruising. Lunge speeds and knockback are set
## independently, so lowering this makes the wrestlers heavier without
## disturbing how far a shove throws anyone. Must stay above
## [member Arena.wall_break_speed] so a wrestler can still walk themselves out.
@export var max_speed: float = 560.0

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

@export_group("Guard")
## Fraction of the cone that gives full coverage before the rim starts to fail.
## See [method guard_coverage_from] for why this is not a smooth fade.
const COVERAGE_FULL_FRACTION := 0.65

## How long the stance lasts, and how long it takes to use again.
@export var guard_duration: float = 0.5
@export var guard_cooldown: float = 2.0

## Fraction of the full circle covered by the guard, from 0 to 1.
##
## Maps to a frontal cone: 0 is no protection at all, 0.5 covers the front half,
## and 1.0 covers every direction. Anything outside the cone is a clean hit, so
## a guarded wrestler can still be punished from behind - being unable to turn
## is the intended cost, not a bug to patch out.
@export_range(0.0, 1.0, 0.05) var guard_coverage_ratio: float = 0.5

## Fraction of an incoming impulse still taken while fully covered. Never zero:
## a guard that negates a hit outright gives no feedback that it connected.
@export_range(0.0, 1.0, 0.05) var guard_damage_taken: float = 0.15

## Fraction of the original impulse reflected back at the attacker, scaled by
## how well the blow was covered.
@export_range(0.0, 2.0, 0.05) var guard_reflect_ratio: float = 0.5

## Seconds the attacker is staggered after hitting a guard.
##
## Without this the bounce barely exists. Interrupting only zeroes the attacker's
## current velocity; the very next physics frame the stick starts rebuilding it at
## ~43 px/frame, which cancels a 392 px reflection within about eight frames.
## In practice they simply stopped against the guard instead of bouncing off it.
@export var guard_stagger_time: float = 0.5

## Acceleration multiplier while staggered. Zero means the stick does nothing
## until the window closes, which is what lets the bounce carry.
@export_range(0.0, 1.0, 0.05) var guard_stagger_accel_scale: float = 0.0

@export_group("Whiff recovery")
## How long a wrestler stays helpless after charging at nothing.
##
## Tuned up from 0.35s: long enough that a whiff is a real opening rather than a
## slap on the wrist. At this length a player who whiffs into open space has most
## of a second for an opponent to close and hit them, which is roughly the time
## it would take to rebuild momentum from rest, so the charge is a net loss.
## Only charged shoves trigger it, so mashing the tap button is never a strategy.
@export var whiff_recovery_time: float = 0.55

## Multiplier on friction while off balance. Braking hard is what makes the
## window feel helpless rather than merely sluggish.
@export_range(1.0, 8.0, 0.1) var whiff_friction_scale: float = 3.0

## Multiplier on acceleration while off balance. Zero means the stick does
## nothing at all until the window closes.
@export_range(0.0, 1.0, 0.05) var whiff_accel_scale: float = 0.0

## Contact with anything at all ends the window early, so brushing past someone
## is a way out rather than serving the full sentence.
@export var whiff_clears_on_contact: bool = true

@export_group("Knockback transfer")
## Fraction of a carried player's speed passed on to whoever they hit.
##
## A fraction rather than all of it, or one shove would cascade through a
## four-player lobby and leave nobody able to hold their position.
@export_range(0.0, 1.0, 0.05) var knockback_transfer_ratio: float = 0.55

## A carried player slower than this passes through as a harmless bump instead of
## shoving anyone around.
@export var knockback_transfer_min_speed: float = 220.0

## Seconds before the same pair can transfer again. Stops two bodies held against
## each other from feeding each other momentum every frame.
@export var knockback_transfer_cooldown: float = 0.25

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

## Whether this wrestler is currently helpless from a whiffed charge.
var recovery_state: RecoveryState = RecoveryState.NONE

## True while planted in the defensive stance. Movement and facing are frozen.
var is_guarding: bool = false

## True while staggered by a guard bounce. The stick is dead until it lapses.
var is_staggered: bool = false

## 1.0 at the start of a stance, falling to 0. For presentation only.
var guard_ratio: float = 0.0

var _move_velocity := Vector2.ZERO
var _knockback_velocity := Vector2.ZERO
## Whoever last shoved this body. Knockback is never transferred back into them.
var _knockback_source: Player
## False for a reflection, which must not chain into a third player.
var _knockback_transferable := true
var _charge_elapsed := 0.0
var _shove_timer := 0.0
var _cooldown_timer := 0.0
var _shove_impulse := 0.0
var _shove_direction := Vector2.RIGHT
var _shove_hits: Array[Player] = []
## Set when the shove in flight connected. Decides whiff versus hit when the
## lunge window closes.
var _shove_connected := false
## True when the shove in flight came from a hold rather than a tap.
var _shove_was_charged := false
var _recovery_timer := 0.0
var _transfer_cooldown := 0.0
var _guard_timer := 0.0
var _guard_cooldown_timer := 0.0
var _guard_was_down := false
var _stagger_timer := 0.0
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
	_shove_connected = false
	_shove_was_charged = false
	_transfer_cooldown = 0.0
	_end_guard()
	_guard_was_down = false
	_guard_cooldown_timer = 0.0
	_stagger_timer = 0.0
	is_staggered = false
	_end_recovery()

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
	_knockback_source = null
	_knockback_transferable = true


## Adds an external impulse, in the same units as [member velocity].
##
## [param source] is whoever caused it. It is remembered only so that knockback
## can never be transferred back into the player who threw it, which would let
## two wrestlers shove each other in a loop.
func add_knockback(impulse: Vector2, source: Player = null, transferable: bool = true) -> void:
	_knockback_velocity += impulse
	_knockback_source = source
	_knockback_transferable = transferable


## Kills stick-driven momentum, so a hit reads as landing on an off-balance
## opponent rather than being fought off.
func interrupt() -> void:
	_move_velocity = Vector2.ZERO


## Whether the stick can currently build momentum. Staggered and off-balance
## wrestlers are the exceptions.
func can_build_momentum() -> bool:
	return not is_staggered and recovery_state == RecoveryState.NONE


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
	_update_recovery(delta)
	_update_stagger(delta)
	_update_guard(delta)
	_update_shove(delta)
	_transfer_cooldown = maxf(0.0, _transfer_cooldown - delta)
	_sync_charge_indicator()

	var input_direction := PlayerInput.get_move_vector(player_index)
	var speed_cap := max_speed
	var accel := acceleration
	if shove_state == ShoveState.CHARGING:
		# Bracing: planted and slow, which is what sells the wind-up.
		speed_cap *= charge_speed_scale
		accel *= charge_accel_scale

	if recovery_state == RecoveryState.WHIFFED:
		accel *= whiff_accel_scale
	if is_staggered:
		accel *= guard_stagger_accel_scale

	# Guarding overrides the lot: no stick, and no turning. A wrestler who cannot
	# pivot is why the stance has a back to it.
	if is_guarding:
		_move_velocity = Vector2.ZERO
	elif input_direction.is_zero_approx():
		var braking := friction * surface_friction_scale
		if _shove_timer > 0.0:
			# Stay committed through the lunge so the attacker actually arrives.
			braking *= shove_friction_scale
		if recovery_state == RecoveryState.WHIFFED:
			braking *= whiff_friction_scale
		_move_velocity = _move_velocity.move_toward(Vector2.ZERO, braking * delta)
	else:
		_move_velocity = _move_velocity.move_toward(input_direction * speed_cap, accel * delta)
		_rotate_facing_toward(_move_velocity.angle(), delta)

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	if _knockback_velocity.is_zero_approx():
		_knockback_source = null
		_knockback_transferable = true

	velocity = _move_velocity + _knockback_velocity
	move_and_slide()

	_transfer_knockback()
	if recovery_state == RecoveryState.WHIFFED and whiff_clears_on_contact and get_slide_collision_count() > 0:
		_end_recovery()


## How well the current guard covers a blow arriving from [param from_direction],
## a unit vector in world space. 1.0 is dead in front, 0.0 is anything the cone
## does not reach.
func guard_coverage_from(from_direction: Vector2) -> float:
	if not is_guarding:
		return 0.0
	var half_angle := PI * guard_coverage_ratio
	if half_angle <= 0.0:
		return 0.0
	if half_angle >= PI:
		return 1.0
	var off_axis := absf(from_direction.angle_to(facing_direction()))
	if off_axis >= half_angle:
		return 0.0
	# Coverage holds at full across the inner part of the cone and gives out
	# sharply at the rim, rather than fading smoothly into uselessness.
	#
	# A plain smoothstep across the whole cone looked reasonable on paper but
	# played as no guard at all: 60 degrees off axis measured 0.26 coverage, and
	# because slide distance goes as the square of impulse that was still 60% of
	# a full unblocked knockback. A defender who was guarding correctly simply
	# got thrown across the ring. The rim is where the guard gives out, so it
	# should read that way.
	var rim := half_angle * COVERAGE_FULL_FRACTION
	if off_axis <= rim:
		return 1.0
	return 1.0 - smoothstep(rim, half_angle, off_axis)


func _update_stagger(delta: float) -> void:
	if _stagger_timer <= 0.0:
		is_staggered = false
		return
	_stagger_timer = maxf(0.0, _stagger_timer - delta)
	is_staggered = _stagger_timer > 0.0


## Staggers the attacker after a guard bounce. See [member guard_stagger_time]
## for why interrupting alone is not enough.
func _apply_guard_stagger() -> void:
	_stagger_timer = maxf(_stagger_timer, guard_stagger_time)
	is_staggered = true


func _update_guard(delta: float) -> void:
	_guard_cooldown_timer = maxf(0.0, _guard_cooldown_timer - delta)

	# Edge-detected by hand for the same reason as the shove button: the
	# just_pressed form is tied to the idle frame.
	var down := PlayerInput.is_guard_pressed(player_index)
	var pressed := down and not _guard_was_down
	_guard_was_down = down

	if not is_guarding:
		if pressed and _guard_cooldown_timer <= 0.0 and not is_staggered and recovery_state == RecoveryState.NONE:
			_enter_guard()
		return

	_guard_timer -= delta
	guard_ratio = clampf(_guard_timer / maxf(guard_duration, 0.001), 0.0, 1.0)
	# Releasing early ends the stance, but the cooldown still applies, so a
	# tap-block on the quick shove is not strictly better than committing.
	if _guard_timer <= 0.0 or not down:
		_end_guard()


func _enter_guard() -> void:
	# Mutually exclusive with a charge: both are immobile commitments, and
	# cancelling a paid-for charge to enter one would be a silent loss.
	# A lunge in flight is a commitment too. Starting a stance on it would leave
	# the wrestler guarding and then whiffed at the same time.
	if shove_state == ShoveState.CHARGING or _shove_timer > 0.0:
		return
	is_guarding = true
	_guard_timer = guard_duration
	guard_ratio = 1.0
	# Planted: stick momentum stops dead, but knockback already in flight keeps
	# sliding, so a late guard cannot undo a hit it did not block.
	interrupt()
	guard_started.emit()


func _end_guard() -> void:
	if not is_guarding:
		return
	is_guarding = false
	guard_ratio = 0.0
	_guard_cooldown_timer = guard_cooldown
	guard_ended.emit()


## Passes some of this body's carried speed into whoever it just ran into.
##
## Deliberately not aimed: a shove throws a victim along the attacker's line of
## attack, whereas a collision throws them along the impact line. That contrast is
## the point - it is the difference between being hit and being used as a weapon.
func _transfer_knockback() -> void:
	if _transfer_cooldown > 0.0:
		return
	# A reflection bounces back through the defender without carrying, so it must
	# not cascade into a third player the way an ordinary shove does.
	if not _knockback_transferable:
		return
	var speed := _knockback_velocity.length()
	if speed < knockback_transfer_min_speed:
		return

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider() as Player
		if other == null or other == self or not other.is_active:
			continue
		# Never hand momentum back to whoever threw it.
		if other == _knockback_source:
			continue

		# The normal points back at us, so negating it points through them.
		var push := -collision.get_normal()
		if push.length_squared() < 0.001:
			push = _knockback_velocity / speed
		push = push.normalized()

		# A guard absorbs a carried shove just as it absorbs a direct one. The
		# blow arrives from this body, so coverage is judged along the line back to it.
		var taken := 1.0
		if other.is_guarding:
			taken = lerpf(1.0, other.guard_damage_taken, other.guard_coverage_from(-push))
		var passed := speed * knockback_transfer_ratio * taken

		other.interrupt()
		other.add_knockback(push * passed, self)
		_transfer_cooldown = knockback_transfer_cooldown
		knockback_transferred.emit(other, passed)
		return


func _update_recovery(delta: float) -> void:
	if recovery_state == RecoveryState.NONE:
		return
	_recovery_timer -= delta
	if _recovery_timer <= 0.0:
		_end_recovery()


## Hands the wrestler over as helpless after a charge that connected with nothing.
func _begin_recovery() -> void:
	recovery_state = RecoveryState.WHIFFED
	# Never stack: re-entering recovery does not extend an existing one.
	_recovery_timer = maxf(_recovery_timer, whiff_recovery_time)
	whiffed.emit()


func _end_recovery() -> void:
	recovery_state = RecoveryState.NONE
	_recovery_timer = 0.0


## Rotates the body toward [param target_global_angle], taking the shortest arc
## so crossing the +/-PI wrap-around does not spin the sprite the long way.
func _rotate_facing_toward(target_global_angle: float, delta: float) -> void:
	# The target must be expressed in the *parent's* frame. Subtracting this
	# body's own rotation here instead would make it a feedback loop that
	# parks halfway to the target.
	var parent := get_parent() as Node2D
	var parent_rotation := parent.get_global_rotation() if parent != null else 0.0
	# Slippery footing turns the wrestler more slowly too, as design.md specifies
	# for the warning track.
	rotation = lerp_angle(rotation, target_global_angle - parent_rotation, clampf(turn_speed * surface_friction_scale * delta, 0.0, 1.0))


func _update_shove(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	if _shove_timer > 0.0:
		_shove_timer -= delta
		if _shove_timer <= 0.0:
			_hitbox.set_deferred(&"monitoring", false)
			_refresh_collision_mask()
			# The lunge window has closed. A charge that never touched anyone
			# inside it connected with thin air, and that is what gets punished.
			if _shove_was_charged and not _shove_connected:
				_begin_recovery()

	# Tracked by hand rather than using is_action_just_pressed, which is tied to
	# the idle frame and can be missed entirely by a physics step.
	var down := PlayerInput.is_shove_pressed(player_index)
	var pressed := down and not _shove_was_down
	var released := not down and _shove_was_down
	_shove_was_down = down

	if shove_state == ShoveState.READY:
		charge_ratio = 0.0
		_set_hitbox_radius(hitbox_radius_min)
		# Helpless after a whiff means no counter-attack either, and no stance.
		# A staggered attacker cannot counter at all.
		if pressed and _cooldown_timer <= 0.0 and not is_guarding and can_build_momentum():
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
		view.guard_ratio = guard_ratio
		view.is_off_balance = recovery_state == RecoveryState.WHIFFED


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
	_shove_connected = false
	_shove_was_charged = not is_tap
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
	_shove_connected = true

	var to_target := _knockback_direction_for(target)
	# Where the blow appears to come from, as the defender sees it.
	var coverage := target.guard_coverage_from(-to_target)

	target.interrupt()
	# Never a full negation: some slide is what tells you a hit landed at all.
	var taken := lerpf(1.0, target.guard_damage_taken, coverage)
	target.add_knockback(to_target * _shove_impulse * taken, self)
	target.flash()

	if coverage > 0.0:
		# A blocked lunge is stopped, not merely slowed. Without this the
		# reflection is swamped by the attacker's own forward momentum and they
		# simply plough through the guard still moving.
		interrupt()
		_apply_guard_stagger()
		# Bounced back along the impact line, not aimed - a block you did not
		# choose to face cannot be aimed either. Flagged non-transferable so a
		# reflected attacker cannot cascade into a third player.
		add_knockback(-to_target * _shove_impulse * target.guard_reflect_ratio * coverage, target, false)
		guard_reflected.emit(target, coverage)

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