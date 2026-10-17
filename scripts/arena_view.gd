class_name ArenaView
extends Node2D

## Presentation for [Arena]. Reads its geometry from the arena at startup and
## draws the floor, the warning track and the wall rim. Kept separate so the
## radii have exactly one definition.

const FLOOR_COLOR := Color(0.44, 0.34, 0.27)
const FLOOR_INNER := Color(0.49, 0.38, 0.30)
const WARNING_COLOR := Color(0.93, 0.72, 0.16, 0.80)
const RIM_COLOR := Color(0.97, 0.94, 0.86)
const VOID_COLOR := Color(0.05, 0.05, 0.07)

## Matches [constant Arena.SEGMENT_COUNT] so drawn wedges line up with collision.
const SEGMENTS := 96

## Seconds per pulse of the rim highlight.
const PULSE_SPEED := 2.2

## Amplitude of the rim pulse. 0 disables it.
const PULSE_AMOUNT := 0.35

var safe_radius: float = 420.0
var warning_radius: float = 600.0
var wall_thickness: float = 28.0

var _pulse := 0.0


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	# Void, then floor, then warning track and rim. Drawn back to front so each
	# layer covers the one before it.
	draw_circle(Vector2.ZERO, warning_radius, VOID_COLOR)
	draw_circle(Vector2.ZERO, warning_radius - wall_thickness, FLOOR_COLOR)
	_draw_ring(safe_radius, warning_radius - wall_thickness, WARNING_COLOR)

	var glow := 0.5 + 0.5 * sin(_pulse * TAU * PULSE_SPEED)
	var rim := RIM_COLOR
	rim.a = 1.0 - PULSE_AMOUNT * (1.0 - glow)
	_draw_ring(warning_radius - wall_thickness, warning_radius, rim)

	# Two shikiri-sen starting lines, mirroring real sumo.
	_draw_start_line(-PI * 0.5)
	_draw_start_line(PI * 0.5)


func _draw_ring(inner: float, outer: float, color: Color) -> void:
	if outer <= inner:
		return
	for wedge in Arena.ring_wedges(inner, outer, SEGMENTS):
		draw_colored_polygon(wedge, color)


func _draw_start_line(angle: float) -> void:
	var direction := Vector2.from_angle(angle)
	var a := direction * (safe_radius - 70.0)
	var b := direction * (safe_radius - 14.0)
	draw_line(a, b, RIM_COLOR, 5.0, true)