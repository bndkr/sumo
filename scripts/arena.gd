class_name Arena
extends Node2D

## The sumo ring: a safe floor, a warning track, and the fatal void beyond.
##
## Geometry is built procedurally from concentric annuli rather than authored in
## the editor, so the radii stay a single source of truth and the collision
## shapes can never drift out of sync with what is drawn.
##
## Zone membership drives gameplay, not just visuals: [WarningZone] lowers a
## player's friction so turning and stopping get less responsive near the edge.
##
## [DeathZone] is built wide so a hard shove in Milestone 5 is caught wherever
## it lands. Milestone 4 consumes it for elimination and is also where the
## [Boundary] wall gets made permeable - until then players cannot leave the ring
## at all, which is why M4's "drive player 2 out" needs the push mechanic first.

## Emitted when a player crosses into the void. Milestone 4 consumes this to
## trigger elimination.
signal elimination_detected(body: Node2D)

## Radius of the safe floor.
@export var safe_radius: float = 420.0

## Outer radius of the warning track. The solid wall sits here, so this is also
## the hard limit a player can currently reach.
@export var warning_radius: float = 600.0

## Thickness of the wall ring.
@export var wall_thickness: float = 28.0

## How far past the wall the death zone is monitored.
@export var death_zone_depth: float = 3000.0

## Friction multiplier applied to players standing in the warning track.
## Below 1.0 makes them slide further and turn more sluggishly.
@export var warning_friction_scale: float = 0.6

## Wedges used to approximate each circle. Higher is smoother and costlier.
@export_range(8, 256, 1) var segment_count: int = 96

## Whether the solid wall is in place. Milestone 5 gives hard shoves enough
## force to break through it, so this is now a tuning aid rather than a
## gameplay dependency: turning it off makes the ring entirely unbounded.
@export var boundary_enabled: bool = true

## A player travelling faster than this stops colliding with the wall and passes
## straight through. Must stay above [member Player.max_speed], or ordinary
## running would breach the ring and Milestone 3's "collide with the arena
## bounds" would stop holding.
@export var wall_break_speed: float = 700.0

@onready var _warning_zone: Area2D = $WarningZone
@onready var _death_zone: Area2D = $DeathZone
@onready var _boundary: StaticBody2D = $Boundary
@onready var _view: ArenaView = $View


func _ready() -> void:
	if safe_radius >= warning_radius:
		push_error("Arena: safe_radius (%f) must be smaller than warning_radius (%f)." % [safe_radius, warning_radius])
		return

	_build_shapes()
	_view.safe_radius = safe_radius
	_view.warning_radius = warning_radius
	_view.wall_thickness = wall_thickness
	_view.set_process(true)

	_warning_zone.body_entered.connect(_on_warning_body_entered)
	_warning_zone.body_exited.connect(_on_warning_body_exited)
	# body_entered, not body_exited: the zone is the void *outside* the ring, so
	# entering it is what means "eliminated".
	_death_zone.body_entered.connect(_on_death_body_entered)
	set_boundary_enabled(boundary_enabled)


func _physics_process(_delta: float) -> void:
	_update_wall_breaches()


## Decides, per player, whether the boundary still stops them.
##
## The wall blocks ordinary play but yields to a hard launch, which is what lets
## a heavy charge actually ring someone out. Players already past the boundary
## stay unblocked so they cannot be shoved back in by the wall they are outside
## of.
func _update_wall_breaches() -> void:
	if not boundary_enabled:
		return
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		if player == null or not player.is_active:
			continue
		var outside := player.global_position.length() >= warning_radius
		player.set_ignores_wall(outside or player.velocity.length() > wall_break_speed)


## Opens or closes the wall so a player can be driven into the void on foot.
## Used for testing and tuning; Milestone 5's shove is the real way out.
func set_boundary_enabled(enabled: bool) -> void:
	boundary_enabled = enabled
	for child in _boundary.get_children():
		var collision := child as CollisionShape2D
		if collision != null:
			collision.set_deferred("disabled", not enabled)


## True when [param point] lies in the warning track.
func is_in_warning_track(point: Vector2) -> bool:
	var distance := point.length()
	return distance >= safe_radius and distance < warning_radius


## Fills the annulus between [param inner_r] and [param outer_r] with
## [param segments] convex wedges. Each wedge spans a slice of the ring, which
## keeps every shape convex - concave ring outlines are unreliable to collide
## against and expensive to decompose.
static func ring_wedges(inner_r: float, outer_r: float, segments: int) -> Array[PackedVector2Array]:
	var wedges: Array[PackedVector2Array] = []
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		wedges.append(PackedVector2Array([
			Vector2.from_angle(a0) * inner_r,
			Vector2.from_angle(a1) * inner_r,
			Vector2.from_angle(a1) * outer_r,
			Vector2.from_angle(a0) * outer_r,
		]))
	return wedges


func _build_shapes() -> void:
	for wedge in ring_wedges(safe_radius, warning_radius, segment_count):
		_add_shape(_warning_zone, wedge)
	for wedge in ring_wedges(warning_radius, warning_radius + death_zone_depth, segment_count):
		_add_shape(_death_zone, wedge)
	for wedge in ring_wedges(warning_radius - wall_thickness, warning_radius, segment_count):
		_add_shape(_boundary, wedge)

	# Own collision layer so a launched player can drop just this one.
	_boundary.collision_layer = Player.WALL_LAYER


func _add_shape(host: Node, wedge: PackedVector2Array) -> void:
	var collision := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = wedge
	collision.shape = shape
	host.add_child(collision)


func _on_warning_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.surface_friction_scale = warning_friction_scale


func _on_warning_body_exited(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.surface_friction_scale = 1.0


func _on_death_body_entered(body: Node2D) -> void:
	if body is Player:
		elimination_detected.emit(body)