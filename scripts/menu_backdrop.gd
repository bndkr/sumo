extends Control

## Decorative backdrop for the start screen: the ring and two wrestlers, drawn
## from simple polygons so the menu matches the placeholder art in the game.
##
## The radii below mirror the Arena defaults. They only set how the picture
## looks here; gameplay still reads the Arena node.

const BACKGROUND := Color(0.07, 0.08, 0.11)
const VOID_COLOR := Color(0.05, 0.05, 0.07)
const FLOOR_COLOR := Color(0.44, 0.34, 0.27)
const WARNING_COLOR := Color(0.93, 0.72, 0.16, 0.8)
const RIM_COLOR := Color(0.97, 0.94, 0.86)

const SAFE_RADIUS := 420.0
const WARNING_RADIUS := 600.0
const WALL_THICKNESS := 45.0
const BODY_RADIUS := 42.0
const SEGMENTS := 64


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)

	var scale_factor := minf(size.y * 0.42, size.x * 0.24) / WARNING_RADIUS
	var centre := Vector2(size.x * 0.72, size.y * 0.5)
	var inner_floor := (WARNING_RADIUS - WALL_THICKNESS) * scale_factor

	draw_circle(centre, WARNING_RADIUS * scale_factor, VOID_COLOR)
	draw_circle(centre, inner_floor, FLOOR_COLOR)
	_draw_ring(centre, SAFE_RADIUS * scale_factor, inner_floor, WARNING_COLOR)
	_draw_ring(centre, inner_floor, WARNING_RADIUS * scale_factor, RIM_COLOR)

	var reach := SAFE_RADIUS * 0.45 * scale_factor
	var body := BODY_RADIUS * scale_factor
	_draw_wrestler(centre + Vector2(-reach, 0.0), 0.0, PlayerBodyView.PLAYER_COLORS[0], body)
	_draw_wrestler(centre + Vector2(reach, 0.0), PI, PlayerBodyView.PLAYER_COLORS[1], body)


func _draw_ring(centre: Vector2, inner: float, outer: float, color: Color) -> void:
	for wedge in Arena.ring_wedges(inner, outer, SEGMENTS):
		var points := PackedVector2Array()
		for point in wedge:
			points.append(centre + point)
		draw_colored_polygon(points, color)


func _draw_wrestler(pos: Vector2, angle: float, color: Color, radius: float) -> void:
	draw_circle(pos, radius, color)
	draw_arc(pos, radius, 0.0, TAU, 40, color.darkened(0.45), maxf(radius * 0.12, 1.0), true)

	var forward := Vector2.from_angle(angle)
	var side := forward.orthogonal()
	var tip := pos + forward * radius * 1.5
	var back := pos + forward * radius * 0.5
	draw_colored_polygon(
		PackedVector2Array([tip, back + side * radius * 0.5, back - side * radius * 0.5]),
		Color(1.0, 1.0, 1.0, 0.9),
	)
