class_name FitCamera
extends Camera2D

## Keeps every active player framed by centring on the roster and zooming out to
## fit its spread.
##
## This is deliberately a plain implementation to satisfy Milestone 2's
## "players at opposite sides of the screen" endpoint. Milestone 6 supersedes
## it with tuned damping and impact shake.

## Slack around the roster so players are never flush against the viewport edge.
@export var padding: float = 1.4

## Never zoom in past 1:1.
@export var max_zoom: float = 1.0

## Never zoom out past this (smaller = further out).
@export var min_zoom: float = 0.45

## Higher converges faster. 0 disables easing.
@export var follow_speed: float = 7.0

## Extra world-space margin for a player's body beyond its centre.
@export var body_margin: float = 40.0

var _players: Array[Player] = []


func _ready() -> void:
	make_current()


## Starts following the players owned by [param manager]. Safe to call once.
func bind(manager: GameManager) -> void:
	if not manager.players_changed.is_connected(_on_players_changed):
		manager.players_changed.connect(_on_players_changed)
	_on_players_changed(manager.players)


func _on_players_changed(players: Array[Player]) -> void:
	_players = players


func _process(delta: float) -> void:
	if _players.is_empty():
		return

	var centre := Vector2.ZERO
	for player in _players:
		centre += player.global_position
	centre /= float(_players.size())

	var extent := 0.0
	for player in _players:
		extent = maxf(extent, player.global_position.distance_to(centre) + body_margin)

	var viewport := get_viewport_rect().size
	var half_needed := maxf(extent * padding, 1.0)
	var target := clampf(
		minf(viewport.x, viewport.y) / (2.0 * half_needed),
		min_zoom,
		max_zoom
	)

	var weight := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(centre, weight)
	zoom = zoom.lerp(Vector2.ONE * target, weight)